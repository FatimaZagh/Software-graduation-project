const billing = require("../services/billingService");
const mongoose = require("mongoose");
const { resolveDoctorBillingConfig } = require("../utils/billingConfig");

function isStrictObjectId(value) {
  return typeof value === "string" && /^[a-fA-F0-9]{24}$/.test(value.trim());
}

function normalizePatientUserId(raw) {
  let validPatientId = String(raw || "").trim();
  if (!isStrictObjectId(validPatientId)) {
    validPatientId = String(new mongoose.Types.ObjectId());
  }
  return validPatientId;
}

function doctorScope(req) {
  return req.doctorScope || {};
}

function adminScope(req) {
  return req.orgAdminScope || req.scoped || {};
}

/** POST /api/billing/deduct-session — doctor ends consultation with fee deduction */
async function deductSession(req, res) {
  const { orgId, doctorUserId, doctorProfile } = doctorScope(req);
  const body = req.body || {};
  const rawPatientId = body.patientUserId || body.patientId;
  const patientUserId = normalizePatientUserId(rawPatientId);
  const isDemoPatientId = !isStrictObjectId(String(rawPatientId || "").trim());
  const amount = body.amount;
  const appointmentId = body.appointmentId || null;
  const clinicId = body.clinicId || null;

  if (!rawPatientId) {
    return res.status(400).json({ success: false, message: "patientUserId (or patientId) is required" });
  }

  let fee = Number(amount);
  if (!Number.isFinite(fee) || fee <= 0) {
    const cfg = await resolveDoctorBillingConfig(doctorUserId);
    fee = cfg.consultationFee;
  }
  if (!Number.isFinite(fee) || fee <= 0) {
    const { BASELINE_CONSULTATION_FEE } = require("../utils/billingConfig");
    fee = BASELINE_CONSULTATION_FEE;
  }

  try {
    const result = await billing.deductSessionFee({
      patientUserId,
      doctorUserId,
      orgId,
      clinicId: clinicId || doctorProfile?.clinicId || null,
      amount: fee,
      appointmentId: appointmentId || null,
      demoMode: isDemoPatientId,
    });
    return res.status(200).json({
      success: true,
      message: "Success",
      feeDeducted: Number(fee),
      patientUserId: String(patientUserId),
      doctorUserId: String(doctorUserId),
      amount: Number(fee),
      currency: "ILS",
      demoMode: isDemoPatientId,
      payment: result.payment,
      walletBalance: Number(result.walletBalance) || 0,
    });
  } catch (e) {
    console.error("[billing/deduct-session]", e);
    const status = e.status || 500;
    return res.status(status).json({
      success: false,
      message: e.message || "Billing failed",
      error: e.message || "Billing failed",
      code: e.code,
      walletBalance: e.walletBalance,
      required: e.required,
    });
  }
}

/** GET /api/admin/billing/ledger */
async function getLedger(req, res, scoped) {
  try {
    const orgId = scoped.orgId;
    const ledger = await billing.listOrgLedger(orgId);
    res.json(
      ledger.map((row) => ({
        ...row,
        amount: Number(row.amount) || 0,
      }))
    );
  } catch (e) {
    console.error("[billing/ledger]", e);
    res.status(500).json({ success: false, message: e.message || "Error loading ledger" });
  }
}

/** GET /api/admin/billing/metrics — enhanced metrics */
async function getMetrics(req, res, scoped) {
  try {
    const metrics = await billing.getOrgBillingMetrics(scoped.orgId);
    res.json({
      success: true,
      ...metrics,
      totalPaid: Number(metrics.totalPaid) || 0,
      totalPending: Number(metrics.totalPending) || 0,
      totalMonthlyClinicRevenue: Number(metrics.totalMonthlyClinicRevenue) || 0,
      totalRevenuePool: Number(metrics.totalRevenuePool) || 0,
      commissionRate: Number(metrics.commissionRate) || 0.2,
    });
  } catch (e) {
    console.error("[billing/metrics]", e);
    res.status(500).json({ success: false, message: e.message || "Error loading billing metrics" });
  }
}

/** GET /api/admin/billing/payroll/preview?doctorUserId= */
async function previewPayroll(req, res, scoped) {
  try {
    const doctorUserId = String(req.query.doctorUserId || "").trim();
    if (!doctorUserId) {
      return res.status(400).json({ success: false, message: "doctorUserId query required" });
    }
    const preview = await billing.previewDoctorPayroll(scoped.orgId, doctorUserId);
    return res.json({ success: true, ...preview });
  } catch (e) {
    console.error("[billing/payroll/preview]", e);
    return res.status(e.status || 500).json({
      success: false,
      message: e.message || "Payroll preview failed",
    });
  }
}

/** POST /api/admin/billing/payroll/generate */
async function generatePayroll(req, res, scoped) {
  const doctorUserId = req.body?.doctorUserId;
  if (!doctorUserId) {
    return res.status(400).json({ success: false, message: "doctorUserId required" });
  }
  try {
    const slip = await billing.generatePayrollSlip({
      orgId: scoped.orgId,
      doctorUserId,
      adminUserId: scoped.userId || scoped.user?._id,
    });
    return res.status(201).json({ success: true, slip });
  } catch (e) {
    console.error("[billing/payroll/generate]", e);
    return res.status(e.status || 500).json({
      success: false,
      message: e.message || "Payroll generation failed",
    });
  }
}

/** GET /api/admin/billing/payroll/slips */
async function listPayrollSlips(req, res, scoped) {
  const PayrollSlip = require("../models/payrollSlip");
  const q = { orgId: scoped.orgId };
  if (req.query.doctorUserId) q.doctorUserId = req.query.doctorUserId;
  const list = await PayrollSlip.find(q).sort({ createdAt: -1 }).limit(100).lean();
  res.json(list);
}

/** GET doctor active billing config for mobile */
async function getDoctorFee(req, res) {
  try {
    const { doctorUserId } = doctorScope(req);
    const cfg = await resolveDoctorBillingConfig(doctorUserId);
    const consultationFee = cfg.consultationFee ? Number(cfg.consultationFee) : 0;
    res.json({
      success: true,
      consultationFee: Number.isFinite(consultationFee) ? consultationFee : 0,
      clinicName: cfg.clinicName || "",
      specializedServices: Array.isArray(cfg.specializedServices) ? cfg.specializedServices : [],
      hasInternalPharmacy: Boolean(cfg.hasInternalPharmacy),
      currency: "ILS",
    });
  } catch (e) {
    console.error("[billing/consultation-fee]", e);
    res.status(500).json({ success: false, message: e.message || "Error loading consultation fee" });
  }
}

module.exports = {
  deductSession,
  getLedger,
  getMetrics,
  previewPayroll,
  generatePayroll,
  listPayrollSlips,
  getDoctorFee,
};
