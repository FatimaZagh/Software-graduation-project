const mongoose = require("mongoose");
const AppointmentModel = require("../models/appointment");
const Doctor = require("../models/doctor");
const UserModel = require("../models/User");
const UserNotification = require("../models/userNotification");
const { normalizeDateToYmd } = require("../utils/doctorPortalHelpers");
const { isDateBlocked } = require("../utils/dynamicSchedule");
const PatientNotification = require("../models/patientNotification");
const WaitingListEntry = require("../models/waitingListEntry");
const {
  computeSlots,
  loadBookedSlots,
  normalizeSlotTime,
  findWorkDayForDate,
  generateAvailableSlotsForDoctor,
} = require("../utils/appointmentSlots");
const {
  DOCTOR_CANCEL_REASONS,
  activeSlotOccupancyQuery,
  primarySlotOccupancyQuery,
  patientActiveBookingQuery,
  isPatientBookedActive,
} = require("../utils/appointmentStatus");
const Clinic = require("../models/clinic");
const { enrichWaitingListEntries } = require("../utils/waitingListHelpers");
const {
  buildSlotId,
  addPatientToSlotWaitingList,
  promoteNextFromWaitlist,
} = require("../services/waitlistPromotion");

const MSG_SAME_DAY_AR =
  "لا يمكنك حجز أكثر من موعد واحد لنفس الطبيب في نفس اليوم";
const MSG_MAX_THREE_AR =
  "عذراً، الحد الأقصى للحجوزات النشطة عند هذا الطبيب هو 3 مواعيد فقط";

/** Check A + B before creating a patient booking. */
async function validatePatientBookingLimits(AppointmentModel, { patientUserId, doctorUserId, dateYmd }) {
  if (!doctorUserId || !dateYmd) return null;

  const patientOid = new mongoose.Types.ObjectId(String(patientUserId));
  const doctorOid = new mongoose.Types.ObjectId(String(doctorUserId));

  const sameDay = await AppointmentModel.findOne(
    patientActiveBookingQuery({
      patientId: patientOid,
      doctorUserId: doctorOid,
      date: dateYmd,
    })
  ).lean();

  if (sameDay) {
    return { status: 400, message: MSG_SAME_DAY_AR };
  }

  const activeCount = await AppointmentModel.countDocuments(
    patientActiveBookingQuery({
      patientId: patientOid,
      doctorUserId: doctorOid,
    })
  );

  if (activeCount >= 3) {
    return { status: 400, message: MSG_MAX_THREE_AR };
  }

  return null;
}

async function resolveDoctorUser(req) {
  const userId = String(req.headers["x-user-id"] || "").trim();
  if (!userId || !mongoose.Types.ObjectId.isValid(userId)) return null;
  const user = await UserModel.findById(userId).lean();
  if (!user || user.role !== "Doctor" || user.status !== "active") return null;
  return user;
}

/** PATCH /api/appointments/:id/postpone — doctor requests patient reschedule */
async function postponeAppointment(req, res) {
  try {
    const doctor = await resolveDoctorUser(req);
    if (!doctor) return res.status(403).json({ message: "Doctor authentication required" });

    const id = String(req.params.id || "").trim();
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid appointment id" });
    }

    const appt = await AppointmentModel.findById(id);
    if (!appt) return res.status(404).json({ message: "Appointment not found" });

    if (appt.doctorUserId && String(appt.doctorUserId) !== String(doctor._id)) {
      return res.status(403).json({ message: "Not your appointment" });
    }

    appt.bookingStatus = "reschedule_requested";
    appt.status = "Waiting";
    await appt.save();

    if (appt.patientId) {
      await UserNotification.create({
        orgId: doctor.orgId || appt.orgId,
        userId: appt.patientId,
        role: "Patient",
        type: "appointment_reschedule_requested",
        title: "Appointment postponed",
        body: "Your doctor requested to reschedule. Please pick a new date and time.",
        read: false,
        meta: { appointmentId: String(appt._id) },
      });
    }

    res.json({
      message: "Patient notified to reschedule",
      appointment: appt.toObject(),
    });
  } catch (e) {
    console.error("[appointment-postpone]", e);
    res.status(500).json({ message: e.message || "Error postponing appointment" });
  }
}

