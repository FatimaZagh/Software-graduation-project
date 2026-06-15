const mongoose = require("mongoose");
const AdverseReport = require("../models/adverseReport");
const {
  PROBLEM_TYPES,
  SEVERITY_LEVELS,
  ONSET_TIMES,
} = require("../models/adverseReport");
const PatientMedication = require("../models/patientMedication");
const AppointmentModel = require("../models/appointment");
const Patient = require("../models/patient");
const User = require("../models/User");
const {
  evaluateCritical,
  dispatchAdverseAlerts,
} = require("../services/adverseReportAlerts");
const { stopPatientMedicationRecord } = require("../services/patientMedicationStop");

function str(v) {
  return String(v ?? "").trim();
}

function arr(v) {
  if (Array.isArray(v)) return v.map((x) => str(x)).filter(Boolean);
  if (typeof v === "string" && v.trim()) return [v.trim()];
  return [];
}

async function resolveDoctorUserId(patientUserId, explicitDoctorId, medicationDoctorId) {
  const candidates = [explicitDoctorId, medicationDoctorId].filter(Boolean);
  for (const id of candidates) {
    const s = String(id).trim();
    if (s && mongoose.Types.ObjectId.isValid(s)) return s;
  }
  const appt = await AppointmentModel.findOne({
    patientId: patientUserId,
    doctorUserId: { $exists: true, $ne: null },
  })
    .sort({ date: -1, createdAt: -1 })
    .select("doctorUserId orgId")
    .lean();
  return appt?.doctorUserId ? String(appt.doctorUserId) : null;
}

async function resolveOrgId(patientUserId, doctorUserId) {
  const patient = await Patient.findOne({ userId: patientUserId }).select("orgId").lean();
  if (patient?.orgId) return patient.orgId;
  const user = await User.findById(patientUserId).select("orgId").lean();
  if (user?.orgId) return user.orgId;
  if (doctorUserId) {
    const doc = await User.findById(doctorUserId).select("orgId").lean();
    if (doc?.orgId) return doc.orgId;
  }
  return null;
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

/**
 * POST /api/patients/:patientUserId/adverse-reports
 */
exports.reportAdverseEffect = async (req, res) => {
  try {
    const patientUserId = req.params.patientUserId || req.params.id;
    if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid patient id" });
    }

    const user = await User.findById(patientUserId).lean();
    if (!user || user.role !== "Patient") {
      return res.status(404).json({ message: "Patient not found" });
    }

    const {
      prescriptionId,
      medicationName,
      problemType,
      symptoms,
      otherSymptoms,
      severity,
      onsetTime,
      additionalNotes,
      doctorUserId,
      doctorId,
      prescriberId,
    } = req.body;
    const explicitDoctorFromBody =
      doctorUserId || doctorId || prescriberId || req.body.prescribingDoctorUserId;

    const medName = str(medicationName);
    if (!medName) return res.status(400).json({ message: "medicationName required" });
    if (!PROBLEM_TYPES.includes(problemType)) {
      return res.status(400).json({ message: "Invalid problemType" });
    }
    if (!SEVERITY_LEVELS.includes(severity)) {
      return res.status(400).json({ message: "Invalid severity" });
    }
    if (!ONSET_TIMES.includes(onsetTime)) {
      return res.status(400).json({ message: "Invalid onsetTime" });
    }

    let prescId = null;
    let medicationDoctorId = null;
    if (prescriptionId && mongoose.Types.ObjectId.isValid(prescriptionId)) {
      const med = await PatientMedication.findOne({
        _id: prescriptionId,
        patientUserId,
      }).lean();
      if (!med) return res.status(404).json({ message: "Prescription not found" });
      prescId = med._id;
      if (med.prescribingDoctorUserId) {
        medicationDoctorId = String(med.prescribingDoctorUserId);
      }
    }

    const resolvedDoctorId = await resolveDoctorUserId(
      patientUserId,
      explicitDoctorFromBody,
      medicationDoctorId
    );
    const orgId = await resolveOrgId(patientUserId, resolvedDoctorId);
    const symptomList = arr(symptoms);
    const isCritical = evaluateCritical({
      problemType,
      symptoms: symptomList,
      severity,
    });

    const report = await AdverseReport.create({
      orgId,
      patientId: patientUserId,
      doctorId: resolvedDoctorId || undefined,
      prescriptionId: prescId || undefined,
      medicationName: medName,
      problemType,
      symptoms: symptomList,
      otherSymptoms: str(otherSymptoms),
      severity,
      onsetTime,
      additionalNotes: str(additionalNotes),
      isCritical,
      doctorAction: { status: "Pending" },
      workflowStatus: "New",
      auditLog: [
        {
          at: new Date(),
          actorRole: "Patient",
          actorId: patientUserId,
          event: "report_submitted",
          detail: `Patient reported ${problemType} for ${medName}`,
        },
      ],
    });

    await dispatchAdverseAlerts(report, user);

    res.status(201).json({
      report,
      isCritical,
      message: isCritical
        ? "Urgent report submitted. Clinical staff notified immediately."
        : "Report submitted successfully.",
    });
  } catch (e) {
    console.error("reportAdverseEffect:", e);
    res.status(500).json({ message: "Error submitting adverse report" });
  }
};

