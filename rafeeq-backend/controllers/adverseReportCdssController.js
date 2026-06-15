const mongoose = require("mongoose");
const AdverseReport = require("../models/adverseReport");
const { WORKFLOW_STATUSES } = require("../models/adverseReport");
const PatientMedication = require("../models/patientMedication");
const PatientMedicalProfile = require("../models/patientMedicalProfile");
const HealthProfile = require("../models/healthProfile");
const AppointmentModel = require("../models/appointment");
const User = require("../models/User");
const PatientNotification = require("../models/patientNotification");
const { collectAllergyStrings } = require("../utils/allergyCdss");
const { notifyUser } = require("../services/adverseReportAlerts");
const { assertDoctorMayEditMedication } = require("./prescriptionLifecycleController");
const { stopPatientMedicationRecord } = require("../services/patientMedicationStop");

function str(v) {
  return String(v ?? "").trim();
}

function pushAudit(report, event, actorRole, actorId, detail) {
  report.auditLog = report.auditLog || [];
  report.auditLog.push({
    at: new Date(),
    actorRole,
    actorId: actorId || undefined,
    event,
    detail,
  });
}

async function assertDoctorReportAccess(doctorUserId, report) {
  if (!report) return false;
  if (report.doctorId && String(report.doctorId) === String(doctorUserId)) return true;
  const docUser = await User.findById(doctorUserId).select("orgId").lean();
  if (
    (!report.doctorId || report.doctorId == null) &&
    docUser?.orgId &&
    report.orgId &&
    String(report.orgId) === String(docUser.orgId)
  ) {
    return true;
  }
  return false;
}

function syncLegacyDoctorAction(report) {
  const ws = report.workflowStatus || "New";
  if (ws === "Resolved" || ws === "Medication Changed") {
    report.doctorAction.status = "Action Taken";
  } else if (ws === "Emergency Case" || ws === "Contacted Patient" || ws === "Reviewed") {
    report.doctorAction.status = "Reviewed";
  } else {
    report.doctorAction.status = "Pending";
  }
}

function todayYmd() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function nextHourTimeSlot() {
  const d = new Date();
  d.setMinutes(0, 0, 0);
  d.setHours(d.getHours() + 1);
  return `${String(d.getHours()).padStart(2, "0")}:00`;
}

async function notifyNursesEmergency(orgId, title, body, meta) {
  if (!orgId) return;
  const nurses = await User.find({ role: "Nurse", orgId }).select("_id").lean();
  for (const n of nurses) {
    await notifyUser(n._id, "Nurse", {
      type: "adr_emergency_broadcast",
      title,
      body,
      meta: { ...meta, flashEmergency: true, priority: "critical" },
    });
  }
}

/**
 * GET /api/doctor/adverse-reports/:reportId/detail
 */
exports.getReportDetail = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const { reportId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(reportId)) {
      return res.status(400).json({ message: "Invalid report id" });
    }
    const report = await AdverseReport.findById(reportId).lean();
    if (!report) return res.status(404).json({ message: "Report not found" });

    const ok = await assertDoctorReportAccess(doctorUserId, report);
    if (!ok) return res.status(403).json({ message: "Access denied" });

    const patient = await User.findById(report.patientId).select("name email phoneNumber").lean();
    const workflowStatus = report.workflowStatus || "New";

    res.json({
      report: { ...report, workflowStatus },
      patient: {
        patientUserId: String(report.patientId),
        name: patient?.name || "Patient",
        email: patient?.email || "",
        phone: patient?.phoneNumber || "",
      },
      workflowStatuses: [...WORKFLOW_STATUSES],
    });
  } catch (e) {
    console.error("getReportDetail:", e);
    res.status(500).json({ message: e.message || "Error loading report" });
  }
};

/**
 * PATCH /api/doctor/adverse-reports/:reportId/workflow
 * body: { workflowStatus }
 */
