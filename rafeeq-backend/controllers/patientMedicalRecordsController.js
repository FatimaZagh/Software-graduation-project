const mongoose = require("mongoose");
const UserModel = require("../models/User");
const HealthProfile = require("../models/healthProfile");
const PatientMedicalProfile = require("../models/patientMedicalProfile");
const Appointment = require("../models/appointment");
const MedicalRecord = require("../models/medicalRecord");
const ClinicSession = require("../models/clinicSession");
const DoctorNote = require("../models/doctorNote");
const Clinic = require("../models/clinic");
const Diagnosis = require("../models/diagnosis");
const ElectronicPrescription = require("../models/electronicPrescription");
const DispensingPrescription = require("../models/dispensingPrescription");
const DispensingPrescriptionItem = require("../models/dispensingPrescriptionItem");
const Prescription = require("../models/prescription");

function uniqueStrings(list) {
  const seen = new Set();
  const out = [];
  for (const raw of list) {
    const s = String(raw || "").trim();
    if (!s) continue;
    const key = s.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(s);
  }
  return out;
}

function mergeAllergyStrings(health, medical) {
  const items = [];
  if (Array.isArray(health?.allergies)) items.push(...health.allergies);
  const al = medical?.allergies;
  if (al && typeof al === "object") {
    for (const key of ["medications", "foods", "materials"]) {
      if (Array.isArray(al[key])) items.push(...al[key]);
    }
  }
  return uniqueStrings(items);
}

