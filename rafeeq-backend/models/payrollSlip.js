const mongoose = require("mongoose");

const payrollSlipSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    doctorUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    doctorName: { type: String, default: "" },
    periodStart: { type: Date, required: true },
    periodEnd: { type: Date, required: true },
    grossEarned: { type: Number, required: true },
    commissionRate: { type: Number, required: true },
    clinicShare: { type: Number, required: true },
    pharmacyRevenue: { type: Number, default: 0 },
    netPayout: { type: Number, required: true },
    currency: { type: String, default: "ILS" },
    transactionIds: [{ type: mongoose.Schema.Types.ObjectId, ref: "Payment" }],
    status: { type: String, enum: ["Generated", "Paid"], default: "Generated", index: true },
    generatedBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model("PayrollSlip", payrollSlipSchema);
