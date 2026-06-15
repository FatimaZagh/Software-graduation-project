const mongoose = require("mongoose");
const Doctor = require("../models/doctor");
const AppointmentModel = require("../models/appointment");
const HealthProfile = require("../models/healthProfile");
const Patient = require("../models/patient");
const PatientMedication = require("../models/patientMedication");
const MedicalRecord = require("../models/medicalRecord");
const WaitingListEntry = require("../models/waitingListEntry");
const ChatMessage = require("../models/chatMessage");
const VisitRating = require("../models/visitRating");
const Prescription = require("../models/prescription");
const ElectronicPrescription = require("../models/electronicPrescription");
const ClinicSession = require("../models/clinicSession");
const UserNotification = require("../models/userNotification");
const PatientMedicalProfile = require("../models/patientMedicalProfile");
const LabRequest = require("../models/labRequest");
const { resolveDoctorOrgId, ensureUserOrgId } = require("../utils/doctorOrgScope");

const UserModel = mongoose.model("users");
const {
  normalizeDateToYmd,
  appointmentMatchQuery,
  apptMatchesDoctor,
} = require("../utils/doctorPortalHelpers");
const { resolveHospitalClinicId } = require("../utils/hospitalClinic");
const { enrichDoctorProfileResponse } = require("../utils/dynamicSchedule");
const { enrichDoctorFacilityFields } = require("../utils/doctorFacilityBinding");
const { resolveDoctorBillingConfig, saveDoctorClinicServices } = require("../utils/billingConfig");
const { encryptMessage } = require("../utils/chatCrypto");
const { resolveChatOrgId, buildBidirectionalChatQuery, mapChatMessageRow } = require("../utils/chatThread");

async function notifyUser(userId, { type = "info", title, body = "", meta = {} }) {
  if (!userId) return;
  await UserNotification.create({
    userId,
    role: "Doctor",
    type,
    title: String(title || "").slice(0, 140),
    body: String(body || "").slice(0, 500),
    read: false,
    meta,
  });
}

exports.validateDoctorUser = async (req, res, next, id) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid doctorUserId" });
    }
    const u = await UserModel.findById(id).lean();
    if (!u) return res.status(404).json({ message: "User not found" });
    if (u.role !== "Doctor") {
      return res.status(403).json({ message: "Doctor role required" });
    }
    const orgId = await resolveDoctorOrgId(req, u);
    if (!orgId) {
      return res.status(403).json({ message: "orgId is required" });
    }
    if (u.orgId && String(u.orgId) !== String(orgId)) {
      return res.status(403).json({ message: "Org scope mismatch" });
    }
    await ensureUserOrgId(u._id, orgId);
    req.doctorUserId = id;
    req.doctorUser = { ...u, orgId };
    req.doctorOrgId = orgId;
    req.query.orgId = String(orgId);
    next();
  } catch (e) {
    res.status(500).json({ message: "Auth check failed" });
  }
};

async function ensureDoctorProfile(userId, orgIdHint = null) {
  const hospitalId = await resolveHospitalClinicId();
  const u = await UserModel.findById(userId).lean();
  const resolvedOrgId =
    orgIdHint ||
    (u?.orgId && mongoose.Types.ObjectId.isValid(String(u.orgId)) ? u.orgId : null);

  let d = await Doctor.findOne({ userId }).lean();
  if (d) {
    const patch = {};
    if (resolvedOrgId && !d.orgId) patch.orgId = resolvedOrgId;
    if (hospitalId && !d.clinicId) patch.clinicId = hospitalId;
    if (Object.keys(patch).length) {
      await Doctor.updateOne({ userId }, { $set: patch });
      d = await Doctor.findOne({ userId }).lean();
    }
    return enrichDoctorProfileResponse(d);
  }

  const created = await Doctor.create({
    userId,
    orgId: resolvedOrgId || undefined,
    displayName: u?.name || "Doctor",
    email: u?.email || "",
    clinicId: u?.clinicId || hospitalId || undefined,
  });
  return enrichDoctorProfileResponse(created.toObject());
}

