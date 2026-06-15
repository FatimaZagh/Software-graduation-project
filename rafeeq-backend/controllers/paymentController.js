const mongoose = require("mongoose");
const UserModel = require("../models/User");
const {
  listPatientSavedCards,
  upsertPatientSavedCard,
  getSavedCardForPatient,
  validateCvv,
  validateCardNumberDigits,
  validateExpiry,
  normalizeCardDigits,
  INVALID_CARD_DETAILS_MSG,
  formatCardForClient,
} = require("../services/savedCardService");
const {
  recordCheckoutPayment,
} = require("../services/paymentHistoryService");
const { listPatientPayments } = require("../controllers/patientPaymentsController");

function resolvePatientUserId(req) {
  return String(
    req.query?.patientUserId ||
      req.query?.patientId ||
      req.body?.patientUserId ||
      req.body?.patientId ||
      req.params?.patientUserId ||
      ""
  ).trim();
}

async function assertPatientUser(patientUserId) {
  if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
    const err = new Error("Valid patientUserId is required.");
    err.statusCode = 400;
    throw err;
  }
  const user = await UserModel.findById(patientUserId).select("_id role").lean();
  if (!user) {
    const err = new Error("Patient not found.");
    err.statusCode = 404;
    throw err;
  }
  return user;
}

function rejectInvalidCard(res) {
  return res.status(400).json({ message: INVALID_CARD_DETAILS_MSG });
}

/** GET /api/payments/saved-cards?patientUserId= */
exports.getSavedCards = async (req, res) => {
  try {
    const patientUserId = resolvePatientUserId(req);
    await assertPatientUser(patientUserId);
    const cards = await listPatientSavedCards(patientUserId);
    return res.json({ success: true, cards });
  } catch (error) {
    const status = error.statusCode || 500;
    if (status >= 500) console.error("[payments/saved-cards]", error);
    return res.status(status).json({ message: error.message || "Error loading saved cards." });
  }
};

/** GET /api/payments/history?patientUserId= */
exports.getPaymentHistory = async (req, res) => {
  try {
    const patientUserId = resolvePatientUserId(req);
    await assertPatientUser(patientUserId);

    const payload = await listPatientPayments(patientUserId);

    return res.json({
      success: true,
      transactions: payload.transactions || [],
      summary: payload.summary || {
        totalPaid: 0,
        currency: "ILS",
        transactionCount: 0,
      },
    });
  } catch (error) {
    const status = error.statusCode || 500;
    if (status >= 500) console.error("[payments/history]", error);
    return res.status(status).json({ message: error.message || "Error loading payment history." });
  }
};

/**
 * POST /api/payments/checkout
 * Saved card: { patientUserId, savedCardId, cvv, amount?, medicineName?, orderId? }
 * New card:   { patientUserId, cardholderName, cardNumber, expirationDate, cvv, saveCard?, amount?, medicineName?, orderId? }
 */
exports.processCheckout = async (req, res) => {
  try {
    const patientUserId = resolvePatientUserId(req);
    await assertPatientUser(patientUserId);

    const cvv = String(req.body?.cvv || "").trim();
    if (!validateCvv(cvv)) {
      return rejectInvalidCard(res);
    }

    const amount = Number(req.body?.amount) || 0;
    const medicineName = String(req.body?.medicineName || req.body?.medicationName || "").trim();
    const orderId = String(req.body?.orderId || "").trim();
    const orgId = String(req.body?.orgId || req.query?.orgId || "").trim();

    const savedCardId = String(req.body?.savedCardId || "").trim();

    if (savedCardId) {
      const card = await getSavedCardForPatient(patientUserId, savedCardId);
      if (!card) {
        return res.status(404).json({ message: "Saved card not found." });
      }

      const payment = await recordCheckoutPayment({
        patientUserId,
        amount,
        medicineName,
        orderId,
        cardLastFour: card.cardLastFour,
        orgId: orgId || null,
      });

      return res.json({
        success: true,
        paymentStatus: "Paid",
        cardholderName: card.cardholderName,
        cardLastFour: card.cardLastFour,
        maskedCardNumber: card.maskedCardNumber,
        savedCardId: String(card._id),
        usedSavedCard: true,
        paymentId: String(payment._id),
        transactionDate: payment.paidAt,
      });
    }

    const cardholderName = String(req.body?.cardholderName || "").trim();
    const cardNumber = String(req.body?.cardNumber || "");
    const expirationDate = String(req.body?.expirationDate || "").trim();
    const saveCard = req.body?.saveCard !== false;

    const digits = normalizeCardDigits(cardNumber);
    if (!validateCardNumberDigits(cardNumber)) {
      return rejectInvalidCard(res);
    }
    if (!validateExpiry(expirationDate)) {
      return res.status(400).json({ message: "Invalid expiration date. Use MM/YY." });
    }
    if (cardholderName.length < 2) {
      return res.status(400).json({ message: "Cardholder name is required." });
    }

    let savedCard = null;
    if (saveCard) {
      const result = await upsertPatientSavedCard({
        patientUserId,
        cardholderName,
        cardNumber: digits,
        expirationDate,
      });
      savedCard = result.card;
    }

    const lastFour = digits.slice(-4);

    const payment = await recordCheckoutPayment({
      patientUserId,
      amount,
      medicineName,
      orderId,
      cardLastFour: lastFour,
      orgId: orgId || null,
    });

    return res.status(201).json({
      success: true,
      paymentStatus: "Paid",
      cardholderName,
      cardLastFour: lastFour,
      maskedCardNumber: `**** **** **** ${lastFour}`,
      savedCardId: savedCard?.id || null,
      cardSaved: Boolean(savedCard),
      usedSavedCard: false,
      paymentId: String(payment._id),
      transactionDate: payment.paidAt,
    });
  } catch (error) {
    const status = error.statusCode || 500;
    if (status >= 500) console.error("[payments/checkout]", error);
    return res.status(status).json({ message: error.message || "Checkout failed." });
  }
};

/** POST /api/payments/saved-cards — optional explicit save without checkout */
exports.saveCard = async (req, res) => {
  try {
    const patientUserId = resolvePatientUserId(req);
    await assertPatientUser(patientUserId);

    const cvv = String(req.body?.cvv || "").trim();
    if (!validateCvv(cvv)) {
      return rejectInvalidCard(res);
    }

    if (!validateCardNumberDigits(req.body?.cardNumber)) {
      return rejectInvalidCard(res);
    }

    const result = await upsertPatientSavedCard({
      patientUserId,
      cardholderName: req.body?.cardholderName,
      cardNumber: req.body?.cardNumber,
      expirationDate: req.body?.expirationDate,
    });

    return res.status(result.created ? 201 : 200).json({
      success: true,
      card: result.card,
      created: result.created,
      message: result.created ? "Card saved successfully." : "Card already on file — details refreshed.",
    });
  } catch (error) {
    const status = error.statusCode || 500;
    if (status >= 500) console.error("[payments/save-card]", error);
    return res.status(status).json({ message: error.message || "Error saving card." });
  }
};

exports.formatCardForClient = formatCardForClient;
