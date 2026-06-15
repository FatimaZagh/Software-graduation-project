const mongoose = require("mongoose");

const patientMedicationPurchaseSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      index: true,
    },
    drugId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Drug",
      required: true,
    },
    drugName: { type: String, required: true, trim: true },
    dosage: { type: String, default: "" },
    quantity: { type: Number, required: true, min: 1 },
    pharmacyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Pharmacy",
      default: null,
    },
    pharmacyName: { type: String, default: "" },
    pharmacyType: {
      type: String,
      enum: ["Internal", "External"],
      default: "External",
    },
    requiresPrescription: { type: Boolean, default: false },
    prescribingDoctorName: { type: String, default: "" },
    prescriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "DispensingPrescription",
      default: null,
    },
    source: {
      type: String,
      enum: ["patient_purchase", "pharmacy_dispense", "pharmacist_fulfillment"],
      default: "patient_purchase",
    },
  },
  { timestamps: true, collection: "patient_medication_purchases" }
);

patientMedicationPurchaseSchema.index({ patientUserId: 1, createdAt: -1 });

module.exports = mongoose.model("PatientMedicationPurchase", patientMedicationPurchaseSchema);
