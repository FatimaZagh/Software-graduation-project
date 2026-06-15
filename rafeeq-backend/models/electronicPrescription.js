const mongoose = require("mongoose");

const rxItemSchema = new mongoose.Schema(
  {
    name: String,
    dosage: String,
    frequency: String,
    duration: { type: String, default: "" },
    instructions: { type: String, default: "" },
  },
  { _id: false }
);

const electronicPrescriptionSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    doctorUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: false,
    },
    appointmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      required: false,
    },
    doctorName: { type: String, default: "" },
    items: { type: [rxItemSchema], default: [] },
    /** PNG/JPEG as base64 data URL or raw base64 (keep small for demo) */
    signatureImageBase64: { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("ElectronicPrescription", electronicPrescriptionSchema);