/** PATCH /api/appointments/:id/reschedule — patient picks new slot (free when reschedule_requested) */
async function rescheduleAppointment(req, res) {
  try {
    const id = String(req.params.id || "").trim();
    const { patientUserId, date, time, doctorUserId, doctorName } = req.body || {};
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid appointment id" });
    }
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(String(patientUserId))) {
      return res.status(400).json({ message: "patientUserId required" });
    }
    const dateYmd = normalizeDateToYmd(date);
    const slot = normalizeSlotTime(time);
    if (!dateYmd || !slot) {
      return res.status(400).json({ message: "date and time (HH:mm) required" });
    }

    const appt = await AppointmentModel.findById(id);
    if (!appt) return res.status(404).json({ message: "Appointment not found" });
    if (!appt.patientId || String(appt.patientId) !== String(patientUserId)) {
      return res.status(403).json({ message: "Not your appointment" });
    }
    if (appt.bookingStatus !== "reschedule_requested") {
      return res.status(400).json({
        message: "This appointment is not awaiting patient reschedule",
        bookingStatus: appt.bookingStatus,
      });
    }

    const docId =
      doctorUserId && mongoose.Types.ObjectId.isValid(String(doctorUserId))
        ? new mongoose.Types.ObjectId(String(doctorUserId))
        : appt.doctorUserId;

    if (!docId) return res.status(400).json({ message: "doctorUserId required for reschedule" });

    const orgId = appt.orgId || (await UserModel.findById(docId).select("orgId").lean())?.orgId;
    const doctorDoc = await Doctor.findOne({ userId: docId }).lean();
    if (!doctorDoc) return res.status(404).json({ message: "Doctor profile not found" });
    if (isDateBlocked(doctorDoc.bookingBlocklist, dateYmd)) {
      return res.status(409).json({ message: "Doctor is unavailable on this date" });
    }

    const schedule = Array.isArray(doctorDoc.workSchedule) ? doctorDoc.workSchedule : [];
    const workDay = findWorkDayForDate(schedule, dateYmd);
    const booked = await loadBookedSlots(AppointmentModel, {
      orgId,
      doctorUserId: docId,
      date: dateYmd,
    });
    booked.delete(normalizeSlotTime(appt.time));
    const available = computeSlots(workDay, booked);
    if (!available.includes(slot)) {
      return res.status(409).json({ message: "Selected time slot is no longer available" });
    }

    const conflict = await AppointmentModel.findOne(
      activeSlotOccupancyQuery({
        _id: { $ne: appt._id },
        doctorUserId: docId,
        date: dateYmd,
        time: slot,
      })
    ).lean();
    if (conflict) {
      return res.status(409).json({ message: "Slot already booked by another patient" });
    }

    appt.date = dateYmd;
    appt.time = slot;
    appt.bookingStatus = "Accepted";
    appt.status = "Waiting";
    if (doctorName) appt.doctorName = String(doctorName);
    appt.doctorUserId = docId;
    await appt.save();

    if (docId) {
      await UserNotification.create({
        orgId,
        userId: docId,
        role: "Doctor",
        type: "appointment_rescheduled",
        title: "Patient rescheduled visit",
        body: `${appt.patientName} · ${dateYmd} ${slot}`,
        read: false,
        meta: { appointmentId: String(appt._id) },
      });
    }

    res.json({ message: "Appointment rescheduled", appointment: appt.toObject() });
  } catch (e) {
    console.error("[appointment-reschedule]", e);
    res.status(500).json({ message: e.message || "Error rescheduling appointment" });
  }
}

function resolveDoctorUserIdFromQuery(query) {
  return String(query.doctorUserId || query.doctorId || "").trim();
}

async function resolveBookingOrgId({ body = {}, query = {}, doctorUserId, clinicId, patientUser }) {
  const fromBody = String(body.orgId || query.orgId || "").trim();
  if (mongoose.Types.ObjectId.isValid(fromBody)) {
    return new mongoose.Types.ObjectId(fromBody);
  }
  if (doctorUserId) {
    const docUser = await UserModel.findById(doctorUserId).select("orgId").lean();
    if (docUser?.orgId) return docUser.orgId;
  }
  if (clinicId && mongoose.Types.ObjectId.isValid(String(clinicId))) {
    const clinic = await Clinic.findById(clinicId).select("orgId").lean();
    if (clinic?.orgId) return clinic.orgId;
  }
  if (patientUser?.orgId) return patientUser.orgId;
  return null;
}

function parseSlotIdParam(slotIdRaw) {
  const raw = decodeURIComponent(String(slotIdRaw || "").trim());
  const parts = raw.split("|");
  if (parts.length < 3) return null;
  const doctorUserId = parts[0];
  const watchSlotDate = parts[1];
  const watchSlotTime = normalizeSlotTime(parts[2]);
  if (!mongoose.Types.ObjectId.isValid(doctorUserId)) return null;
  if (!watchSlotDate || !watchSlotTime) return null;
  return { doctorUserId, watchSlotDate, watchSlotTime };
}

