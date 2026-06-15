const mongoose = require("mongoose");
const Doctor = require("../models/doctor");
const UserModel = require("../models/User");
const Patient = require("../models/patient");
const HealthProfile = require("../models/healthProfile");
const PatientMedicalProfile = require("../models/patientMedicalProfile");
const PatientMedication = require("../models/patientMedication");
const AppointmentModel = require("../models/appointment");
const MedicalRecord = require("../models/medicalRecord");
const Prescription = require("../models/prescription");
const LabRequest = require("../models/labRequest");
const RadiologyRequest = require("../models/radiologyRequest");
const Diagnosis = require("../models/diagnosis");
const DoctorNote = require("../models/doctorNote");
const UserNotification = require("../models/userNotification");
const Staff = require("../models/staff");
const {
  appointmentMatchQuery,
  apptMatchesDoctor,
  normalizeDateToYmd,
} = require("../utils/doctorPortalHelpers");
const { enrichDoctorProfileResponse } = require("../utils/dynamicSchedule");
const { enrichDoctorFacilityFields } = require("../utils/doctorFacilityBinding");

function todayYmd() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function scope(req) {
  return req.doctorScope;
}

/** Enforce visit lifecycle rules for appointment-linked clinical writes. */
async function assertAppointmentClinicalWritable(appointmentId, orgId) {
  if (!appointmentId || !mongoose.Types.ObjectId.isValid(appointmentId)) {
    return { appointment: null, upsert: false };
  }
  const appt = await AppointmentModel.findOne({ _id: appointmentId, orgId }).lean();
  if (!appt) {
    const err = new Error("Appointment not found");
    err.statusCode = 404;
    throw err;
  }
  if (appt.status === "Completed") {
    const err = new Error("This visit is completed — clinical records are locked.");
    err.statusCode = 403;
    err.code = "SESSION_LOCKED";
    throw err;
  }
  if (appt.status !== "In Progress") {
    const err = new Error("Start the visit before saving clinical data for this appointment.");
    err.statusCode = 409;
    err.code = "VISIT_NOT_IN_PROGRESS";
    throw err;
  }
  return { appointment: appt, upsert: true };
}

async function patientIdsForDoctor(doctorUserId, orgId) {
  const doc = await Doctor.findOne({ userId: doctorUserId }).lean();
  const u = await UserModel.findById(doctorUserId).select("name").lean();
  const q = appointmentMatchQuery(doctorUserId, doc?.displayName, u?.name);
  q.orgId = orgId;
  const appts = await AppointmentModel.find(q).select("patientId patientName").lean();
  const ids = new Set();
  for (const a of appts) {
    if (a.patientId) ids.add(String(a.patientId));
  }
  const [rxIds, dxIds] = await Promise.all([
    Prescription.distinct("patientUserId", { doctorUserId, orgId }),
    Diagnosis.distinct("patientUserId", { doctorUserId, orgId }),
  ]);
  for (const id of [...rxIds, ...dxIds]) {
    if (id) ids.add(String(id));
  }
  return { ids: [...ids], doc, user: u };
}

/** GET /dashboard/stats */
async function getDashboardStats(req, res) {
  const { orgId, doctorUserId, doctorProfile } = scope(req);
  const today = todayYmd();
  const { ids } = await patientIdsForDoctor(doctorUserId, orgId);
  const apptQ = appointmentMatchQuery(doctorUserId, doctorProfile.displayName, scope(req).user.name);
  apptQ.orgId = orgId;

  const [apptsToday, chronicCount, followUpCount, totalPatients, completedVisits] = await Promise.all([
    AppointmentModel.countDocuments({ ...apptQ, date: today, bookingStatus: { $ne: "Rejected" } }),
    PatientMedicalProfile.countDocuments({
      userId: { $in: ids },
      chronicDiseases: { $exists: true, $not: { $size: 0 } },
    }),
    AppointmentModel.countDocuments({
      ...apptQ,
      date: { $gte: today },
      status: { $in: ["Waiting", "In Progress"] },
    }),
    ids.length,
    AppointmentModel.countDocuments({ ...apptQ, status: "Completed" }),
  ]);

  res.json({
    totalPatients,
    dailyCases: apptsToday,
    chronicPatients: chronicCount,
    followUpAppointments: followUpCount,
    completedVisits,
    availabilityStatus: doctorProfile.availabilityStatus || "Available",
  });
}

