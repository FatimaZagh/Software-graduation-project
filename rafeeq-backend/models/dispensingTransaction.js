const mongoose = require("mongoose");

const dispensingTransactionSchema = new mongoose.Schema(
  {
    prescriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "DispensingPrescription",
      default: null,
      index: true,
    },
    prescriptionItemId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "DispensingPrescriptionItem",
      default: null,
      index: true,
    },
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    pharmacyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Pharmacy",
      default: null,
      index: true,
    },
    drugId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Drug",
      required: true,
    },
    drugName: { type: String, default: "" },
    quantity: { type: Number, required: true, min: 1 },
    performedBy: { type: String, default: "" },
    source: { type: String, enum: ["patient_purchase", "pharmacy_dispense"], default: "patient_purchase" },
  },
  { timestamps: true, collection: "dispensing_transactions" }
);

module.exports = mongoose.model("DispensingTransaction", dispensingTransactionSchema);
