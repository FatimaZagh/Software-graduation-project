const mongoose = require("mongoose");

const staffLeaveRequestSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    staffId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    type: { type: String, enum: ["Sick", "Annual", "Emergency"], required: true },
    fromDate: { type: String, required: true },
    toDate: { type: String, required: true },
    reason: { type: String, default: "" },
    status: { type: String, enum: ["Pending", "Approved", "Rejected"], default: "Pending", index: true },
    rejectionReason: { type: String, default: "" },
    decidedByAdminUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    decidedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model("StaffLeaveRequest", staffLeaveRequestSchema);
