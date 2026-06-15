const mongoose = require("mongoose");

const doseLogSchema = new mongoose.Schema(
  {
    scheduledFor: { type: Date, required: true },
    takenAt: { type: Date, default: null },
    taken: { type: Boolean, default: false },
  },
  { _id: false }
);

const medicationReminderSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    medicineName: { type: String, required: true },
    doseTimes: { type: [String], default: [] },
    timezone: { type: String, default: "UTC" },
    doseLogs: { type: [doseLogSchema], default: [] },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model("MedicationReminder", medicationReminderSchema);
