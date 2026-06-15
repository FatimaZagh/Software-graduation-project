const mongoose = require("mongoose");

const rxLineSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    dosage: { type: String, default: "" },
    duration: { type: String, default: "" },
    durationInDays: { type: Number, min: 1 },
    instructions: { type: String, default: "" },
    frequency: { type: String, default: "" },
  },
  { _id: false }
);

const prescriptionSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true },
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    doctorUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    appointmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      default: null,
    },
    doctorDisplayName: { type: String, default: "" },
    medicationName: { type: String, default: "" },
    dosage: { type: String, default: "" },
    frequency: { type: String, default: "" },
    duration: { type: String, default: "" },
    durationInDays: { type: Number, min: 1 },
    startDate: { type: Date, default: null },
    instructions: { type: String, default: "" },
    status: {
      type: String,
      enum: ["Active", "Discontinued"],
      default: "Active",
      index: true,
    },
    discontinuedAt: { type: Date, default: null },
    discontinuedBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    items: { type: [rxLineSchema], default: [] },
    signatureImageBase64: { type: String, default: "" },
    syncedToPharmacy: { type: Boolean, default: false },
    syncedToPatientApp: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Prescription", prescriptionSchema);
