const mongoose = require("mongoose");
const Payment = require("../models/payment");
const PharmacyOrderTransaction = require("../models/pharmacyOrderTransaction");
const MedicationRequest = require("../models/medicationRequest");
const Pharmacy = require("../models/pharmacy");
const UserModel = require("../models/User");

function normalizePaymentStatus(raw) {
  const s = String(raw || "").trim();
  if (s === "Paid" || s === "Dispensed" || s === "Approved") return "Paid";
  if (s === "Failed" || s === "Rejected") return "Failed";
  return "Pending";
}

function mapTransactionRow({
  id,
  transactionId,
  medicationName,
  pharmacyName,
  amountPaid,
  paymentStatus,
  transactionDate,
  failureReason,
  currency,
  serviceType,
}) {
  return {
    id: id ? String(id) : null,
    transactionId: transactionId || (id ? String(id) : null),
    medicationName: medicationName || "Healthcare payment",
    pharmacyName: pharmacyName || "",
    serviceType: serviceType || "Other",
    amountPaid: Number(amountPaid) || 0,
    currency: currency || "ILS",
    paymentStatus,
    transactionDate: transactionDate ? new Date(transactionDate).toISOString() : null,
    failureReason: failureReason || "",
  };
}

async function buildPharmacyTransactionRows(patientUserId) {
  const patientOid = new mongoose.Types.ObjectId(patientUserId);

  const [txRows, orderRows] = await Promise.all([
    PharmacyOrderTransaction.find({ patientUserId: patientOid })
      .sort({ createdAt: -1 })
      .limit(200)
      .lean(),
    MedicationRequest.find({
      patientUserId: patientOid,
      status: { $in: ["Paid", "Failed", "Pending", "Mock Processing"] },
    })
      .sort({ createdAt: -1 })
      .limit(200)
      .lean(),
  ]);

  const pharmacyIds = [
    ...new Set(
      [...txRows, ...orderRows]
        .map((r) => r.pharmacyId)
        .filter(Boolean)
        .map(String)
    ),
  ].map((id) => new mongoose.Types.ObjectId(id));

  const orderIdsFromTx = txRows.map((t) => t.orderId).filter(Boolean);

  const extraOrders =
    orderIdsFromTx.length > 0
      ? await MedicationRequest.find({ _id: { $in: orderIdsFromTx } }).lean()
      : [];

  const pharmacies = pharmacyIds.length
    ? await Pharmacy.find({ _id: { $in: pharmacyIds } })
        .select("name")
        .lean()
    : [];

  const pharmacyNameById = new Map(pharmacies.map((p) => [String(p._id), p.name || "Pharmacy"]));
  const orderById = new Map(
    [...orderRows, ...extraOrders].map((o) => [String(o._id), o])
  );

  const seen = new Set();
  const results = [];

  for (const tx of txRows) {
    const order = orderById.get(String(tx.orderId)) || {};
    const key = `tx:${tx._id}`;
    if (seen.has(key)) continue;
    seen.add(key);

    results.push(
      mapTransactionRow({
        id: tx._id,
        medicationName: order.medicationName || "Medication order",
        pharmacyName: pharmacyNameById.get(String(tx.pharmacyId)) || "",
        amountPaid: tx.amount ?? order.amount ?? 0,
        paymentStatus: normalizePaymentStatus(tx.status),
        transactionDate: tx.createdAt || order.paidAt || order.createdAt,
        failureReason: tx.failureReason || order.failureReason || "",
        currency: tx.currency || "ILS",
        serviceType: "Pharmacy",
      })
    );
  }

  for (const order of orderRows) {
    const key = `order:${order._id}`;
    if (seen.has(key)) continue;
    const linkedTx = txRows.find((t) => String(t.orderId) === String(order._id));
    if (linkedTx) continue;
    seen.add(key);

    results.push(
      mapTransactionRow({
        id: order._id,
        medicationName: order.medicationName || "Medication order",
        pharmacyName: pharmacyNameById.get(String(order.pharmacyId)) || "",
        amountPaid: order.amount ?? 0,
        paymentStatus: normalizePaymentStatus(order.status || order.patientPaymentStatus),
        transactionDate: order.paidAt || order.updatedAt || order.createdAt,
        failureReason: order.failureReason || "",
        currency: "ILS",
        serviceType: "Pharmacy",
      })
    );
  }

  return results;
}

async function buildLegacyPaymentRows(patientUserId) {
  const patientOid = new mongoose.Types.ObjectId(patientUserId);
  const rows = await Payment.find({ patientUserId: patientOid })
    .sort({ paidAt: -1 })
    .limit(100)
    .lean();

  return rows.map((p) =>
    mapTransactionRow({
      id: p._id,
      transactionId: p.transactionId,
      medicationName:
        p.serviceType === "Consultation"
          ? p.description || "Consultation fee"
          : p.medicationName || p.description || "Clinic payment",
      pharmacyName: p.serviceType === "Pharmacy" ? "Rafeeq Pharmacy" : "Rafeeq Clinic",
      amountPaid: p.amount,
      paymentStatus: normalizePaymentStatus(p.status),
      transactionDate: p.paidAt || p.createdAt,
      failureReason: "",
      currency: p.currency || "ILS",
      serviceType: p.serviceType || p.type || "Other",
    })
  );
}

async function listPatientPayments(patientUserId) {
  const [pharmacyRows, legacyRows] = await Promise.all([
    buildPharmacyTransactionRows(patientUserId),
    buildLegacyPaymentRows(patientUserId),
  ]);

  const merged = [...pharmacyRows, ...legacyRows].sort((a, b) => {
    const da = a.transactionDate ? new Date(a.transactionDate).getTime() : 0;
    const db = b.transactionDate ? new Date(b.transactionDate).getTime() : 0;
    return db - da;
  });

  const totalPaid = merged
    .filter((r) => r.paymentStatus === "Paid")
    .reduce((sum, r) => sum + (Number(r.amountPaid) || 0), 0);

  return {
    transactions: merged,
    summary: {
      totalPaid: Math.round(totalPaid * 100) / 100,
      currency: "ILS",
      transactionCount: merged.length,
    },
  };
}

exports.getPatientPayments = async (req, res) => {
  try {
    const patientUserId =
      req.params.patientUserId ||
      req.params.patientId ||
      String(req.query.patientId || req.query.patientUserId || "").trim();

    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Valid patientId is required." });
    }

    const user = await UserModel.findById(patientUserId).select("_id role").lean();
    if (!user) {
      return res.status(404).json({ message: "Patient not found." });
    }

    const payload = await listPatientPayments(patientUserId);
    return res.json(payload);
  } catch (error) {
    console.error("[patient/payments]", error);
    return res.status(500).json({ message: "Error fetching payment history." });
  }
};

exports.listPatientPayments = listPatientPayments;