/** GET /api/appointments/available-dates?doctorUserId=&days=14&orgId= */
async function getAvailableDates(req, res) {
  try {
    const doctorUserId = resolveDoctorUserIdFromQuery(req.query);
    const orgIdStr = String(req.query.orgId || "").trim();
    const days = Math.min(60, Math.max(1, parseInt(req.query.days, 10) || 14));

    if (!doctorUserId || !mongoose.Types.ObjectId.isValid(doctorUserId)) {
      return res.status(400).json({ message: "doctorUserId is required" });
    }
    const orgId =
      orgIdStr && mongoose.Types.ObjectId.isValid(orgIdStr)
        ? new mongoose.Types.ObjectId(orgIdStr)
        : null;
    if (!orgId) return res.status(400).json({ message: "orgId is required" });

    const doctorUser = await UserModel.findById(doctorUserId).lean();
    if (!doctorUser || doctorUser.role !== "Doctor") {
      return res.status(404).json({ message: "Doctor not found" });
    }

    const doctorDoc = await Doctor.findOne({ userId: doctorUserId }).lean();
    if (!doctorDoc) return res.status(404).json({ message: "Doctor profile not found" });

    const schedule = Array.isArray(doctorDoc.workSchedule) ? doctorDoc.workSchedule : [];
    const start = new Date();
    start.setHours(12, 0, 0, 0);
    const dates = [];

    for (let i = 0; i < days; i++) {
      const d = new Date(start);
      d.setDate(start.getDate() + i);
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, "0");
      const day = String(d.getDate()).padStart(2, "0");
      const dateYmd = `${y}-${m}-${day}`;
      if (isDateBlocked(doctorDoc.bookingBlocklist, dateYmd)) continue;
      const workDay = findWorkDayForDate(schedule, dateYmd);
      if (workDay) dates.push(dateYmd);
    }

    res.json({ doctorUserId, dates });
  } catch (e) {
    console.error("[appointment-available-dates]", e);
    res.status(500).json({ message: e.message || "Error loading available dates" });
  }
}

/**
 * GET /api/appointments/doctor-active-days/:doctorId?orgId=&days=60
 * Returns YYYY-MM-DD dates (chronological) where this doctor has at least one bookable time slot.
 */
async function getDoctorActiveDays(req, res) {
  try {
    const doctorUserId = String(
      req.params.doctorId || req.params.doctorUserId || ""
    ).trim();
    const orgIdStr = String(req.query.orgId || "").trim();
    const days = Math.min(120, Math.max(1, parseInt(req.query.days, 10) || 60));

    if (!doctorUserId || !mongoose.Types.ObjectId.isValid(doctorUserId)) {
      return res.status(400).json({ message: "doctorId is required" });
    }
    const orgId =
      orgIdStr && mongoose.Types.ObjectId.isValid(orgIdStr)
        ? new mongoose.Types.ObjectId(orgIdStr)
        : null;
    if (!orgId) return res.status(400).json({ message: "orgId is required" });

    const doctorUser = await UserModel.findById(doctorUserId).lean();
    if (!doctorUser || doctorUser.role !== "Doctor") {
      return res.status(404).json({ message: "Doctor not found" });
    }

    const doctorDoc = await Doctor.findOne({ userId: doctorUserId }).lean();
    if (!doctorDoc) return res.status(404).json({ message: "Doctor profile not found" });

    const doctorOid = new mongoose.Types.ObjectId(doctorUserId);
    const schedule = Array.isArray(doctorDoc.workSchedule) ? doctorDoc.workSchedule : [];
    const start = new Date();
    start.setHours(12, 0, 0, 0);
    const activeDates = [];

    for (let i = 0; i < days; i++) {
      const d = new Date(start);
      d.setDate(start.getDate() + i);
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, "0");
      const day = String(d.getDate()).padStart(2, "0");
      const dateYmd = `${y}-${m}-${day}`;

      const result = await generateAvailableSlotsForDoctor(AppointmentModel, {
        orgId,
        doctorUserId: doctorOid,
        dateYmd,
        workSchedule: schedule,
        bookingBlocklist: doctorDoc.bookingBlocklist,
        isDateBlockedFn: isDateBlocked,
      });

      if (
        result.hasSchedule &&
        !result.onLeave &&
        Array.isArray(result.availableSlots) &&
        result.availableSlots.length > 0
      ) {
        activeDates.push(dateYmd);
      }
    }

    res.json({ doctorUserId, activeDates });
  } catch (e) {
    console.error("[appointment-doctor-active-days]", e);
    res.status(500).json({ message: e.message || "Error loading doctor active days" });
  }
}

