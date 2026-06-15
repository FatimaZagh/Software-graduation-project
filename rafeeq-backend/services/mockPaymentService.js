const mongoose = require("mongoose");
const Drug = require("../models/drug");
const Pharmacy = require("../models/pharmacy");
const MedicationRequest = require("../models/medicationRequest");
const PharmacyOrderTransaction = require("../models/pharmacyOrderTransaction");
const PatientNotification = require("../models/patientNotification");
const prescriptionDispensing = require("./prescriptionDispensingService");
const pharmacyInventoryService = require("./pharmacyInventoryService");
const { recordPharmacyClinicRevenue } = require("./billingService");
const {
  splitOrderNotificationBody,
  splitOrderNotificationTitle,
  paymentSuccessTitle,
  paymentSuccessBody,
} = require("../utils/medicationOrderMessages");

function roundMoney(value) {
  return Math.round(Number(value) * 100) / 100;
}

function resolveInventoryItem(pharmacy, drugId) {
  if (!drugId || !mongoose.Types.ObjectId.isValid(drugId)) return null;
  const drugOid = new mongoose.Types.ObjectId(drugId);
  return (pharmacy.inventory || []).find((row) => {
    const id = row.drug_id?._id || row.drug_id;
    return id && new mongoose.Types.ObjectId(id).equals(drugOid);
  });
}

function resolveUnitPrice(pharmacy, drugId) {
  const item = resolveInventoryItem(pharmacy, drugId);
  return Number(item?.price ?? 0);
}

function resolveOrderAmount(pharmacy, drugId, quantity) {
  const unitPrice = resolveUnitPrice(pharmacy, drugId);
  const qty = Math.max(1, Number(quantity) || 1);
  return roundMoney(unitPrice * qty);
}

function resolvePatientLocale(request) {
  return String(request?.patientLocale || "en").trim() || "en";
}

async function notifyPatientPaymentSuccess(request, amount, pharmacyName) {
  if (!request?.patientUserId) return;
  const locale = resolvePatientLocale(request);
  try {
    await PatientNotification.create({
      patientUserId: request.patientUserId,
      type: "medication_request",
      title: paymentSuccessTitle(locale),
      body: paymentSuccessBody({
        medicationName: request.medicationName,
        amount,
        pharmacyName,
        locale,
      }),
      read: false,
      meta: {
        requestId: String(request._id),
        status: "Paid",
        amount,
        pharmacyId: request.pharmacyId ? String(request.pharmacyId) : null,
      },
    });
  } catch (_) {}
}

async function notifyPatientSplitOrder(request, { fulfilledQty, backorderQty }) {
  if (!request?.patientUserId) return;
  const locale = resolvePatientLocale(request);
  try {
    await PatientNotification.create({
      patientUserId: request.patientUserId,
      type: "PARTIAL_FULFILLMENT",
      title: splitOrderNotificationTitle(locale),
      body: splitOrderNotificationBody({
        medicationName: request.medicationName,
        fulfilledQty,
        backorderQty,
        locale,
      }),
      read: false,
      meta: {
        action: "PARTIAL_FULFILLMENT",
        requestId: String(request._id),
        status: "Backorder",
        fulfilledQuantity: fulfilledQty,
        backorderQuantity: backorderQty,
        medicationName: request.medicationName || "",
        drugId: request.drugId ? String(request.drugId) : null,
        pharmacyId: request.pharmacyId ? String(request.pharmacyId) : null,
      },
    });
  } catch (_) {}
}

async function notifyPatientPaymentFailed(request, reason) {
  if (!request?.patientUserId) return;
  const locale = resolvePatientLocale(request);
  const isAr = locale === "ar" || locale.startsWith("ar");
  try {
    await PatientNotification.create({
      patientUserId: request.patientUserId,
      type: "medication_request",
      title: isAr ? "فشل الدفع" : "Payment failed",
      body: isAr
        ? `تعذر إتمام الدفع لـ ${request.medicationName}. ${reason || "يرجى المحاولة لاحقاً."}`
        : `We could not complete payment for ${request.medicationName}. ${reason || "Please try again or contact the pharmacy."}`,
      read: false,
      meta: {
        requestId: String(request._id),
        status: "Failed",
      },
    });
  } catch (_) {}
}

async function recordPurchaseLedger({ request, rxContext, fulfillQty, phDoc, performedBy }) {
  const routing = require("./pharmacyRoutingService");
  let doctorName = "";
  if (rxContext?.requiresPrescription && rxContext.prescriptionId) {
    doctorName = await routing.resolveDoctorNameForPrescription(rxContext.prescriptionId);
  }
  await routing.recordPatientPurchase({
    patientUserId: request.patientUserId,
    orgId: request.orgId ? String(request.orgId) : null,
    drug: rxContext.drug,
    quantity: fulfillQty,
    pharmacy: phDoc.toObject ? phDoc.toObject() : phDoc,
    requiresPrescription: Boolean(rxContext?.requiresPrescription),
    prescribingDoctorName: doctorName,
    prescriptionId: rxContext?.prescriptionId || null,
    source: "pharmacist_fulfillment",
  });
}

