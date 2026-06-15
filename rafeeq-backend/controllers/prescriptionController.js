const mongoose = require("mongoose");
const PatientMedication = require("../models/patientMedication");
const PatientStoppedMedAlert = require("../models/patientStoppedMedAlert");
const User = require("../models/User");
const {
  loadPatientMedicationsWithLifecycle,
  startPatientMedication,
} = require("../services/medicationLifecycle");

async function assertPatient(patientUserId) {
  if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
    return { error: { status: 400, message: "Invalid patient id" } };
  }
  const user = await User.findById(patientUserId).lean();
  if (!user || user.role !== "Patient") {
    return { error: { status: 404, message: "Patient not found" } };
  }
  return { user };
}

/**
 * GET /api/patients/:id/medications
 * Returns { active, completed } with auto-expiration applied.
 */
exports.getActiveMedications = async (req, res) => {
  try {
    const patientUserId = req.params.id || req.params.patientUserId;
    const check = await assertPatient(patientUserId);
    if (check.error) return res.status(check.error.status).json({ message: check.error.message });

    const any = await PatientMedication.countDocuments({ patientUserId });
    if (any === 0) {
      const { parseDurationInDays } = require("../services/medicationLifecycle");
      await PatientMedication.insertMany([
        {
          patientUserId,
          medicationName: "Vitamin D3",
          dosage: "1000 IU",
          frequency: "Once daily",
          prescribedBy: "Dr. Ahmed Hassan",
          notes: "Sample entry — replace with your real prescriptions.",
          status: "Active",
          active: false,
          startDate: null,
          durationInDays: 30,
        },
      ]);
    }

    const { active, completed } = await loadPatientMedicationsWithLifecycle(patientUserId);
    res.json({ active, completed });
  } catch (e) {
    console.error("getActiveMedications:", e);
    res.status(500).json({ message: "Error loading medications" });
  }
};

/**
 * POST /api/patients/:id/medications/:medId/start
 * POST /api/prescriptions/:medId/start  (body: { patientUserId })
 */
exports.startMedication = async (req, res) => {
  try {
    const medId = req.params.medId || req.params.id;
    const patientUserId = req.params.medId
      ? req.params.id
      : req.body?.patientUserId;

    if (!mongoose.Types.ObjectId.isValid(medId)) {
      return res.status(400).json({ message: "Invalid medication id" });
    }
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({
        message: "patientUserId is required (path or body for /api/prescriptions/:id/start)",
      });
    }

    const check = await assertPatient(patientUserId);
    if (check.error) return res.status(check.error.status).json({ message: check.error.message });

    const result = await startPatientMedication(patientUserId, medId);
    if (result.error) {
      return res.status(result.error.status).json({ message: result.error.message });
    }

    res.json({
      medication: result.medication,
      message: result.alreadyStarted
        ? "Medication already started"
        : "Medication course started",
    });
  } catch (e) {
    console.error("startMedication:", e);
    res.status(500).json({ message: e.message || "Error starting medication" });
  }
};

/**
 * GET /api/patients/:id/stopped-medication-alerts
 */
exports.getStoppedMedicationAlerts = async (req, res) => {
  try {
    const patientUserId =
      req.params.id || req.params.patientUserId || req.query.patientUserId;
    const check = await assertPatient(patientUserId);
    if (check.error) return res.status(check.error.status).json({ message: check.error.message });

    const alerts = await PatientStoppedMedAlert.find({
      patientUserId,
      acknowledged: false,
    })
      .sort({ stoppedAt: -1 })
      .lean();

    res.json(alerts);
  } catch (e) {
    console.error("getStoppedMedicationAlerts:", e);
    res.status(500).json({ message: "Error loading stopped medication alerts" });
  }
};

/**
 * POST /api/patients/:id/stopped-medication-alerts/:alertId/acknowledge
 */
exports.acknowledgeStoppedAlert = async (req, res) => {
  try {
    const patientUserId = req.params.id || req.params.patientUserId;
    const { alertId } = req.params;
    const check = await assertPatient(patientUserId);
    if (check.error) return res.status(check.error.status).json({ message: check.error.message });

    if (!mongoose.Types.ObjectId.isValid(alertId)) {
      return res.status(400).json({ message: "Invalid alert id" });
    }

    const alert = await PatientStoppedMedAlert.findOneAndUpdate(
      { _id: alertId, patientUserId, acknowledged: false },
      { $set: { acknowledged: true, acknowledgedAt: new Date() } },
      { new: true }
    ).lean();

    if (!alert) return res.status(404).json({ message: "Alert not found or already dismissed" });

    res.json({ alert, message: "Acknowledgment recorded." });
  } catch (e) {
    console.error("acknowledgeStoppedAlert:", e);
    res.status(500).json({ message: "Error recording acknowledgment" });
  }
};
