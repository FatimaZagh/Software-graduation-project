const mongoose = require("mongoose");

const invoiceSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    patientUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    amount: { type: Number, required: true },
    status: { type: String, enum: ["Paid", "Pending"], default: "Pending", index: true },
    insuranceCompany: { type: String, default: "" },
    discountApplied: { type: Number, default: 0 },
    paymentMethod: { type: String, default: "" },
    description: { type: String, default: "" },
    dueDate: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Invoice", invoiceSchema);
