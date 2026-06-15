const mongoose = require("mongoose");

const ITEM_STATUS = ["Active", "Fully Dispensed"];

const dispensingPrescriptionItemSchema = new mongoose.Schema(
  {
    prescriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "DispensingPrescription",
      required: true,
      index: true,
    },
    drugId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Drug",
      required: true,
      index: true,
    },
    drugName: { type: String, required: true, trim: true },
    instructions: { type: String, default: "" },
    prescribedQuantity: { type: Number, required: true, min: 1 },
    dispensedQuantity: { type: Number, default: 0, min: 0 },
    remainingQuantity: { type: Number, required: true, min: 0 },
    itemStatus: {
      type: String,
      enum: ITEM_STATUS,
      default: "Active",
      index: true,
    },
  },
  { timestamps: true, collection: "dispensing_prescription_items" }
);

dispensingPrescriptionItemSchema.index({ prescriptionId: 1, drugId: 1 });

module.exports = mongoose.model("DispensingPrescriptionItem", dispensingPrescriptionItemSchema);
module.exports.ITEM_STATUS = ITEM_STATUS;
