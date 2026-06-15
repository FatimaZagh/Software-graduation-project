const mongoose = require("mongoose");

const waitingListEntrySchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    doctorUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      index: true,
    },
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      index: true,
    },
    clinicId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Clinic",
      index: true,
    },
    /** Composite key: doctorUserId|YYYY-MM-DD|HH:mm */
    slotId: { type: String, default: "", index: true },
    preferredDate: { type: String, default: "" },
    preferredTime: { type: String, default: "" },
    watchSlotDate: { type: String, default: "" },
    watchSlotTime: { type: String, default: "" },
    status: {
      type: String,
      enum: ["Active", "Promoted", "Cancelled"],
      default: "Active",
    },
    promotedAppointmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      default: null,
    },
    notes: { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("WaitingListEntry", waitingListEntrySchema);
