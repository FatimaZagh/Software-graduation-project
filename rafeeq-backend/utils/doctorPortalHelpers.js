const mongoose = require("mongoose");

function escapeRegex(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Lowercase label with honorific stripped (EN + common AR) for comparison. */
function stripDoctorTitle(s) {
  return String(s || "")
    .trim()
    .replace(/^dr\.?\s+/i, "")
    .replace(/^(د\.|الدكتور|دكتور)\s*/u, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Normalize any common appointment date input to YYYY-MM-DD (UTC calendar parts when given Date).
 */
function normalizeDateToYmd(input) {
  if (input == null || input === "") return "";
  if (input instanceof Date && !Number.isNaN(input.getTime())) {
    const y = input.getUTCFullYear();
    const m = String(input.getUTCMonth() + 1).padStart(2, "0");
    const d = String(input.getUTCDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }
  const s = String(input).trim();
  const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (iso) {
    const y = parseInt(iso[1], 10);
    const mo = String(parseInt(iso[2], 10)).padStart(2, "0");
    const da = String(parseInt(iso[3], 10)).padStart(2, "0");
    return `${y}-${mo}-${da}`;
  }
  const us = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (us) {
    const mo = String(parseInt(us[1], 10)).padStart(2, "0");
    const da = String(parseInt(us[2], 10)).padStart(2, "0");
    const y = us[3];
    return `${y}-${mo}-${da}`;
  }
  return s;
}

/** Distinct display strings to match against stored doctorName (exact / spacing). */
function doctorNameSearchVariants(displayName, userName) {
  const out = new Set();
  const add = (x) => {
    const t = String(x || "").trim().replace(/\s+/g, " ");
    if (t) out.add(t);
  };
  add(displayName);
  add(userName);
  const base = String(displayName || "").trim().replace(/\s+/g, " ");
  const core = base.replace(/^dr\.?\s+/i, "").trim();
  if (core) {
    add(core);
    add(`Dr. ${core}`);
    add(`Dr ${core}`);
    add(`د. ${core}`);
  }
  const ub = String(userName || "").trim().replace(/\s+/g, " ");
  const ucore = ub.replace(/^dr\.?\s+/i, "").trim();
  if (ucore && ucore !== core) {
    add(ucore);
    add(`Dr. ${ucore}`);
    add(`Dr ${ucore}`);
  }
  return [...out];
}

function appointmentMatchQuery(doctorUserId, displayName, userName) {
  const oid = new mongoose.Types.ObjectId(doctorUserId);
  const variants = doctorNameSearchVariants(displayName, userName);
  const or = [{ doctorUserId: oid }];
  for (const v of variants) {
    if (!v) continue;
    or.push({ doctorName: new RegExp(`^\\s*${escapeRegex(v)}\\s*$`, "i") });
  }
  return { $or: or };
}

function apptMatchesDoctor(appt, doctorUserId, displayName, userName) {
  if (!appt) return false;
  if (String(appt.doctorUserId || "") === String(doctorUserId)) return true;
  const apptCore = stripDoctorTitle(appt.doctorName);
  if (!apptCore) return false;
  const a = stripDoctorTitle(displayName);
  const b = stripDoctorTitle(userName);
  return (a && apptCore === a) || (b && apptCore === b);
}

module.exports = {
  normalizeDateToYmd,
  doctorNameSearchVariants,
  appointmentMatchQuery,
  apptMatchesDoctor,
  stripDoctorTitle,
};
