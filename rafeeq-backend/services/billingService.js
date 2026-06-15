const mongoose = require("mongoose");
const Payment = require("../models/payment");
const PayrollSlip = require("../models/payrollSlip");
const UserModel = require("../models/User");
const Patient = require("../models/patient");
const Doctor = require("../models/doctor");
const Organization = require("../models/Organization");
const Clinic = require("../models/clinic");

function roundMoney(n) {
  return Math.round(Number(n) * 100) / 100;
}

function monthRange(date = new Date()) {
  const start = new Date(date.getFullYear(), date.getMonth(), 1);
  const end = new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
  return { start, end };
}

async function creditClinicRevenue({ orgId, clinicId, amount }) {
  const amt = roundMoney(amount);
  if (amt <= 0) return;
  if (orgId) {
    await Organization.findByIdAndUpdate(orgId, {
      $inc: { "billingSettings.totalRevenue": amt },
    });
  }
  if (clinicId) {
    await Clinic.findByIdAndUpdate(clinicId, { $inc: { totalRevenue: amt } });
  }
}

function isStrictObjectId(value) {
  return typeof value === "string" && /^[a-fA-F0-9]{24}$/.test(value.trim());
}

/**
 * Deduct consultation fee from patient wallet and record payment.
 */
async function deductSessionFee({
  patientUserId,
  doctorUserId,
  orgId,
  clinicId,
  amount,
  appointmentId,
  demoMode = false,
}) {
  const amt = roundMoney(amount);
  if (amt <= 0) throw Object.assign(new Error("Amount must be greater than zero"), { status: 400 });

  const patientOid = String(patientUserId || "").trim();
  if (!isStrictObjectId(patientOid)) {
    throw Object.assign(new Error("Valid patientUserId is required"), { status: 400 });
  }

  if (demoMode) {
    try {
      const payment = await Payment.create({
        orgId: orgId || null,
        clinicId: clinicId || null,
        patientUserId: patientOid,
        doctorUserId: doctorUserId || null,
        appointmentId:
          appointmentId && isStrictObjectId(String(appointmentId)) ? appointmentId : null,
        amount: amt,
        currency: "ILS",
        serviceType: "Consultation",
        type: "Consultation",
        description: "Consultation fee (demo patient ID)",
        status: "Paid",
        settlementStatus: "Unsettled",
        paidAt: new Date(),
      });
      return {
        payment: payment.toObject(),
        walletBalance: 0,
        demoMode: true,
      };
    } catch (e) {
      throw Object.assign(new Error("Unable to record demo consultation payment"), { status: 500 });
    }
  }

  if (appointmentId && isStrictObjectId(String(appointmentId))) {
    const existing = await Payment.findOne({
      appointmentId,
      serviceType: "Consultation",
      status: "Paid",
    }).lean();
    if (existing) {
      throw Object.assign(new Error("Consultation fee already deducted for this session"), {
        status: 409,
        code: "ALREADY_BILLED",
        payment: existing,
      });
    }
  }

  const patient = await UserModel.findOne({
    _id: patientOid,
    role: "Patient",
  }).lean();
  if (!patient) throw Object.assign(new Error("Patient not found"), { status: 404 });

  const balance = roundMoney(patient.walletBalance ?? 0);
  if (balance < amt) {
    throw Object.assign(
      new Error(`Insufficient wallet balance. Available: ${balance} ILS, required: ${amt} ILS`),
      { status: 402, code: "INSUFFICIENT_WALLET", walletBalance: balance, required: amt }
    );
  }

  const newBalance = roundMoney(balance - amt);
  const updatedPatient = await UserModel.findByIdAndUpdate(
    patientOid,
    { $set: { walletBalance: newBalance } },
    { new: true }
  );
  if (!updatedPatient) {
    throw Object.assign(new Error("Patient not found"), { status: 404 });
  }

  let payment;
  try {
    payment = await Payment.create({
      orgId: orgId || updatedPatient.orgId || null,
      clinicId: clinicId || updatedPatient.clinicId || null,
      patientUserId: patientOid,
      doctorUserId: doctorUserId || null,
      appointmentId: appointmentId || null,
      amount: amt,
      currency: "ILS",
      serviceType: "Consultation",
      type: "Consultation",
      description: "Consultation fee",
      status: "Paid",
      settlementStatus: "Unsettled",
      paidAt: new Date(),
    });
  } catch (e) {
    await UserModel.findByIdAndUpdate(patientOid, { $set: { walletBalance: balance } });
    if (e?.name === "ValidationError" || String(e?.message || "").includes("Cast to ObjectId")) {
      throw Object.assign(new Error("Invalid patient identifier for billing"), { status: 400 });
    }
    throw e;
  }

  await creditClinicRevenue({
    orgId: orgId || updatedPatient.orgId,
    clinicId: clinicId || updatedPatient.clinicId,
    amount: amt,
  });

  return {
    payment: payment.toObject(),
    walletBalance: updatedPatient.walletBalance,
  };
}