exports.getProfile = async (req, res) => {
  try {
    let d = await ensureDoctorProfile(req.doctorUserId, req.doctorOrgId);
    const before = {
      orgId: d.orgId,
      clinicId: d.clinicId,
      currentClinic: d.currentClinic,
    };
    d = await enrichDoctorFacilityFields(d);
    const patch = {};
    if (d.orgId && !before.orgId) patch.orgId = d.orgId;
    if (d.clinicId && !before.clinicId) patch.clinicId = d.clinicId;
    if (d.currentClinic && !before.currentClinic) patch.currentClinic = d.currentClinic;
    if (Object.keys(patch).length) {
      await Doctor.updateOne({ userId: req.doctorUserId }, { $set: patch });
    }
    const billing = await resolveDoctorBillingConfig(req.doctorUserId);
    const profile = enrichDoctorProfileResponse(d);
    profile.consultationFee = billing.consultationFee;
    res.json(profile);
  } catch (e) {
    res.status(500).json({ message: "Error loading doctor profile" });
  }
};

exports.putProfile = async (req, res) => {
  try {
    await ensureDoctorProfile(req.doctorUserId);
    const allowed = [
      "certifications",
      "consultationFee",
      "profileImageBase64",
      "availabilityStatus",
    ];
    const $set = {};
    for (const k of allowed) {
      if (Object.prototype.hasOwnProperty.call(req.body, k)) {
        $set[k] = req.body[k];
      }
    }
    if ($set.profileImageBase64 != null) {
      $set.profileImageBase64 = String($set.profileImageBase64).slice(0, 1_200_000);
    }
    if ($set.yearsExperience != null) {
      const n = Number($set.yearsExperience);
      $set.yearsExperience = Number.isNaN(n) ? 0 : n;
      $set.yearsOfExperience = $set.yearsExperience;
    }
    if ($set.yearsOfExperience != null) {
      const n = Number($set.yearsOfExperience);
      $set.yearsOfExperience = Number.isNaN(n) ? 0 : n;
      $set.yearsExperience = $set.yearsOfExperience;
    }
    if ($set.specialty != null) {
      $set.specialization = String($set.specialty);
    }
    if ($set.specialization != null && $set.specialty == null) {
      $set.specialty = String($set.specialization);
    }
    if ($set.consultationFee != null) {
      const n = Number($set.consultationFee);
      if (!Number.isNaN(n) && n > 0) {
        $set.consultationFee = n;
        $set["clinicServicesConfig.consultationFee"] = n;
      } else {
        delete $set.consultationFee;
      }
    }
    const hospitalId = await resolveHospitalClinicId();
    if (hospitalId) {
      $set.clinicId = hospitalId;
    }
    const updated = await Doctor.findOneAndUpdate(
      { userId: req.doctorUserId },
      { $set },
      { new: true, upsert: false }
    ).lean();
    if (updated?.displayName) {
      await UserModel.findByIdAndUpdate(req.doctorUserId, { name: updated.displayName });
    }
    res.json(updated);
  } catch (e) {
    res.status(500).json({ message: "Error saving doctor profile" });
  }
};

exports.getClinicServices = async (req, res) => {
  try {
    await ensureDoctorProfile(req.doctorUserId, req.doctorOrgId);
    const cfg = await resolveDoctorBillingConfig(req.doctorUserId);
    res.json({ ...cfg, currency: "ILS" });
  } catch (e) {
    res.status(500).json({ message: "Error loading clinic services configuration" });
  }
};

exports.putClinicServices = async (req, res) => {
  try {
    await ensureDoctorProfile(req.doctorUserId, req.doctorOrgId);
    const saved = await saveDoctorClinicServices(req.doctorUserId, req.body || {});
    res.json({ ...saved, currency: "ILS" });
  } catch (e) {
    res.status(e.status || 500).json({ message: e.message || "Error saving clinic services" });
  }
};

exports.getAppointments = async (req, res) => {
  try {
    const doc = await ensureDoctorProfile(req.doctorUserId);
    const q = appointmentMatchQuery(
      req.doctorUserId,
      doc.displayName,
      req.doctorUser?.name
    );
    const list = await AppointmentModel.find(q).sort({ date: 1, time: 1 }).lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error listing appointments" });
  }
};

