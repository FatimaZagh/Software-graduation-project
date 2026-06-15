const mongoose = require("mongoose");

const attachmentSchema = new mongoose.Schema(
  {
    fileUrl: { type: String, default: "" },
    fileName: { type: String, default: "" },
    mimeType: { type: String, default: "" },
    uploadedAt: { type: Date, default: () => new Date() },
    uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
  },
  { _id: false }
);

const labRequestSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    clinicId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic", default: null, index: true },
    patientUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    visitId: { type: mongoose.Schema.Types.ObjectId, ref: "Appointment", default: null },
    testName: { type: String, required: true, trim: true },
    notes: { type: String, default: "" },
    doctorUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", index: true },
    requestedBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true },
    testType: { type: String, default: "Blood" },
    resultUrls: { type: [String], default: [] },
    resultAnalysis: { type: String, default: "" },
    attachment: { type: attachmentSchema, default: () => ({}) },
    isReadByDoctor: { type: Boolean, default: false, index: true },
    readByDoctorAt: { type: Date, default: null },
    isLocked: { type: Boolean, default: false },
    completedAt: { type: Date, default: null },
    submittedBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    status: {
      type: String,
      enum: ["Requested", "Sample-Collected", "Completed"],
      default: "Requested",
      index: true,
    },
    resultImages: {
      type: [
        {
          fileUrl: { type: String, default: "" },
          uploadedAt: { type: Date, default: () => new Date() },
          uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
        },
      ],
      default: [],
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("LabRequest", labRequestSchema);