/** GET /api/appointments/available-slots?doctorUserId=&date=YYYY-MM-DD&orgId= */
/** Alias: GET /api/appointments/slots?doctorId=&date= */
async function getAvailableSlots(req, res) {
  try {
    const doctorUserId = resolveDoctorUserIdFromQuery(req.query);
    const dateYmd = normalizeDateToYmd(req.query.date);
    const orgIdStr = String(req.query.orgId || req.body?.orgId || "").trim();

    if (!doctorUserId || !mongoose.Types.ObjectId.isValid(doctorUserId)) {
      return res.status(400).json({ message: "doctorUserId is required" });
    }
    if (!dateYmd) {
      return res.status(400).json({ message: "Query param date=YYYY-MM-DD is required" });
    }

    const doctorUser = await UserModel.findById(doctorUserId).lean();
    if (!doctorUser || doctorUser.role !== "Doctor") {
      return res.status(404).json({ message: "Doctor not found" });
    }

    let orgId =
      orgIdStr && mongoose.Types.ObjectId.isValid(orgIdStr)
        ? new mongoose.Types.ObjectId(orgIdStr)
        : null;
    if (!orgId && doctorUser.orgId) orgId = doctorUser.orgId;

    const doctorDoc = await Doctor.findOne({ userId: doctorUserId }).lean();
    if (!orgId && doctorDoc?.orgId) orgId = doctorDoc.orgId;
    if (!doctorDoc) return res.status(404).json({ message: "Doctor profile not found" });

    const result = await generateAvailableSlotsForDoctor(AppointmentModel, {
      orgId,
      doctorUserId: new mongoose.Types.ObjectId(doctorUserId),
      dateYmd,
      workSchedule: doctorDoc.workSchedule,
      bookingBlocklist: doctorDoc.bookingBlocklist,
      isDateBlockedFn: isDateBlocked,
    });

    const waitEntries = await WaitingListEntry.find({
      doctorUserId: new mongoose.Types.ObjectId(doctorUserId),
      watchSlotDate: dateYmd,
      status: "Active",
    })
      .select("patientUserId slotId watchSlotTime")
      .lean();

    const waitingListBySlotId = new Map();
    const waitingListByTime = new Map();
    for (const entry of waitEntries) {
      const patientId = String(entry.patientUserId || "");
      if (!patientId) continue;
      const timeNorm = normalizeSlotTime(entry.watchSlotTime);
      const sid =
        entry.slotId ||
        (timeNorm ? buildSlotId(doctorUserId, dateYmd, timeNorm) : "");
      if (sid) {
        if (!waitingListBySlotId.has(sid)) waitingListBySlotId.set(sid, []);
        waitingListBySlotId.get(sid).push(patientId);
      }
      if (timeNorm) {
        if (!waitingListByTime.has(timeNorm)) waitingListByTime.set(timeNorm, []);
        waitingListByTime.get(timeNorm).push(patientId);
      }
    }

    const availableSlots = (result.availableSlots || []).map((s) => {
      const value = normalizeSlotTime(s.value || s.time);
      const slotId = buildSlotId(doctorUserId, dateYmd, value);
      const fromSlot = waitingListBySlotId.get(slotId) || [];
      const fromTime = value ? waitingListByTime.get(value) || [] : [];
      const waitingList = [...new Set([...fromSlot, ...fromTime])];
      return {
        ...s,
        slotId,
        waitingList,
      };
    });

    res.json({
      doctorUserId,
      ...result,
      availableSlots,
    });
  } catch (e) {
    console.error("[appointment-available-slots]", e);
    res.status(500).json({ message: e.message || "Error loading available slots" });
  }
}

/**
 * POST /api/appointments/slots/:slotId/waiting-list
 * slotId = doctorUserId|YYYY-MM-DD|HH:mm (not an Appointment _id).
 * body: { patientId, patientUserId }
 */
async function postSlotWaitingList(req, res) {
  try {
    const parsed = parseSlotIdParam(req.params.slotId);
    if (!parsed) {
      return res.status(400).json({
        success: false,
        message: "Missing or invalid slotId (expected doctorId|date|time)",
      });
    }

    const patientId = String(
      req.body?.patientId || req.body?.patientUserId || req.query?.patientUserId || ""
    ).trim();

    if (!patientId) {
      return res.status(400).json({
        success: false,
        message: "Missing slotId or patientId",
      });
    }
    if (!mongoose.Types.ObjectId.isValid(patientId)) {
      return res.status(400).json({ success: false, message: "Invalid patientId" });
    }

    const slotId = buildSlotId(
      parsed.doctorUserId,
      parsed.watchSlotDate,
      parsed.watchSlotTime
    );

    const orgId = await resolveBookingOrgId({
      body: req.body,
      query: req.query,
      doctorUserId: parsed.doctorUserId,
      clinicId: req.body?.clinicId,
    });

    const result = await addPatientToSlotWaitingList({
      patientUserId: patientId,
      doctorUserId: parsed.doctorUserId,
      dateYmd: parsed.watchSlotDate,
      timeHhmm: parsed.watchSlotTime,
      orgId,
      clinicId:
        req.body?.clinicId && mongoose.Types.ObjectId.isValid(String(req.body.clinicId))
          ? new mongoose.Types.ObjectId(String(req.body.clinicId))
          : null,
    });

    if (result.rejected) {
      return res.status(400).json({ success: false, message: result.message });
    }

    return res.status(201).json({
      success: true,
      message: "Successfully added to the waiting list for this slot.",
      data: result.entry,
      slotId,
    });
  } catch (error) {
    console.error("Error in postSlotWaitingList:", error);
    return res.status(500).json({ success: false, message: "Internal server error" });
  }
}

/**
 * DELETE /api/appointments/waiting-list/:entryId
 * query/body: patientUserId (or patientId)
 * Marks the patient's active waitlist row as Cancelled (FIFO queue uses WaitingListEntry, not Appointment.waitingList).
 */
