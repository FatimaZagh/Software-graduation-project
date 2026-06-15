const PatientMedication = require("../models/patientMedication");
const PatientStoppedMedAlert = require("../models/patientStoppedMedAlert");
const PatientNotification = require("../models/patientNotification");

function str(v) {
  return String(v ?? "").trim();
}

/**
 * Mark a patient medication Stopped and create a persistent home alert (if not already pending).
 */
async function stopPatientMedicationRecord({
  patientUserId,
  medId,
  doctorUserId,
  reason,
  adverseReportId,
}) {
  const med = await PatientMedication.findOne({ _id: medId, patientUserId });
  if (!med) return null;
  if (med.status === "Stopped") return med.toObject();

  const stopNote = str(reason) || "Stopped by physician.";
  med.status = "Stopped";
  med.active = false;
  med.stoppedAt = new Date();
  med.stoppedByDoctorId = doctorUserId || undefined;
  med.notes = `${med.notes || ""}\n[STOP ${new Date().toISOString().slice(0, 10)}] ${stopNote}`.trim();
  await med.save();

  const existingAlert = await PatientStoppedMedAlert.findOne({
    patientUserId,
    patientMedicationId: medId,
    acknowledged: false,
  }).lean();

  if (!existingAlert) {
    await PatientStoppedMedAlert.create({
      patientUserId,
      patientMedicationId: medId,
      medicationName: med.medicationName,
      stoppedAt: med.stoppedAt,
      stoppedByDoctorId: doctorUserId || undefined,
      acknowledged: false,
    });
  }

  await PatientNotification.create({
    patientUserId,
    type: "medication_stopped_by_doctor",
    title: "تم إيقاف هذا الدواء بواسطة الطبيب",
    body: `تم إيقاف ${med.medicationName} بواسطة الطبيب. لا تتناوله حتى يتم مراجعة خطتك العلاجية.`,
    read: false,
    meta: {
      patientMedicationId: String(medId),
      doctorUserId: doctorUserId ? String(doctorUserId) : undefined,
      adverseReportId: adverseReportId ? String(adverseReportId) : undefined,
    },
  });

  return med.toObject();
}

/** Mongo filter: only medications visible on "My Medications". */
function activeMedicationFilter(patientUserId) {
  return {
    patientUserId,
    status: { $ne: "Stopped" },
    active: true,
  };
}

module.exports = {
  stopPatientMedicationRecord,
  activeMedicationFilter,
};
