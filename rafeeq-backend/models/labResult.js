const mongoose = require("mongoose");

const labResultSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    title: { type: String, required: true },
    mimeType: { type: String, default: "application/pdf" },
    /** Store small PDF/image as base64; for large files use external storage in production */
    fileBase64: { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("LabResult", labResultSchema);