async function leaveWaitingListEntry(req, res) {
  try {
    const entryId = String(req.params.entryId || "").trim();
    const patientUserId = String(
      req.body?.patientUserId ||
        req.body?.patientId ||
        req.query?.patientUserId ||
        req.query?.patientId ||
        ""
    ).trim();

    if (!mongoose.Types.ObjectId.isValid(entryId)) {
      return res.status(400).json({ success: false, message: "Invalid waiting list entry id" });
    }
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ success: false, message: "patientUserId is required" });
    }

    const entry = await WaitingListEntry.findOneAndUpdate(
      { _id: entryId, patientUserId, status: "Active" },
      { $set: { status: "Cancelled" } },
      { new: true }
    ).lean();

    if (!entry) {
      return res.status(404).json({
        success: false,
        message: "Waiting list entry not found or already removed",
      });
    }

    return res.json({
      success: true,
      message: "You have left the waiting list for this slot.",
      data: entry,
    });
  } catch (error) {
    console.error("Error in leaveWaitingListEntry:", error);
    return res.status(500).json({ success: false, message: "Internal server error" });
  }
}

/**
 * DELETE /api/appointments/slots/:slotId/waiting-list
 * slotId = doctorUserId|YYYY-MM-DD|HH:mm — removes this patient from the slot queue.
 */
async function leaveSlotWaitingList(req, res) {
  try {
    const parsed = parseSlotIdParam(req.params.slotId);
    if (!parsed) {
      return res.status(400).json({
        success: false,
        message: "Missing or invalid slotId (expected doctorId|date|time)",
      });
    }

    const patientUserId = String(
      req.body?.patientUserId ||
        req.body?.patientId ||
        req.query?.patientUserId ||
        req.query?.patientId ||
        ""
    ).trim();

    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ success: false, message: "patientUserId is required" });
    }

    const slotId = buildSlotId(
      parsed.doctorUserId,
      parsed.watchSlotDate,
      parsed.watchSlotTime
    );

    const entry = await WaitingListEntry.findOneAndUpdate(
      { patientUserId, slotId, status: "Active" },
      { $set: { status: "Cancelled" } },
      { new: true }
    ).lean();

    if (!entry) {
      return res.status(404).json({
        success: false,
        message: "You are not on the waiting list for this slot",
      });
    }

    return res.json({
      success: true,
      message: "You have left the waiting list for this slot.",
      data: entry,
    });
  } catch (error) {
    console.error("Error in leaveSlotWaitingList:", error);
    return res.status(500).json({ success: false, message: "Internal server error" });
  }
}

const REASON_AR = {
  Emergency: "حالة طارئة",
  "Sick Leave": "إجازة مرضية",
  Surgery: "عملية جراحية",
  "Equipment Issue": "عطل في المعدات",
  Other: "سبب آخر",
};

/** PATCH /api/appointments/:id/cancel-by-doctor */
async function cancelByDoctor(req, res) {
  try {
    const doctor = await resolveDoctorUser(req);
    if (!doctor) return res.status(403).json({ message: "Doctor authentication required" });

    const id = String(req.params.id || "").trim();
    const reason = String(req.body?.reason || "").trim();
    const notes = String(req.body?.notes || "").trim();

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid appointment id" });
    }
    if (!reason || !DOCTOR_CANCEL_REASONS.includes(reason)) {
      return res.status(400).json({
        message: "Valid reason required",
        allowedReasons: DOCTOR_CANCEL_REASONS,
      });
    }

    const appt = await AppointmentModel.findById(id);
    if (!appt) return res.status(404).json({ message: "Appointment not found" });
    if (appt.doctorUserId && String(appt.doctorUserId) !== String(doctor._id)) {
      return res.status(403).json({ message: "Not your appointment" });
    }
    if (["cancelled_by_doctor", "cancelled_by_patient", "Completed"].includes(appt.status)) {
      return res.status(400).json({ message: "Appointment cannot be cancelled", status: appt.status });
    }

    appt.status = "cancelled_by_doctor";
    appt.bookingStatus = "cancelled_by_doctor";
    appt.cancellationReason = reason;
    appt.cancellationNotes = notes;
    appt.cancelledAt = new Date();
    appt.cancelledBy = "doctor";
    await appt.save();

    const reasonAr = REASON_AR[reason] || reason;
    const bodyAr = `تم إلغاء الموعد من قِبل الطبيب لحالة طارئة (${reasonAr}). يرجى إعادة حجز موعد آخر من المواعيد المتاحة.`;

    if (appt.patientId) {
      await UserNotification.create({
        orgId: doctor.orgId || appt.orgId,
        userId: appt.patientId,
        role: "Patient",
        type: "appointment_cancelled_by_doctor",
        title: "تم إلغاء الموعد",
        body: bodyAr,
        read: false,
        meta: {
          appointmentId: String(appt._id),
          reason,
          notes,
          doctorName: appt.doctorName,
        },
      });
      await PatientNotification.create({
        orgId: doctor.orgId || appt.orgId,
        patientUserId: appt.patientId,
        type: "appointment_cancelled_by_doctor",
        title: "تم إلغاء الموعد",
        body: bodyAr,
        read: false,
        meta: {
          appointmentId: String(appt._id),
          reason,
          notes,
        },
      });
    }

    let waitlistPromotion = { promoted: false };
    if (appt.doctorUserId && appt.date && appt.time) {
      waitlistPromotion = await promoteNextFromWaitlist({
        doctorUserId: String(appt.doctorUserId),
        dateYmd: appt.date,
        timeHhmm: appt.time,
        orgId: appt.orgId || doctor.orgId,
        doctorName: appt.doctorName,
        clinicId: appt.clinicId,
      });
    }

    res.json({
      message: "Appointment cancelled",
      appointment: appt.toObject(),
      waitlistPromotion,
    });
  } catch (e) {
    console.error("[appointment-cancel-by-doctor]", e);
    res.status(500).json({ message: e.message || "Error cancelling appointment" });
  }
}

