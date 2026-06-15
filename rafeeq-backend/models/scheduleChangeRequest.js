const mongoose = require("mongoose");

const workDaySchema = new mongoose.Schema(
  {
    dayOfWeek: { type: Number, min: 0, max: 6 },
    dayName: { type: String, default: "" },
    startTime: { type: String, default: "09:00" },
    endTime: { type: String, default: "17:00" },
    breaks: [
      {
        start: { type: String, default: "12:00" },
        end: { type: String, default: "13:00" },
      },
    ],
  },
  { _id: false }
);

const scheduleChangeRequestSchema = new mongoose.Schema(
  {
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      required: true,
      index: true,
    },
    doctorUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    doctorDisplayName: { type: String, default: "" },
    /** Mon–Sun map: { Mon: { enabled, start, end }, ... } */
    dynamicSchedule: { type: mongoose.Schema.Types.Mixed, default: () => ({}) },
    proposedSchedule: { type: [workDaySchema], default: [] },
    /** Alias stored for API payloads using requestedHours */
    requestedHours: { type: [workDaySchema], default: [] },
    workingHours: {
      start: { type: String, default: "09:00" },
      end: { type: String, default: "17:00" },
    },
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
      index: true,
    },
    reviewedByAdminUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    reviewedAt: { type: Date, default: null },
    rejectionReason: { type: String, default: "" },
  },
  { timestamps: true }
);

scheduleChangeRequestSchema.index({ orgId: 1, status: 1, createdAt: -1 });
scheduleChangeRequestSchema.index(
  { doctorUserId: 1, status: 1 },
  { partialFilterExpression: { status: "pending" } }
);

module.exports = mongoose.model("ScheduleChangeRequests", scheduleChangeRequestSchema);
