const mongoose = require("mongoose");

const uploadedDocSchema = new mongoose.Schema(
  {
    docType: {
      type: String,
      enum: ["License", "ID", "Specialty", "Contract"],
      required: true,
    },
    fileUrl: { type: String, default: "" },
  },
  { _id: true }
);

const staffProfileSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, unique: true, index: true },
    salary: { type: Number, default: 0 },
    specialty: { type: String, default: "" },
    shiftHours: {
      start: { type: String, default: "08:00" },
      end: { type: String, default: "17:00" },
    },
    permissions: { type: [String], default: [] },
    departmentId: { type: mongoose.Schema.Types.ObjectId, ref: "Department", default: null },
    uploadedDocs: { type: [uploadedDocSchema], default: [] },
    loginDisabled: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model("StaffProfile", staffProfileSchema);
