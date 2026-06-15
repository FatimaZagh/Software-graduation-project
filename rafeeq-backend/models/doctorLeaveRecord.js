const mongoose = require("mongoose");

const LEAVE_TYPES = [
  "Annual Leave",
  "Sick Leave",
  "Short Permission / Emergency Leave",
];

/** Legacy doctor-only leave records (collection: doctorleaverequests). */
const doctorLeaveRecordSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true },
    doctorUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    doctorId: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
    clinicId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic" },
    type: {
      type: String,
      enum: LEAVE_TYPES,
      default: "Annual Leave",
    },
    fromDate: { type: String, required: true },
    toDate: { type: String, required: true },
    startDate: { type: String },
    endDate: { type: String },
    reason: { type: String, default: "" },
    status: {
      type: String,
      enum: ["pending", "Pending", "approved", "Approved", "rejected", "Rejected"],
      default: "pending",
      index: true,
    },
    decidedByAdminUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
    decidedAt: { type: Date },
  },
  { timestamps: true }
);

doctorLeaveRecordSchema.pre("validate", function syncDates() {
  if (this.startDate && !this.fromDate) this.fromDate = this.startDate;
  if (this.endDate && !this.toDate) this.toDate = this.endDate;
  if (this.fromDate && !this.startDate) this.startDate = this.fromDate;
  if (this.toDate && !this.endDate) this.endDate = this.toDate;
  if (this.doctorUserId && !this.doctorId) this.doctorId = this.doctorUserId;
});

doctorLeaveRecordSchema.index({ orgId: 1, status: 1, createdAt: -1 });

module.exports = mongoose.model("DoctorLeaveRecord", doctorLeaveRecordSchema, "doctorleaverequests");
