const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const UPLOAD_BASE = path.join(__dirname, "..", "uploads");
const UPLOAD_ROOT = path.join(UPLOAD_BASE, "doctor-registrations");
const FILE_SECRET = process.env.FILE_SIGN_SECRET || process.env.JWT_SECRET || "rafeeq-file-sign-dev";

const MAX_BYTES = 8 * 1024 * 1024;

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function extFromMime(mime) {
  const m = String(mime || "").toLowerCase();
  if (m.includes("png")) return ".png";
  if (m.includes("pdf")) return ".pdf";
  if (m.includes("webp")) return ".webp";
  return ".jpg";
}

/**
 * Persist a base64 data URL or pass-through http(s) URL.
 * Returns a signed relative API URL for local files.
 */
function storeDoctorDocument(input, { requestKey, fieldName }) {
  const raw = String(input || "").trim();
  if (!raw) return "";
  if (/^https?:\/\//i.test(raw)) return raw.slice(0, 2048);

  let mime = "image/jpeg";
  let b64 = raw;
  const match = raw.match(/^data:([^;]+);base64,(.+)$/i);
  if (match) {
    mime = match[1];
    b64 = match[2];
  }

  const buf = Buffer.from(b64, "base64");
  if (!buf.length) return "";
  if (buf.length > MAX_BYTES) {
    throw new Error(`${fieldName} exceeds maximum upload size (8MB)`);
  }

  const safeKey = String(requestKey || "pending").replace(/[^a-zA-Z0-9_-]/g, "");
  const dir = path.join(UPLOAD_ROOT, safeKey);
  ensureDir(dir);
  const filename = `${fieldName}${extFromMime(mime)}`;
  const abs = path.join(dir, filename);
  fs.writeFileSync(abs, buf);

  return signFileUrl(`doctor-registrations/${safeKey}/${filename}`);
}

function signFileUrl(relativePath) {
  const exp = Date.now() + 7 * 24 * 60 * 60 * 1000;
  const payload = `${relativePath}:${exp}`;
  const sig = crypto.createHmac("sha256", FILE_SECRET).update(payload).digest("hex");
  return `/api/files/${relativePath}?exp=${exp}&sig=${sig}`;
}

function verifySignedFileRequest(relativePath, exp, sig) {
  if (!relativePath || !exp || !sig) return false;
  const expNum = Number(exp);
  if (!Number.isFinite(expNum) || expNum < Date.now()) return false;
  const expected = crypto.createHmac("sha256", FILE_SECRET).update(`${relativePath}:${expNum}`).digest("hex");
  try {
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(String(sig)));
  } catch (_) {
    return false;
  }
}

function resolveUploadAbsolute(relativePath) {
  const normalized = path.normalize(String(relativePath)).replace(/^(\.\.(\/|\\|$))+/, "");
  const abs = path.join(UPLOAD_BASE, normalized);
  if (!abs.startsWith(UPLOAD_BASE)) return null;
  return abs;
}

module.exports = {
  storeDoctorDocument,
  signFileUrl,
  verifySignedFileRequest,
  resolveUploadAbsolute,
  UPLOAD_ROOT,
};
