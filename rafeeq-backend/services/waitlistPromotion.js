const mongoose = require("mongoose");
const AppointmentModel = require("../models/appointment");
const WaitingListEntry = require("../models/waitingListEntry");
const UserModel = require("../models/User");
const UserNotification = require("../models/userNotification");
const PatientNotification = require("../models/patientNotification");
const { normalizeSlotTime } = require("../utils/appointmentSlots");
const { primarySlotOccupancyQuery } = require("../utils/appointmentStatus");
const {
  validatePatientWaitlistEligibility,
  buildSlotId,
} = require("../utils/waitingListHelpers");

/**
 * Add a patient to the FIFO waiting list for a specific doctor/date/time slot.
 */
async function addPatientToSlotWaitingList({
  patientUserId,
  doctorUserId,
  dateYmd,
  timeHhmm,
  orgId = null,
  clinicId = null,
}) {
  const validation = await validatePatientWaitlistEligibility({
    patientUserId,
    doctorUserId,
    dateYmd,
    timeHhmm,
  });

  if (!validation.ok) {
    return { rejected: true, message: validation.message };
  }

  const slotNorm = validation.slotNorm;
  const slotId = validation.slotId;

  const entry = await WaitingListEntry.create({
    patientUserId,
    doctorUserId: new mongoose.Types.ObjectId(String(doctorUserId)),
    slotId,
    watchSlotDate: validation.date,
    watchSlotTime: slotNorm,
    preferredDate: validation.date,
    preferredTime: slotNorm,
    status: "Active",
    ...(orgId ? { orgId } : {}),
    ...(clinicId ? { clinicId } : {}),
  });

  return { entry: entry.toObject(), rejected: false, slotId };
}

/**
 * FIFO: promote the oldest Active waitlist entry for this slot into a confirmed booking.
 */
async function promoteNextFromWaitlist({
  doctorUserId,
  dateYmd,
  timeHhmm,
  orgId,
  doctorName,
  clinicId = null,
}) {
  if (!doctorUserId || !dateYmd || !timeHhmm) {
    return { promoted: false, reason: "missing_slot_context" };
  }

  const slotId = buildSlotId(doctorUserId, dateYmd, timeHhmm);
  const slotNorm = normalizeSlotTime(timeHhmm);
  const doctorOid = new mongoose.Types.ObjectId(String(doctorUserId));

  const existingPrimary = await AppointmentModel.findOne(
    primarySlotOccupancyQuery({
      doctorUserId: doctorOid,
      date: dateYmd,
      time: slotNorm,
    })
  ).lean();

  if (existingPrimary) {
    return { promoted: false, reason: "slot_still_occupied" };
  }

  let next = await WaitingListEntry.findOne({ slotId, status: "Active" })
    .sort({ createdAt: 1 })
    .exec();

  if (!next) {
    next = await WaitingListEntry.findOne({
      doctorUserId: doctorOid,
      watchSlotDate: dateYmd,
      watchSlotTime: slotNorm,
      status: "Active",
    })
      .sort({ createdAt: 1 })
      .exec();
  }

  if (!next) {
    return { promoted: false, reason: "waitlist_empty" };
  }

  const patient = await UserModel.findById(next.patientUserId).lean();
  const patientName = patient?.name || "Patient";
  const resolvedOrgId = orgId || next.orgId || patient?.orgId || null;
  const resolvedClinicId = clinicId || next.clinicId || null;

  const appt = await AppointmentModel.create({
    patientName,
    patientId: next.patientUserId,
    time: slotNorm,
    date: dateYmd,
    orgId: resolvedOrgId,
    status: "booked",
    bookingStatus: "Accepted",
    doctorUserId: doctorOid,
    doctorName: doctorName || "",
    promotedFromWaitlist: true,
    isForceAccepted: false,
    ...(resolvedClinicId ? { clinicId: resolvedClinicId } : {}),
  });

  next.status = "Promoted";
  next.promotedAppointmentId = appt._id;
  await next.save();

  const notifyBody = `Your appointment has been confirmed on ${dateYmd} at ${timeHhmm} after a slot became available.`;

  await PatientNotification.create({
    orgId: resolvedOrgId,
    patientUserId: next.patientUserId,
    type: "waitlist_promoted",
    title: "Confirmed from Waitlist",
    body: notifyBody,
    read: false,
    meta: {
      appointmentId: String(appt._id),
      slotId,
      doctorUserId: String(doctorUserId),
    },
  });

  await UserNotification.create({
    orgId: resolvedOrgId,
    userId: next.patientUserId,
    role: "Patient",
    type: "waitlist_promoted",
    title: "Appointment confirmed",
    body: notifyBody,
    read: false,
    meta: {
      appointmentId: String(appt._id),
      slotId,
      doctorUserId: String(doctorUserId),
    },
  });

  if (doctorUserId) {
    await UserNotification.create({
      orgId: resolvedOrgId,
      userId: doctorOid,
      role: "Doctor",
      type: "waitlist_promoted",
      title: "Waitlist patient promoted",
      body: `${patientName} was auto-booked for ${dateYmd} ${slotNorm} after a cancellation.`,
      read: false,
      meta: { appointmentId: String(appt._id), patientUserId: String(next.patientUserId) },
    });
  }

  return {
    promoted: true,
    appointment: appt.toObject(),
    waitingListEntryId: String(next._id),
    patientUserId: String(next.patientUserId),
  };
}

module.exports = {
  buildSlotId,
  addPatientToSlotWaitingList,
  promoteNextFromWaitlist,
};