exports.patchWorkflowStatus = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const { reportId } = req.params;
    const { workflowStatus } = req.body || {};
    if (!workflowStatus || !WORKFLOW_STATUSES.includes(workflowStatus)) {
      return res.status(400).json({ message: `workflowStatus must be one of: ${WORKFLOW_STATUSES.join(", ")}` });
    }

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    const access = await assertDoctorReportAccess(doctorUserId, report);
    if (!access) return res.status(403).json({ message: "Access denied" });

    report.workflowStatus = workflowStatus;
    if (workflowStatus === "Emergency Case") report.isEmergencyCase = true;
    report.doctorAction.actionDate = new Date();
    syncLegacyDoctorAction(report);
    pushAudit(report, "workflow_update", "Doctor", doctorUserId, `workflowStatus=${workflowStatus}`);
    await report.save();

    res.json(report.toObject());
  } catch (e) {
    console.error("patchWorkflowStatus:", e);
    res.status(500).json({ message: e.message || "Error updating workflow" });
  }
};

/**
 * POST .../mark-emergency
 */
exports.markEmergency = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const { reportId } = req.params;
    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }

    report.isEmergencyCase = true;
    report.workflowStatus = "Emergency Case";
    report.isCritical = true;
    syncLegacyDoctorAction(report);
    report.doctorAction.actionDate = new Date();
    pushAudit(report, "mark_emergency", "Doctor", doctorUserId, "Marked as emergency case");
    await report.save();

    const patient = await User.findById(report.patientId).select("name").lean();
    const pname = patient?.name || "Patient";
    await notifyNursesEmergency(
      report.orgId,
      "EMERGENCY ADR — physician triage",
      `${pname} — ${report.medicationName}: physician marked EMERGENCY.`,
      { adverseReportId: String(report._id), patientId: String(report.patientId) }
    );

    res.json({ report: report.toObject(), message: "Emergency flag broadcast to nursing." });
  } catch (e) {
    console.error("markEmergency:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};

/**
 * POST .../stop-medication
 */
exports.stopMedicationForReport = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const orgId = req.doctorScope.orgId;
    const { reportId } = req.params;
    const { reason } = req.body || {};

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }

    if (!report.prescriptionId) {
      return res.status(400).json({ message: "No linked prescription on this report" });
    }

    const med = await PatientMedication.findOne({
      _id: report.prescriptionId,
      patientUserId: report.patientId,
    }).lean();
    if (!med) return res.status(404).json({ message: "Linked medication not found" });

    const ok = await assertDoctorMayEditMedication(doctorUserId, orgId, report.patientId, med);
    if (!ok) return res.status(403).json({ message: "Not authorized to stop this medication" });

    const stopNote = str(reason) || "Stopped by physician (ADR CDSS).";
    const updated = await stopPatientMedicationRecord({
      patientUserId: report.patientId,
      medId: med._id,
      doctorUserId,
      reason: stopNote,
      adverseReportId: report._id,
    });
    if (!updated) return res.status(404).json({ message: "Linked medication not found" });

    report.medicationSuspended = true;
    report.workflowStatus = "Medication Changed";
    syncLegacyDoctorAction(report);
    report.doctorAction.actionDate = new Date();
    pushAudit(report, "stop_medication", "Doctor", doctorUserId, stopNote);
    await report.save();

    res.json({ report: report.toObject(), message: "Medication stopped." });
  } catch (e) {
    console.error("stopMedicationForReport:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};

/**
 * POST .../modify-medication { dosage, frequency, notes }
 */
exports.modifyMedicationForReport = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const orgId = req.doctorScope.orgId;
    const { reportId } = req.params;
    const { dosage, frequency, notes } = req.body || {};

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }
    if (!report.prescriptionId) {
      return res.status(400).json({ message: "No linked prescription" });
    }

    const med = await PatientMedication.findOne({
      _id: report.prescriptionId,
      patientUserId: report.patientId,
    }).lean();
    if (!med) return res.status(404).json({ message: "Medication not found" });

    const ok = await assertDoctorMayEditMedication(doctorUserId, orgId, report.patientId, med);
    if (!ok) return res.status(403).json({ message: "Not authorized to modify this medication" });

    const $set = {};
    if (dosage != null) $set.dosage = str(dosage);
    if (frequency != null) $set.frequency = str(frequency);
    const changeLine = `[MODIFY ${new Date().toISOString().slice(0, 10)} Dr] ${str(notes) || "Dosage/frequency updated."}`;
    $set.notes = `${med.notes || ""}\n${changeLine}`.trim();

    const updated = await PatientMedication.findOneAndUpdate(
      { _id: report.prescriptionId, patientUserId: report.patientId, status: { $ne: "Stopped" }, active: true },
      { $set },
      { new: true }
    ).lean();

    if (!updated) {
      return res.status(400).json({ message: "Medication is inactive or could not be updated" });
    }

    report.workflowStatus = "Medication Changed";
    syncLegacyDoctorAction(report);
    pushAudit(report, "modify_medication", "Doctor", doctorUserId, JSON.stringify({ dosage, frequency }));
    await report.save();

    res.json({ report: report.toObject(), medication: updated });
  } catch (e) {
    console.error("modifyMedicationForReport:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};

/**
 * POST .../replace-medication { replacementName, replacementDosage?, replacementFrequency?, notes? }
 */
exports.replaceMedicationForReport = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const orgId = req.doctorScope.orgId;
    const { reportId } = req.params;
    const { replacementName, replacementDosage, replacementFrequency, notes } = req.body || {};
    const newName = str(replacementName);
    if (!newName) return res.status(400).json({ message: "replacementName required" });

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }
    if (!report.prescriptionId) {
      return res.status(400).json({ message: "No linked prescription" });
    }

    const med = await PatientMedication.findOne({
      _id: report.prescriptionId,
      patientUserId: report.patientId,
    }).lean();
    if (!med) return res.status(404).json({ message: "Medication not found" });

    const ok = await assertDoctorMayEditMedication(doctorUserId, orgId, report.patientId, med);
    if (!ok) return res.status(403).json({ message: "Not authorized" });

    const docUser = await User.findById(doctorUserId).select("name").lean();
    const prescriberLabel = docUser?.name || "Doctor";

    await stopPatientMedicationRecord({
      patientUserId: report.patientId,
      medId: med._id,
      doctorUserId,
      reason: `Replaced with ${newName}. ${str(notes)}`,
      adverseReportId: report._id,
    });

    const created = await PatientMedication.create({
      patientUserId: report.patientId,
      prescribingDoctorUserId: doctorUserId,
      medicationName: newName,
      dosage: str(replacementDosage) || "",
      frequency: str(replacementFrequency) || "As directed",
      prescribedBy: prescriberLabel,
      notes: `Replacement for ${report.medicationName} (ADR). ${str(notes)}`,
      status: "Active",
      active: false,
      startDate: null,
      durationInDays: 30,
    });

    report.prescriptionId = created._id;
    report.workflowStatus = "Medication Changed";
    syncLegacyDoctorAction(report);
    pushAudit(report, "replace_medication", "Doctor", doctorUserId, `${report.medicationName} → ${newName}`);
    await report.save();

    await PatientNotification.create({
      patientUserId: report.patientId,
      type: "medication_replaced",
      title: "Medication change",
      body: `Your clinician replaced ${report.medicationName} with ${newName}. Follow the new instructions in your medication list.`,
      read: false,
      meta: { adverseReportId: String(report._id), newMedicationId: String(created._id) },
    });

    res.json({ report: report.toObject(), newMedication: created.toObject() });
  } catch (e) {
    console.error("replaceMedicationForReport:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};

/**
 * POST .../schedule-urgent-visit
 */
exports.scheduleUrgentVisit = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const orgId = req.doctorScope.orgId;
    const { reportId } = req.params;

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }

    const patient = await User.findById(report.patientId).select("name").lean();
    const doctor = await User.findById(doctorUserId).select("name").lean();
    const pname = patient?.name || "Patient";
    const dname = doctor?.name || "Doctor";

    const appt = await AppointmentModel.create({
      orgId,
      patientName: pname,
      patientId: report.patientId,
      time: nextHourTimeSlot(),
      date: todayYmd(),
      status: "Waiting",
      bookingStatus: "Accepted",
      doctorUserId,
      doctorName: dname,
      branch: "ADR urgent",
      initialSymptoms: `Urgent visit — ADR follow-up (${report.medicationName}).`,
    });

    report.workflowStatus = "Reviewed";
    syncLegacyDoctorAction(report);
    pushAudit(report, "urgent_visit", "Doctor", doctorUserId, `appointmentId=${appt._id}`);
    await report.save();

    await PatientNotification.create({
      patientUserId: report.patientId,
      type: "urgent_visit_scheduled",
      title: "Urgent clinic visit scheduled",
      body: `An urgent visit was scheduled with ${dname} following your adverse report.`,
      read: false,
      meta: { adverseReportId: String(report._id), appointmentId: String(appt._id) },
    });

    res.json({ appointment: appt.toObject(), report: report.toObject() });
  } catch (e) {
    console.error("scheduleUrgentVisit:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};

/**
 * POST .../er-redirect
 */
exports.setErRedirect = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const { reportId } = req.params;
    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }

    const erHomeMessage = "Go to the nearest medical center";
    await PatientNotification.create({
      patientUserId: report.patientId,
      type: "er_redirect",
      title: erHomeMessage,
      body: erHomeMessage,
      read: false,
      meta: {
        adverseReportId: String(report._id),
        priority: "critical",
        homeBannerMessage: erHomeMessage,
      },
    });

    report.workflowStatus = "Contacted Patient";
    syncLegacyDoctorAction(report);
    pushAudit(report, "er_redirect", "Doctor", doctorUserId, "ER directive sent to patient");
    await report.save();

    res.json({ report: report.toObject(), message: "ER directive pushed to patient notifications." });
  } catch (e) {
    console.error("setErRedirect:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};

/**
 * POST .../clinical-notes { text }
 */
exports.appendClinicalNotes = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const { reportId } = req.params;
    const text = str(req.body?.text);
    if (!text) return res.status(400).json({ message: "text required" });

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }

    report.clinicalDocumentation = report.clinicalDocumentation || [];
    report.clinicalDocumentation.push({
      text,
      doctorId: doctorUserId,
      createdAt: new Date(),
    });
    report.doctorAction.notes = [report.doctorAction.notes, text].filter(Boolean).join("\n---\n");
    pushAudit(report, "clinical_note", "Doctor", doctorUserId, text.slice(0, 500));
    await report.save();

    let profile = await PatientMedicalProfile.findOne({ userId: report.patientId });
    if (!profile) {
      profile = await PatientMedicalProfile.create({
        userId: report.patientId,
        orgId: report.orgId,
        medicalHistoryNotes: "",
      });
    }
    const stamp = new Date().toISOString().slice(0, 16);
    profile.medicalHistoryNotes = `${profile.medicalHistoryNotes || ""}\n[${stamp} CDSS/ADR] ${text}`.trim();
    await profile.save();

    res.json({ report: report.toObject(), message: "Clinical notes saved." });
  } catch (e) {
    console.error("appendClinicalNotes:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};

/**
 * POST .../allergy-profile { drugName?, drugClass?, severity? }
 */
exports.saveAllergyProfile = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const { reportId } = req.params;
    const drugName = str(req.body?.drugName);
    const drugClass = str(req.body?.drugClass);
    const severity = str(req.body?.severity) || "Unknown";

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });
    if (!(await assertDoctorReportAccess(doctorUserId, report))) {
      return res.status(403).json({ message: "Access denied" });
    }

    const base = drugName || report.medicationName;
    const entry = `${base}${drugClass ? ` [class: ${drugClass}]` : ""} — ${severity} (ADR confirmed ${new Date().toISOString().slice(0, 10)})`;

    let profile = await PatientMedicalProfile.findOne({ userId: report.patientId });
    if (!profile) {
      profile = await PatientMedicalProfile.create({
        userId: report.patientId,
        orgId: report.orgId,
        allergies: { medications: [], foods: [], materials: [] },
      });
    }
    profile.allergies = profile.allergies || { medications: [], foods: [], materials: [] };
    profile.allergies.medications = profile.allergies.medications || [];
    if (!profile.allergies.medications.includes(entry)) {
      profile.allergies.medications.push(entry);
    }
    await profile.save();

    let hp = await HealthProfile.findOne({ userId: report.patientId });
    if (hp) {
      hp.allergies = hp.allergies || [];
      if (!hp.allergies.includes(entry)) hp.allergies.push(entry);
      await hp.save();
    }

    report.workflowStatus = "Medication Changed";
    syncLegacyDoctorAction(report);
    pushAudit(report, "allergy_registry", "Doctor", doctorUserId, entry);
    await report.save();

    res.json({ report: report.toObject(), allergyEntry: entry, message: "Allergy saved to patient profile." });
  } catch (e) {
    console.error("saveAllergyProfile:", e);
    res.status(500).json({ message: e.message || "Error" });
  }
};
