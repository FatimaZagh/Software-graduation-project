/** Hardcoded internal pharmacy portal credentials (clinic registration). */
const INTERNAL_PHARMACIST_PASSWORD_PLAIN = "123456";

/**
 * clinicnameph@rafeeq.com — clinic name without spaces, lowercase, alphanumeric only.
 */
function buildInternalPharmacistEmail(clinicName) {
  const slug = String(clinicName || "clinic")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "")
    .replace(/[^a-z0-9]/g, "");
  const base = slug.length > 0 ? slug : "clinic";
  return `${base}ph@rafeeq.com`;
}

module.exports = {
  INTERNAL_PHARMACIST_PASSWORD_PLAIN,
  buildInternalPharmacistEmail,
};
