const mongoose = require("mongoose");

const attachmentSchema = new mongoose.Schema(
  {
    fileName: { type: String, default: "attachment" },
    mimeType: { type: String, default: "application/octet-stream" },
    dataBase64: { type: String, default: "" },
  },
  { _id: false }
);

const clinicSessionSchema = new mongoose.Schema(
  {
    appointmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      required: true,
      index: true,
    },
    doctorUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
    },
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      default: null,
    },
    diagnosis: { type: String, default: "" },
    notes: { type: String, default: "" },
    vitals: {
      weightKg: { type: Number, default: null },
      bpSystolic: { type: Number, default: null },
      bpDiastolic: { type: Number, default: null },
      heartRate: { type: Number, default: null },
      temperatureC: { type: Number, default: null },
    },
    attachments: { type: [attachmentSchema], default: [] },
    startedAt: { type: Date, default: null },
    endedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model("ClinicSession", clinicSessionSchema);
