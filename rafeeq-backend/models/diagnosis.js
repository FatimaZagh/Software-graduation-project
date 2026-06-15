const mongoose = require("mongoose");

const diagnosisSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    doctorUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    patientUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    appointmentId: { type: mongoose.Schema.Types.ObjectId, ref: "Appointment", default: null },
    condition: { type: String, required: true, trim: true },
    severity: {
      type: String,
      enum: ["Mild", "Moderate", "Severe", "Critical"],
      default: "Moderate",
    },
    symptoms: { type: [String], default: [] },
    treatmentPlan: { type: String, default: "" },
    notes: { type: String, default: "" },
    active: { type: Boolean, default: true, index: true },
  },
  { timestamps: true }
);

diagnosisSchema.index({ patientUserId: 1, active: 1, createdAt: -1 });

module.exports = mongoose.model("Diagnosis", diagnosisSchema);