/** GET /queue/today */
async function getTodayQueue(req, res) {
  const { orgId, doctorUserId, doctorProfile, user } = scope(req);
  const today = todayYmd();
  const q = appointmentMatchQuery(doctorUserId, doctorProfile.displayName, user.name);
  q.orgId = orgId;
  q.date = today;
  q.bookingStatus = { $in: ["Pending", "Accepted"] };
  const list = await AppointmentModel.find(q).sort({ time: 1 }).lean();
  res.json(list);
}

/** PUT /availability */
async function putAvailability(req, res) {
  const { doctorUserId } = scope(req);
  const status = String(req.body?.status || "").trim();
  const allowed = ["Available", "Busy", "In Surgery", "Offline"];
  if (!allowed.includes(status)) {
    return res.status(400).json({ message: `status must be one of: ${allowed.join(", ")}` });
  }
  const updated = await Doctor.findOneAndUpdate(
    { userId: doctorUserId },
    { $set: { availabilityStatus: status } },
    { new: true }
  ).lean();
  res.json({ availabilityStatus: updated?.availabilityStatus || status });
}

/** GET /patients */
async function listPatients(req, res) {
  const { orgId, doctorUserId } = scope(req);
  const q = String(req.query.q || "").trim().toLowerCase();
  const { ids } = await patientIdsForDoctor(doctorUserId, orgId);
  if (!ids.length) return res.json([]);

  const users = await UserModel.find({ _id: { $in: ids }, role: "Patient" })
    .select("name email profileImageUrl phoneNumber")
    .lean();
  const patients = await Patient.find({ userId: { $in: ids } }).lean();
  const byUser = Object.fromEntries(patients.map((p) => [String(p.userId), p]));

  let rows = users.map((u) => {
    const profile = byUser[String(u._id)] || {};
    return {
      patientUserId: String(u._id),
      name: u.name || profile.fullName || "Patient",
      email: u.email,
      phone: u.phoneNumber || profile.phone || "",
      profileImageUrl: u.profileImageUrl || profile.profileImage || "",
      age: profile.age ?? null,
      gender: profile.gender || "",
    };
  });
  if (q) {
    rows = rows.filter(
      (r) => r.name.toLowerCase().includes(q) || r.email.toLowerCase().includes(q) || r.phone.includes(q)
    );
  }
  res.json(rows);
}

function mapPrescriptionLine(rx) {
  const firstItem = Array.isArray(rx.items) && rx.items.length ? rx.items[0] : null;
  return {
    id: String(rx._id),
    medicationName: rx.medicationName || firstItem?.name || "Medication",
    dosage: rx.dosage || firstItem?.dosage || "",
    frequency: rx.frequency || firstItem?.frequency || "",
    duration: rx.duration || firstItem?.duration || "",
    durationInDays: rx.durationInDays ?? firstItem?.durationInDays ?? null,
    instructions: rx.instructions || firstItem?.instructions || "",
    status: rx.status || "Active",
  };
}

/** Merge diagnoses + prescriptions into a chronological visit timeline. */
function buildPatientVisitTimeline({ diagnoses, prescriptions, appointments }) {
  const entries = [];
  const usedRxIds = new Set();
  const apptById = new Map(appointments.map((a) => [String(a._id), a]));

  for (const dx of diagnoses) {
    const dxTime = new Date(dx.createdAt || 0).getTime();
    const linkedRx = prescriptions.filter((rx) => {
      const rxId = String(rx._id);
      if (usedRxIds.has(rxId)) return false;
      if (dx.appointmentId && rx.appointmentId && String(dx.appointmentId) === String(rx.appointmentId)) {
        return true;
      }
      const rxTime = new Date(rx.createdAt || 0).getTime();
      return Math.abs(rxTime - dxTime) <= 2 * 60 * 60 * 1000;
    });
    linkedRx.forEach((rx) => usedRxIds.add(String(rx._id)));

    let status = "Recorded";
    if (dx.appointmentId) {
      const appt = apptById.get(String(dx.appointmentId));
      if (appt) status = appt.status || appt.bookingStatus || status;
    }

    entries.push({
      id: String(dx._id),
      visitDate: dx.createdAt,
      status,
      diagnosis: {
        condition: dx.condition,
        symptoms: Array.isArray(dx.symptoms) ? dx.symptoms : [],
        severity: dx.severity || "Moderate",
        treatmentPlan: dx.treatmentPlan || "",
        notes: dx.notes || "",
      },
      prescriptions: linkedRx.map(mapPrescriptionLine),
    });
  }

  for (const rx of prescriptions) {
    if (usedRxIds.has(String(rx._id))) continue;
    let status = "Prescription";
    if (rx.appointmentId) {
      const appt = apptById.get(String(rx.appointmentId));
      if (appt) status = appt.status || appt.bookingStatus || status;
    }
    entries.push({
      id: String(rx._id),
      visitDate: rx.createdAt,
      status,
      diagnosis: null,
      prescriptions: [mapPrescriptionLine(rx)],
    });
  }

  entries.sort((a, b) => new Date(b.visitDate || 0) - new Date(a.visitDate || 0));
  return entries;
}