/**
 * GET /api/patients/:patientUserId/adverse-reports
 */
exports.listPatientReports = async (req, res) => {
  try {
    const patientUserId = req.params.patientUserId || req.params.id;
    const list = await AdverseReport.find({ patientId: patientUserId })
      .sort({ createdAt: -1 })
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading reports" });
  }
};

/**
 * GET /api/doctor-portal/:doctorUserId/adverse-reports
 */
exports.listDoctorReports = async (req, res) => {
  try {
    const doctorUserId = req.doctorUserId;
    const docUser = await User.findById(doctorUserId).select("orgId").lean();
    const filter = {
      $or: [{ doctorId: doctorUserId }],
    };
    if (docUser?.orgId) {
      filter.$or.push({ doctorId: null, orgId: docUser.orgId });
    }
    if (req.query.criticalOnly === "true") {
      filter.isCritical = true;
    }
    const list = await AdverseReport.find(filter).sort({ createdAt: -1 }).lean();

    const enriched = list.map((r) => ({
      ...r,
      workflowStatus: r.workflowStatus || "New",
      urgentNotification: r.isCritical || r.severity === "Severe" || r.isEmergencyCase,
      redHighlight: Boolean(r.isCritical || r.severity === "Severe" || r.isEmergencyCase),
      directContactAvailable: Boolean(r.patientId),
      proposeSuspensionAvailable:
        (r.isCritical || r.severity === "Severe") &&
        r.doctorAction?.status !== "Action Taken" &&
        !r.medicationSuspended,
      flashEmergencyStyle: Boolean(r.isEmergencyCase),
    }));

    res.json(enriched);
  } catch (e) {
    res.status(500).json({ message: "Error loading ADR reports" });
  }
};

/**
 * PATCH /api/doctor-portal/:doctorUserId/adverse-reports/:reportId
 */
exports.updateDoctorAction = async (req, res) => {
  try {
    const { reportId } = req.params;
    const doctorUserId = req.doctorUserId;
    const { status, notes } = req.body;

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });

    if (status) {
      const allowed = ["Pending", "Reviewed", "Action Taken"];
      if (!allowed.includes(status)) {
        return res.status(400).json({ message: "Invalid doctor action status" });
      }
      report.doctorAction.status = status;
      report.doctorAction.actionDate = new Date();
    }
    if (notes != null) report.doctorAction.notes = str(notes);

    pushAudit(
      report,
      "doctor_review",
      "Doctor",
      doctorUserId,
      `Status: ${report.doctorAction.status}. ${str(notes)}`
    );

    await report.save();

    const PatientNotification = require("../models/patientNotification");
    await PatientNotification.create({
      patientUserId: report.patientId,
      type: "adr_doctor_update",
      title: "Doctor reviewed your report",
      body: `Your report for ${report.medicationName} was marked: ${report.doctorAction.status}.`,
      read: false,
      meta: { adverseReportId: String(report._id) },
    });

    res.json(report.toObject());
  } catch (e) {
    res.status(500).json({ message: "Error updating report" });
  }
};

/**
 * POST /api/doctor-portal/:doctorUserId/adverse-reports/:reportId/propose-suspension
 */
