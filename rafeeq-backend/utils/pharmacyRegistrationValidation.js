const mongoose = require("mongoose");

function str(v) {
  return v == null ? "" : String(v).trim();
}

/**
 * Resolve explicit or inferred pharmacy affiliation type.
 * - Explicit pharmacyType / pharmacyCategory wins.
 * - When orgId is present and type is not External, treat as Internal.
 * - Otherwise External (independent community pharmacy).
 */
function resolvePharmacyRegistrationType(body, pharmacyProfile, { resolvedOrgId = null } = {}) {
  const profile = pharmacyProfile && typeof pharmacyProfile === "object" ? pharmacyProfile : {};
  if (
    body?.isIndependentPharmacy === true ||
    body?.isIndependentPharmacy === "true" ||
    String(body?.registrationKind || "").toLowerCase() === "independent_pharmacy"
  ) {
    return "External";
  }
  const raw = str(body?.pharmacyType || profile.pharmacyType || body?.pharmacyCategory);
  if (/^internal$/i.test(raw)) return "Internal";
  if (/^external$/i.test(raw) || /independent/i.test(raw)) return "External";
  if (resolvedOrgId) return "Internal";
  return "External";
}

function extractOrgIdFromBody(body) {
  const raw = str(body?.orgId || body?.organizationId || body?.facilityId);
  if (!raw || !mongoose.Types.ObjectId.isValid(raw)) return null;
  return new mongoose.Types.ObjectId(raw);
}

function extractClinicIdFromBody(body) {
  const raw = str(body?.clinicId || body?.branchId);
  if (!raw || !mongoose.Types.ObjectId.isValid(raw)) return null;
  return new mongoose.Types.ObjectId(raw);
}

function buildPharmacySignupPayload(body) {
  const {
    pharmacyProfile,
    pharmacyName,
    address,
    city,
    licenseNumber,
    operatingHours,
    is24Hours,
    licenseImage,
    latitude,
    longitude,
    phone,
  } = body || {};

  const base =
    pharmacyProfile && typeof pharmacyProfile === "object"
      ? { ...pharmacyProfile }
      : {
          pharmacyName,
          address,
          city,
          licenseNumber,
          operatingHours,
          is24Hours: is24Hours === true || is24Hours === "true",
          licenseImage,
          latitude: latitude != null ? Number(latitude) : null,
          longitude: longitude != null ? Number(longitude) : null,
          phone: phone != null ? String(phone) : "",
        };

  const resolvedOrgId = extractOrgIdFromBody(body);
  const pharmacyType = resolvePharmacyRegistrationType(body, base, { resolvedOrgId });
  return { ...base, pharmacyType };
}

/**
 * Validates pharmacist signup payload.
 * External pharmacies: orgId / clinicId / facilityId are NOT required and are cleared.
 * Internal pharmacies: orgId (facility) IS required; clinicId is optional.
 */
function validatePharmacySignup({ body, normalizedRole, resolvedOrgId, resolvedClinicId }) {
  if (normalizedRole !== "Pharmacist") {
    return {
      ok: true,
      pharmacyPayload: null,
      pharmacyType: null,
      isExternalPharmacist: false,
      resolvedOrgId,
      resolvedClinicId,
    };
  }

  const pharmacyPayload = buildPharmacySignupPayload(body);
  const pharmacyType = pharmacyPayload.pharmacyType || "External";
  const isIndependentFlag =
    body?.isIndependentPharmacy === true ||
    body?.isIndependentPharmacy === "true" ||
    String(body?.registrationKind || "").toLowerCase() === "independent_pharmacy";
  const isExternalPharmacist = pharmacyType === "External" || isIndependentFlag;

  if (isExternalPharmacist) {
    return {
      ok: true,
      pharmacyPayload,
      pharmacyType,
      isExternalPharmacist: true,
      resolvedOrgId: null,
      resolvedClinicId: null,
    };
  }

  if (!resolvedOrgId) {
    return {
      ok: false,
      status: 400,
      message: "orgId (facilityId) is required for internal pharmacy registration",
    };
  }

  return {
    ok: true,
    pharmacyPayload,
    pharmacyType,
    isExternalPharmacist: false,
    resolvedOrgId,
    resolvedClinicId: resolvedClinicId || null,
  };
}

module.exports = {
  resolvePharmacyRegistrationType,
  extractOrgIdFromBody,
  extractClinicIdFromBody,
  buildPharmacySignupPayload,
  validatePharmacySignup,
};