/**
 * Core fulfillment: deduct stock, credit wallet, log transaction, update request.
 */
async function executeFulfillment({
  existing,
  phDoc,
  fulfillQty,
  rxContext,
  performedBy,
  lastFour,
  isSplit,
  backorderQty,
}) {
  const unitPrice = resolveUnitPrice(phDoc, existing.drugId);
  const amount = roundMoney(unitPrice * fulfillQty);

  if (rxContext?.requiresPrescription && rxContext.prescriptionItemId) {
    await prescriptionDispensing.recordDispensingOnItem({
      prescriptionItemId: rxContext.prescriptionItemId,
      quantity: fulfillQty,
    });
  }

  await pharmacyInventoryService.dispenseDrug({
    pharmacyId: phDoc._id,
    drugId: existing.drugId,
    amount: fulfillQty,
    performedBy,
  });

  const walletPharmacy = await Pharmacy.findById(phDoc._id);
  walletPharmacy.wallet_balance = roundMoney(Number(walletPharmacy.wallet_balance || 0) + amount);
  await walletPharmacy.save();

  const txPayload = {
    orderId: existing._id,
    pharmacyId: phDoc._id,
    patientUserId: existing.patientUserId,
    amount,
    currency: "ILS",
    status: "Mock Processing",
    cardLastFour: lastFour,
  };

  let paymentTx = await PharmacyOrderTransaction.create(txPayload);
  paymentTx.status = "Paid";
  await paymentTx.save();

  const lineItems = [
    {
      lineType: "Fulfilled",
      quantity: fulfillQty,
      status: "Paid",
      amount,
    },
  ];
  if (isSplit && backorderQty > 0) {
    lineItems.push({
      lineType: "Backorder",
      quantity: backorderQty,
      status: "Backorder",
      amount: 0,
    });
  }

  const updatePayload = {
    status: isSplit ? "Partially Fulfilled" : "Paid",
    amount,
    fulfilledQuantity: fulfillQty,
    backorderQuantity: isSplit ? backorderQty : 0,
    lineItems,
    transactionId: paymentTx._id,
    cardLastFour: lastFour,
    paidAt: new Date(),
    failureReason: "",
  };

  const updatedRequest = await MedicationRequest.findByIdAndUpdate(
    existing._id,
    { $set: updatePayload },
    { new: true, runValidators: true }
  );

  await recordPurchaseLedger({
    request: existing,
    rxContext,
    fulfillQty,
    phDoc,
    performedBy,
  });

  if (phDoc.pharmacyType === "Internal" || phDoc.orgId) {
    try {
      await recordPharmacyClinicRevenue({
        patientUserId: existing.patientUserId,
        orgId: phDoc.orgId,
        clinicId: phDoc.clinicId,
        amount,
        medicationName: existing.medicationName || "",
        orderId: String(existing._id),
      });
    } catch (revErr) {
      console.error("[mockPayment] clinic revenue credit failed:", revErr.message);
    }
  }

  return {
    request: updatedRequest.toObject ? updatedRequest.toObject() : updatedRequest,
    paymentTx: paymentTx.toObject ? paymentTx.toObject() : paymentTx,
    pharmacyName: phDoc.name,
    amount,
    fulfilledQty: fulfillQty,
    backorderQty: isSplit ? backorderQty : 0,
    isSplit,
  };
}

/**
 * Approve a pending medication request with optional partial fulfillment + backorder split.
 */
