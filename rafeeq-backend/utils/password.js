const bcrypt = require("bcryptjs");

const SALT_ROUNDS = 11;

function isBcryptHash(stored) {
  const s = String(stored || "");
  return s.startsWith("$2a$") || s.startsWith("$2b$") || s.startsWith("$2y$");
}

function hashPassword(plain) {
  const p = String(plain ?? "");
  if (!p) return "";
  return bcrypt.hashSync(p, SALT_ROUNDS);
}

/** Returns true if plain matches stored (bcrypt or legacy plaintext). */
function verifyPassword(stored, plain) {
  const st = String(stored ?? "");
  const pl = String(plain ?? "");
  if (!st || !pl) return false;
  if (isBcryptHash(st)) {
    try {
      return bcrypt.compareSync(pl, st);
    } catch (_) {
      return false;
    }
  }
  return st === pl;
}

module.exports = { hashPassword, verifyPassword, isBcryptHash };