function parseVisitDate(appt, session, record) {
  if (session?.endedAt) return new Date(session.endedAt);
  if (session?.startedAt) return new Date(session.startedAt);
  if (record?.createdAt) return new Date(record.createdAt);
  const date = String(appt?.date || "").trim();
  const time = String(appt?.time || "").trim();
  if (date) {
    const combined = time ? `${date}T${time}` : date;
    const parsed = new Date(combined);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  if (appt?.createdAt) return new Date(appt.createdAt);
  return null;
}

function buildVitalSigns(session, vitalsEntry) {
  const sessionVitals = session?.vitals && typeof session.vitals === "object" ? session.vitals : {};
  let bloodPressure = null;
  if (sessionVitals.bpSystolic != null && sessionVitals.bpDiastolic != null) {
    bloodPressure = `${sessionVitals.bpSystolic}/${sessionVitals.bpDiastolic}`;
  } else if (vitalsEntry?.bloodPressure) {
    bloodPressure = String(vitalsEntry.bloodPressure).trim();
  }

  return {
    bloodPressure: bloodPressure || null,
    heartRate: sessionVitals.heartRate ?? vitalsEntry?.pulse ?? null,
    temperature: sessionVitals.temperatureC ?? vitalsEntry?.temperature ?? null,
  };
}

function findVitalsForVisit(vitalsTimeline, appointmentId) {
  if (!Array.isArray(vitalsTimeline) || !appointmentId) return null;
  const id = String(appointmentId);
  const matches = vitalsTimeline.filter((v) => v?.visitId && String(v.visitId) === id);
  if (!matches.length) return null;
  return [...matches].sort(
    (a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime()
  )[0];
}

function findChiefComplaint(appt, nursingNotes, appointmentId) {
  const fromAppt = String(appt?.initialSymptoms || "").trim();
  if (fromAppt) return fromAppt;
  if (!Array.isArray(nursingNotes) || !appointmentId) return "";
  const id = String(appointmentId);
  const symptomNote = nursingNotes.find(
    (n) =>
      n?.visitId &&
      String(n.visitId) === id &&
      (n.noteType === "initial_symptoms" || String(n.body || "").trim())
  );
  return String(symptomNote?.body || "").trim();
}

function combineNotes(record, session, doctorNotes) {
  const parts = uniqueStrings([
    String(record?.notes || "").trim(),
    String(session?.notes || "").trim(),
    ...(Array.isArray(doctorNotes) ? doctorNotes.map((n) => String(n?.body || "").trim()) : []),
  ]);
  return parts.join("\n\n");
}

function resolveDiagnosis(apptId, record, session, diagnosesForVisit) {
  const fromRecord = String(record?.diagnosis || session?.diagnosis || "").trim();
  if (fromRecord) return fromRecord;
  if (!Array.isArray(diagnosesForVisit) || !diagnosesForVisit.length) return "";
  return uniqueStrings(diagnosesForVisit.map((d) => String(d?.condition || "").trim())).join(", ");
}

function collectPrescribedMedications(apptId, record, electronicRx, dispensingRx, dispensingItems, legacyRx) {
  const names = [];
  if (Array.isArray(record?.prescription)) {
    for (const item of record.prescription) {
      const name = String(item?.name || "").trim();
      if (name) names.push(name);
    }
  }
  for (const rx of electronicRx) {
    if (String(rx.appointmentId || "") !== apptId) continue;
    for (const item of rx.items || []) {
      const name = String(item?.name || "").trim();
      if (name) names.push(name);
    }
  }
  for (const rx of dispensingRx) {
    if (String(rx.appointmentId || "") !== apptId) continue;
    const rxId = String(rx._id);
    for (const item of dispensingItems) {
      if (String(item.prescriptionId || "") !== rxId) continue;
      const name = String(item?.drugName || "").trim();
      if (name) names.push(name);
    }
  }
  for (const rx of legacyRx) {
    if (String(rx.appointmentId || "") !== apptId) continue;
    const name = String(rx.medicationName || "").trim();
    if (name) names.push(name);
  }
  return uniqueStrings(names);
}

async function buildClinicalBaseline(patientUserId) {
  const patientOid = new mongoose.Types.ObjectId(patientUserId);
  const [health, medical] = await Promise.all([
    HealthProfile.findOne({ userId: patientOid }).lean(),
    PatientMedicalProfile.findOne({ userId: patientOid }).lean(),
  ]);

  return {
    bloodType: String(medical?.bloodType || health?.bloodType || "").trim(),
    chronicDiseases: uniqueStrings([
      ...(Array.isArray(health?.chronicDiseases) ? health.chronicDiseases : []),
      ...(Array.isArray(medical?.chronicDiseases) ? medical.chronicDiseases : []),
    ]),
    allergies: mergeAllergyStrings(health, medical),
  };
}

async function buildEncounters(patientUserId) {
  const patientOid = new mongoose.Types.ObjectId(patientUserId);

  const [appointments, medicalProfile] = await Promise.all([
    Appointment.find({
      patientId: patientOid,
      status: { $nin: ["cancelled_by_doctor", "cancelled_by_patient"] },
    })
      .sort({ date: -1, time: -1, createdAt: -1 })
      .limit(100)
      .lean(),
    PatientMedicalProfile.findOne({ userId: patientOid })
      .select("vitalsTimeline nursingNotes")
      .lean(),
  ]);

  if (!appointments.length) return [];

  const apptIds = appointments.map((a) => a._id);
  const clinicIds = [
    ...new Set(appointments.map((a) => a.clinicId).filter(Boolean).map(String)),
  ].map((id) => new mongoose.Types.ObjectId(id));

  const [records, sessions, doctorNotes, clinics, diagnoses, electronicRx, dispensingRx, legacyRx] =
    await Promise.all([
      MedicalRecord.find({ appointmentId: { $in: apptIds } }).lean(),
      ClinicSession.find({ appointmentId: { $in: apptIds } }).lean(),
      DoctorNote.find({ patientUserId: patientOid, active: true }).sort({ createdAt: -1 }).lean(),
      clinicIds.length
        ? Clinic.find({ _id: { $in: clinicIds } })
            .select("name")
            .lean()
        : [],
      Diagnosis.find({ patientUserId: patientOid, appointmentId: { $in: apptIds }, active: true })
        .sort({ createdAt: -1 })
        .lean(),
      ElectronicPrescription.find({ patientUserId: patientOid, appointmentId: { $in: apptIds } })
        .sort({ createdAt: -1 })
        .lean(),
      DispensingPrescription.find({ patientUserId: patientOid, appointmentId: { $in: apptIds } })
        .sort({ issueDate: -1 })
        .lean(),
      Prescription.find({ patientUserId: patientOid, appointmentId: { $in: apptIds } })
        .sort({ createdAt: -1 })
        .lean(),
    ]);

  const dispensingIds = dispensingRx.map((rx) => rx._id);
  const dispensingItems = dispensingIds.length
    ? await DispensingPrescriptionItem.find({ prescriptionId: { $in: dispensingIds } }).lean()
    : [];

  const recordByAppt = new Map(records.map((r) => [String(r.appointmentId), r]));
  const sessionByAppt = new Map(sessions.map((s) => [String(s.appointmentId), s]));
  const clinicNameById = new Map(clinics.map((c) => [String(c._id), c.name || "Clinic"]));
  const nursingNotes = medicalProfile?.nursingNotes || [];
  const vitalsTimeline = medicalProfile?.vitalsTimeline || [];

  const encounters = [];

  for (const appt of appointments) {
    const apptId = String(appt._id);
    const record = recordByAppt.get(apptId);
    const session = sessionByAppt.get(apptId);
    const visitDoctorNotes = doctorNotes.filter(
      (n) => n.appointmentId && String(n.appointmentId) === apptId
    );

    const hasClinicalData =
      record ||
      session ||
      visitDoctorNotes.length > 0 ||
      ["Completed", "In Progress"].includes(String(appt.status || ""));

    if (!hasClinicalData) continue;

    const vitalsEntry = findVitalsForVisit(vitalsTimeline, appt._id);
    const visitDate = parseVisitDate(appt, session, record);
    const clinicName =
      (appt.clinicId && clinicNameById.get(String(appt.clinicId))) ||
      String(appt.branch || "").trim() ||
      "Rafeeq Clinic";
    const visitDiagnoses = diagnoses.filter((d) => d.appointmentId && String(d.appointmentId) === apptId);
    const prescribedMedications = collectPrescribedMedications(
      apptId,
      record,
      electronicRx,
      dispensingRx,
      dispensingItems,
      legacyRx
    );

    encounters.push({
      id: apptId,
      visitDate: visitDate ? visitDate.toISOString() : null,
      doctorName: String(appt.doctorName || "Attending physician").trim(),
      clinicName,
      chiefComplaint: findChiefComplaint(appt, nursingNotes, appt._id),
      diagnosis: resolveDiagnosis(apptId, record, session, visitDiagnoses),
      prescribedMedications,
      vitalSigns: buildVitalSigns(session, vitalsEntry),
      notes: combineNotes(record, session, visitDoctorNotes),
    });
  }

  encounters.sort((a, b) => {
    const da = a.visitDate ? new Date(a.visitDate).getTime() : 0;
    const db = b.visitDate ? new Date(b.visitDate).getTime() : 0;
    return db - da;
  });

  return encounters;
}

async function aggregatePatientMedicalRecords(patientUserId) {
  const [baseline, encounters] = await Promise.all([
    buildClinicalBaseline(patientUserId),
    buildEncounters(patientUserId),
  ]);

  return {
    bloodType: baseline.bloodType,
    chronicDiseases: baseline.chronicDiseases,
    chronicConditions: baseline.chronicDiseases,
    allergies: baseline.allergies,
    encounters,
  };
}

async function getMedicalRecords(req, res) {
  try {
    const { patientId, patientUserId: patientUserIdParam, id } = req.params;
    const patientUserId =
      req.patientUserId ||
      patientId ||
      patientUserIdParam ||
      id ||
      String(req.query.patientId || req.query.patientUserId || req.query.id || "").trim();

    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Valid patientId is required." });
    }

    const user = await UserModel.findById(patientUserId).select("_id role").lean();
    if (!user) {
      return res.status(404).json({ message: "Patient not found." });
    }

    const payload = await aggregatePatientMedicalRecords(patientUserId);
    return res.json(payload);
  } catch (error) {
    console.error("[patient/medical-records]", error);
    return res.status(500).json({ message: "Error fetching medical records." });
  }
}

exports.getMedicalRecords = getMedicalRecords;
exports.getPatientMedicalRecords = getMedicalRecords;
exports.aggregatePatientMedicalRecords = aggregatePatientMedicalRecords;
