const mongoose = require("mongoose");
const UserModel = require("../models/User");
const Patient = require("../models/patient");
const PatientMedicalProfile = require("../models/patientMedicalProfile");
const PatientMedicalFile = require("../models/patientMedicalFile");
const AppointmentModel = require("../models/appointment");
const LabRequest = require("../models/labRequest");
const StaffProfile = require("../models/staffProfile");
const Staff = require("../models/Staff");
const Department = require("../models/department");
const StaffLeaveRequest = require("../models/staffLeaveRequest");
const NurseAttendance = require("../models/nurseAttendance");
const UserNotification = require("../models/userNotification");
const PatientNotification = require("../models/patientNotification");
const { enrichDiagnosticOrders } = require("../utils/diagnosticEnrichment");
const { hashPassword } = require("../utils/password");

function str(v) {
  return v == null ? "" : String(v).trim();
}

function todayYmd() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

async function ensureMedicalProfile(patientUserId, orgId) {
  let doc = await PatientMedicalProfile.findOne({ userId: patientUserId });
  if (!doc) {
    doc = await PatientMedicalProfile.create({ userId: patientUserId, orgId });
  } else if (orgId && !doc.orgId) {
    doc.orgId = orgId;
    await doc.save();
  }
  return doc;
}

async function assertPatientInOrg(patientUserId, orgId) {
  const user = await UserModel.findOne({ _id: patientUserId, role: "Patient" }).lean();
  if (!user) return null;
  let patient = await Patient.findOne({ userId: patientUserId, orgId }).lean();
  if (!patient) {
    patient = await Patient.findOne({ userId: patientUserId }).lean();
    const pOrg = patient?.orgId ? String(patient.orgId) : "";
    const uOrg = user.orgId ? String(user.orgId) : "";
    if (pOrg && pOrg !== String(orgId) && uOrg !== String(orgId)) return null;
  }
  return { user, patient: patient || {} };
}

function scope(req) {
  return req.nurseScope;
}

/** GET /api/nurse/dashboard */
async function getDashboard(req, res) {
  const { orgId, userId, profile } = scope(req);
  const date = todayYmd();
  const [queueCount, attendance] = await Promise.all([
    AppointmentModel.countDocuments({ orgId, date, nurseQueueStatus: { $in: ["Checked-In", "Triaged", "Forwarded-To-Doctor", ""] } }),
    NurseAttendance.findOne({ orgId, nurseUserId: userId, dateYmd: date }).lean(),
  ]);
  res.json({
    orgId: String(orgId),
    nurseName: scope(req).user.name,
    queueToday: queueCount,
    shiftHours: profile.shiftHours || { start: "08:00", end: "17:00" },
    permissions: scope(req).permissions,
    attendance: attendance || { dateYmd: date, checkInAt: null, checkOutAt: null },
  });
}

/** GET /api/nurse/patients?q= */
async function searchPatients(req, res) {
  const { orgId } = scope(req);
  const q = str(req.query.q).toLowerCase();
  const patients = await Patient.find({ orgId }).limit(200).lean();
  const userIds = patients.map((p) => p.userId).filter(Boolean);
  const users = await UserModel.find({ _id: { $in: userIds } })
    .select("name email phoneNumber gender dateOfBirth")
    .lean();
  const userMap = Object.fromEntries(users.map((u) => [String(u._id), u]));
  let rows = patients.map((p) => {
    const u = userMap[String(p.userId)] || {};
    return {
      userId: p.userId,
      displayName: p.fullName || u.name || "",
      bloodType: p.bloodType || "",
      gender: str(p.gender || u.gender),
    };
  });
  if (q) {
    rows = rows.filter((r) => {
      const u = userMap[String(r.userId)] || {};
      return (
        String(r.displayName).toLowerCase().includes(q) ||
        String(u.email || "").toLowerCase().includes(q) ||
        String(u.phoneNumber || "").includes(q)
      );
    });
  }
  res.json(rows.slice(0, 80));
}

