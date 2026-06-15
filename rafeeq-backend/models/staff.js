const mongoose = require("mongoose");

const EMERGENCY_CONTACT = new mongoose.Schema(
  {
    name: { type: String, default: "" },
    fullName: { type: String, default: "" },
    phone: { type: String, default: "" },
    relationship: { type: String, default: "" },
  },
  { _id: false }
);

const WORKING_DAY = new mongoose.Schema(
  {
    day: { type: String, default: "" },
    startTime: { type: String, default: "08:00" },
    endTime: { type: String, default: "17:00" },
  },
  { _id: false }
);

const STAFF_ROLES = ["Nurse", "Receptionist", "Lab Technician", "Radiologist", "Pharmacist", "Staff/Operations"];

const SPECIALTIES = [
  "Emergency",
  "Pediatrics",
  "Dermatology",
  "Laboratory",
  "Radiology",
  "Dentistry",
  "Reception",
  "General",
];

const staffSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null, index: true },
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    departmentId: { type: mongoose.Schema.Types.ObjectId, ref: "Department", default: null },

    fullName: { type: String, default: "", trim: true },
    firstName: { type: String, required: true, trim: true },
    fatherName: { type: String, default: "", trim: true },
    lastName: { type: String, required: true, trim: true },
    username: { type: String, required: true, trim: true, lowercase: true, unique: true },
    email: { type: String, required: true, trim: true, lowercase: true, unique: true },
    phone: { type: String, default: "" },
    passwordHash: { type: String, required: true },
    profileImage: { type: String, default: "" },
    gender: { type: String, default: "" },
    birthDate: { type: Date, default: null },

    employeeId: { type: String, default: "" },
    specialtyOrDepartment: { type: String, enum: SPECIALTIES, default: "General" },
    experienceYears: { type: Number, default: 0 },
    educationLevel: { type: String, enum: ["Diploma", "BSc", "MSc"], default: "Diploma" },
    university: { type: String, default: "" },
    licenseNumber: { type: String, default: "" },
    nursingLicenseNumber: { type: String, default: "" },
    licenseExpiryDate: { type: Date, default: null },
    employmentType: { type: String, enum: ["Full-Time", "Part-Time", "Shifts"], default: "Full-Time" },

    residentialAddress: { type: String, default: "" },
    city: { type: String, default: "" },
    emergencyContact: { type: EMERGENCY_CONTACT, default: () => ({}) },

    /** @deprecated use orgId — kept for legacy queries */
    targetOrgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true },

    role: { type: String, default: "Nurse", enum: STAFF_ROLES },
    permissions: { type: [String], default: [] },
    branchId: { type: mongoose.Schema.Types.ObjectId, ref: "Clinic", default: null },
    supervisorDoctorId: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    salary: { type: Number, default: null },
    workingDaysAndHours: { type: [WORKING_DAY], default: [] },
    employeeStatus: {
      type: String,
      enum: ["Active", "On-Leave", "Suspended"],
      default: "Active",
    },
    accountStatus: {
      type: String,
      enum: ["Pending", "Approved", "Rejected"],
      default: "Pending",
      index: true,
    },
    rejectionReason: { type: String, default: "" },
    reviewedByAdminUserId: { type: mongoose.Schema.Types.ObjectId, ref: "users", default: null },
    reviewedAt: { type: Date, default: null },
  },
  { timestamps: true, collection: "staffs" }
);

staffSchema.index({ orgId: 1, accountStatus: 1, createdAt: -1 });

/** Mongoose 9+: do not use `next` in sync validate hooks — it is not provided */
staffSchema.pre("validate", function syncDerivedFields() {
  if (!this.fullName && (this.firstName || this.lastName)) {
    const parts = [this.firstName, this.fatherName, this.lastName].filter(Boolean);
    this.fullName = parts.join(" ").replace(/\s+/g, " ").trim();
  }
  if (!this.licenseNumber && this.nursingLicenseNumber) {
    this.licenseNumber = this.nursingLicenseNumber;
  }
  if (!this.nursingLicenseNumber && this.licenseNumber) {
    this.nursingLicenseNumber = this.licenseNumber;
  }
  if (this.orgId && !this.targetOrgId) {
    this.targetOrgId = this.orgId;
  }
  if (!this.orgId && this.targetOrgId) {
    this.orgId = this.targetOrgId;
  }
  if (this.emergencyContact) {
    const ec = this.emergencyContact;
    if (!ec.name && ec.fullName) ec.name = ec.fullName;
    if (!ec.fullName && ec.name) ec.fullName = ec.name;
  }
});

const Staff = mongoose.models.Staff || mongoose.model("Staff", staffSchema);

module.exports = Staff;
module.exports.STAFF_SPECIALTIES = SPECIALTIES;
module.exports.STAFF_ROLES = STAFF_ROLES;
