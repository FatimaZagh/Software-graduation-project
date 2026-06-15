const mongoose = require("mongoose");

const emergencyContactSchema = new mongoose.Schema(
  {
    name: { type: String, default: "" },
    phone: { type: String, default: "" },
    relationship: { type: String, default: "" },
  },
  { _id: false }
);

const allergiesSchema = new mongoose.Schema(
  {
    medications: { type: [String], default: [] },
    foods: { type: [String], default: [] },
    materials: { type: [String], default: [] },
  },
  { _id: false }
);

const socialHabitsSchema = new mongoose.Schema(
  {
    smoking: { type: Boolean, default: false },
    alcohol: { type: Boolean, default: false },
  },
  { _id: false }
);

const medicalFileSchema = new mongoose.Schema(
  {
    fileUrl: { type: String, default: "" },
    fileType: { type: String, default: "" },
    uploadedAt: { type: Date, default: () => new Date() },
    originalName: { type: String, default: "" },
  },
  { _id: true }
);

const {
  vitalsTimelineEntrySchema,
  medicationAdministrationSchema,
  nursingNoteSchema,
} = require("./nursingSchemas");

const patientMedicalProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      unique: true,
      index: true,
    },
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },

    city: { type: String, default: "" },
    residentialAddress: { type: String, default: "" },
    detailedAddress: { type: String, default: "" },

    emergencyContact: { type: emergencyContactSchema, default: () => ({}) },

    bloodType: { type: String, default: "" },
    height: { type: Number, default: null },
    weight: { type: Number, default: null },

    chronicDiseases: { type: [String], default: [] },
    allergies: { type: allergiesSchema, default: () => ({}) },
    currentMedications: { type: [String], default: [] },
    pastSurgeries: { type: [String], default: [] },
    medicalHistoryNotes: { type: String, default: "" },
    familyMedicalHistory: { type: [String], default: [] },

    socialHabits: { type: socialHabitsSchema, default: () => ({}) },
    pregnancyStatus: { type: String, default: "" },
    lastClinicVisit: { type: Date, default: null },

    medicalFiles: { type: [medicalFileSchema], default: [] },

    /** Nurse-recorded vitals timeline — visible to doctor & admin via unified patient file */
    vitalsTimeline: { type: [vitalsTimelineEntrySchema], default: [] },
    medicationAdministration: { type: [medicationAdministrationSchema], default: [] },
    nursingNotes: { type: [nursingNoteSchema], default: [] },
  },
  { timestamps: true }
);

module.exports = mongoose.model("PatientMedicalProfile", patientMedicalProfileSchema);
