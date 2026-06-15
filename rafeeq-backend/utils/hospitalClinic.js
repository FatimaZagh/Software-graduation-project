const Clinic = require("../models/clinic");

/** In-memory cache: single-hospital deployment uses one clinic for all doctors. */
let cachedHospitalClinicId = null;

/**
 * Resolves the canonical hospital clinic ObjectId (prefers "Main Branch" in the name).
 */
async function resolveHospitalClinicId() {
  if (cachedHospitalClinicId) return cachedHospitalClinicId;
  const main = await Clinic.findOne({ name: { $regex: /Main Branch/i } }).lean();
  const c = main || (await Clinic.findOne().sort({ name: 1 }).lean());
  cachedHospitalClinicId = c?._id || null;
  return cachedHospitalClinicId;
}

function clearHospitalClinicCache() {
  cachedHospitalClinicId = null;
}

module.exports = { resolveHospitalClinicId, clearHospitalClinicCache };
