const mongoose = require("mongoose");

const userNotificationSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    role: { type: String, default: "" },
    type: { type: String, default: "info" },
    title: { type: String, required: true },
    body: { type: String, default: "" },
    read: { type: Boolean, default: false, index: true },
    meta: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true }
);

module.exports = mongoose.model("UserNotification", userNotificationSchema);