/** GET /patients/:patientUserId */
async function getPatientEmr(req, res) {
  const { orgId, doctorUserId, doctorProfile, user } = scope(req);
  const { patientUserId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
    return res.status(400).json({ message: "Invalid patient id" });
  }

  const { ids } = await patientIdsForDoctor(doctorUserId, orgId);
  if (!ids.includes(String(patientUserId))) {
    return res.status(403).json({ message: "Patient is not in your care panel" });
  }

  const pid = new mongoose.Types.ObjectId(patientUserId);
  const [patientUser, patient, health, medical, meds, appts, diagnoses, prescriptions, labs, radiology, notes, records] =
    await Promise.all([
      UserModel.findById(pid).lean(),
      Patient.findOne({ userId: pid }).lean(),
      HealthProfile.findOne({ userId: pid }).lean(),
      PatientMedicalProfile.findOne({ userId: pid }).lean(),
      PatientMedication.find({ patientUserId: pid, status: "Active", active: true }).lean(),
      AppointmentModel.find({ patientId: pid, orgId }).sort({ date: -1 }).limit(30).lean(),
      Diagnosis.find({ patientUserId: pid, orgId }).sort({ createdAt: -1 }).limit(100).lean(),
      Prescription.find({ patientUserId: pid, orgId }).sort({ createdAt: -1 }).limit(100).lean(),
      LabRequest.find({ patientUserId: pid, orgId }).sort({ createdAt: -1 }).limit(30).lean(),
      RadiologyRequest.find({ patientUserId: pid, orgId }).sort({ createdAt: -1 }).limit(30).lean(),
      DoctorNote.find({ patientUserId: pid, orgId, active: true }).sort({ createdAt: -1 }).limit(40).lean(),
      MedicalRecord.find({ orgId }).sort({ createdAt: -1 }).limit(20).lean(),
    ]);

  const apptIds = appts.map((a) => a._id);
  const linkedRecords = records.filter((r) => apptIds.some((id) => String(id) === String(r.appointmentId)));

  const allergyMeds = [
    ...(medical?.allergies?.medications || []),
    ...(health?.allergies || []),
  ].filter(Boolean);

  const visitTimeline = buildPatientVisitTimeline({
    diagnoses,
    prescriptions,
    appointments: appts,
  });

  res.json({
    patient: patientUser,
    demographics: patient,
    healthProfile: health,
    medicalProfile: medical,
    allergies: allergyMeds,
    activeMedications: meds,
    visits: appts,
    diagnoses,
    prescriptions,
    visitTimeline,
    labRequests: labs,
    radiologyRequests: radiology,
    doctorNotes: notes,
    medicalRecords: linkedRecords,
    vitalsTimeline: medical?.vitalsTimeline || [],
  });
}