function computePatientAge(user, patient) {
  if (patient?.age != null && Number(patient.age) > 0) return Number(patient.age);
  const dob = user?.dateOfBirth || patient?.birthDate;
  if (!dob) return null;
  const d = new Date(dob);
  if (Number.isNaN(d.getTime())) return null;
  const today = new Date();
  let age = today.getFullYear() - d.getFullYear();
  const m = today.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < d.getDate())) age -= 1;
  return age >= 0 ? age : null;
}

function formatDobIso(user, patient, profile) {
  const raw = user?.dateOfBirth || patient?.birthDate || profile?.birthDate;
  if (!raw) return null;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

function collectActiveAllergies(profile) {
  const a = profile?.allergies;
  if (!a || typeof a !== "object") return [];
  const out = [];
  for (const key of ["medications", "foods", "materials"]) {
    const list = a[key];
    if (Array.isArray(list)) {
      for (const item of list) {
        const s = str(item);
        if (s) out.push(s);
      }
    }
  }
  return [...new Set(out)];
}

/** GET /api/nurse/patients/:patientId/clinical-summary — read-only medical essentials (no PII) */
async function getPatientClinicalSummary(req, res) {
  const { orgId } = scope(req);
  const { patientId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(patientId)) {
    return res.status(400).json({ message: "Invalid patientId" });
  }
  const ctx = await assertPatientInOrg(patientId, orgId);
  if (!ctx) return res.status(404).json({ message: "Patient not found in this facility" });

  const profile = await PatientMedicalProfile.findOne({ userId: patientId })
    .select("bloodType chronicDiseases allergies gender birthDate")
    .lean();

  const displayName = str(ctx.patient?.fullName || ctx.user?.name || "Patient");
  const gender = str(profile?.gender || ctx.patient?.gender || ctx.user?.gender);
  const bloodType = str(profile?.bloodType || ctx.patient?.bloodType);
  const age = computePatientAge(ctx.user, ctx.patient);
  const dateOfBirth = formatDobIso(ctx.user, ctx.patient, profile);
  const chronicConditions = Array.isArray(profile?.chronicDiseases)
    ? profile.chronicDiseases.map((c) => str(c)).filter(Boolean)
    : [];

  res.json({
    readOnly: true,
    displayName,
    age,
    dateOfBirth,
    ageOrDobLabel:
      age != null && dateOfBirth ? `${age} years · DOB ${dateOfBirth}` : age != null ? `${age} years` : dateOfBirth || "—",
    gender: gender || "—",
    bloodType: bloodType || "—",
    chronicConditions,
    allergies: collectActiveAllergies(profile),
  });
}

/** GET /api/nurse/patients/:patientId/file */
async function getPatientFile(req, res) {
  const { orgId } = scope(req);
  const { patientId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(patientId)) {
    return res.status(400).json({ message: "Invalid patientId" });
  }
  const ctx = await assertPatientInOrg(patientId, orgId);
  if (!ctx) return res.status(404).json({ message: "Patient not found in this facility" });

  const [profile, files, labs] = await Promise.all([
    PatientMedicalProfile.findOne({ userId: patientId }).lean(),
    PatientMedicalFile.find({ userId: patientId, orgId }).sort({ createdAt: -1 }).limit(40).lean(),
    LabRequest.find({ orgId, patientUserId: patientId }).sort({ createdAt: -1 }).limit(30).lean(),
  ]);

  res.json({
    patient: ctx.patient,
    user: ctx.user,
    medicalProfile: profile || {},
    medicalFiles: files,
    labRequests: labs,
    vitalsTimeline: profile?.vitalsTimeline || [],
    medicationAdministration: profile?.medicationAdministration || [],
    nursingNotes: (profile?.nursingNotes || []).filter((n) => !n.visibleToDoctorOnly || true),
  });
}

/** POST /api/nurse/vitals/:patientId */
async function postVitals(req, res) {
  const { orgId, userId } = scope(req);
  const { patientId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(patientId)) {
    return res.status(400).json({ message: "Invalid patientId" });
  }
  const ctx = await assertPatientInOrg(patientId, orgId);
  if (!ctx) return res.status(404).json({ message: "Patient not found" });

  const entry = {
    bloodPressure: str(req.body.bloodPressure),
    temperature: req.body.temperature != null ? Number(req.body.temperature) : null,
    weight: req.body.weight != null ? Number(req.body.weight) : null,
    height: req.body.height != null ? Number(req.body.height) : null,
    pulse: req.body.pulse != null ? Number(req.body.pulse) : null,
    oxygenSaturation: req.body.oxygenSaturation != null ? Number(req.body.oxygenSaturation) : null,
    bloodSugar: req.body.bloodSugar != null ? Number(req.body.bloodSugar) : null,
    recordedBy: userId,
    visitId: mongoose.Types.ObjectId.isValid(req.body.visitId) ? req.body.visitId : null,
    createdAt: new Date(),
  };

  const doc = await ensureMedicalProfile(patientId, orgId);
  doc.vitalsTimeline.push(entry);
  if (entry.weight != null) doc.weight = entry.weight;
  if (entry.height != null) doc.height = entry.height;
  await doc.save();

  const saved = doc.vitalsTimeline[doc.vitalsTimeline.length - 1];
  res.status(201).json(saved);
}

/** PUT /api/nurse/vitals/:patientId/:vitalId */
async function putVitals(req, res) {
  const { orgId, userId } = scope(req);
  const { patientId, vitalId } = req.params;
  const doc = await PatientMedicalProfile.findOne({ userId: patientId });
  if (!doc) return res.status(404).json({ message: "Profile not found" });

  const entry = doc.vitalsTimeline.id(vitalId);
  if (!entry) return res.status(404).json({ message: "Vital entry not found" });
  if (entry.recordedBy && String(entry.recordedBy) !== String(userId)) {
    return res.status(403).json({ message: "Can only edit your own vitals entries" });
  }

  const fields = ["bloodPressure", "temperature", "weight", "height", "pulse", "oxygenSaturation", "bloodSugar"];
  for (const f of fields) {
    if (Object.prototype.hasOwnProperty.call(req.body, f)) {
      entry[f] = f === "bloodPressure" ? str(req.body[f]) : Number(req.body[f]);
    }
  }
  await doc.save();
  res.json(entry);
}

/** GET /api/nurse/queue/today */
async function getTodayQueue(req, res) {
  const { orgId } = scope(req);
  const date = str(req.query.date) || todayYmd();
  const list = await AppointmentModel.find({ orgId, date })
    .sort({ time: 1 })
    .limit(200)
    .lean();
  res.json(list);
}

/** POST /api/nurse/visits/:visitId/check-in */
async function checkInVisit(req, res) {
  const { orgId } = scope(req);
  const { visitId } = req.params;
  const appt = await AppointmentModel.findOne({ _id: visitId, orgId });
  if (!appt) return res.status(404).json({ message: "Visit not found" });
  appt.nurseQueueStatus = "Checked-In";
  if (appt.status === "Waiting") appt.status = "Waiting";
  await appt.save();
  res.json(appt);
}

/** POST /api/nurse/visits/:visitId/triage */
async function triageVisit(req, res) {
  const { orgId, userId } = scope(req);
  const { visitId } = req.params;
  const appt = await AppointmentModel.findOne({ _id: visitId, orgId });
  if (!appt) return res.status(404).json({ message: "Visit not found" });

  const symptoms = str(req.body.initialSymptoms || req.body.symptoms);
  const forward = req.body.forwardToDoctor === true || str(req.body.action) === "forward";

  if (symptoms) appt.initialSymptoms = symptoms;
  appt.nurseQueueStatus = forward ? "Forwarded-To-Doctor" : "Triaged";
  await appt.save();

  if (appt.patientId) {
    const doc = await ensureMedicalProfile(appt.patientId, orgId);
    if (symptoms) {
      doc.nursingNotes.push({
        visitId: appt._id,
        noteType: "initial_symptoms",
        body: symptoms,
        authorId: userId,
        visibleToDoctorOnly: false,
      });
    }
    const obs = str(req.body.nursingObservations);
    if (obs) {
      doc.nursingNotes.push({
        visitId: appt._id,
        noteType: "observation",
        body: obs,
        authorId: userId,
      });
    }
    const alert = str(req.body.doctorAlert);
    if (alert) {
      doc.nursingNotes.push({
        visitId: appt._id,
        noteType: "doctor_alert",
        body: alert,
        urgentForDoctor: Boolean(req.body.urgent),
        authorId: userId,
        visibleToDoctorOnly: true,
      });
    }
    await doc.save();

    if (forward && appt.doctorUserId) {
      await UserNotification.create({
        userId: appt.doctorUserId,
        role: "Doctor",
        type: "nurse_forward",
        title: "Patient forwarded from triage",
        body: `${appt.patientName} — ${symptoms || "Ready for consultation"}`,
        read: false,
        meta: { appointmentId: String(appt._id), patientId: String(appt.patientId) },
      });
    }
  }

  res.json(appt);
}

/** POST /api/nurse/notes */
async function postNursingNote(req, res) {
  const { orgId, userId } = scope(req);
  const patientUserId = req.body.patientUserId;
  if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
    return res.status(400).json({ message: "patientUserId required" });
  }
  const ctx = await assertPatientInOrg(patientUserId, orgId);
  if (!ctx) return res.status(404).json({ message: "Patient not found" });

  const doc = await ensureMedicalProfile(patientUserId, orgId);
  const note = {
    visitId: mongoose.Types.ObjectId.isValid(req.body.visitId) ? req.body.visitId : null,
    noteType: ["initial_symptoms", "shift_log", "doctor_alert", "observation"].includes(str(req.body.noteType))
      ? str(req.body.noteType)
      : "observation",
    body: str(req.body.body),
    urgentForDoctor: Boolean(req.body.urgentForDoctor),
    authorId: userId,
    visibleToDoctorOnly: req.body.noteType === "doctor_alert" || Boolean(req.body.visibleToDoctorOnly),
  };
  doc.nursingNotes.push(note);
  await doc.save();
  res.status(201).json(doc.nursingNotes[doc.nursingNotes.length - 1]);
}

