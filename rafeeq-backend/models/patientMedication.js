const mongoose = require("mongoose");

const patientMedicationSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    prescribingDoctorUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      index: true,
    },
    medicationName: { type: String, required: true },
    dosage: { type: String, default: "" },
    frequency: { type: String, default: "" },
    prescribedBy: { type: String, default: "" },
    /** Legacy record timestamp; patient course start uses startDate. */
    startedAt: { type: Date },
    /** Set when patient confirms first dose (toggle ON). Null until then. */
    startDate: { type: Date, default: null },
    /** Course length in days (set by prescribing doctor). */
    durationInDays: { type: Number, default: 30, min: 1 },
    notes: { type: String, default: "" },
    status: {
      type: String,
      enum: ["Active", "Stopped", "Expired"],
      default: "Active",
      index: true,
    },
    active: { type: Boolean, default: false },
    stoppedAt: { type: Date },
    stoppedByDoctorId: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
    expiredAt: { type: Date },
  },
  { timestamps: true }
);

module.exports = mongoose.model("PatientMedication", patientMedicationSchema);
