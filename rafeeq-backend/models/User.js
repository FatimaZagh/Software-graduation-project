const mongoose = require("mongoose");

const ALLOWED_ROLES = [
  "Organization Admin",
  "Doctor",
  "Nurse",
  "Lab Technician",
  "Radiologist",
  "Pharmacist",
  "InternalPharmacist",
  "Intern/Trainee",
  "Staff/Operations",
  "Patient",
];

const userSchema = new mongoose.Schema(
  {
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      required: false,
      index: true,
    },
    status: {
      type: String,
      enum: ["pending", "active"],
      default: "active",
      index: true,
    },
    name: { type: String, default: "" },
    email: { type: String, default: "", index: true },
    role: { type: String, enum: ALLOWED_ROLES, required: true, index: true },
    password: { type: String, default: "" },
    profileImageUrl: { type: String, default: "" },
    clinicId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Clinic",
      required: false,
    },
    phoneNumber: { type: String, default: "" },
    loginMethod: {
      type: String,
      enum: ["email", "google", "facebook"],
      default: "email",
      index: true,
    },
    gender: { type: String, default: "" },
    dateOfBirth: { type: Date, default: null },
    identityNumber: { type: String, default: "" },
    maritalStatus: { type: String, default: "" },
    googleId: { type: String, sparse: true, index: true },
    facebookId: { type: String, sparse: true, index: true },
    /** Patient prepaid balance for consultations and clinic services (ILS). */
    walletBalance: { type: Number, default: 5000, min: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.models.users || mongoose.model("users", userSchema);
module.exports.ALLOWED_ROLES = ALLOWED_ROLES;

