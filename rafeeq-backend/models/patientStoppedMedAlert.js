const mongoose = require("mongoose");

/** Persistent home-screen alert until patient acknowledges a doctor stop. */
const patientStoppedMedAlertSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    patientMedicationId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "PatientMedication",
      required: true,
    },
    medicationName: { type: String, required: true, trim: true },
    stoppedAt: { type: Date, default: Date.now },
    stoppedByDoctorId: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
    acknowledged: { type: Boolean, default: false, index: true },
    acknowledgedAt: { type: Date },
  },
  { timestamps: true }
);

patientStoppedMedAlertSchema.index({ patientUserId: 1, acknowledged: 1, stoppedAt: -1 });

module.exports = mongoose.model("PatientStoppedMedAlert", patientStoppedMedAlertSchema);
