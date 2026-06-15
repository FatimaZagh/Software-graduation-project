const mongoose = require("mongoose");

const documentsSchema = new mongoose.Schema(
  {
    idCardUrl: { type: String, default: "" },
    medicalLicenseUrl: { type: String, default: "" },
    certificatesUrl: { type: String, default: "" },
    cvUrl: { type: String, default: "" },
  },
  { _id: false }
);

const pharmacyProfileSchema = new mongoose.Schema(
  {
    pharmacyName: { type: String, default: "" },
    address: { type: String, default: "" },
    city: { type: String, default: "" },
    licenseNumber: { type: String, default: "" },
    operatingHours: { type: String, default: "" },
    is24Hours: { type: Boolean, default: false },
    licenseImage: { type: String, default: "" },
    latitude: { type: Number, default: null },
    longitude: { type: Number, default: null },
    phone: { type: String, default: "" },
    pharmacyType: { type: String, enum: ["Internal", "External"], default: "External" },
  },
  { _id: false }
);

const doctorProfileSchema = new mongoose.Schema(
  {
    fullName: { type: String, default: "" },
    phone: { type: String, default: "" },
    gender: { type: String, default: "" },
    birthDate: { type: Date, default: null },
    residentialAddress: { type: String, default: "" },
    nationality: { type: String, default: "" },
    specialty: { type: String, default: "" },
    yearsOfExperience: { type: Number, default: 0 },
    licenseNumber: { type: String, default: "" },
    qualifications: { type: [String], default: [] },
    education: { type: String, default: "" },
    currentClinic: { type: String, default: "" },
    bio: { type: String, default: "" },
    consultationFee: { type: Number, default: 0 },
    workingDays: { type: [String], default: [] },
    workingHours: {
      start: { type: String, default: "09:00" },
      end: { type: String, default: "17:00" },
    },
    dynamicSchedule: { type: mongoose.Schema.Types.Mixed, default: () => ({}) },
    workSchedule: { type: [mongoose.Schema.Types.Mixed], default: [] },
    languages: { type: [String], default: [] },
    sessionType: {
      type: String,
      enum: ["In-person", "Online", "Both"],
      default: "In-person",
    },
    documents: { type: documentsSchema, default: () => ({}) },
  },
  { _id: false }
);

const registrationRequestSchema = new mongoose.Schema(
  {
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      required: true,
      index: true,
    },
    clinicId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic", index: true },
    doctorClinicId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic", index: true },
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
      index: true,
    },
    role: {
      type: String,
      enum: ["Doctor", "Nurse", "Lab Technician", "Radiologist", "Pharmacist", "Intern/Trainee", "Staff/Operations"],
      required: true,
      index: true,
    },

    name: { type: String, default: "" },
    email: { type: String, default: "", index: true },
    password: { type: String, default: "", select: false },
    passwordHash: { type: String, default: "", select: false },
    profileImageUrl: { type: String, default: "" },
    phone: { type: String, default: "" },

    doctorProfile: { type: doctorProfileSchema, default: () => ({}) },
    pharmacyProfile: { type: pharmacyProfileSchema, default: () => ({}) },

    doctorSpecialization: { type: String, default: "" },
    doctorYearsExperience: { type: Number, default: 0 },
    doctorCertificatesBase64: { type: [String], default: [] },
    doctorSignatureBase64: { type: String, default: "" },
  },
  { timestamps: true }
);

registrationRequestSchema.index({ orgId: 1, status: 1, createdAt: -1 });
registrationRequestSchema.index(
  { "doctorProfile.licenseNumber": 1 },
  { unique: true, sparse: true, partialFilterExpression: { "doctorProfile.licenseNumber": { $type: "string", $ne: "" } } }
);

module.exports = mongoose.model("RegistrationRequests", registrationRequestSchema);