/** PATCH /api/appointments/:id/cancel-by-patient */
async function cancelByPatient(req, res) {
  try {
    const id = String(req.params.id || "").trim();
    const patientUserId = String(req.body?.patientUserId || "").trim();

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid appointment id" });
    }
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "patientUserId required" });
    }

    const appt = await AppointmentModel.findById(id);
    if (!appt) return res.status(404).json({ message: "Appointment not found" });
    if (!appt.patientId || String(appt.patientId) !== patientUserId) {
      return res.status(403).json({ message: "Not your appointment" });
    }
    if (!isPatientBookedActive(appt)) {
      return res.status(400).json({ message: "Only active booked visits can be cancelled", status: appt.status });
    }

    const slotDate = appt.date;
    const slotTime = appt.time;
    const slotDoctorId = appt.doctorUserId;
    const slotOrgId = appt.orgId;
    const slotDoctorName = appt.doctorName;

    appt.status = "cancelled_by_patient";
    appt.bookingStatus = "cancelled_by_patient";
    appt.cancelledAt = new Date();
    appt.cancelledBy = "patient";
    await appt.save();

    if (appt.doctorUserId) {
      await UserNotification.create({
        orgId: appt.orgId,
        userId: appt.doctorUserId,
        role: "Doctor",
        type: "appointment_cancelled_by_patient",
        title: "Patient cancelled visit",
        body: `${appt.patientName} · ${appt.date} ${appt.time}`,
        read: false,
        meta: { appointmentId: String(appt._id) },
      });
    }

    let promotion = { promoted: false };
    if (slotDoctorId && slotDate && slotTime) {
      promotion = await promoteNextFromWaitlist({
        doctorUserId: String(slotDoctorId),
        dateYmd: slotDate,
        timeHhmm: slotTime,
        orgId: slotOrgId,
        doctorName: slotDoctorName,
        clinicId: appt.clinicId,
      });
    }

    res.json({
      message: "Appointment cancelled",
      appointment: appt.toObject(),
      waitlistPromotion: promotion,
    });
  } catch (e) {
    console.error("[appointment-cancel-by-patient]", e);
    res.status(500).json({ message: e.message || "Error cancelling appointment" });
  }
}

