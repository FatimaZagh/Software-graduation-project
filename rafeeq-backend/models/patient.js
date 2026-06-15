const mongoose = require("mongoose");

const patientSchema = new mongoose.Schema({
  orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
  clinicId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic", index: true, default: null },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "users",
    required: true,
    unique: true,
  },
  fullName: { type: String, required: true },
  email: { type: String, default: "" },
  phone: { type: String, default: "" },
  bloodType: { type: String, default: "" },
  weightKg: { type: Number, default: null },
  /** Height in cm (optional; mirrors medical profile). */
  heightCm: { type: Number, default: null },
  /** Human-readable label for dashboard, e.g. "2 days ago" */
  lastCheckupLabel: { type: String, default: "" },
  defaultBranch: { type: String, default: "Rafeeq Clinic — Main Branch" },
  address: { type: String, default: "" },
  gender: { type: String, default: "" },
  age: { type: Number, default: null },
  /** Base64 data URL or raw base64 for profile photo (keep images reasonably small). */
  profileImage: { type: String, default: "" },
});

module.exports = mongoose.model("Patient", patientSchema);
