const mongoose = require("mongoose");

/** One document per uploaded medical file (avoids 16MB BSON cap on parent profile). */
const patientMedicalFileSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
    fileUrl: { type: String, default: "" },
    fileType: { type: String, default: "" },
    originalName: { type: String, default: "" },
    uploadedAt: { type: Date, default: () => new Date() },
  },
  { timestamps: true }
);

module.exports = mongoose.model("PatientMedicalFile", patientMedicalFileSchema);