/** Record pharmacy sale into clinic/org revenue pool + Payment ledger. */
async function recordPharmacyClinicRevenue({
  patientUserId,
  orgId,
  clinicId,
  amount,
  medicationName,
  orderId,
  doctorUserId,
}) {
  const amt = roundMoney(amount);
  if (amt <= 0) return null;

  const payment = await Payment.create({
    orgId: orgId || null,
    clinicId: clinicId || null,
    patientUserId,
    doctorUserId: doctorUserId || null,
    amount: amt,
    currency: "ILS",
    serviceType: "Pharmacy",
    type: "Pharmacy",
    description: medicationName ? `Pharmacy — ${medicationName}` : "Pharmacy purchase",
    medicationName: medicationName || "",
    orderId: orderId ? String(orderId) : "",
    status: "Paid",
    settlementStatus: "Unsettled",
    paidAt: new Date(),
  });

  await creditClinicRevenue({ orgId, clinicId, amount: amt });
  return payment.toObject();
}

async function listOrgLedger(orgId, { limit = 300 } = {}) {
  const oid = new mongoose.Types.ObjectId(String(orgId));
  const payments = await Payment.find({ orgId: oid })
    .sort({ paidAt: -1, createdAt: -1 })
    .limit(limit)
    .lean();

  const patientIds = [...new Set(payments.map((p) => String(p.patientUserId)).filter(Boolean))];
  const [patients, users] = await Promise.all([
    Patient.find({ userId: { $in: patientIds } })
      .select("userId fullName")
      .lean(),
    UserModel.find({ _id: { $in: patientIds } })
      .select("name")
      .lean(),
  ]);
  const nameByUser = new Map();
  for (const p of patients) nameByUser.set(String(p.userId), p.fullName || "Patient");
  for (const u of users) {
    const id = String(u._id);
    if (!nameByUser.has(id)) nameByUser.set(id, u.name || "Patient");
  }

  return payments.map((p) => ({
    transactionId: p.transactionId || String(p._id),
    id: String(p._id),
    patientUserId: String(p.patientUserId),
    patientName: nameByUser.get(String(p.patientUserId)) || "Patient",
    doctorUserId: p.doctorUserId ? String(p.doctorUserId) : "",
    serviceType: p.serviceType || p.type || "Other",
    status: p.status || "Paid",
    amount: roundMoney(p.amount),
    currency: p.currency || "ILS",
    settlementStatus: p.settlementStatus || "Unsettled",
    paidAt: p.paidAt || p.createdAt,
    description: p.description || "",
  }));
}

