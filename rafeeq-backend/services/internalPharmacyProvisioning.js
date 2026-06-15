const mongoose = require("mongoose");
const Organization = require("../models/Organization");
const Clinic = require("../models/clinic");
const Pharmacy = require("../models/pharmacy");
const UserModel = require("../models/User");
const { hashPassword } = require("../utils/password");
const {
  buildInternalPharmacistEmail,
  INTERNAL_PHARMACIST_PASSWORD_PLAIN,
} = require("../utils/internalPharmacistAuth");
const { createPharmacy, ensurePharmacyInventory } = require("./pharmacyInventoryService");
const { isOrganizationApproved } = require("../utils/organizationStatus");

const DEFAULT_LAT = 32.2211;
const DEFAULT_LNG = 35.2544;

/**
 * Create (or reuse) an internal org/clinic pharmacy and seed master drug template inventory.
 */
async function provisionInternalPharmacy({
  orgId,
  clinicId = null,
  pharmacyName = "",
  latitude = DEFAULT_LAT,
  longitude = DEFAULT_LNG,
  address = "",
  phone = "",
}) {
  if (!orgId || !mongoose.Types.ObjectId.isValid(orgId)) {
    const err = new Error("Valid orgId is required to provision internal pharmacy.");
    err.statusCode = 400;
    throw err;
  }

  const org = await Organization.findById(orgId).lean();
  if (!org) {
    const err = new Error("Organization not found.");
    err.statusCode = 404;
    throw err;
  }

  const orgOid = new mongoose.Types.ObjectId(orgId);
  let clinic = null;
  if (clinicId && mongoose.Types.ObjectId.isValid(clinicId)) {
    clinic = await Clinic.findOne({ _id: clinicId, orgId: orgOid }).lean();
  }

  if (org.internalPharmacyId) {
    const existing = await Pharmacy.findById(org.internalPharmacyId);
    if (existing) {
      await ensurePharmacyInventory(existing);
      const clinicNameForEmail = clinic?.name || existing.name || org.name;
      const pharmacistAccount = await ensureInternalPharmacistUser({
        orgId: orgOid,
        clinicId: clinic?._id || existing.clinicId || null,
        clinicName: clinicNameForEmail,
        pharmacy: existing,
      });
      return {
        pharmacy: existing,
        seeded: existing.inventory?.length || 0,
        reused: true,
        internalPharmacist: pharmacistAccount,
      };
    }
  }

  const name =
    pharmacyName?.trim() ||
    (clinic?.name ? `${clinic.name} — In-House Pharmacy` : `${org.name} — Clinic Pharmacy`);

  const orgApproved = isOrganizationApproved(org.status);
  const { pharmacy, seededCount } = await createPharmacy({
    name,
    latitude: Number(latitude) || DEFAULT_LAT,
    longitude: Number(longitude) || DEFAULT_LNG,
    status: orgApproved ? "Active" : "Inactive",
    address: address || org.address || org.location?.address || "",
    userId: null,
  });

  pharmacy.orgId = orgOid;
  pharmacy.clinicId = clinic?._id || null;
  pharmacy.pharmacyType = "Internal";
  pharmacy.phone = phone || org.phone || "";
  pharmacy.facilityApprovalLocked = !orgApproved;
  await pharmacy.save();

  const clinicNameForEmail = clinic?.name || name || org.name;
  const pharmacistAccount = await ensureInternalPharmacistUser({
    orgId: orgOid,
    clinicId: clinic?._id || null,
    clinicName: clinicNameForEmail,
    pharmacy,
  });

  await Organization.updateOne(
    { _id: orgOid },
    { $set: { hasInternalPharmacy: true, internalPharmacyId: pharmacy._id } }
  );

  if (clinic) {
    await Clinic.updateOne(
      { _id: clinic._id },
      { $set: { hasInternalPharmacy: true, internalPharmacyId: pharmacy._id } }
    );
  } else {
    const firstClinic = await Clinic.findOne({ orgId: orgOid }).sort({ createdAt: 1 });
    if (firstClinic) {
      await Clinic.updateOne(
        { _id: firstClinic._id },
        { $set: { hasInternalPharmacy: true, internalPharmacyId: pharmacy._id } }
      );
    }
  }

  return {
    pharmacy,
    seeded: seededCount,
    reused: false,
    internalPharmacist: pharmacistAccount,
  };
}

/**
 * Create or refresh InternalPharmacist user: clinicnameph@rafeeq.com / 123456
 */
