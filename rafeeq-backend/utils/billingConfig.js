const Doctor = require("../models/doctor");
const Clinic = require("../models/clinic");

const DEFAULT_SPECIALIZED_SERVICES = [
  { key: "follow_up", name: "Follow-up Visit", price: 75, enabled: true },
  { key: "emergency", name: "Emergency Consultation", price: 200, enabled: true },
  { key: "online", name: "Online Consultation", price: 80, enabled: true },
  { key: "home_visit", name: "Home Visit", price: 250, enabled: false },
];

/** Standard baseline when doctor has not configured a positive fee yet. */
const BASELINE_CONSULTATION_FEE = 100;

function roundMoney(n) {
  return Math.round(Number(n) * 100) / 100;
}

function sanitizeServices(raw) {
  if (!Array.isArray(raw)) return DEFAULT_SPECIALIZED_SERVICES.map((s) => ({ ...s }));
  const out = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const name = String(item.name || "").trim();
    if (!name) continue;
    const price = roundMoney(item.price);
    if (price < 0) continue;
    out.push({
      key: String(item.key || name.toLowerCase().replace(/\s+/g, "_")).slice(0, 64),
      name: name.slice(0, 120),
      price,
      enabled: item.enabled !== false,
    });
  }
  return out.length ? out : DEFAULT_SPECIALIZED_SERVICES.map((s) => ({ ...s }));
}

function parseFeeValue(raw) {
  if (raw == null || raw === "") return null;
  const n = roundMoney(raw);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function resolveFeeFromDoctor(doc, baseline = BASELINE_CONSULTATION_FEE) {
  if (!doc) return baseline;
  // Prefer top-level consultationFee, then nested clinicServicesConfig — skip zero/null.
  const candidates = [doc.consultationFee, doc.clinicServicesConfig?.consultationFee];
  for (const raw of candidates) {
    const fee = parseFeeValue(raw);
    if (fee != null) return fee;
  }
  return baseline;
}

async function resolveDoctorBillingConfig(doctorUserId) {
  const doc = await Doctor.findOne({ userId: doctorUserId })
    .select("consultationFee clinicServicesConfig clinicId currentClinic")
    .lean();
  if (!doc) {
    return {
      clinicName: "",
      clinicId: null,
      consultationFee: BASELINE_CONSULTATION_FEE,
      specializedServices: DEFAULT_SPECIALIZED_SERVICES.map((s) => ({ ...s })),
      hasInternalPharmacy: false,
    };
  }

  let clinicName =
    doc.clinicServicesConfig?.clinicName ||
    doc.currentClinic ||
    "";
  let hasInternalPharmacy = false;
  let clinicServices = [];

  if (doc.clinicId) {
    const clinic = await Clinic.findById(doc.clinicId)
      .select("name servicePricing defaultConsultationFee hasInternalPharmacy")
      .lean();
    if (clinic) {
      clinicName = clinicName || clinic.name || "";
      hasInternalPharmacy = Boolean(clinic.hasInternalPharmacy);
      if (Array.isArray(clinic.servicePricing) && clinic.servicePricing.length) {
        clinicServices = sanitizeServices(clinic.servicePricing);
      }
    }
  }

  const doctorServices = sanitizeServices(doc.clinicServicesConfig?.specializedServices);
  const specializedServices = doctorServices.length ? doctorServices : clinicServices;

  let consultationFee = resolveFeeFromDoctor(doc);
  if (consultationFee <= 0 && doc.clinicId) {
    const clinic = await Clinic.findById(doc.clinicId).select("defaultConsultationFee").lean();
    const clinicFee = parseFeeValue(clinic?.defaultConsultationFee);
    if (clinicFee != null) consultationFee = clinicFee;
  }
  if (consultationFee <= 0) consultationFee = BASELINE_CONSULTATION_FEE;

  return {
    clinicName,
    clinicId: doc.clinicId ? String(doc.clinicId) : null,
    consultationFee,
    specializedServices,
    hasInternalPharmacy,
  };
}

async function saveDoctorClinicServices(doctorUserId, payload = {}) {
  const doc = await Doctor.findOne({ userId: doctorUserId });
  if (!doc) throw Object.assign(new Error("Doctor profile not found"), { status: 404 });

  const consultationFee = roundMoney(payload.consultationFee ?? doc.consultationFee ?? 100);
  const specializedServices = sanitizeServices(payload.specializedServices);

  let clinicName = String(payload.clinicName || doc.clinicServicesConfig?.clinicName || doc.currentClinic || "").trim();
  if (!clinicName && doc.clinicId) {
    const clinic = await Clinic.findById(doc.clinicId).select("name").lean();
    clinicName = clinic?.name || "";
  }

  doc.consultationFee = consultationFee;
  doc.clinicServicesConfig = {
    clinicName,
    consultationFee,
    specializedServices,
    updatedAt: new Date(),
  };
  if (clinicName && !doc.currentClinic) doc.currentClinic = clinicName;
  await doc.save();

  if (doc.clinicId) {
    await Clinic.findByIdAndUpdate(doc.clinicId, {
      $set: {
        defaultConsultationFee: consultationFee,
        servicePricing: specializedServices,
      },
    });
  }

  return resolveDoctorBillingConfig(doctorUserId);
}

module.exports = {
  DEFAULT_SPECIALIZED_SERVICES,
  BASELINE_CONSULTATION_FEE,
  roundMoney,
  parseFeeValue,
  sanitizeServices,
  resolveFeeFromDoctor,
  resolveDoctorBillingConfig,
  saveDoctorClinicServices,
};