exports.patchAppointmentBooking = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const { bookingStatus } = req.body;
    if (!["Pending", "Accepted", "Rejected"].includes(bookingStatus)) {
      return res.status(400).json({ message: "Invalid bookingStatus" });
    }
    const doc = await ensureDoctorProfile(req.doctorUserId);
    const appt = await AppointmentModel.findById(appointmentId);
    if (!appt) return res.status(404).json({ message: "Appointment not found" });
    if (!apptMatchesDoctor(appt, req.doctorUserId, doc.displayName, req.doctorUser?.name)) {
      return res.status(403).json({ message: "Not assigned to this doctor" });
    }
    appt.bookingStatus = bookingStatus;
    if (bookingStatus === "Accepted") {
      appt.doctorUserId = req.doctorUserId;
      if (!appt.doctorName && doc.displayName) appt.doctorName = doc.displayName;
    }
    await appt.save();
    res.json(appt.toObject());
  } catch (e) {
    res.status(500).json({ message: "Error updating booking" });
  }
};

exports.patchAppointmentReschedule = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const { date, time } = req.body;
    if (!date || !time) return res.status(400).json({ message: "date and time required" });
    const doc = await ensureDoctorProfile(req.doctorUserId);
    const appt = await AppointmentModel.findById(appointmentId);
    if (!appt) return res.status(404).json({ message: "Not found" });
    if (!apptMatchesDoctor(appt, req.doctorUserId, doc.displayName, req.doctorUser?.name)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    appt.date = normalizeDateToYmd(date) || String(date).trim();
    appt.time = String(time).trim();
    appt.bookingStatus = "Accepted";
    await appt.save();
    // Notify patient if linked
    try {
      const PatientNotification = require("../models/patientNotification");
      if (appt.patientId) {
        await PatientNotification.create({
          patientUserId: appt.patientId,
          type: "appointment_rescheduled",
          title: "Your appointment was rescheduled",
          body: `New time: ${appt.date} ${appt.time}`,
          read: false,
          meta: { appointmentId: String(appt._id), doctorUserId: String(req.doctorUserId) },
        });
      }
    } catch (_) {}
    res.json(appt.toObject());
  } catch (e) {
    res.status(500).json({ message: "Error rescheduling" });
  }
};

exports.patchAppointmentVisit = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const { status } = req.body;
    if (!["Waiting", "In Progress", "Completed", "Cancelled"].includes(status)) {
      return res.status(400).json({ message: "Invalid visit status" });
    }
    const doc = await ensureDoctorProfile(req.doctorUserId);
    const appt = await AppointmentModel.findById(appointmentId);
    if (!appt) return res.status(404).json({ message: "Not found" });
    if (!apptMatchesDoctor(appt, req.doctorUserId, doc.displayName, req.doctorUser?.name)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    appt.status = status;
    await appt.save();
    if (status === "In Progress") {
      await ClinicSession.findOneAndUpdate(
        { appointmentId: appt._id },
        {
          $set: {
            doctorUserId: req.doctorUserId,
            patientUserId: appt.patientId || null,
            startedAt: new Date(),
          },
        },
        { upsert: true, new: true }
      );
    }
    if (status === "Completed") {
      await ClinicSession.findOneAndUpdate(
        { appointmentId: appt._id },
        { $set: { endedAt: new Date() } }
      );
    }
    res.json(appt.toObject());
  } catch (e) {
    res.status(500).json({ message: "Error updating visit" });
  }
};

exports.getWaitingList = async (req, res) => {
  try {
    const list = await WaitingListEntry.find({ status: "Active" })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading waiting list" });
  }
};