/** POST /api/nurse/medications/log */
async function logMedication(req, res) {
  const { orgId, userId } = scope(req);
  const patientUserId = req.body.patientUserId;
  if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
    return res.status(400).json({ message: "patientUserId required" });
  }
  const name = str(req.body.medicationName);
  if (!name) return res.status(400).json({ message: "medicationName required" });

  const ctx = await assertPatientInOrg(patientUserId, orgId);
  if (!ctx) return res.status(404).json({ message: "Patient not found" });

  const doc = await ensureMedicalProfile(patientUserId, orgId);
  const log = {
    medicationName: name,
    dosage: str(req.body.dosage),
    administeredAt: req.body.administeredAt ? new Date(req.body.administeredAt) : new Date(),
    administeredBy: userId,
    visitId: mongoose.Types.ObjectId.isValid(req.body.visitId) ? req.body.visitId : null,
    adverseReaction: str(req.body.adverseReaction),
    notes: str(req.body.notes),
  };
  doc.medicationAdministration.push(log);
  await doc.save();
  res.status(201).json(doc.medicationAdministration[doc.medicationAdministration.length - 1]);
}

/** POST /api/nurse/labs/request */
async function requestLab(req, res) {
  const { orgId, userId } = scope(req);
  const patientUserId = req.body.patientUserId;
  const testName = str(req.body.testName);
  if (!mongoose.Types.ObjectId.isValid(patientUserId) || !testName) {
    return res.status(400).json({ message: "patientUserId and testName required" });
  }
  const ctx = await assertPatientInOrg(patientUserId, orgId);
  if (!ctx) return res.status(404).json({ message: "Patient not found" });

  const lab = await LabRequest.create({
    orgId,
    patientUserId,
    testName,
    notes: str(req.body.notes),
    requestedBy: userId,
    visitId: mongoose.Types.ObjectId.isValid(req.body.visitId) ? req.body.visitId : null,
    status: "Requested",
  });
  res.status(201).json(lab);
}

