const mongoose = require("mongoose");

const PROBLEM_TYPES = [
  "Allergy",
  "Mild Side Effect",
  "Moderate Side Effect",
  "Severe Side Effect",
  "Intolerable",
];

const SEVERITY_LEVELS = ["Mild", "Moderate", "Severe"];

const ONSET_TIMES = ["After first dose", "After days", "After weeks"];

const DOCTOR_ACTION_STATUSES = ["Pending", "Reviewed", "Action Taken"];

const WORKFLOW_STATUSES = [
  "New",
  "Reviewed",
  "Contacted Patient",
  "Medication Changed",
  "Resolved",
  "Emergency Case",
];

const adverseReportSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true },
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    doctorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      index: true,
    },
    prescriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "PatientMedication",
    },
    medicationName: { type: String, required: true, trim: true },
    problemType: {
      type: String,
      enum: PROBLEM_TYPES,
      required: true,
    },
    symptoms: { type: [String], default: [] },
    otherSymptoms: { type: String, default: "" },
    severity: {
      type: String,
      enum: SEVERITY_LEVELS,
      required: true,
    },
    onsetTime: {
      type: String,
      enum: ONSET_TIMES,
      required: true,
    },
    additionalNotes: { type: String, default: "" },
    isCritical: { type: Boolean, default: false, index: true },
    /** Highest triage — surfaces above all other ADRs. */
    isEmergencyCase: { type: Boolean, default: false, index: true },
    /** Doctor workflow / report status matrix (CDSS). */
    workflowStatus: {
      type: String,
      enum: WORKFLOW_STATUSES,
      default: "New",
      index: true,
    },
    /** Permanent clinical documentation appended by treating physician. */
    clinicalDocumentation: [
      {
        text: { type: String, default: "" },
        doctorId: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
        createdAt: { type: Date, default: Date.now },
      },
    ],
    doctorAction: {
      status: {
        type: String,
        enum: DOCTOR_ACTION_STATUSES,
        default: "Pending",
      },
      notes: { type: String, default: "" },
      actionDate: { type: Date },
      proposedSuspension: { type: Boolean, default: false },
    },
    medicationSuspended: { type: Boolean, default: false },
    auditLog: [
      {
        at: { type: Date, default: Date.now },
        actorRole: { type: String, default: "" },
        actorId: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
        event: { type: String, default: "" },
        detail: { type: String, default: "" },
      },
    ],
  },
  { timestamps: true }
);

module.exports = mongoose.model("AdverseReport", adverseReportSchema);
module.exports.PROBLEM_TYPES = PROBLEM_TYPES;
module.exports.SEVERITY_LEVELS = SEVERITY_LEVELS;
module.exports.ONSET_TIMES = ONSET_TIMES;
module.exports.DOCTOR_ACTION_STATUSES = DOCTOR_ACTION_STATUSES;
module.exports.WORKFLOW_STATUSES = WORKFLOW_STATUSES;
