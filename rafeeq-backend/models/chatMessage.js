const mongoose = require("mongoose");

const chatMessageSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    receiverId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "users",
      required: true,
      index: true,
    },
    /** Denormalized roles for UI convenience. */
    senderRole: { type: String, enum: ["patient", "doctor", "admin", "system"], required: true },
    receiverRole: { type: String, enum: ["patient", "doctor", "admin", "system"], required: true },
    /** Encrypted payload (AES-256-GCM) */
    bodyEnc: {
      alg: { type: String, default: "AES-256-GCM" },
      ivB64: { type: String, default: "" },
      tagB64: { type: String, default: "" },
      cipherTextB64: { type: String, default: "" },
    },
    /** Back-compat: legacy plaintext body (will not be used for new messages). */
    body: { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("ChatMessage", chatMessageSchema);