/** PUT /api/nurse/labs/:labId/upload */
async function uploadLabResults(req, res) {
  const { orgId, userId } = scope(req);
  const { labId } = req.params;
  const lab = await LabRequest.findOne({ _id: labId, orgId });
  if (!lab) return res.status(404).json({ message: "Lab request not found" });

  const images = Array.isArray(req.body.resultImages) ? req.body.resultImages : [];
  for (const img of images) {
    const url = str(img.fileUrl || img);
    if (!url) continue;
    lab.resultImages.push({
      fileUrl: url.slice(0, 14 * 1024 * 1024),
      uploadedBy: userId,
    });
  }
  if (req.body.status && ["Requested", "Sample-Collected", "Completed"].includes(str(req.body.status))) {
    lab.status = str(req.body.status);
  } else if (lab.resultImages.length) {
    lab.status = "Completed";
  }
  await lab.save();
  res.json(lab);
}

/** Active lab queue statuses (includes legacy "Pending" + radiology-style "Scheduled"). */
const INCOMING_LAB_STATUSES = ["Requested", "Pending", "Sample-Collected", "Scheduled"];

function incomingLabQueueFilter(orgId) {
  const filter = {
    status: { $in: INCOMING_LAB_STATUSES },
    isLocked: { $ne: true },
  };
  if (orgId && mongoose.Types.ObjectId.isValid(String(orgId))) {
    filter.orgId = new mongoose.Types.ObjectId(String(orgId));
  }
  return filter;
}