/** POST /diagnoses */
async function postDiagnosis(req, res) {
  const { orgId, doctorUserId } = scope(req);
  const { patientUserId, condition, severity, symptoms, treatmentPlan, notes, appointmentId } = req.body;
  if (!patientUserId || !condition) {
    return res.status(400).json({ message: "patientUserId and condition are required" });
  }

  const apptOid =
    appointmentId && mongoose.Types.ObjectId.isValid(appointmentId) ? appointmentId : null;
  let sessionPolicy = { appointment: null, upsert: false };
  try {
    sessionPolicy = await assertAppointmentClinicalWritable(apptOid, orgId);
  } catch (e) {
    return res.status(e.statusCode || 500).json({ message: e.message, code: e.code });
  }

  const payload = {
    condition: String(condition).trim(),
    severity: ["Mild", "Moderate", "Severe", "Critical"].includes(severity) ? severity : "Moderate",
    symptoms: Array.isArray(symptoms) ? symptoms.map(String) : [],
    treatmentPlan: treatmentPlan != null ? String(treatmentPlan) : "",
    notes: notes != null ? String(notes) : "",
    active: true,
  };

  if (sessionPolicy.upsert && apptOid) {
    const existing = await Diagnosis.findOne({
      orgId,
      patientUserId,
      appointmentId: apptOid,
      active: true,
    });
    if (existing) {
      Object.assign(existing, payload);
      await existing.save();
      return res.json({ ...existing.toObject(), isUpdate: true });
    }
  }

  const doc = await Diagnosis.create({
    orgId,
    doctorUserId,
    patientUserId,
    appointmentId: apptOid,
    ...payload,
  });
  res.status(201).json({ ...doc.toObject(), isUpdate: false });
}

/** POST /prescriptions */
async function postPrescription(req, res) {
  const { orgId, doctorUserId, doctorProfile } = scope(req);
  const {
    patientUserId,
    medicationName,
    dosage,
    frequency,
    duration,
    instructions,
    appointmentId,
    items,
  } = req.body;
  if (!patientUserId) return res.status(400).json({ message: "patientUserId required" });

  const lines = Array.isArray(items) && items.length
    ? items
    : [
        {
          name: medicationName,
          dosage,
          frequency,
          duration,
          instructions,
        },
      ];

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

  const apptOid =
    appointmentId && mongoose.Types.ObjectId.isValid(appointmentId) ? appointmentId : null;
  let sessionPolicy = { appointment: null, upsert: false };
  try {
    sessionPolicy = await assertAppointmentClinicalWritable(apptOid, orgId);
  } catch (e) {
    return res.status(e.statusCode || 500).json({ message: e.message, code: e.code });
  }

  const doctorDisplayName = doctorProfile.displayName || scope(req).user.name;
  const rxPayload = {
    doctorDisplayName,
    medicationName: String(medicationName || lines[0]?.name || "").trim(),
    dosage: String(dosage || lines[0]?.dosage || ""),
    frequency: String(frequency || lines[0]?.frequency || ""),
    duration: String(duration || lines[0]?.duration || ""),
    instructions: String(instructions || lines[0]?.instructions || ""),
    status: "Active",
    items: lines.map((it) => ({
      name: String(it.name || "").trim(),
      dosage: String(it.dosage || ""),
      frequency: String(it.frequency || ""),
      duration: String(it.duration || ""),
      instructions: String(it.instructions || ""),
    })),
  };

  const { parseDurationInDays } = require("../services/medicationLifecycle");
  let rx;
  let isUpdate = false;

  if (sessionPolicy.upsert && apptOid) {
    const existing = await Prescription.findOne({
      orgId,
      patientUserId,
      appointmentId: apptOid,
      status: "Active",
    });
    if (existing) {
      Object.assign(existing, rxPayload);
      await existing.save();
      rx = existing;
      isUpdate = true;
    }
  }

  if (!rx) {
    rx = await Prescription.create({
      orgId,
      patientUserId,
      doctorUserId,
      appointmentId: apptOid,
      ...rxPayload,
    });
  }

  for (const it of rx.items) {
    if (!it.name) continue;
    const days = parseDurationInDays(it.duration, it.durationInDays);
    const medFilter = {
      patientUserId,
      prescribingDoctorUserId: doctorUserId,
      medicationName: it.name,
    };
    const medPayload = {
      dosage: it.dosage,
      frequency: it.frequency,
      prescribedBy: rx.doctorDisplayName,
      notes: it.instructions,
      status: "Active",
      active: false,
      durationInDays: days,
    };
    if (isUpdate) {
      await PatientMedication.findOneAndUpdate(medFilter, { $set: medPayload });
    } else {
      await PatientMedication.create({
        ...medFilter,
        ...medPayload,
        startDate: null,
      });
    }
  }

  res.status(isUpdate ? 200 : 201).json({ ...rx.toObject(), isUpdate });
}