exports.getPreconsult = async (req, res) => {
  try {
    const { patientUserId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid patient id" });
    }
    const health = await HealthProfile.findOne({ userId: patientUserId }).lean();
    const patient = await Patient.findOne({ userId: patientUserId }).lean();
    const meds = await PatientMedication.find({ patientUserId, active: true }).lean();
    const appts = await AppointmentModel.find({ patientId: patientUserId })
      .sort({ date: -1, time: -1 })
      .limit(20)
      .lean();
    const apptIds = appts.map((a) => a._id);
    let records = [];
    if (apptIds.length) {
      records = await MedicalRecord.find({ appointmentId: { $in: apptIds } })
        .sort({ createdAt: -1 })
        .limit(15)
        .lean();
    }
    const medicalProfile = await PatientMedicalProfile.findOne({ userId: patientUserId }).lean();
    const labs = await LabRequest.find({ patientUserId })
      .sort({ createdAt: -1 })
      .limit(20)
      .lean();

    const nursingNotes = (medicalProfile?.nursingNotes || []).filter(
      (n) => n.visibleToDoctorOnly || n.noteType === "doctor_alert" || n.noteType === "initial_symptoms"
    );

    res.json({
      healthProfile: health || {},
      patient: patient || {},
      currentMedications: meds,
      recentAppointments: appts,
      recentMedicalRecords: records,
      vitalsTimeline: medicalProfile?.vitalsTimeline || [],
      medicationAdministration: medicalProfile?.medicationAdministration || [],
      nursingNotes,
      labRequests: labs,
    });
  } catch (e) {
    res.status(500).json({ message: "Error loading preconsult" });
  }
};

exports.getSession = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    let s = await ClinicSession.findOne({ appointmentId }).lean();
    if (!s) {
      s = {
        appointmentId,
        diagnosis: "",
        notes: "",
        vitals: {},
        attachments: [],
      };
    }
    res.json(s);
  } catch (e) {
    res.status(500).json({ message: "Error loading session" });
  }
};

exports.putSession = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const appt = await AppointmentModel.findById(appointmentId);
    if (!appt) return res.status(404).json({ message: "Appointment not found" });
    const doc = await ensureDoctorProfile(req.doctorUserId);
    if (!apptMatchesDoctor(appt, req.doctorUserId, doc.displayName, req.doctorUser?.name)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    const { diagnosis, notes, vitals, attachments } = req.body;
    const $set = {
      doctorUserId: req.doctorUserId,
      patientUserId: appt.patientId || null,
    };
    if (diagnosis != null) $set.diagnosis = String(diagnosis);
    if (notes != null) $set.notes = String(notes);
    if (vitals != null && typeof vitals === "object") $set.vitals = vitals;
    if (Array.isArray(attachments)) {
      $set.attachments = attachments.map((a) => ({
        fileName: String(a.fileName || "file").slice(0, 200),
        mimeType: String(a.mimeType || "application/octet-stream").slice(0, 120),
        dataBase64: String(a.dataBase64 || "").slice(0, 900_000),
      }));
    }
    const updated = await ClinicSession.findOneAndUpdate(
      { appointmentId },
      { $set },
      { new: true, upsert: true }
    ).lean();
    res.json(updated);
  } catch (e) {
    res.status(500).json({ message: "Error saving session" });
  }
};

