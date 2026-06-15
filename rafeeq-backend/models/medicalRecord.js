const mongoose = require("mongoose");

const prescriptionItemSchema = new mongoose.Schema(
  {
    name: String,
    dosage: String,
    frequency: String,
  },
  { _id: false }
);

const medicalRecordSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
    appointmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      required: true,
    },
    diagnosis: { type: String, default: "" },
    prescription: { type: [prescriptionItemSchema], default: [] },
    notes: { type: String, default: "" },
    invoiceId: { type: mongoose.Schema.Types.ObjectId, ref: "Invoice", default: null },
    insuranceStatus: { type: String, default: "" },
    adminWorkflowLogs: {
      type: [
        {
          at: { type: Date, default: Date.now },
          byUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
          note: { type: String, default: "" },
        },
      ],
      default: [],
    },
    visibilityAccess: { type: [String], default: [] },
  },
  { timestamps: true }
);

module.exports = mongoose.model("MedicalRecord", medicalRecordSchema);
