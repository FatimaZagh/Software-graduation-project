const mongoose = require("mongoose");

const adminSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, unique: true, index: true },
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    email: { type: String, default: "" },
    name: { type: String, default: "" },
    role: { type: String, default: "Organization Admin" },
  },
  { timestamps: true }
);

adminSchema.index({ orgId: 1, userId: 1 });

module.exports = mongoose.model("Admin", adminSchema);