async function getOrgBillingMetrics(orgId) {
  const oid = new mongoose.Types.ObjectId(String(orgId));
  const { start, end } = monthRange();
  const [monthlyPaid, allPaid, pending, org] = await Promise.all([
    Payment.aggregate([
      {
        $match: {
          orgId: oid,
          status: "Paid",
          paidAt: { $gte: start, $lte: end },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" }, count: { $sum: 1 } } },
    ]),
    Payment.aggregate([
      { $match: { orgId: oid, status: "Paid" } },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),
    Payment.countDocuments({ orgId: oid, status: "Pending" }),
    Organization.findById(orgId).select("billingSettings").lean(),
  ]);

  return {
    totalMonthlyClinicRevenue: roundMoney(monthlyPaid[0]?.total || 0),
    monthlyTransactionCount: monthlyPaid[0]?.count || 0,
    totalPaid: roundMoney(allPaid[0]?.total || 0),
    totalPending: pending,
    totalRevenuePool: roundMoney(org?.billingSettings?.totalRevenue || 0),
    commissionRate: org?.billingSettings?.clinicCommissionRate ?? 0.2,
    currency: "ILS",
    periodStart: start.toISOString(),
    periodEnd: end.toISOString(),
  };
}

async function previewDoctorPayroll(orgId, doctorUserId) {
  const oid = new mongoose.Types.ObjectId(String(orgId));
  const did = new mongoose.Types.ObjectId(String(doctorUserId));
  const org = await Organization.findById(orgId).select("billingSettings").lean();
  const rate = org?.billingSettings?.clinicCommissionRate ?? 0.2;

  const unsettledConsult = await Payment.find({
    orgId: oid,
    doctorUserId: did,
    serviceType: "Consultation",
    status: "Paid",
    settlementStatus: "Unsettled",
  }).lean();

  const unsettledPharmacy = await Payment.find({
    orgId: oid,
    doctorUserId: did,
    serviceType: "Pharmacy",
    status: "Paid",
    settlementStatus: "Unsettled",
  }).lean();

  const grossEarned = roundMoney(unsettledConsult.reduce((s, p) => s + (Number(p.amount) || 0), 0));
  const pharmacyRevenue = roundMoney(unsettledPharmacy.reduce((s, p) => s + (Number(p.amount) || 0), 0));
  const clinicShare = roundMoney(grossEarned * rate);
  const netPayout = roundMoney(grossEarned - clinicShare + pharmacyRevenue);

  const doctor = await Doctor.findOne({ userId: did }).select("displayName fullName").lean();
  const doctorName = doctor?.displayName || doctor?.fullName || "Doctor";

  return {
    doctorUserId: String(doctorUserId),
    doctorName,
    grossEarned,
    commissionRate: rate,
    clinicShare,
    pharmacyRevenue,
    netPayout,
    unsettledCount: unsettledConsult.length,
    pharmacyTransactionCount: unsettledPharmacy.length,
    currency: "ILS",
  };
}

async function generatePayrollSlip({ orgId, doctorUserId, adminUserId }) {
  const oid = new mongoose.Types.ObjectId(String(orgId));
  const did = new mongoose.Types.ObjectId(String(doctorUserId));
  const { start, end } = monthRange();
  const preview = await previewDoctorPayroll(orgId, doctorUserId);

  const unsettledConsult = await Payment.find({
    orgId: oid,
    doctorUserId: did,
    serviceType: "Consultation",
    status: "Paid",
    settlementStatus: "Unsettled",
  });

  const unsettledPharmacy = await Payment.find({
    orgId: oid,
    doctorUserId: did,
    serviceType: "Pharmacy",
    status: "Paid",
    settlementStatus: "Unsettled",
  });

  const allUnsettled = [...unsettledConsult, ...unsettledPharmacy];
  if (allUnsettled.length === 0) {
    throw Object.assign(new Error("No unsettled payments for this doctor"), { status: 409 });
  }

  const slip = await PayrollSlip.create({
    orgId: oid,
    doctorUserId: did,
    doctorName: preview.doctorName,
    periodStart: start,
    periodEnd: end,
    grossEarned: preview.grossEarned,
    commissionRate: preview.commissionRate,
    clinicShare: preview.clinicShare,
    pharmacyRevenue: preview.pharmacyRevenue,
    netPayout: preview.netPayout,
    currency: "ILS",
    transactionIds: allUnsettled.map((p) => p._id),
    generatedBy: adminUserId || null,
    status: "Generated",
  });

  await Payment.updateMany(
    { _id: { $in: allUnsettled.map((p) => p._id) } },
    { $set: { settlementStatus: "Settled", payrollSlipId: slip._id } }
  );

  return slip.toObject();
}

module.exports = {
  roundMoney,
  deductSessionFee,
  recordPharmacyClinicRevenue,
  listOrgLedger,
  getOrgBillingMetrics,
  previewDoctorPayroll,
  generatePayrollSlip,
  creditClinicRevenue,
};
