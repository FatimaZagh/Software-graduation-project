const mongoose = require("mongoose");
const AppointmentModel = require("../models/appointment");
const WaitingListEntry = require("../models/waitingListEntry");
const UserModel = require("../models/User");
const Clinic = require("../models/clinic");
const { normalizeSlotTime } = require("./appointmentSlots");
const { patientActiveBookingQuery } = require("./appointmentStatus");

const DUPLICATE_WAITLIST_MSG =
  "You cannot join the waiting list for a slot you have already booked or requested.";

function buildSlotId(doctorUserId, dateYmd, timeHhmm) {
  const t = normalizeSlotTime(timeHhmm);
  return `${doctorUserId}|${dateYmd}|${t}`;
}

/**
 * Reject if patient already holds this slot or is already queued for it.
 */
async function validatePatientWaitlistEligibility({
  patientUserId,
  doctorUserId,
  dateYmd,
  timeHhmm,
}) {
  if (!patientUserId || !doctorUserId || !dateYmd || !timeHhmm) {
    return { ok: false, message: "Missing slot or patient context" };
  }

  const slotNorm = normalizeSlotTime(timeHhmm);
  const date = String(dateYmd).trim();
  if (!slotNorm || !date) {
    return { ok: false, message: "Invalid slot date or time" };
  }

  const patientOid = new mongoose.Types.ObjectId(String(patientUserId));
  const doctorOid = new mongoose.Types.ObjectId(String(doctorUserId));

  const existingBooking = await AppointmentModel.findOne(
    patientActiveBookingQuery({
      patientId: patientOid,
      doctorUserId: doctorOid,
      date,
      time: slotNorm,
    })
  ).lean();

  if (existingBooking) {
    return { ok: false, message: DUPLICATE_WAITLIST_MSG };
  }

  const slotId = buildSlotId(doctorUserId, date, slotNorm);
  const existingWait = await WaitingListEntry.findOne({
    patientUserId: patientOid,
    slotId,
    status: "Active",
  }).lean();

  if (existingWait) {
    return { ok: false, message: DUPLICATE_WAITLIST_MSG };
  }

  return { ok: true, slotId, slotNorm, date };
}

/** Attach doctorName, clinicName, date, time for patient-facing lists. */
async function enrichWaitingListEntries(entries) {
  if (!Array.isArray(entries) || entries.length === 0) return [];

  const doctorIds = [
    ...new Set(entries.map((e) => String(e.doctorUserId || "")).filter(Boolean)),
  ];
  const clinicIds = [
    ...new Set(entries.map((e) => String(e.clinicId || "")).filter(Boolean)),
  ];

  const doctorOids = doctorIds
    .filter((id) => mongoose.Types.ObjectId.isValid(id))
    .map((id) => new mongoose.Types.ObjectId(id));
  const clinicOids = clinicIds
    .filter((id) => mongoose.Types.ObjectId.isValid(id))
    .map((id) => new mongoose.Types.ObjectId(id));

  const [doctorUsers, clinics] = await Promise.all([
    doctorOids.length
      ? UserModel.find({ _id: { $in: doctorOids } })
          .select("name")
          .lean()
      : [],
    clinicOids.length
      ? Clinic.find({ _id: { $in: clinicOids } })
          .select("name")
          .lean()
      : [],
  ]);

  const doctorNameById = {};
  for (const u of doctorUsers) {
    doctorNameById[String(u._id)] = u.name || "";
  }

  const clinicNameById = {};
  for (const c of clinics) {
    clinicNameById[String(c._id)] = c.name || "";
  }

  return entries.map((e) => {
    const date = e.watchSlotDate || e.preferredDate || "";
    const time = e.watchSlotTime || e.preferredTime || "";
    const doctorUserId = e.doctorUserId ? String(e.doctorUserId) : "";
    const clinicId = e.clinicId ? String(e.clinicId) : "";
    const doctorName = doctorNameById[doctorUserId] || "";
    const clinicName = clinicId ? clinicNameById[clinicId] || "" : "";

    return {
      ...e,
      doctorUserId,
      clinicId: clinicId || null,
      doctorName,
      clinicName,
      date,
      time,
    };
  });
}

module.exports = {
  DUPLICATE_WAITLIST_MSG,
  buildSlotId,
  validatePatientWaitlistEligibility,
  enrichWaitingListEntries,
};