exports.postPrescription = async (req, res) => {
  try {
    const {
      patientUserId,
      appointmentId,
      items,
      signatureImageBase64,
    } = req.body;
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "patientUserId required" });
    }
    const doc = await ensureDoctorProfile(req.doctorUserId);
    const lines = Array.isArray(items) ? items : [];
    const sig = signatureImageBase64 ? String(signatureImageBase64).slice(0, 500_000) : "";

    const { collectAllergyStrings, evaluatePrescriptionAllergies } = require("../utils/allergyCdss");
    const medical = await PatientMedicalProfile.findOne({ userId: patientUserId }).lean();
    const health = await HealthProfile.findOne({ userId: patientUserId }).lean();
    const allergyList = collectAllergyStrings(medical, health);
    const medNames = lines.map((it) => String(it.name || "").trim()).filter(Boolean);
    const allergyCheck = evaluatePrescriptionAllergies(allergyList, medNames);
    if (allergyCheck.blocked && !req.body.overrideAllergyCheck) {
      return res.status(409).json({
        code: "ALLERGY_CDSS_BLOCK",
        blocked: true,
        message: allergyCheck.message,
        conflicts: allergyCheck.conflicts,
      });
    }

    const rx = await Prescription.create({
      patientUserId,
      doctorUserId: req.doctorUserId,
      appointmentId: appointmentId && mongoose.Types.ObjectId.isValid(appointmentId) ? appointmentId : null,
      doctorDisplayName: doc.displayName || "Doctor",
      items: lines.map((it) => ({
        name: String(it.name || "").trim(),
        dosage: String(it.dosage || ""),
        duration: String(it.duration || ""),
        instructions: String(it.instructions || ""),
        frequency: String(it.frequency || ""),
      })),
      signatureImageBase64: sig,
      syncedToPharmacy: true,
      syncedToPatientApp: true,
    });

    await ElectronicPrescription.create({
      orgId: req.doctorUser?.orgId || null,
      patientUserId,
      doctorUserId: req.doctorUserId,
      appointmentId: rx.appointmentId,
      doctorName: rx.doctorDisplayName,
      items: rx.items.map((it) => ({
        name: it.name,
        dosage: it.dosage,
        frequency: it.frequency,
        duration: it.duration,
        instructions: it.instructions,
      })),
      signatureImageBase64: sig,
    });

    const { parseDurationInDays } = require("../services/medicationLifecycle");
    for (const it of rx.items) {
      if (!it.name) continue;
      const days = parseDurationInDays(it.duration, it.durationInDays);
      await PatientMedication.create({
        patientUserId,
        prescribingDoctorUserId: req.doctorUserId,
        medicationName: it.name,
        dosage: it.dosage,
        frequency: it.frequency || `${it.duration} — ${it.instructions}`.trim(),
        prescribedBy: rx.doctorDisplayName,
        notes: it.instructions,
        status: "Active",
        active: false,
        startDate: null,
        durationInDays: days,
      });
    }

    res.status(201).json(rx.toObject());
  } catch (e) {
    res.status(500).json({ message: "Error creating prescription" });
  }
};

exports.getChatPatients = async (req, res) => {
  try {
    const doctorId = new mongoose.Types.ObjectId(req.doctorUserId);
    const ids = await ChatMessage.aggregate([
      {
        $match: {
          $or: [{ senderId: doctorId }, { receiverId: doctorId }],
        },
      },
      {
        $project: {
          otherId: {
            $cond: [{ $eq: ["$senderId", doctorId] }, "$receiverId", "$senderId"],
          },
        },
      },
      { $group: { _id: "$otherId" } },
    ]);
    const otherIds = ids.map((x) => x._id).filter(Boolean);
    const users = await UserModel.find({ _id: { $in: otherIds }, role: "Patient" })
      .select("name email profileImageUrl")
      .lean();
    res.json(users);
  } catch (e) {
    res.status(500).json({ message: "Error listing chat patients" });
  }
};

exports.getChatMessages = async (req, res) => {
  try {
    const { patientUserId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid patientUserId" });
    }
    const doctorId = req.doctorUserId;
    const filter = buildBidirectionalChatQuery(doctorId, patientUserId);
    const list = await ChatMessage.find(filter).sort({ createdAt: 1 }).limit(200).lean();
    res.json(list.map(mapChatMessageRow));
  } catch (e) {
    console.error("getChatMessages", e);
    res.status(500).json({ message: "Error loading messages" });
  }
};

