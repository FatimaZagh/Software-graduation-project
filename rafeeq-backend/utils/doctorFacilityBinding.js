const mongoose = require("mongoose");
const Organization = require("../models/Organization");
const Clinic = require("../models/clinic");

function str(v) {
  return v == null ? "" : String(v).trim();
}

function toObjectId(id) {
  const s = str(id);
  if (!mongoose.Types.ObjectId.isValid(s)) return null;
  return new mongoose.Types.ObjectId(s);
}

/** Extract organization id from flat or nested registration payload. */
function resolveRegistrationOrgId(raw = {}) {
  const facility =
    raw.facility && typeof raw.facility === "object" ? raw.facility : null;
  const organization =
    raw.organization && typeof raw.organization === "object" ? raw.organization : null;
  const candidates = [
    raw.orgId,
    raw.organizationId,
    raw.facilityId,
    raw.targetOrgId,
    raw.selectedFacilityId,
    raw.selectedOrgId,
    facility?._id,
    facility?.id,
    facility?.orgId,
    organization?._id,
    organization?.id,
  ];
  for (const c of candidates) {
    const s = str(c);
    if (mongoose.Types.ObjectId.isValid(s)) return s;
  }
  return "";
}

/** Extract clinic branch id from flat or nested registration payload. */
function resolveRegistrationClinicId(raw = {}) {
  const clinic = raw.clinic && typeof raw.clinic === "object" ? raw.clinic : null;
  const candidates = [
    raw.clinicId,
    raw.doctorClinicId,
    raw.currentClinicId,
    raw.branchId,
    raw.facilityId,
    clinic?._id,
    clinic?.id,
  ];
  for (const c of candidates) {
    const s = str(c);
    if (mongoose.Types.ObjectId.isValid(s)) return s;
  }
  return "";
}

function logDoctorRegistrationPayload(raw = {}) {
  const safe = { ...raw };
  delete safe.password;
  delete safe.passwordHash;
  delete safe.profileImageUrl;
  delete safe.profileImage;
  if (safe.documents) safe.documents = "[redacted]";
  console.log("[doctor-register] incoming payload keys:", Object.keys(raw));
  console.log("[doctor-register] facility trace:", {
    orgId: raw.orgId,
    organizationId: raw.organizationId,
    facilityId: raw.facilityId,
    clinicId: raw.clinicId,
    doctorClinicId: raw.doctorClinicId,
    currentClinic: raw.currentClinic,
    clinicName: raw.clinicName,
    clinicNestedId: raw.clinic?._id ?? raw.clinic?.id,
    facilityNestedId: raw.facility?._id ?? raw.facility?.id,
    organizationNestedId: raw.organization?._id ?? raw.organization?.id,
  });
  console.log("[doctor-register] sanitized payload:", JSON.stringify(safe).slice(0, 2500));
}

/**
 * Resolve org + clinic binding for doctor onboarding.
 * Falls back to the organization's first clinic branch when only org is selected.
 */
async function resolveDoctorFacilityBinding(raw = {}) {
  const orgIdRaw = resolveRegistrationOrgId(raw);
  const clinicIdRaw = resolveRegistrationClinicId(raw);
  const labelFromBody = str(
    raw.currentClinic || raw.clinicName || raw.facilityName || raw.organizationName
  );

  let orgId = toObjectId(orgIdRaw);
  let clinicId = toObjectId(clinicIdRaw);
  let orgName = "";
  let clinicName = "";
  let currentClinic = labelFromBody;

  if (orgId) {
    const org = await Organization.findById(orgId).select("name").lean();
    if (!org) {
      return { orgId: null, clinicId: null, orgName: "", clinicName: "", currentClinic: "" };
    }
    orgName = str(org.name);
    if (!currentClinic) currentClinic = orgName;
  }

  if (clinicId) {
    const clinic = await Clinic.findOne({
      _id: clinicId,
      ...(orgId ? { orgId } : {}),
    })
      .select("name orgId")
      .lean();
    if (clinic) {
      clinicName = str(clinic.name);
      currentClinic = clinicName || currentClinic;
      if (!orgId && clinic.orgId) orgId = toObjectId(clinic.orgId);
    } else {
      clinicId = null;
    }
  }

  if (orgId && !clinicId) {
    const firstClinic = await Clinic.findOne({ orgId }).sort({ createdAt: 1 }).select("_id name").lean();
    if (firstClinic) {
      clinicId = toObjectId(firstClinic._id);
      clinicName = str(firstClinic.name);
      currentClinic = clinicName || currentClinic || orgName;
    }
  }

  if (!currentClinic && orgName) currentClinic = orgName;
  if (!currentClinic && orgId) currentClinic = String(orgId);

  return { orgId, clinicId, orgName, clinicName, currentClinic };
}

/** Enrich stored doctor row with resolved facility labels for profile APIs. */
async function enrichDoctorFacilityFields(doc) {
  if (!doc || typeof doc !== "object") return doc;
  const row = { ...doc };
  let orgName = "";
  let clinicName = str(row.currentClinic);

  const orgOid = toObjectId(row.orgId);
  if (orgOid) {
    const org = await Organization.findById(orgOid).select("name").lean();
    orgName = str(org?.name);
    if (!clinicName) clinicName = orgName;
  }

  const clinicOid = toObjectId(row.clinicId);
  if (clinicOid) {
    const clinic = await Clinic.findById(clinicOid).select("name orgId").lean();
    if (clinic) {
      clinicName = str(clinic.name) || clinicName;
      if (!orgOid && clinic.orgId) {
        row.orgId = clinic.orgId;
        const org = await Organization.findById(clinic.orgId).select("name").lean();
        orgName = str(org?.name);
      }
    }
  } else if (orgOid && !clinicOid) {
    const firstClinic = await Clinic.findOne({ orgId: orgOid }).sort({ createdAt: 1 }).select("_id name").lean();
    if (firstClinic) {
      row.clinicId = firstClinic._id;
      clinicName = str(firstClinic.name) || clinicName;
    }
  }

  if (!str(row.currentClinic)) {
    row.currentClinic = clinicName || orgName || "";
  }

  return {
    ...row,
    organizationName: orgName,
    clinicName,
    doctorClinicId: row.clinicId || null,
  };
}

module.exports = {
  resolveRegistrationOrgId,
  resolveRegistrationClinicId,
  logDoctorRegistrationPayload,
  resolveDoctorFacilityBinding,
  enrichDoctorFacilityFields,
};