async function approveMedicationRequestWithPayment(
  requestId,
  { pharmacyId: scopePharmacyId, performedBy = "", cardLastFour = "4242" } = {}
) {
  if (!requestId || !mongoose.Types.ObjectId.isValid(requestId)) {
    const err = new Error("Valid requestId is required.");
    err.statusCode = 400;
    throw err;
  }

  const existing = await MedicationRequest.findById(requestId);
  if (!existing) return null;

  if (scopePharmacyId && existing.pharmacyId && String(existing.pharmacyId) !== String(scopePharmacyId)) {
    const err = new Error("This medication request belongs to another pharmacy.");
    err.statusCode = 403;
    throw err;
  }

  const currentStatus = String(existing.status || "Pending");
  if (currentStatus === "Paid" || currentStatus === "Partially Fulfilled") {
    return pharmacyInventoryService.formatMedicationRequestRecord(existing.toObject());
  }
  if (currentStatus !== "Pending") {
    const err = new Error(`Only Pending requests can be approved. Current status: ${currentStatus}`);
    err.statusCode = 409;
    throw err;
  }

  if (!existing.drugId) {
    const err = new Error("Request is missing drugId — cannot verify inventory or price.");
    err.statusCode = 400;
    throw err;
  }

  const pharmacy = await Pharmacy.findById(existing.pharmacyId);
  if (!pharmacy) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  const requestedQty = Math.max(1, Number(existing.requestedQuantity || existing.quantity) || 1);
  const inventoryItem = resolveInventoryItem(pharmacy, existing.drugId);
  if (!inventoryItem) {
    await markRequestFailed(existing, pharmacy, {
      reason: "Drug not found in pharmacy inventory.",
      cardLastFour,
    });
    return;
  }

  const availableStock = Math.max(0, Number(inventoryItem.quantity) || 0);
  if (availableStock <= 0) {
    await markRequestFailed(existing, pharmacy, {
      reason: "Out of stock at this pharmacy.",
      cardLastFour,
    });
    return;
  }

  const isSplit = requestedQty > availableStock;
  const fulfillQty = isSplit ? availableStock : requestedQty;
  const backorderQty = isSplit ? requestedQty - availableStock : 0;
  const lastFour = String(cardLastFour || "4242").replace(/\D/g, "").slice(-4) || "4242";

  let rxContext = null;
  try {
    rxContext = await prescriptionDispensing.validatePatientPurchase({
      patientUserId: existing.patientUserId,
      drugId: existing.drugId,
      medicationName: existing.medicationName,
      quantity: fulfillQty,
    });
  } catch (rxErr) {
    await markRequestFailed(existing, pharmacy, {
      reason: rxErr.message || "Prescription validation failed.",
      cardLastFour: lastFour,
    });
    return;
  }

  const phDoc = await Pharmacy.findById(existing.pharmacyId);
  if (!phDoc) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  const item = resolveInventoryItem(phDoc, existing.drugId);
  const liveStock = Math.max(0, Number(item?.quantity) || 0);
  if (liveStock <= 0) {
    const err = new Error("Out of stock at this pharmacy.");
    err.statusCode = 409;
    throw err;
  }

  const liveRequested = Math.max(1, Number(existing.requestedQuantity || existing.quantity) || 1);
  const liveSplit = liveRequested > liveStock;
  const liveFulfill = liveSplit ? liveStock : liveRequested;
  const liveBackorder = liveSplit ? liveRequested - liveStock : 0;

  const result = await executeFulfillment({
    existing,
    phDoc,
    fulfillQty: liveFulfill,
    rxContext,
    performedBy,
    lastFour,
    isSplit: liveSplit,
    backorderQty: liveBackorder,
  });

  if (result.isSplit) {
    await notifyPatientSplitOrder(result.request, {
      fulfilledQty: result.fulfilledQty,
      backorderQty: result.backorderQty,
    });
  } else {
    await notifyPatientPaymentSuccess(result.request, result.amount, result.pharmacyName);
  }

  const refreshedPharmacy = await Pharmacy.findById(existing.pharmacyId).select("wallet_balance").lean();

  return {
    ...pharmacyInventoryService.formatMedicationRequestRecord(result.request),
    payment: {
      id: String(result.paymentTx._id),
      amount: result.amount,
      status: result.paymentTx.status,
      cardLastFour: result.paymentTx.cardLastFour,
    },
    walletBalance: roundMoney(Number(refreshedPharmacy?.wallet_balance ?? 0)),
    split: result.isSplit
      ? {
          fulfilledQuantity: result.fulfilledQty,
          backorderQuantity: result.backorderQty,
        }
      : null,
  };
}

async function markRequestFailed(request, pharmacy, { reason, cardLastFour }) {
  const qty = Math.max(1, Number(request.quantity) || 1);
  const amount = resolveOrderAmount(pharmacy, request.drugId, qty);
  const lastFour = String(cardLastFour || "4242").replace(/\D/g, "").slice(-4) || "4242";

  let paymentTx = null;
  try {
    paymentTx = await PharmacyOrderTransaction.create({
      orderId: request._id,
      pharmacyId: pharmacy._id,
      patientUserId: request.patientUserId,
      amount,
      currency: "ILS",
      status: "Failed",
      cardLastFour: lastFour,
      failureReason: reason || "Payment could not be processed.",
    });
  } catch (_) {}

  const updated = await MedicationRequest.findByIdAndUpdate(
    request._id,
    {
      $set: {
        status: "Failed",
        amount,
        transactionId: paymentTx?._id || null,
        failureReason: reason || "Payment could not be processed.",
      },
    },
    { new: true, runValidators: true }
  ).lean();

  await notifyPatientPaymentFailed(updated || request.toObject(), reason);

  const formatted = pharmacyInventoryService.formatMedicationRequestRecord(updated);
  const err = new Error(reason || "Payment failed.");
  err.statusCode = 409;
  err.request = formatted;
  err.payment = paymentTx
    ? {
        id: String(paymentTx._id),
        amount,
        status: "Failed",
        cardLastFour: lastFour,
      }
    : null;
  throw err;
}

module.exports = {
  approveMedicationRequestWithPayment,
  resolveOrderAmount,
  roundMoney,
};