/** POST /api/appointments/book — patient books a visit. */
async function bookAppointment(req, res) {
  try {
    const {
      patientUserId,
      patientName,
      time,
      date,
      doctorName,
      doctorUserId: bodyDoctorUserId,
      branch,
      status,
      clinicId,
    } = req.body || {};

    if (!patientUserId || !patientName || !time || !date) {
      return res.status(400).json({
        message: "patientUserId, patientName, time, and date are required",
      });
    }
    if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid patientUserId" });
    }

    const user = await UserModel.findById(patientUserId).lean();
    if (!user) return res.status(404).json({ message: "Patient user not found" });

    let doctorUserId = null;
    if (bodyDoctorUserId && mongoose.Types.ObjectId.isValid(String(bodyDoctorUserId))) {
      const du = await UserModel.findById(String(bodyDoctorUserId)).lean();
      if (du && du.role === "Doctor") {
        doctorUserId = new mongoose.Types.ObjectId(String(bodyDoctorUserId));
      }
    }

    const dateYmd = normalizeDateToYmd(date) || String(date).trim();
    const slotNorm = normalizeSlotTime(time) || normalizeSlotTime(String(time).trim());
    const clinicOid =
      clinicId && mongoose.Types.ObjectId.isValid(String(clinicId))
        ? new mongoose.Types.ObjectId(String(clinicId))
        : null;
    const resolvedOrgId = await resolveBookingOrgId({
      body: req.body,
      query: req.query,
      doctorUserId,
      clinicId: clinicOid,
      patientUser: user,
    });

    if (doctorUserId) {
      const limitErr = await validatePatientBookingLimits(AppointmentModel, {
        patientUserId,
        doctorUserId,
        dateYmd,
      });
      if (limitErr) {
        return res.status(limitErr.status).json({ message: limitErr.message });
      }

      const conflict = await AppointmentModel.findOne(
        primarySlotOccupancyQuery({
          doctorUserId,
          date: dateYmd,
          time: slotNorm,
        })
      ).lean();

      if (conflict) {
        const result = await addPatientToSlotWaitingList({
          patientUserId,
          doctorUserId: String(doctorUserId),
          dateYmd,
          timeHhmm: slotNorm,
          orgId: resolvedOrgId,
          clinicId: clinicOid,
        });

        if (result.rejected) {
          return res.status(400).json({ message: result.message });
        }

        return res.status(201).json({
          addedToWaitingList: true,
          message: "This time slot is full. You have been added to the waiting list.",
          waitingListEntry: result.entry,
        });
      }

      const doctorDoc = await Doctor.findOne({ userId: doctorUserId }).lean();
      if (doctorDoc) {
        const schedule = Array.isArray(doctorDoc.workSchedule) ? doctorDoc.workSchedule : [];
        const workDay = findWorkDayForDate(schedule, dateYmd);
        const booked = await loadBookedSlots(AppointmentModel, {
          orgId: resolvedOrgId,
          doctorUserId,
          date: dateYmd,
        });
        const available = computeSlots(workDay, booked);
        if (workDay && slotNorm && !available.includes(slotNorm)) {
          const result = await addPatientToSlotWaitingList({
            patientUserId,
            doctorUserId: String(doctorUserId),
            dateYmd,
            timeHhmm: slotNorm,
            orgId: resolvedOrgId,
            clinicId: clinicOid,
          });

          if (result.rejected) {
            return res.status(400).json({ message: result.message });
          }

          return res.status(201).json({
            addedToWaitingList: true,
            message: "This time slot is unavailable. You have been added to the waiting list.",
            waitingListEntry: result.entry,
          });
        }
      }
    }

    const appt = new AppointmentModel({
      patientName,
      patientId: patientUserId,
      time: slotNorm || String(time).trim(),
      date: dateYmd,
      orgId: resolvedOrgId,
      status: status != null ? status : "booked",
      bookingStatus: "Accepted",
      doctorName: doctorName != null ? String(doctorName) : "",
      branch: branch != null ? String(branch) : "",
      ...(doctorUserId ? { doctorUserId } : {}),
      ...(clinicOid ? { clinicId: clinicOid } : {}),
    });
    await appt.save();

    if (doctorUserId) {
      await UserNotification.create({
        orgId: resolvedOrgId,
        userId: doctorUserId,
        role: "Doctor",
        type: "appointment_booked",
        title: "A new patient booked a visit",
        body: `${patientName} · ${dateYmd} ${String(time).trim()}`,
        read: false,
        meta: { appointmentId: String(appt._id), patientUserId: String(patientUserId) },
      });
    }

    res.status(201).json(appt);
  } catch (e) {
    console.error("[appointment-book]", e);
    res.status(500).json({ message: "Error booking appointment" });
  }
}

/** PATCH /api/appointments/:id/dismiss-cancel-alert — patient acknowledges doctor cancellation card */
async function dismissCancelAlert(req, res) {
  try {
    const id = String(req.params.id || "").trim();
    const patientUserId = String(req.body?.patientUserId || "").trim();

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid appointment id" });
    }
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "patientUserId required" });
    }

    const appt = await AppointmentModel.findById(id);
    if (!appt) return res.status(404).json({ message: "Appointment not found" });
    if (!appt.patientId || String(appt.patientId) !== patientUserId) {
      return res.status(403).json({ message: "Not your appointment" });
    }
    if (appt.status !== "cancelled_by_doctor") {
      return res.status(400).json({ message: "Not a doctor-cancelled appointment" });
    }

    appt.cancelAlertDismissed = true;
    await appt.save();

    const apptId = String(appt._id);
    await PatientNotification.updateMany(
      {
        patientUserId: appt.patientId,
        type: "appointment_cancelled_by_doctor",
        "meta.appointmentId": apptId,
      },
      { $set: { read: true } }
    );
    await UserNotification.updateMany(
      {
        userId: appt.patientId,
        type: "appointment_cancelled_by_doctor",
        "meta.appointmentId": apptId,
      },
      { $set: { read: true } }
    );

    res.json({ message: "Cancellation alert dismissed", appointment: appt.toObject() });
  } catch (e) {
    console.error("[appointment-dismiss-cancel-alert]", e);
    res.status(500).json({ message: e.message || "Error dismissing alert" });
  }
}

