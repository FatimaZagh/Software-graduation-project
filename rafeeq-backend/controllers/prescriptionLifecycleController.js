const mongoose = require("mongoose");
const PatientMedication = require("../models/patientMedication");
const AppointmentModel = require("../models/appointment");
const { stopPatientMedicationRecord } = require("../services/patientMedicationStop");

function str(v) {
  return String(v ?? "").trim();
}

async function assertDoctorMayEditMedication(doctorUserId, orgId, patientUserId, med) {
  if (!med) return false;
  if (med.prescribingDoctorUserId && String(med.prescribingDoctorUserId) === String(doctorUserId)) {
    return true;
  }
  const appt = await AppointmentModel.findOne({
    patientId: patientUserId,
    doctorUserId,
    orgId,
  })
    .select("_id")
    .lean();
  return Boolean(appt);
}

exports.assertDoctorMayEditMedication = assertDoctorMayEditMedication;

/**
 * POST /api/doctor/patient-medications/:id/stop
 * body: { patientUserId, reason?, adverseReportId? }
 */
exports.stopPatientMedication = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const orgId = req.doctorScope.orgId;
    const medId = req.params.id;
    const { patientUserId, reason, adverseReportId } = req.body || {};

    if (!mongoose.Types.ObjectId.isValid(medId) || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid medication or patient id" });
    }

    const med = await PatientMedication.findOne({ _id: medId, patientUserId }).lean();
    if (!med) return res.status(404).json({ message: "Medication not found" });

    const ok = await assertDoctorMayEditMedication(doctorUserId, orgId, patientUserId, med);
    if (!ok) return res.status(403).json({ message: "Not authorized to stop this medication" });

    const stopNote = str(reason) || "Stopped by physician (CDSS / ADR workflow).";
    const updated = await stopPatientMedicationRecord({
      patientUserId,
      medId,
      doctorUserId,
      reason: stopNote,
      adverseReportId,
    });
    if (!updated) return res.status(404).json({ message: "Medication not found" });

    res.json({ medication: updated, message: "Medication stopped and patient notified." });
  } catch (e) {
    console.error("stopPatientMedication:", e);
    res.status(500).json({ message: e.message || "Error stopping medication" });
  }
};

/**
 * POST /api/doctor/patient-medications/:id/modify
 * body: { patientUserId, dosage?, frequency?, notes? }
 */
exports.modifyPatientMedication = async (req, res) => {
  try {
    const doctorUserId = req.doctorScope.doctorUserId;
    const orgId = req.doctorScope.orgId;
    const medId = req.params.id;
    const { patientUserId, dosage, frequency, notes } = req.body || {};

    if (!mongoose.Types.ObjectId.isValid(medId) || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid medication or patient id" });
    }

    const med = await PatientMedication.findOne({ _id: medId, patientUserId }).lean();
    if (!med) return res.status(404).json({ message: "Medication not found" });

    const ok = await assertDoctorMayEditMedication(doctorUserId, orgId, patientUserId, med);
    if (!ok) return res.status(403).json({ message: "Not authorized to modify this medication" });

    const $set = {};
    if (dosage != null) $set.dosage = str(dosage);
    if (frequency != null) $set.frequency = str(frequency);
    const changeLine = `[MODIFY ${new Date().toISOString().slice(0, 10)} Dr] ${str(notes) || "Dosage/frequency updated."}`;
    $set.notes = `${med.notes || ""}\n${changeLine}`.trim();

    const updated = await PatientMedication.findOneAndUpdate(
      { _id: medId, patientUserId, status: "Active" },
      { $set },
      { new: true }
    ).lean();

    if (!updated) {
      return res.status(400).json({ message: "Medication is inactive or could not be updated" });
    }

    res.json({ medication: updated, message: "Medication updated." });
  } catch (e) {
    console.error("modifyPatientMedication:", e);
    res.status(500).json({ message: e.message || "Error modifying medication" });
  }
};
