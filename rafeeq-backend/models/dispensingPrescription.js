const mongoose = require("mongoose");

const PRESCRIPTION_STATUS = ["Active", "Completed", "Expired", "Cancelled"];

const dispensingPrescriptionSchema = new mongoose.Schema(
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
    doctorDisplayName: { type: String, default: "" },
    patientDisplayName: { type: String, default: "" },
    prescriptionCode: { type: String, trim: true, index: true },
    electronicSignature: { type: String, default: "" },
    issueDate: { type: Date, required: true, default: () => new Date() },
    expiryDate: { type: Date, required: true, index: true },
    status: {
      type: String,
      enum: PRESCRIPTION_STATUS,
      default: "Active",
      index: true,
    },
    appointmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      default: null,
    },
  },
  { timestamps: true, collection: "dispensing_prescriptions" }
);

dispensingPrescriptionSchema.index({ patientUserId: 1, status: 1, expiryDate: 1 });

module.exports = mongoose.model("DispensingPrescription", dispensingPrescriptionSchema);
module.exports.PRESCRIPTION_STATUS = PRESCRIPTION_STATUS;