/** GET /api/patients/:patientUserId/my-bookings */
async function getPatientMyBookings(req, res) {
  try {
    const patientUserId = String(req.params.patientUserId || req.params.id || "").trim();
    if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid patient id" });
    }

    const confirmedRaw = await AppointmentModel.find(
      patientActiveBookingQuery({ patientId: patientUserId })
    )
      .sort({ date: 1, time: 1 })
      .lean();

    const confirmedBookings = confirmedRaw.map((a) => ({
      ...a,
      promotedFromWaitlist: a.promotedFromWaitlist === true,
      isForceAccepted: a.isForceAccepted === true,
      canCancel: isPatientBookedActive(a),
    }));

    const waitingListsRaw = await WaitingListEntry.find({
      patientUserId,
      status: "Active",
    })
      .sort({ watchSlotDate: 1, watchSlotTime: 1, createdAt: 1 })
      .lean();

    const waitingLists = await enrichWaitingListEntries(waitingListsRaw);

    res.json({ confirmedBookings, waitingLists });
  } catch (e) {
    console.error("[getPatientMyBookings]", e);
    res.status(500).json({ message: e.message || "Error loading bookings" });
  }
}

/**
 * POST /api/doctor/appointments/force-accept
 * body: { waitingListEntryId }
 * Doctor manually seats a second patient in a slot that already has one primary booking.
 */
async function forceAcceptFromWaitlist(req, res) {
  try {
    const doctor = await resolveDoctorUser(req);
    if (!doctor) return res.status(403).json({ message: "Doctor authentication required" });

    const waitingListEntryId = String(req.body?.waitingListEntryId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(waitingListEntryId)) {
      return res.status(400).json({ message: "waitingListEntryId is required" });
    }

    const entry = await WaitingListEntry.findById(waitingListEntryId);
    if (!entry || entry.status !== "Active") {
      return res.status(404).json({ message: "Waiting list entry not found or inactive" });
    }

    const doctorUserId = entry.doctorUserId || doctor._id;
    if (String(doctorUserId) !== String(doctor._id)) {
      return res.status(403).json({ message: "Not authorized for this waitlist entry" });
    }

    const dateYmd = entry.watchSlotDate;
    const slotNorm = normalizeSlotTime(entry.watchSlotTime);
    if (!dateYmd || !slotNorm) {
      return res.status(400).json({ message: "Waiting list entry missing slot date/time" });
    }

    const primaryCount = await AppointmentModel.countDocuments(
      primarySlotOccupancyQuery({
        doctorUserId: new mongoose.Types.ObjectId(String(doctorUserId)),
        date: dateYmd,
        time: slotNorm,
      })
    );

    const forceCount = await AppointmentModel.countDocuments(
      activeSlotOccupancyQuery({
        doctorUserId: new mongoose.Types.ObjectId(String(doctorUserId)),
        date: dateYmd,
        time: slotNorm,
        isForceAccepted: true,
      })
    );

    if (primaryCount < 1) {
      return res.status(409).json({
        message: "No primary booking exists for this slot. Use standard promotion or patient booking first.",
      });
    }
    if (forceCount >= 1) {
      return res.status(409).json({
        message: "This slot already has a force-accepted second patient.",
      });
    }

    const patient = await UserModel.findById(entry.patientUserId).lean();
    if (!patient) return res.status(404).json({ message: "Patient not found" });

    const docProfile = await Doctor.findOne({ userId: doctorUserId }).lean();
    const doctorName =
      docProfile?.displayName || doctor.name || entry.notes || "Doctor";

    const appt = await AppointmentModel.create({
      patientName: patient.name || "Patient",
      patientId: entry.patientUserId,
      time: slotNorm,
      date: dateYmd,
      orgId: doctor.orgId || patient.orgId || null,
      status: "booked",
      bookingStatus: "Accepted",
      doctorUserId: new mongoose.Types.ObjectId(String(doctorUserId)),
      doctorName,
      promotedFromWaitlist: false,
      isForceAccepted: true,
    });

    entry.status = "Promoted";
    entry.promotedAppointmentId = appt._id;
    await entry.save();

    await PatientNotification.create({
      patientUserId: entry.patientUserId,
      type: "waitlist_force_accepted",
      title: "Confirmed by your doctor",
      body: `Dr. ${doctorName} confirmed your appointment on ${dateYmd} at ${entry.watchSlotTime}.`,
      read: false,
      meta: { appointmentId: String(appt._id), doctorUserId: String(doctorUserId) },
    });

    res.status(201).json({
      message: "Patient force-accepted into slot",
      appointment: appt.toObject(),
      waitingListEntry: entry.toObject(),
    });
  } catch (e) {
    console.error("[forceAcceptFromWaitlist]", e);
    res.status(500).json({ message: e.message || "Error force-accepting patient" });
  }
}

module.exports = {
  postponeAppointment,
  rescheduleAppointment,
  getAvailableDates,
  getDoctorActiveDays,
  getAvailableSlots,
  postSlotWaitingList,
  leaveWaitingListEntry,
  leaveSlotWaitingList,
  getPatientMyBookings,
  forceAcceptFromWaitlist,
  cancelByDoctor,
  cancelByPatient,
  bookAppointment,
  validatePatientBookingLimits,
  dismissCancelAlert,
};