exports.proposeMedicationSuspension = async (req, res) => {
  try {
    const { reportId } = req.params;
    const doctorUserId = req.doctorUserId;
    const notes = str(req.body.notes) || "Temporary suspension proposed due to adverse reaction.";

    const report = await AdverseReport.findById(reportId);
    if (!report) return res.status(404).json({ message: "Report not found" });

    if (report.prescriptionId) {
      await stopPatientMedicationRecord({
        patientUserId: report.patientId,
        medId: report.prescriptionId,
        doctorUserId,
        reason: `ADR suspension: ${notes}`,
        adverseReportId: report._id,
      });
      report.medicationSuspended = true;
    }

    report.doctorAction.status = "Action Taken";
    report.doctorAction.proposedSuspension = true;
    report.doctorAction.notes = notes;
    report.doctorAction.actionDate = new Date();

    pushAudit(report, "propose_suspension", "Doctor", doctorUserId, notes);
    await report.save();

    const PatientNotification = require("../models/patientNotification");
    await PatientNotification.create({
      patientUserId: report.patientId,
      type: "adr_suspension",
      title: "Medication temporarily suspended",
      body: `${report.medicationName} was suspended pending clinical review.`,
      read: false,
      meta: { adverseReportId: String(report._id) },
    });

    res.json({
      report: report.toObject(),
      medicationSuspended: report.medicationSuspended,
      message: "Temporary medication suspension recorded.",
    });
  } catch (e) {
    res.status(500).json({ message: "Error proposing suspension" });
  }
};

/**
 * GET /api/admin/adverse-analytics — Organization Admin
 */
exports.getAdverseAnalytics = async (req, res) => {
  try {
    const orgId = req.scoped?.user?.orgId || req.query.orgId;
    const match = orgId && mongoose.Types.ObjectId.isValid(orgId) ? { orgId } : {};

    const reports = await AdverseReport.find(match).sort({ createdAt: -1 }).lean();

    const drugCounts = {};
    const doctorResponseMs = [];
    const auditTrail = [];

    for (const r of reports) {
      const drug = r.medicationName || "Unknown";
      drugCounts[drug] = (drugCounts[drug] || 0) + 1;

      if (r.doctorAction?.actionDate && r.createdAt) {
        const ms =
          new Date(r.doctorAction.actionDate).getTime() - new Date(r.createdAt).getTime();
        if (ms >= 0) doctorResponseMs.push(ms);
      }

      auditTrail.push({
        reportId: r._id,
        medicationName: r.medicationName,
        patientReport: {
          problemType: r.problemType,
          symptoms: r.symptoms,
          severity: r.severity,
          onsetTime: r.onsetTime,
          additionalNotes: r.additionalNotes,
          submittedAt: r.createdAt,
        },
        doctorAction: {
          status: r.doctorAction?.status,
          notes: r.doctorAction?.notes,
          actionDate: r.doctorAction?.actionDate,
          proposedSuspension: r.doctorAction?.proposedSuspension,
        },
        isCritical: r.isCritical,
      });
    }

    const topDrugs = Object.entries(drugCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15)
      .map(([medicationName, count]) => ({ medicationName, count }));

    const avgResponseHours =
      doctorResponseMs.length > 0
        ? (
            doctorResponseMs.reduce((a, b) => a + b, 0) /
            doctorResponseMs.length /
            3600000
          ).toFixed(2)
        : null;

    res.json({
      summary: {
        totalReports: reports.length,
        criticalCount: reports.filter((r) => r.isCritical).length,
        pendingDoctorReview: reports.filter((r) => r.doctorAction?.status === "Pending")
          .length,
        suspensions: reports.filter((r) => r.medicationSuspended).length,
        avgDoctorResponseHours: avgResponseHours,
      },
      topDrugsBySideEffects: topDrugs,
      auditTrail: auditTrail.slice(0, 100),
    });
  } catch (e) {
    console.error("getAdverseAnalytics:", e);
    res.status(500).json({ message: "Error loading adverse analytics" });
  }
};

exports.getFormOptions = (_req, res) => {
  res.json({
    problemTypes: PROBLEM_TYPES,
    severityLevels: SEVERITY_LEVELS,
    onsetTimes: ONSET_TIMES,
    symptomOptions: [
      "Rash",
      "Dizziness",
      "Nausea",
      "Vomiting",
      "Headache",
      "Dyspnea",
      "Facial Swelling",
      "Itching",
      "Abdominal Pain",
      "Fatigue",
    ],
  });
};
