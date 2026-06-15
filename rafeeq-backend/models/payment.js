const mongoose = require("mongoose");
const crypto = require("crypto");

const paymentSchema = new mongoose.Schema(
  {
    transactionId: {
      type: String,
      unique: true,
      sparse: true,
      default: () => `TXN-${Date.now()}-${crypto.randomBytes(4).toString("hex").toUpperCase()}`,
    },
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
    clinicId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic", index: true, required: false },
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    doctorUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", index: true, default: null },
    appointmentId: { type: mongoose.Schema.Types.ObjectId, ref: "Appointment", default: null },
    amount: { type: Number, required: true },
    currency: { type: String, default: "ILS" },
    serviceType: {
      type: String,
      enum: ["Consultation", "Pharmacy", "Other"],
      default: "Other",
      index: true,
    },
    /** @deprecated use serviceType — kept for legacy readers */
    type: { type: String, default: "" },
    description: { type: String, default: "" },
    medicationName: { type: String, default: "" },
    orderId: { type: String, default: "", index: true },
    cardLastFour: { type: String, default: "" },
    status: { type: String, enum: ["Paid", "Pending", "Failed"], default: "Paid", index: true },
    settlementStatus: {
      type: String,
      enum: ["Unsettled", "Settled"],
      default: "Unsettled",
      index: true,
    },
    payrollSlipId: { type: mongoose.Schema.Types.ObjectId, ref: "PayrollSlip", default: null },
    paidAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

paymentSchema.pre("validate", function syncTypeField() {
  if (this.serviceType && !this.type) this.type = this.serviceType;
  if (this.type && !this.serviceType) {
    const t = String(this.type);
    if (t === "Consultation" || t === "Pharmacy") this.serviceType = t;
  }
});

module.exports = mongoose.model("Payment", paymentSchema);