/** GET /api/nurse/lab-requests/incoming — doctor orders awaiting lab processing */
async function listIncomingLabRequests(req, res) {
  const { orgId } = scope(req);

  // Org-scoped first; demo fallback returns all active queue items when scope is empty.
  let list = await LabRequest.find(incomingLabQueueFilter(orgId))
    .sort({ createdAt: -1 })
    .limit(100)
    .lean();

  if (!list.length) {
    list = await LabRequest.find(incomingLabQueueFilter(null))
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
  }

  res.json(await enrichDiagnosticOrders(list));
}

/** PUT /api/nurse/lab-requests/:id/submit — finalize lab report (immutable) */
async function submitIncomingLabReport(req, res) {
  const { orgId, userId } = scope(req);
  let lab = await LabRequest.findOne({ _id: req.params.id, orgId });
  if (!lab) {
    lab = await LabRequest.findOne({ _id: req.params.id });
  }
  if (!lab) return res.status(404).json({ message: "Lab order not found" });
  if (lab.isLocked || lab.status === "Completed") {
    return res.status(409).json({ message: "Results are locked and cannot be modified" });
  }

  const analysis = str(req.body.resultAnalysis || req.body.results);
  if (!analysis) return res.status(400).json({ message: "resultAnalysis is required" });

  const fileUrl = str(req.body.attachmentUrl || req.body.fileUrl);
  const fileName = str(req.body.attachmentName || req.body.fileName);
  const mimeType = str(req.body.mimeType) || "application/pdf";

  lab.resultAnalysis = analysis;
  if (fileUrl) {
    lab.attachment = {
      fileUrl: fileUrl.slice(0, 14 * 1024 * 1024),
      fileName,
      mimeType,
      uploadedAt: new Date(),
      uploadedBy: userId,
    };
    lab.resultImages.push({ fileUrl: lab.attachment.fileUrl, uploadedBy: userId });
  }
  lab.status = "Completed";
  lab.isLocked = true;
  lab.completedAt = new Date();
  lab.submittedBy = userId;
  lab.isReadByDoctor = false;
  await lab.save();

  if (lab.doctorUserId) {
    await UserNotification.create({
      orgId,
      userId: lab.doctorUserId,
      role: "Doctor",
      type: "lab_result_completed",
      title: "Lab results ready",
      body: `${lab.testName} completed for review`,
      read: false,
      meta: { labRequestId: String(lab._id), patientUserId: String(lab.patientUserId) },
    });
  }
  await PatientNotification.create({
    patientUserId: lab.patientUserId,
    type: "lab_result",
    title: "New lab result available",
    body: `${lab.testName} results are ready`,
    read: false,
    meta: { labRequestId: String(lab._id) },
  });

  const [enriched] = await enrichDiagnosticOrders([lab.toObject()]);
  res.json(enriched);
}

