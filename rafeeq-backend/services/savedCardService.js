const crypto = require("crypto");
const mongoose = require("mongoose");
const PatientSavedCard = require("../models/patientSavedCard");

function normalizeCardDigits(cardNumber) {
  return String(cardNumber || "").replace(/\D/g, "");
}

function buildCardFingerprint(patientUserId, cardDigits) {
  return crypto
    .createHash("sha256")
    .update(`${String(patientUserId)}:${cardDigits}`)
    .digest("hex");
}

function maskCardNumber(lastFour) {
  return `**** **** **** ${lastFour}`;
}

function validateCvv(cvv) {
  return /^\d{3,4}$/.test(String(cvv || "").trim());
}

function validateCardNumberDigits(cardNumber) {
  const digits = normalizeCardDigits(cardNumber);
  return digits.length === 16 && /^\d{16}$/.test(digits);
}

const INVALID_CARD_DETAILS_MSG =
  "Invalid card details. Please check your card number and CVV.";

function validateExpiry(expirationDate) {
  const match = String(expirationDate || "")
    .trim()
    .match(/^(0[1-9]|1[0-2])\/(\d{2})$/);
  if (!match) return false;
  const year = parseInt(match[2], 10);
  const now = new Date();
  const currentYY = now.getFullYear() % 100;
  const currentMM = now.getMonth() + 1;
  const expMM = parseInt(match[1], 10);
  if (year < currentYY) return false;
  if (year === currentYY && expMM < currentMM) return false;
  return true;
}

function formatCardForClient(doc) {
  if (!doc) return null;
  const row = doc.toObject ? doc.toObject() : doc;
  return {
    id: String(row._id),
    cardholderName: row.cardholderName || "",
    expirationDate: row.expirationDate || "",
    maskedCardNumber: row.maskedCardNumber || "",
    cardLastFour: row.cardLastFour || "",
  };
}

async function listPatientSavedCards(patientUserId) {
  const rows = await PatientSavedCard.find({ patientUserId })
    .sort({ updatedAt: -1, createdAt: -1 })
    .lean();
  return rows.map((row) => ({
    id: String(row._id),
    cardholderName: row.cardholderName || "",
    expirationDate: row.expirationDate || "",
    maskedCardNumber: row.maskedCardNumber || "",
    cardLastFour: row.cardLastFour || "",
  }));
}

/**
 * Save card for patient if fingerprint is new; otherwise refresh metadata only.
 * NEVER persists CVV or full card number.
 */
async function upsertPatientSavedCard({
  patientUserId,
  cardholderName,
  cardNumber,
  expirationDate,
}) {
  const digits = normalizeCardDigits(cardNumber);
  if (digits.length !== 16) {
    const err = new Error("Card number must be exactly 16 digits.");
    err.statusCode = 400;
    throw err;
  }
  if (!validateExpiry(expirationDate)) {
    const err = new Error("Invalid expiration date. Use MM/YY.");
    err.statusCode = 400;
    throw err;
  }

  const name = String(cardholderName || "").trim();
  if (name.length < 2) {
    const err = new Error("Cardholder name is required.");
    err.statusCode = 400;
    throw err;
  }

  const patientOid = new mongoose.Types.ObjectId(String(patientUserId));
  const lastFour = digits.slice(-4);
  const fingerprint = buildCardFingerprint(patientUserId, digits);

  const existing = await PatientSavedCard.findOne({
    patientUserId: patientOid,
    cardFingerprint: fingerprint,
  });

  if (existing) {
    existing.cardholderName = name;
    existing.expirationDate = String(expirationDate).trim();
    existing.maskedCardNumber = maskCardNumber(lastFour);
    existing.cardLastFour = lastFour;
    await existing.save();
    return { card: formatCardForClient(existing), created: false };
  }

  const created = await PatientSavedCard.create({
    patientUserId: patientOid,
    cardholderName: name,
    expirationDate: String(expirationDate).trim(),
    maskedCardNumber: maskCardNumber(lastFour),
    cardLastFour: lastFour,
    cardFingerprint: fingerprint,
  });

  return { card: formatCardForClient(created), created: true };
}

async function getSavedCardForPatient(patientUserId, savedCardId) {
  if (!mongoose.Types.ObjectId.isValid(savedCardId)) return null;
  return PatientSavedCard.findOne({
    _id: savedCardId,
    patientUserId,
  }).lean();
}

module.exports = {
  normalizeCardDigits,
  validateCvv,
  validateCardNumberDigits,
  validateExpiry,
  INVALID_CARD_DETAILS_MSG,
  formatCardForClient,
  listPatientSavedCards,
  upsertPatientSavedCard,
  getSavedCardForPatient,
};
