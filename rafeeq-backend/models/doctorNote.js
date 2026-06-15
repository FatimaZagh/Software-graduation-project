const mongoose = require("mongoose");

const doctorNoteSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    doctorUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    patientUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    appointmentId: { type: mongoose.Schema.Types.ObjectId, ref: "Appointment", default: null },
    noteType: {
      type: String,
      enum: ["clinical", "followup", "post_visit", "general"],
      default: "clinical",
    },
    body: { type: String, required: true, trim: true },
    active: { type: Boolean, default: true, index: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model("DoctorNote", doctorNoteSchema);
