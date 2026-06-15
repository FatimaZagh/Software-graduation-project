const mongoose = require("mongoose");

const appointmentSchema = new mongoose.Schema({
  orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
  patientName: { type: String, required: true },
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "users",
    required: false,
  },
  time: { type: String, required: true },
  date: { type: String, required: true },
  /** booked | Waiting | In Progress | Completed | cancelled_by_doctor | cancelled_by_patient | … */
  status: { type: String, default: "booked" },
  cancellationReason: { type: String, default: "" },
  cancellationNotes: { type: String, default: "" },
  cancelledAt: { type: Date, required: false },
  cancelledBy: { type: String, enum: ["", "doctor", "patient"], default: "" },
  /** Patient tapped reschedule on doctor-cancelled alert — hide from home upcoming. */
  cancelAlertDismissed: { type: Boolean, default: false },
  /** Nurse triage pipeline: Check-In → Forwarded-To-Doctor */
  nurseQueueStatus: {
    type: String,
    enum: ["", "Scheduled", "Checked-In", "Triaged", "Forwarded-To-Doctor"],
    default: "",
  },
  initialSymptoms: { type: String, default: "" },
  /** Doctor approval + cancellation lifecycle */
  bookingStatus: {
    type: String,
    enum: [
      "Pending",
      "Accepted",
      "Rejected",
      "reschedule_requested",
      "cancelled_by_doctor",
      "cancelled_by_patient",
    ],
    default: "Accepted",
  },
  doctorUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "users",
    required: false,
  },
  doctorName: { type: String, default: "" },
  branch: { type: String, default: "" },
  clinicId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Clinic",
    required: false,
  },
  /** Auto-promoted from waitlist when a slot opened (FIFO). */
  promotedFromWaitlist: { type: Boolean, default: false },
  /** Doctor-approved second patient in the same time slot. */
  isForceAccepted: { type: Boolean, default: false },
});

module.exports = mongoose.model("Appointment", appointmentSchema);
