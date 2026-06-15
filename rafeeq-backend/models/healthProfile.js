const mongoose = require("mongoose");

const healthProfileSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      unique: true,
    },
    chronicDiseases: { type: [String], default: [] },
    allergies: { type: [String], default: [] },
    pastSurgeries: { type: [String], default: [] },
    heightCm: { type: Number, default: null },
    weightKg: { type: Number, default: null },
    bloodPressureSystolic: { type: Number, default: null },
    bloodPressureDiastolic: { type: Number, default: null },
    glucoseMgDl: { type: Number, default: null },
    bloodType: { type: String, default: "" },
    lastCheckupLabel: { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("HealthProfile", healthProfileSchema);
