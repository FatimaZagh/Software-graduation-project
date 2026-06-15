const PatientMedication = require("../models/patientMedication");

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Parse doctor-facing duration text into days (e.g. "7 days", "2 weeks", "1 month").
 */
function parseDurationInDays(durationText, explicitDays) {
  if (explicitDays != null && explicitDays !== "") {
    const n = Number(explicitDays);
    if (!Number.isNaN(n) && n > 0) return Math.floor(n);
  }
  const s = String(durationText || "").trim().toLowerCase();
  if (!s) return 30;

  const numMatch = s.match(/(\d+(?:\.\d+)?)/);
  const n = numMatch ? parseFloat(numMatch[1]) : NaN;
  if (Number.isNaN(n) || n <= 0) return 30;

  if (/\bweek/.test(s)) return Math.max(1, Math.round(n * 7));
  if (/\bmonth/.test(s)) return Math.max(1, Math.round(n * 30));
  if (/\bday/.test(s)) return Math.max(1, Math.round(n));
  if (/\b(year|yr)\b/.test(s)) return Math.max(1, Math.round(n * 365));
  return Math.max(1, Math.round(n));
}

function getStartDate(med) {
  if (med.startDate) return new Date(med.startDate);
  return null;
}

function getDurationDays(med) {
  const d = med.durationInDays;
  if (d != null && d > 0) return d;
  return 30;
}

function isMedicationExpired(med, now = new Date()) {
  if (med.status === "Expired" || med.status === "Stopped") return med.status === "Expired";
  const start = getStartDate(med);
  if (!start) return false;
  const endMs = start.getTime() + getDurationDays(med) * MS_PER_DAY;
  return now.getTime() >= endMs;
}

async function expireMedicationIfNeeded(med, now = new Date()) {
  if (!med || med.status === "Stopped") return med;
  if (!getStartDate(med)) {
    if (med.active) {
      med.active = false;
      await med.save();
    }
    return med;
  }
  if (!isMedicationExpired(med, now)) return med;

  if (med.status !== "Expired") {
    med.status = "Expired";
    med.active = false;
    med.expiredAt = now;
    await med.save();
  }
  return med;
}

function serializeMedication(med) {
  const obj = med.toObject ? med.toObject() : { ...med };
  const start = getStartDate(obj);
  const days = getDurationDays(obj);
  let endsAt = null;
  if (start) {
    endsAt = new Date(start.getTime() + days * MS_PER_DAY);
  }
  const expired = obj.status === "Expired" || (start && isMedicationExpired(obj));
  const started = Boolean(start);
  return {
    ...obj,
    startDate: start,
    durationInDays: days,
    endsAt,
    isExpired: expired,
    /** Patient toggle ON only after first start; OFF when null, expired, or stopped. */
    patientTaking: started && !expired && obj.status === "Active" && obj.active === true,
    canToggle: !expired && obj.status !== "Stopped",
  };
}

/**
 * Load patient meds, auto-expire overdue courses, split active vs completed history.
 */
async function loadPatientMedicationsWithLifecycle(patientUserId) {
  const docs = await PatientMedication.find({
    patientUserId,
    status: { $nin: ["Stopped"] },
  })
    .sort({ createdAt: -1 })
    .lean();

  const now = new Date();
  const active = [];
  const completed = [];

  for (const row of docs) {
    const doc = await PatientMedication.findById(row._id);
    if (!doc) continue;
    await expireMedicationIfNeeded(doc, now);
    const serialized = serializeMedication(doc);
    if (serialized.isExpired || serialized.status === "Expired") {
      completed.push(serialized);
    } else {
      active.push(serialized);
    }
  }

  return { active, completed };
}

/**
 * Patient confirms first dose — records startDate and turns therapy ON.
 */
async function startPatientMedication(patientUserId, medId) {
  const med = await PatientMedication.findOne({ _id: medId, patientUserId });
  if (!med) return { error: { status: 404, message: "Medication not found" } };
  if (med.status === "Stopped") {
    return { error: { status: 400, message: "Medication was stopped by your doctor" } };
  }
  if (med.status === "Expired") {
    return { error: { status: 400, message: "Medication course has expired" } };
  }
  if (getStartDate(med) && med.active) {
    return { medication: serializeMedication(med), alreadyStarted: true };
  }

  const now = new Date();
  med.startDate = now;
  med.startedAt = med.startedAt || now;
  med.active = true;
  med.status = "Active";
  med.expiredAt = undefined;
  await med.save();

  return { medication: serializeMedication(med) };
}

module.exports = {
  parseDurationInDays,
  isMedicationExpired,
  expireMedicationIfNeeded,
  serializeMedication,
  loadPatientMedicationsWithLifecycle,
  startPatientMedication,
};
