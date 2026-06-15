const mongoose = require("mongoose");

const APPLICANT_ROLES = ["Doctor", "Patient", "Staff"];
const LEAVE_STATUSES = ["Pending", "Approved", "Rejected"];

const leaveRequestSchema = new mongoose.Schema(
  {
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      index: true,
      required: true,
    },
    clinicId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Clinic",
      index: true,
      default: null,
    },
    applicantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    applicantRole: {
      type: String,
      enum: APPLICANT_ROLES,
      required: true,
      index: true,
    },
    leaveType: {
      type: String,
      default: "Casual",
      trim: true,
    },
    reason: { type: String, default: "", trim: true },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    status: {
      type: String,
      enum: LEAVE_STATUSES,
      default: "Pending",
      index: true,
    },
    rejectionReason: { type: String, default: "" },
    decidedByAdminUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    decidedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

leaveRequestSchema.index({ orgId: 1, status: 1, createdAt: -1 });
leaveRequestSchema.index({ orgId: 1, clinicId: 1, status: 1, createdAt: -1 });
leaveRequestSchema.index({ applicantId: 1, createdAt: -1 });

module.exports = mongoose.model("LeaveRequest", leaveRequestSchema, "leaverequests");
