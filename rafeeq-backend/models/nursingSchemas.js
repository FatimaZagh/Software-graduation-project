const mongoose = require("mongoose");

const vitalsTimelineEntrySchema = new mongoose.Schema(
  {
    bloodPressure: { type: String, default: "" },
    temperature: { type: Number, default: null },
    weight: { type: Number, default: null },
    height: { type: Number, default: null },
    pulse: { type: Number, default: null },
    oxygenSaturation: { type: Number, default: null },
    bloodSugar: { type: Number, default: null },
    recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    visitId: { type: mongoose.Schema.Types.ObjectId, ref: "Appointment", default: null },
    createdAt: { type: Date, default: () => new Date() },
  },
  { _id: true }
);

const medicationAdministrationSchema = new mongoose.Schema(
  {
    medicationName: { type: String, required: true, trim: true },
    dosage: { type: String, default: "" },
    administeredAt: { type: Date, default: () => new Date() },
    administeredBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true },
    visitId: { type: mongoose.Schema.Types.ObjectId, ref: "Appointment", default: null },
    adverseReaction: { type: String, default: "" },
    notes: { type: String, default: "" },
  },
  { _id: true }
);

const nursingNoteSchema = new mongoose.Schema(
  {
    visitId: { type: mongoose.Schema.Types.ObjectId, ref: "Appointment", default: null },
    noteType: {
      type: String,
      enum: ["initial_symptoms", "shift_log", "doctor_alert", "observation"],
      default: "observation",
    },
    body: { type: String, default: "" },
    urgentForDoctor: { type: Boolean, default: false },
    authorId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true },
    visibleToDoctorOnly: { type: Boolean, default: false },
    createdAt: { type: Date, default: () => new Date() },
  },
  { _id: true }
);

module.exports = {
  vitalsTimelineEntrySchema,
  medicationAdministrationSchema,
  nursingNoteSchema,
};
