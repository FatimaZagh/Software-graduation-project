const mongoose = require("mongoose");

const auditLogSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", required: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "users", required: true, index: true },
    action: { type: String, required: true, index: true },
    targetId: { type: String, default: "" },
    targetType: { type: String, default: "" },
    ipAddress: { type: String, default: "" },
    successStatus: { type: Boolean, default: true },
    metadata: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true }
);

module.exports = mongoose.model("AuditLog", auditLogSchema);