/** PUT /prescriptions/:id/stop */
async function stopPrescription(req, res) {
  const { doctorUserId } = scope(req);
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: "Invalid id" });
  const rx = await Prescription.findOneAndUpdate(
    { _id: id, doctorUserId, status: "Active" },
    {
      $set: {
        status: "Discontinued",
        discontinuedAt: new Date(),
        discontinuedBy: doctorUserId,
      },
    },
    { new: true }
  ).lean();
  if (!rx) return res.status(404).json({ message: "Prescription not found" });
  if (rx.medicationName) {
    await PatientMedication.updateMany(
      { patientUserId: rx.patientUserId, medicationName: rx.medicationName, status: "Active" },
      { $set: { status: "Stopped", active: false, stoppedAt: new Date(), stoppedByDoctorId: doctorUserId } }
    );
  }
  res.json(rx);
}

/** POST /lab-requests */
async function postLabRequest(req, res) {
  const { orgId, doctorUserId } = scope(req);
  const { patientUserId, testName, testType, notes, appointmentId } = req.body;
  if (!patientUserId || !testName) {
    return res.status(400).json({ message: "patientUserId and testName required" });
  }
  const doc = await LabRequest.create({
    orgId,
    clinicId: req.doctorScope?.user?.clinicId || null,
    patientUserId,
    doctorUserId,
    requestedBy: doctorUserId,
    visitId: appointmentId && mongoose.Types.ObjectId.isValid(appointmentId) ? appointmentId : null,
    testName: String(testName).trim(),
    testType: testType != null ? String(testType) : "Blood",
    notes: notes != null ? String(notes) : "",
    status: "Requested",
  });
  res.status(201).json(doc.toObject());
}

/** POST /radiology-requests */
async function postRadiologyRequest(req, res) {
  const { orgId, doctorUserId } = scope(req);
  const { patientUserId, modality, studyName, notes, appointmentId } = req.body;
  if (!patientUserId || !studyName) {
    return res.status(400).json({ message: "patientUserId and studyName required" });
  }
  const mod = ["X-Ray", "MRI", "CT", "Ultrasound", "Other"].includes(modality) ? modality : "X-Ray";
  const doc = await RadiologyRequest.create({
    orgId,
    clinicId: req.doctorScope?.user?.clinicId || null,
    patientUserId,
    doctorUserId,
    requestedBy: doctorUserId,
    appointmentId: appointmentId && mongoose.Types.ObjectId.isValid(appointmentId) ? appointmentId : null,
    modality: mod,
    studyName: String(studyName).trim(),
    notes: notes != null ? String(notes) : "",
    status: "Requested",
  });
  res.status(201).json(doc.toObject());
}

/** POST /doctor-notes */
async function postDoctorNote(req, res) {
  const { orgId, doctorUserId } = scope(req);
  const { patientUserId, body, noteType, appointmentId } = req.body;
  if (!patientUserId || !body) return res.status(400).json({ message: "patientUserId and body required" });
  const doc = await DoctorNote.create({
    orgId,
    doctorUserId,
    patientUserId,
    appointmentId: appointmentId && mongoose.Types.ObjectId.isValid(appointmentId) ? appointmentId : null,
    noteType: ["clinical", "followup", "post_visit", "general"].includes(noteType) ? noteType : "clinical",
    body: String(body).trim(),
    active: true,
  });
  res.status(201).json(doc.toObject());
}

/** GET /appointments */
async function getAppointments(req, res) {
  const { orgId, doctorUserId, doctorProfile, user } = scope(req);
  const q = appointmentMatchQuery(doctorUserId, doctorProfile.displayName, user.name);
  q.orgId = orgId;
  const list = await AppointmentModel.find(q).sort({ date: -1, time: -1 }).limit(200).lean();
  res.json(list);
}