/** GET /api/nurse/labs/patient/:patientId */
async function listPatientLabs(req, res) {
  const { orgId } = scope(req);
  const { patientId } = req.params;
  const list = await LabRequest.find({ orgId, patientUserId: patientId }).sort({ createdAt: -1 }).limit(50).lean();
  res.json(list);
}

/** POST /api/nurse/alerts/dispatch */
async function dispatchAlert(req, res) {
  const { orgId } = scope(req);
  const patientUserId = req.body.patientUserId;
  const title = str(req.body.title);
  const body = str(req.body.body);
  if (!mongoose.Types.ObjectId.isValid(patientUserId) || !title) {
    return res.status(400).json({ message: "patientUserId and title required" });
  }
  await UserNotification.create({
    userId: patientUserId,
    role: "Patient",
    type: "nurse_alert",
    title,
    body: body || title,
    read: false,
    meta: { orgId: String(orgId), channel: req.body.channel || "push" },
  });
  res.json({ ok: true, message: "Notification queued for patient" });
}

async function buildHrContractBundle(userId, orgId, profile) {
  let departmentName = "Not assigned";
  if (profile?.departmentId) {
    const dept = await Department.findById(profile.departmentId).select("name").lean();
    if (dept?.name) departmentName = dept.name;
  }

  const staff =
    (await Staff.findOne({ userId, orgId }).lean()) ||
    (await Staff.findOne({ userId }).lean());

  const shiftStart = profile?.shiftHours?.start || staff?.workingDaysAndHours?.[0]?.startTime || "08:00";
  const shiftEnd = profile?.shiftHours?.end || staff?.workingDaysAndHours?.[0]?.endTime || "17:00";
  const workingDaysArr = staff?.workingDaysAndHours?.length
    ? staff.workingDaysAndHours
    : profile?.workingDaysAndHours || [];
  const workingDaysLabel =
    workingDaysArr.length > 0
      ? workingDaysArr.map((w) => `${w.day} ${w.startTime || shiftStart}–${w.endTime || shiftEnd}`).join(", ")
      : "Pending admin assignment";

  const salary = profile?.salary ?? staff?.salary ?? null;

  return {
    departmentName,
    shiftTimings: `${shiftStart} – ${shiftEnd}`,
    shiftStart,
    shiftEnd,
    workingDays: workingDaysLabel,
    workingDaysList: workingDaysArr,
    monthlySalary: salary,
    monthlySalaryLabel: salary != null && salary > 0 ? `${salary}` : "Pending admin assignment",
  };
}

/** GET /api/nurse/profile — account + HR contract hub */
async function getProfile(req, res) {
  const { user, profile, orgId, userId } = scope(req);
  const contract = await buildHrContractBundle(userId, orgId, profile);
  res.json({
    user: {
      id: String(user._id),
      name: user.name,
      email: user.email,
      phoneNumber: user.phoneNumber || "",
      profileImageUrl: user.profileImageUrl || "",
      role: user.role,
    },
    account: {
      fullName: user.name || "",
      email: user.email || "",
      phone: user.phoneNumber || "",
    },
    contract,
    orgId: String(orgId),
    profile: profile || {},
  });
}

