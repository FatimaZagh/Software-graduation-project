const mongoose = require("mongoose");

const departmentClinicSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, default: "" },
    roomNumber: { type: String, default: "" },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: true }
);

const departmentSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    name: { type: String, required: true, trim: true },
    description: { type: String, default: "" },
    supervisorDoctorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      default: null,
      index: true,
    },
    clinics: { type: [departmentClinicSchema], default: [] },
  },
  { timestamps: true }
);

departmentSchema.index({ orgId: 1, name: 1 });

module.exports = mongoose.model("Department", departmentSchema);
