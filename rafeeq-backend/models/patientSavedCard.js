const mongoose = require("mongoose");

const patientSavedCardSchema = new mongoose.Schema(
  {
    patientUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    cardholderName: { type: String, required: true, trim: true },
    expirationDate: { type: String, required: true, trim: true },
    maskedCardNumber: { type: String, required: true, trim: true },
    cardLastFour: { type: String, required: true, trim: true },
    /** SHA-256 fingerprint — used for dedup; never store full PAN or CVV. */
    cardFingerprint: { type: String, required: true, index: true },
  },
  { timestamps: true }
);

patientSavedCardSchema.index({ patientUserId: 1, cardFingerprint: 1 }, { unique: true });

module.exports = mongoose.model("PatientSavedCard", patientSavedCardSchema);
