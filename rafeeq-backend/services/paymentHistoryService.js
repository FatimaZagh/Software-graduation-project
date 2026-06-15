const mongoose = require("mongoose");
const Payment = require("../models/payment");

/**
 * Persist a successful checkout row for payment history timeline.
 */
async function recordCheckoutPayment({
  patientUserId,
  amount = 0,
  medicineName = "",
  orderId = "",
  cardLastFour = "",
  orgId = null,
  currency = "ILS",
}) {
  const patientOid = new mongoose.Types.ObjectId(String(patientUserId));
  const paidAt = new Date();
  const name = String(medicineName || "").trim() || "Medication purchase";
  const lastFour = String(cardLastFour || "").replace(/\D/g, "").slice(-4);

  const doc = await Payment.create({
    patientUserId: patientOid,
    amount: Math.round(Number(amount) * 100) / 100 || 0,
    currency: currency || "ILS",
    description: name,
    medicationName: name,
    orderId: String(orderId || "").trim(),
    cardLastFour: lastFour,
    status: "Paid",
    paidAt,
    ...(orgId && mongoose.Types.ObjectId.isValid(String(orgId))
      ? { orgId: new mongoose.Types.ObjectId(String(orgId)) }
      : {}),
  });

  return doc.toObject();
}

async function listCheckoutPaymentsForPatient(patientUserId) {
  const patientOid = new mongoose.Types.ObjectId(String(patientUserId));
  const rows = await Payment.find({ patientUserId: patientOid })
    .sort({ paidAt: -1, createdAt: -1 })
    .limit(200)
    .lean();

  return rows.map((p) => ({
    id: String(p._id),
    medicationName: p.medicationName || p.description || "Healthcare payment",
    pharmacyName: "",
    amountPaid: Number(p.amount) || 0,
    currency: p.currency || "ILS",
    paymentStatus: p.status === "Failed" ? "Failed" : p.status === "Paid" ? "Paid" : "Pending",
    transactionDate: (p.paidAt || p.createdAt || new Date()).toISOString(),
    failureReason: "",
    cardLastFour: p.cardLastFour || "",
    orderId: p.orderId || "",
  }));
}

module.exports = {
  recordCheckoutPayment,
  listCheckoutPaymentsForPatient,
};
