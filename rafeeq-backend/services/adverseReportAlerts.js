const UserNotification = require("../models/userNotification");
const PatientNotification = require("../models/patientNotification");

const CRITICAL_SYMPTOMS = ["Dyspnea", "Facial Swelling"];

function evaluateCritical({ problemType, symptoms, severity }) {
  const symptomList = Array.isArray(symptoms) ? symptoms : [];
  const hasCriticalSymptom = symptomList.some((s) =>
    CRITICAL_SYMPTOMS.includes(String(s).trim())
  );
  const severeProblem = problemType === "Severe Side Effect";
  const severeLevel = severity === "Severe";
  return hasCriticalSymptom || severeProblem || severeLevel;
}

async function notifyUser(userId, role, payload) {
  if (!userId) return;
  await UserNotification.create({
    userId,
    role,
    type: payload.type || "info",
    title: payload.title,
    body: payload.body,
    read: false,
    meta: payload.meta || {},
  });
}

async function notifyNurses(orgId, payload) {
  if (!orgId) return [];
  const User = require("../models/User");
  const nurses = await User.find({ role: "Nurse", orgId }).select("_id").lean();
  for (const n of nurses) {
    await notifyUser(n._id, "Nurse", payload);
  }
  return nurses.map((n) => n._id);
}

/**
 * Dispatch ADR alerts to doctor, nurses, and patient confirmation.
 */
async function dispatchAdverseAlerts(report, patientUser) {
  const isCritical = report.isCritical;
  const med = report.medicationName;
  const patientName = patientUser?.name || patientUser?.email || "Patient";

  const baseMeta = {
    adverseReportId: String(report._id),
    patientId: String(report.patientId),
    medicationName: med,
    isCritical,
    problemType: report.problemType,
    severity: report.severity,
    symptoms: report.symptoms,
  };

  if (report.doctorId) {
    await notifyUser(report.doctorId, "Doctor", {
      type: isCritical ? "adr_critical" : "adr_report",
      title: isCritical
        ? "URGENT: Critical adverse drug reaction"
        : "New adverse effect report",
      body: `${patientName} reported a reaction to ${med} (${report.problemType}, ${report.severity}).`,
      meta: {
        ...baseMeta,
        priority: isCritical ? "high" : "normal",
        redHighlight: isCritical,
        actions: isCritical
          ? ["direct_contact", "propose_medication_suspension", "review_report"]
          : ["review_report"],
      },
    });
  }

  await notifyNurses(report.orgId, {
    type: isCritical ? "adr_critical" : "adr_report",
    title: isCritical ? "URGENT ADR — Nursing alert" : "ADR report for nursing review",
    body: `${patientName} — ${med}: ${report.problemType}. Severity: ${report.severity}.`,
    meta: { ...baseMeta, priority: isCritical ? "high" : "normal" },
  });

  await PatientNotification.create({
    patientUserId: report.patientId,
    type: "adr_submitted",
    title: "Report received",
    body: isCritical
      ? "Your report was flagged as urgent. Clinical staff have been notified immediately."
      : "Your side effect report was sent to your care team.",
    read: false,
    meta: baseMeta,
  });
}

module.exports = {
  CRITICAL_SYMPTOMS,
  evaluateCritical,
  dispatchAdverseAlerts,
  notifyUser,
};
