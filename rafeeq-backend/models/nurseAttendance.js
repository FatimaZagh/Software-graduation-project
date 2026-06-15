const mongoose = require("mongoose");

const nurseAttendanceSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    nurseUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    dateYmd: { type: String, required: true, index: true },
    checkInAt: { type: Date, default: null },
    checkOutAt: { type: Date, default: null },
  },
  { timestamps: true }
);

nurseAttendanceSchema.index({ orgId: 1, nurseUserId: 1, dateYmd: 1 }, { unique: true });

module.exports = mongoose.model("NurseAttendance", nurseAttendanceSchema);
