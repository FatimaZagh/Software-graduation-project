const mongoose = require("mongoose");

const workDaySchema = new mongoose.Schema(
  {
    dayOfWeek: { type: Number, min: 0, max: 6, required: false },
    dayName: { type: String, default: "" },
    startTime: { type: String, default: "09:00" },
    endTime: { type: String, default: "17:00" },
    breaks: [
      {
        start: { type: String, default: "12:00" },
        end: { type: String, default: "13:00" },
      },
    ],
  },
  { _id: false }
);

const documentsSchema = new mongoose.Schema(
  {
    idCardUrl: { type: String, default: "" },
    medicalLicenseUrl: { type: String, default: "" },
    certificatesUrl: { type: String, default: "" },
    cvUrl: { type: String, default: "" },
  },
  { _id: false }
);

const doctorSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true },
    clinicId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic", index: true },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      unique: true,
    },
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "approved",
      index: true,
    },

    fullName: { type: String, default: "" },
    email: { type: String, default: "" },
    phone: { type: String, default: "" },
    passwordHash: { type: String, default: "", select: false },

    gender: { type: String, default: "" },
    birthDate: { type: Date, default: null },
    residentialAddress: { type: String, default: "" },
    nationality: { type: String, default: "" },

    specialty: { type: String, default: "" },
    specialization: { type: String, default: "" },
    yearsOfExperience: { type: Number, default: 0 },
    yearsExperience: { type: Number, default: 0 },
    licenseNumber: { type: String, default: "" },
    qualifications: { type: [String], default: [] },
    education: { type: String, default: "" },
    currentClinic: { type: String, default: "" },
    bio: { type: String, default: "" },

    consultationFee: { type: Number, default: 100 },
    /** Active clinic & services billing configuration */
    clinicServicesConfig: {
      clinicName: { type: String, default: "" },
      consultationFee: { type: Number, default: 100 },
      specializedServices: [
        {
          key: { type: String, default: "" },
          name: { type: String, default: "" },
          price: { type: Number, default: 0, min: 0 },
          enabled: { type: Boolean, default: true },
        },
      ],
      updatedAt: { type: Date, default: null },
    },
    workingDays: { type: [String], default: [] },
    workingHours: {
      start: { type: String, default: "09:00" },
      end: { type: String, default: "17:00" },
    },
    languages: { type: [String], default: [] },
    sessionType: {
      type: String,
      enum: ["In-person", "Online", "Both"],
      default: "In-person",
    },
    availabilityStatus: {
      type: String,
      enum: ["Available", "Busy", "In Surgery", "Offline"],
      default: "Available",
      index: true,
    },
    specialtyAddons: { type: mongoose.Schema.Types.Mixed, default: () => ({}) },

    documents: { type: documentsSchema, default: () => ({}) },

    profileImageUrl: { type: String, default: "" },
    profileImageBase64: { type: String, default: "" },
    displayName: { type: String, default: "" },
    certifications: { type: [String], default: [] },
    certificateFilesBase64: { type: [String], default: [] },
    signatureImageBase64: { type: String, default: "" },
    workSchedule: { type: [workDaySchema], default: [] },
    dynamicSchedule: { type: mongoose.Schema.Types.Mixed, default: () => ({}) },
    bookingBlocklist: [
      {
        fromDate: { type: String, default: "" },
        toDate: { type: String, default: "" },
        type: { type: String, default: "Leave" },
        leaveRequestId: { type: mongoose.Schema.Types.ObjectId, ref: "LeaveRequest" },
      },
    ],
  },
  { timestamps: true }
);

doctorSchema.pre("validate", function syncLegacyFields() {
  if (this.specialty && !this.specialization) this.specialization = this.specialty;
  if (this.specialization && !this.specialty) this.specialty = this.specialization;
  if (this.yearsOfExperience != null && this.yearsExperience == null) {
    this.yearsExperience = this.yearsOfExperience;
  }
  if (this.yearsExperience != null && this.yearsOfExperience == null) {
    this.yearsOfExperience = this.yearsExperience;
  }
  if (this.fullName && !this.displayName) this.displayName = this.fullName;
});

doctorSchema.index({ orgId: 1, status: 1 });
doctorSchema.index({ licenseNumber: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model("Doctor", doctorSchema);
