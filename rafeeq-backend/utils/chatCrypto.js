const crypto = require("crypto");

function getSecret() {
  return String(process.env.CHAT_SECRET || "dev-chat-secret-change-me");
}

function conversationKey(senderId, receiverId) {
  const a = String(senderId);
  const b = String(receiverId);
  const sorted = [a, b].sort().join("|");
  // derive 32-byte key
  return crypto.createHash("sha256").update(getSecret()).update(sorted).digest();
}

function encryptMessage(plainText, senderId, receiverId) {
  const key = conversationKey(senderId, receiverId);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(String(plainText), "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    alg: "AES-256-GCM",
    ivB64: iv.toString("base64"),
    tagB64: tag.toString("base64"),
    cipherTextB64: ciphertext.toString("base64"),
  };
}

function decryptMessage(enc, senderId, receiverId) {
  try {
    const key = conversationKey(senderId, receiverId);
    const iv = Buffer.from(String(enc.ivB64 || ""), "base64");
    const tag = Buffer.from(String(enc.tagB64 || ""), "base64");
    const ciphertext = Buffer.from(String(enc.cipherTextB64 || ""), "base64");
    const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
    decipher.setAuthTag(tag);
    const plain = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    return plain.toString("utf8");
  } catch (_) {
    return "";
  }
}

module.exports = { encryptMessage, decryptMessage };