/** PUT /api/auth/profile/update — nurse account settings */
async function updateAuthProfile(req, res) {
  const { userId, orgId } = scope(req);
  const fullName = str(req.body.fullName || req.body.name);
  const email = str(req.body.email).toLowerCase();
  const phone = str(req.body.phoneNumber || req.body.phone);
  const currentPassword = str(req.body.currentPassword);
  const newPassword = str(req.body.newPassword);

  const user = await UserModel.findById(userId);
  if (!user) return res.status(404).json({ message: "User not found" });

  const $set = {};
  if (fullName) $set.name = fullName;
  if (email) {
    if (!email.includes("@")) return res.status(400).json({ message: "Valid email is required" });
    const dup = await UserModel.findOne({ email, _id: { $ne: userId } }).lean();
    if (dup) return res.status(409).json({ message: "Email already in use" });
    $set.email = email;
  }
  if (req.body.phoneNumber != null || req.body.phone != null) {
    $set.phoneNumber = phone;
  }

  if (Object.keys($set).length > 0) {
    await UserModel.updateOne({ _id: userId }, { $set });
    const staffPatch = {};
    if (fullName) staffPatch.fullName = fullName;
    if (email) staffPatch.email = email;
    if (req.body.phoneNumber != null || req.body.phone != null) staffPatch.phone = phone;
    if (Object.keys(staffPatch).length > 0) {
      await Staff.updateMany({ $or: [{ userId }, { email: user.email }] }, { $set: staffPatch });
    }
  }

  if (newPassword) {
    if (newPassword.length < 6) {
      return res.status(400).json({ message: "Password must be at least 6 characters" });
    }
    const { verifyPassword } = require("../utils/password");
    if (!currentPassword) {
      return res.status(400).json({ message: "Current password is required to set a new password" });
    }
    if (!verifyPassword(user.password, currentPassword)) {
      return res.status(401).json({ message: "Current password is incorrect" });
    }
    user.password = hashPassword(newPassword);
    await user.save();
  }

  const updated = await UserModel.findById(userId).lean();
  const profile = await StaffProfile.findOne({ userId, orgId }).lean();
  const contract = await buildHrContractBundle(userId, orgId, profile);

  res.json({
    message: "Profile updated successfully",
    user: {
      id: String(updated._id),
      name: updated.name,
      email: updated.email,
      phoneNumber: updated.phoneNumber || "",
    },
    account: {
      fullName: updated.name || "",
      email: updated.email || "",
      phone: updated.phoneNumber || "",
    },
    contract,
  });
}

/** PUT /api/nurse/profile */
async function putProfile(req, res) {
  return updateAuthProfile(req, res);
}

/** POST /api/nurse/profile/password */
async function changePassword(req, res) {
  const { userId } = scope(req);
  const current = str(req.body.currentPassword);
  const next = str(req.body.newPassword);
  if (next.length < 6) return res.status(400).json({ message: "Password must be at least 6 characters" });
  const u = await UserModel.findById(userId);
  if (!u) return res.status(404).json({ message: "User not found" });
  const { verifyPassword } = require("../utils/password");
  if (!verifyPassword(u.password, current)) {
    return res.status(401).json({ message: "Current password incorrect" });
  }
  u.password = hashPassword(next);
  await u.save();
  res.json({ ok: true });
}

/** POST /api/nurse/leave */
async function requestLeave(req, res) {
  const { orgId, userId } = scope(req);
  const { type, fromDate, toDate, reason } = req.body;
  if (!["Sick", "Annual", "Emergency"].includes(str(type))) {
    return res.status(400).json({ message: "Invalid leave type" });
  }
  if (!fromDate || !toDate) return res.status(400).json({ message: "fromDate and toDate required" });
  const doc = await StaffLeaveRequest.create({
    orgId,
    staffId: userId,
    type: str(type),
    fromDate: str(fromDate),
    toDate: str(toDate),
    reason: str(reason),
  });
  res.status(201).json(doc);
}

/** POST /api/nurse/attendance/check-in | check-out */
async function attendanceToggle(req, res) {
  const { orgId, userId } = scope(req);
  const dateYmd = todayYmd();
  const action = str(req.body.action || req.path.split("/").pop());
  let row = await NurseAttendance.findOne({ orgId, nurseUserId: userId, dateYmd });
  if (!row) {
    row = await NurseAttendance.create({ orgId, nurseUserId: userId, dateYmd });
  }
  const now = new Date();
  if (action.includes("check-in") || action === "check-in") {
    row.checkInAt = now;
  } else {
    row.checkOutAt = now;
  }
  await row.save();
  res.json(row);
}

module.exports = {
  getDashboard,
  searchPatients,
  getPatientClinicalSummary,
  getPatientFile,
  postVitals,
  putVitals,
  getTodayQueue,
  checkInVisit,
  triageVisit,
  postNursingNote,
  logMedication,
  requestLab,
  uploadLabResults,
  listIncomingLabRequests,
  submitIncomingLabReport,
  listPatientLabs,
  dispatchAlert,
  getProfile,
  putProfile,
  updateAuthProfile,
  changePassword,
  requestLeave,
  attendanceToggle,
};