exports.postChatMessage = async (req, res) => {
  try {
    const { patientUserId } = req.params;
    const { body } = req.body;
    if (!body || !String(body).trim()) return res.status(400).json({ message: "body required" });
    if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid patientUserId" });
    }
    const orgId = resolveChatOrgId(req);
    if (!orgId) {
      return res.status(403).json({ message: "orgId is required" });
    }
    const patient = await UserModel.findById(patientUserId).lean();
    if (!patient || patient.role !== "Patient") return res.status(404).json({ message: "Patient not found" });

    const enc = encryptMessage(String(body).trim(), req.doctorUserId, patientUserId);
    const msg = await ChatMessage.create({
      orgId,
      senderId: req.doctorUserId,
      receiverId: patientUserId,
      senderRole: "doctor",
      receiverRole: "patient",
      bodyEnc: enc,
      body: "",
    });
    // Notify patient
    try {
      const PatientNotification = require("../models/patientNotification");
      const doc = await ensureDoctorProfile(req.doctorUserId);
      await PatientNotification.create({
        patientUserId,
        type: "message",
        title: `${doc.displayName || "Doctor"} sent you a message`,
        body: String(body).trim().slice(0, 120),
        read: false,
        meta: {
          doctorUserId: String(req.doctorUserId),
          senderId: String(req.doctorUserId),
          receiverId: String(patientUserId),
        },
      });
    } catch (_) {}
    const row = mapChatMessageRow(msg.toObject());
    if (!row.body) {
      const plain = String(body).trim();
      row.body = plain;
      row.text = plain;
      row.message = plain;
      row.content = plain;
    }
    res.status(201).json(row);
  } catch (e) {
    res.status(500).json({ message: "Error sending message" });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const list = await UserNotification.find({ userId: req.doctorUserId })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading notifications" });
  }
};

exports.patchNotificationRead = async (req, res) => {
  try {
    const { notificationId } = req.params;
    const n = await UserNotification.findOneAndUpdate(
      { _id: notificationId, userId: req.doctorUserId },
      { $set: { read: true } },
      { new: true }
    ).lean();
    if (!n) return res.status(404).json({ message: "Notification not found" });
    res.json(n);
  } catch (e) {
    res.status(500).json({ message: "Error updating notification" });
  }
};

exports.getReviews = async (req, res) => {
  try {
    const doc = await ensureDoctorProfile(req.doctorUserId);
    const q = appointmentMatchQuery(
      req.doctorUserId,
      doc.displayName,
      req.doctorUser?.name
    );
    const apptIds = (await AppointmentModel.find(q).select("_id").lean()).map((a) => a._id);
    const list = await VisitRating.find({
      $or: [{ doctorUserId: req.doctorUserId }, { appointmentId: { $in: apptIds } }],
    })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading reviews" });
  }
};

exports.getAnalytics = async (req, res) => {
  try {
    const doc = await ensureDoctorProfile(req.doctorUserId);
    const q = appointmentMatchQuery(
      req.doctorUserId,
      doc.displayName,
      req.doctorUser?.name
    );
    const all = await AppointmentModel.find(q).lean();
    const today = new Date();
    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, "0");
    const d = String(today.getDate()).padStart(2, "0");
    const todayStr = `${y}-${m}-${d}`;
    const todayAppts = all.filter((a) => normalizeDateToYmd(a.date) === todayStr);
    const completed = all.filter((a) => a.status === "Completed").length;
    const cancelled = all.filter((a) => a.status === "Cancelled").length;
    const total = all.length;
    const uniquePatients = new Set(
      all.map((a) => String(a.patientId || "")).filter(Boolean)
    ).size;
    const fee = doc.consultationFee ? Number(doc.consultationFee) : 0;
    const safeFee = Number.isFinite(fee) ? fee : 0;
    const completedToday = todayAppts.filter((a) => a.status === "Completed").length;
    const earningsToday = completedToday * safeFee;
    const cancellationRate = total ? Math.round((cancelled / total) * 1000) / 10 : 0;

    res.json({
      totalPatientsToday: new Set(
        todayAppts.map((a) => String(a.patientId || "")).filter(Boolean)
      ).size,
      /** Appointments scheduled for the server's local calendar "today" (YYYY-MM-DD normalized). */
      appointmentsToday: todayAppts.length,
      /** All appointments ever assigned to this doctor (matched by id + name rules). */
      totalAppointments: total,
      earningsToday,
      newPatientsApprox: uniquePatients,
      cancellationRate,
      consultationFee: safeFee,
      /** Echo for debugging clients (local server date). */
      statsDateLocal: todayStr,
    });
  } catch (e) {
    res.status(500).json({ message: "Error analytics" });
  }
};
