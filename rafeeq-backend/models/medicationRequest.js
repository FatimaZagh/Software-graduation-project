const mongoose = require("mongoose");

const REQUEST_STATUSES = [
  "Pending",
  "Paid",
  "Failed",
  "Rejected",
  "Approved",
  "Dispensed",
  "Partially Fulfilled",
  "Backorder",
];

const LINE_ITEM_STATUSES = ["Paid", "Fulfilled", "Backorder", "Awaiting Stock"];

const orderLineItemSchema = new mongoose.Schema(
  {
    lineType: { type: String, enum: ["Fulfilled", "Backorder"], required: true },
    quantity: { type: Number, required: true, min: 1 },
    status: { type: String, enum: LINE_ITEM_STATUSES, required: true },
    amount: { type: Number, default: 0, min: 0 },
  },
  { _id: true }
);

const medicationRequestSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    pharmacyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Pharmacy",
      required: true,
      index: true,
    },
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      required: false,
      index: true,
    },
    medicationName: { type: String, required: true },
    drugId: { type: mongoose.Schema.Types.ObjectId, ref: "Drug", default: null },
    quantity: { type: Number, default: 1 },
    requestedQuantity: { type: Number, default: null },
    fulfilledQuantity: { type: Number, default: 0 },
    backorderQuantity: { type: Number, default: 0 },
    lineItems: { type: [orderLineItemSchema], default: [] },
    status: {
      type: String,
      enum: REQUEST_STATUSES,
      default: "Pending",
      index: true,
    },
    amount: { type: Number, default: null, min: 0 },
    transactionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "PharmacyOrderTransaction",
      default: null,
    },
    cardLastFour: { type: String, default: "" },
    cardholderName: { type: String, default: "" },
    patientPaymentStatus: { type: String, default: "" },
    patientLocale: { type: String, default: "en" },
    paidAt: { type: Date, default: null },
    failureReason: { type: String, default: "" },
    notifyWhenInStock: { type: Boolean, default: false },
    notes: { type: String, default: "" },
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
    },
  },
  { timestamps: true }
);

medicationRequestSchema.index({ pharmacyId: 1, status: 1, createdAt: -1 });

module.exports = mongoose.model("MedicationRequest", medicationRequestSchema);
module.exports.REQUEST_STATUSES = REQUEST_STATUSES;
module.exports.LINE_ITEM_STATUSES = LINE_ITEM_STATUSES;
