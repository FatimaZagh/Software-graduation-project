const mongoose = require("mongoose");

const TRANSACTION_STATUSES = ["Pending", "Mock Processing", "Paid", "Failed"];

const pharmacyOrderTransactionSchema = new mongoose.Schema(
  {
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MedicationRequest",
      required: true,
      index: true,
    },
    pharmacyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Pharmacy",
      required: true,
      index: true,
    },
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: false,
      index: true,
    },
    amount: { type: Number, required: true, min: 0 },
    currency: { type: String, default: "ILS" },
    status: {
      type: String,
      enum: TRANSACTION_STATUSES,
      default: "Pending",
      index: true,
    },
    cardLastFour: { type: String, default: "4242", trim: true },
    failureReason: { type: String, default: "" },
  },
  { timestamps: true, collection: "pharmacy_order_transactions" }
);

pharmacyOrderTransactionSchema.index({ pharmacyId: 1, createdAt: -1 });

module.exports = mongoose.model("PharmacyOrderTransaction", pharmacyOrderTransactionSchema);
module.exports.TRANSACTION_STATUSES = TRANSACTION_STATUSES;