/** PUT /appointments/:id/status */
async function putAppointmentStatus(req, res) {
  const { doctorUserId, doctorProfile, user } = scope(req);
  const { id } = req.params;
  const { bookingStatus, visitStatus, postVisitSummary, date, time } = req.body;

  if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: "Invalid appointment id" });
  const appt = await AppointmentModel.findById(id);
  if (!appt) return res.status(404).json({ message: "Appointment not found" });
  if (!apptMatchesDoctor(appt, doctorUserId, doctorProfile.displayName, user.name)) {
    return res.status(403).json({ message: "Not your appointment" });
  }

  if (bookingStatus) {
    if (!["Pending", "Accepted", "Rejected", "Postponed", "reschedule_requested"].includes(bookingStatus)) {
      return res.status(400).json({ message: "Invalid bookingStatus" });
    }
    appt.bookingStatus =
      bookingStatus === "Postponed" ? "reschedule_requested" : bookingStatus;
    if (bookingStatus === "Accepted") appt.doctorUserId = doctorUserId;
  }
  if (visitStatus) {
    if (!["Waiting", "In Progress", "Completed", "Cancelled", "Terminated"].includes(visitStatus)) {
      return res.status(400).json({ message: "Invalid visit status" });
    }
    appt.status =
      visitStatus === "Terminated" ? "Cancelled" : visitStatus === "Completed" ? "Completed" : visitStatus;
  }
  if (date) appt.date = normalizeDateToYmd(date) || String(date);
  if (time) appt.time = String(time).trim();
  await appt.save();

  if (postVisitSummary && appt.patientId) {
    await DoctorNote.create({
      orgId: scope(req).orgId,
      doctorUserId,
      patientUserId: appt.patientId,
      appointmentId: appt._id,
      noteType: "post_visit",
      body: String(postVisitSummary),
      active: true,
    });
  }

  res.json(appt.toObject());
}

/** POST /nurse-notify */
async function postNurseNotify(req, res) {
  const { orgId, doctorUserId, doctorProfile } = scope(req);
  const { message, patientUserId } = req.body;
  if (!message || !String(message).trim()) {
    return res.status(400).json({ message: "message required" });
  }
  const nurses = await UserModel.find({ orgId, role: "Nurse", status: "active" }).select("_id").lean();
  const title = `Doctor directive — ${doctorProfile.displayName || "Doctor"}`;
  const body = String(message).trim();
  for (const n of nurses) {
    await UserNotification.create({
      orgId,
      userId: n._id,
      role: "Nurse",
      type: "doctor_directive",
      title,
      body,
      read: false,
      meta: { doctorUserId: String(doctorUserId), patientUserId: patientUserId ? String(patientUserId) : "" },
    });
  }
  res.status(201).json({ sent: nurses.length });
}

/** POST /clinical/safety-check */
async function postSafetyCheck(req, res) {
  const { patientUserId, medicationName, dosage } = req.body;
  if (!patientUserId || !medicationName) {
    return res.status(400).json({ message: "patientUserId and medicationName required" });
  }
  const med = String(medicationName).trim().toLowerCase();
  const warnings = [];
  const medical = await PatientMedicalProfile.findOne({ userId: patientUserId }).lean();
  const health = await HealthProfile.findOne({ userId: patientUserId }).lean();
  const allergyList = [
    ...(medical?.allergies?.medications || []),
    ...(Array.isArray(health?.allergies) ? health.allergies : []),
  ].map((a) => String(a).toLowerCase());

  for (const a of allergyList) {
    if (a && (med.includes(a) || a.includes(med))) {
      warnings.push({ type: "allergy", message: `Possible allergy conflict: ${a}` });
    }
  }

  const doseNum = parseFloat(String(dosage || "").replace(/[^\d.]/g, ""));
  if (doseNum > 1000) {
    warnings.push({ type: "overdose", message: "Dosage appears unusually high — verify units." });
  }

  const highRisk = warnings.length > 0;
  res.json({ safe: !highRisk, warnings, highRisk });
}

/** GET /profile */
async function getProfile(req, res) {
  const { doctorProfile } = scope(req);
  const enriched = await enrichDoctorFacilityFields(doctorProfile);
  res.json(enrichDoctorProfileResponse(enriched));
}

/** GET /drugs?q= — drug catalog lookup for e-Rx issuance */
async function searchDrugs(req, res) {
  const prescriptionDispensing = require("../services/prescriptionDispensingService");
  const list = await prescriptionDispensing.searchCatalogForPatient(req.query.q);
  res.json(list);
}

module.exports = {
  getDashboardStats,
  getTodayQueue,
  putAvailability,
  listPatients,
  getPatientEmr,
  postDiagnosis,
  postPrescription,
  searchDrugs,
  stopPrescription,
  postLabRequest,
  postRadiologyRequest,
  postDoctorNote,
  getAppointments,
  putAppointmentStatus,
  postNurseNotify,
  postSafetyCheck,
  getProfile,
};