async function ensureInternalPharmacistUser({ orgId, clinicId, clinicName, pharmacy, forceActive = null }) {
  const email = buildInternalPharmacistEmail(clinicName);
  const passwordHash = hashPassword(INTERNAL_PHARMACIST_PASSWORD_PLAIN);
  const displayName = `${String(clinicName || "Clinic").trim()} Pharmacist`;

  let pharmacistStatus = "pending";
  if (forceActive === true) {
    pharmacistStatus = "active";
  } else if (forceActive === false) {
    pharmacistStatus = "pending";
  } else if (orgId && mongoose.Types.ObjectId.isValid(orgId)) {
    const orgRow = await Organization.findById(orgId).select("status").lean();
    pharmacistStatus = isOrganizationApproved(orgRow?.status) ? "active" : "pending";
  }

  let user = await UserModel.findOne({ email: new RegExp(`^${email.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "i") });

  if (user) {
    user.role = "InternalPharmacist";
    user.orgId = orgId;
    user.clinicId = clinicId || null;
    user.password = passwordHash;
    user.status = pharmacistStatus;
    user.name = displayName;
    await user.save();
  } else {
    user = await UserModel.create({
      orgId,
      clinicId: clinicId || null,
      name: displayName,
      email,
      role: "InternalPharmacist",
      password: passwordHash,
      status: pharmacistStatus,
    });
  }

  if (pharmacy) {
    pharmacy.userId = String(user._id);
    await pharmacy.save();
  }

  return {
    userId: String(user._id),
    email,
    password: INTERNAL_PHARMACIST_PASSWORD_PLAIN,
    role: "InternalPharmacist",
    clinicId: clinicId ? String(clinicId) : null,
  };
}

/**
 * After org approval: seed internal pharmacy when pharmacy module + flag enabled.
 */
async function provisionInternalPharmacyForOrganization(orgId) {
  const org = await Organization.findById(orgId).lean();
  if (!org) return null;
  const pharmacyModule = org.activeModules?.pharmacy === true;
  const wantsInternal = org.hasInternalPharmacy === true || pharmacyModule;
  if (!pharmacyModule || !wantsInternal) return null;

  return provisionInternalPharmacy({
    orgId,
    pharmacyName: `${org.name} — Internal Pharmacy`,
    address: org.address || org.location?.address || "",
    phone: org.phone || "",
  });
}

/**
 * External pharmacist pharmacy linked to org after signup approval.
 */
async function provisionExternalPharmacyFromProfile({ orgId, userId, profile = {} }) {
  if (!userId) return null;
  const lat = profile.latitude != null ? Number(profile.latitude) : DEFAULT_LAT;
  const lng = profile.longitude != null ? Number(profile.longitude) : DEFAULT_LNG;
  const name = String(profile.pharmacyName || "Community Pharmacy").trim();
  const orgOid =
    orgId && mongoose.Types.ObjectId.isValid(String(orgId))
      ? new mongoose.Types.ObjectId(String(orgId))
      : null;

  const existing = await Pharmacy.findOne({ userId: String(userId) });
  if (existing) {
    await ensurePharmacyInventory(existing);
    if (!existing.orgId && orgOid) {
      existing.orgId = orgOid;
    }
    existing.pharmacyType = "External";
    if (!orgOid) {
      existing.clinicId = null;
    }
    await existing.save();
    return existing;
  }

  const { pharmacy } = await createPharmacy({
    name,
    latitude: lat,
    longitude: lng,
    status: "Inactive",
    userId: String(userId),
    address: profile.address || "",
  });

  pharmacy.orgId = orgOid;
  pharmacy.clinicId = null;
  pharmacy.pharmacyType = "External";
  pharmacy.phone = profile.phone || "";
  pharmacy.licenseNumber = profile.licenseNumber || "";
  pharmacy.operatingHours = profile.operatingHours || pharmacy.operatingHours;
  if (orgOid) {
    const org = await Organization.findById(orgOid).select("status").lean();
    const orgApproved = isOrganizationApproved(org?.status);
    pharmacy.facilityApprovalLocked = !orgApproved;
    pharmacy.status = orgApproved ? pharmacy.status || "Active" : "Inactive";
  } else {
    pharmacy.facilityApprovalLocked = true;
    pharmacy.status = "Inactive";
  }
  await pharmacy.save();
  return pharmacy;
}

module.exports = {
  provisionInternalPharmacy,
  provisionInternalPharmacyForOrganization,
  provisionExternalPharmacyFromProfile,
  ensureInternalPharmacistUser,
  buildInternalPharmacistEmail,
  INTERNAL_PHARMACIST_PASSWORD_PLAIN,
};
