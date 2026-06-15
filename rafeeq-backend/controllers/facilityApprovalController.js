const mongoose = require("mongoose");
const Organization = require("../models/Organization");
const Clinic = require("../models/clinic");
const UserModel = require("../models/User");
const Pharmacy = require("../models/pharmacy");
const {
  FACILITY_STATUS,
  isOrganizationApproved,
  normalizeFacilityStatus,
  pendingOrganizationQuery,
} = require("../utils/organizationStatus");
const {
  provisionInternalPharmacyForOrganization,
} = require("../services/internalPharmacyProvisioning");

const PHARMACY_ROLES = ["Pharmacist", "InternalPharmacist"];

function facilitySummary(org, extras = {}) {
  const admin = extras.admin || null;
  const clinics = Array.isArray(extras.clinics) ? extras.clinics : [];
  const pharmacies = Array.isArray(extras.pharmacies) ? extras.pharmacies : [];

  return {
    id: String(org._id),
    orgId: String(org._id),
    name: org.name || "",
    status: org.status || FACILITY_STATUS.PENDING,
    phone: org.phone || "",
    address: org.address || org.location?.address || "",
    city: org.city || org.location?.city || "",
    mapUrl: org.mapUrl || "",
    latitude: org.latitude ?? null,
    longitude: org.longitude ?? null,
    description: org.description || "",
    specialty: org.specialty || "",
    logoUrl: org.logoUrl || "",
    moduleKeys: org.moduleKeys || [],
    activeModules: org.activeModules || {},
    hasInternalPharmacy: Boolean(org.hasInternalPharmacy),
    subscriptionType: org.subscriptionType || "Free",
    registeredAt: org.createdAt || null,
    updatedAt: org.updatedAt || null,
    admin: admin
      ? {
          userId: String(admin._id),
          name: admin.name || "",
          email: admin.email || "",
          status: admin.status || "pending",
        }
      : null,
    clinics: clinics.map((c) => ({
      id: String(c._id),
      name: c.name || "",
      address: c.address || "",
      city: c.city || "",
      phone: c.phone || "",
      hasInternalPharmacy: Boolean(c.hasInternalPharmacy),
    })),
    pharmacies: pharmacies.map((p) => ({
      id: String(p._id),
      name: p.name || "",
      type: p.pharmacyType || "Internal",
      status: p.status || "Active",
      pharmacistUserId: p.userId || null,
      loginLocked: !isOrganizationApproved(org.status),
    })),
    registrationFiles: {
      logoUrl: org.logoUrl || "",
    },
  };
}

async function loadFacilityReviewBundle(orgId) {
  const oid = new mongoose.Types.ObjectId(orgId);
  const [org, clinics, pharmacies, adminUser] = await Promise.all([
    Organization.findById(oid).lean(),
    Clinic.find({ orgId: oid }).sort({ name: 1 }).lean(),
    Pharmacy.find({ orgId: oid }).sort({ createdAt: 1 }).lean(),
    UserModel.findOne({ orgId: oid, role: "Organization Admin" })
      .select("name email status createdAt")
      .sort({ createdAt: 1 })
      .lean(),
  ]);
  return { org, clinics, pharmacies, adminUser };
}

/**
 * GET /api/admin/facilities/pending
 * List facilities awaiting Super Admin approval with submitted details.
 */
exports.listPendingFacilities = async (req, res) => {
  try {
    const list = await Organization.find(pendingOrganizationQuery())
      .sort({ createdAt: -1 })
      .limit(500)
      .lean();

    const data = [];
    for (const org of list) {
      const oid = String(org._id);
      const [clinics, pharmacies, adminUser] = await Promise.all([
        Clinic.find({ orgId: org._id }).sort({ name: 1 }).lean(),
        Pharmacy.find({ orgId: org._id }).sort({ createdAt: 1 }).lean(),
        UserModel.findOne({ orgId: org._id, role: "Organization Admin" })
          .select("name email status createdAt")
          .sort({ createdAt: 1 })
          .lean(),
      ]);
      data.push(facilitySummary(org, { admin: adminUser, clinics, pharmacies }));
    }

    return res.status(200).json({
      success: true,
      count: data.length,
      data,
      facilities: data,
    });
  } catch (error) {
    console.error("[admin/facilities/pending]", error);
    return res.status(500).json({
      success: false,
      message: "Unable to load pending facilities. Please try again.",
    });
  }
};

/**
 * GET /api/admin/facilities/:id
 * Review a single facility (any status) with full submitted details.
 */
exports.getFacilityForReview = async (req, res) => {
  try {
    const orgId = String(req.params.id || req.params.orgId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(400).json({ success: false, message: "Invalid facility id" });
    }

    const { org, clinics, pharmacies, adminUser } = await loadFacilityReviewBundle(orgId);
    if (!org) {
      return res.status(404).json({ success: false, message: "Facility not found" });
    }

    return res.status(200).json({
      success: true,
      data: facilitySummary(org, { admin: adminUser, clinics, pharmacies }),
    });
  } catch (error) {
    console.error("[admin/facilities/:id]", error);
    return res.status(500).json({
      success: false,
      message: "Unable to load facility details.",
    });
  }
};

async function unlockFacilityAccounts(orgId) {
  const oid = new mongoose.Types.ObjectId(orgId);
  await UserModel.updateMany(
    { orgId: oid, role: "Organization Admin" },
    { $set: { status: "active" } }
  );
  await UserModel.updateMany(
    { orgId: oid, role: { $in: PHARMACY_ROLES } },
    { $set: { status: "active" } }
  );
  await Pharmacy.updateMany(
    { orgId: oid },
    { $set: { status: "Active", facilityApprovalLocked: false } }
  );
}

/**
 * POST /api/admin/facilities/:id/approve
 * Approve a pending facility, unlock org admin + pharmacy accounts, seed internal pharmacy if needed.
 */
exports.approveFacility = async (req, res) => {
  try {
    const orgId = String(req.params.id || req.params.orgId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(400).json({ success: false, message: "Invalid facility id" });
    }

    const oid = new mongoose.Types.ObjectId(orgId);
    const existing = await Organization.findById(oid).lean();
    if (!existing) {
      return res.status(404).json({ success: false, message: "Facility not found" });
    }

    const currentStatus = normalizeFacilityStatus(existing.status);

    if (currentStatus === FACILITY_STATUS.ACTIVE) {
      return res.status(200).json({
        success: true,
        message: "Facility is already active.",
        status: FACILITY_STATUS.ACTIVE,
        organization: existing,
      });
    }

    if (currentStatus === FACILITY_STATUS.REJECTED) {
      return res.status(409).json({
        success: false,
        message: "Rejected facilities cannot be approved via this endpoint. Re-register the facility instead.",
      });
    }

    const updated = await Organization.findOneAndUpdate(
      { _id: oid },
      { $set: { status: "active" } },
      { new: true, runValidators: true }
    ).lean();

    if (!updated) {
      return res.status(404).json({ success: false, message: "Facility not found" });
    }

    const clinicCount = await Clinic.countDocuments({ orgId: oid });
    if (clinicCount === 0) {
      await Clinic.create({
        orgId: oid,
        name: existing.name || "Main Clinic",
        address: existing.address || existing.location?.address || "",
        city: existing.city || existing.location?.city || "",
        phone: existing.phone || "",
        hasInternalPharmacy: Boolean(existing.hasInternalPharmacy),
      });
    }

    await unlockFacilityAccounts(orgId);

    let internalPharmacyCredentials = null;
    try {
      const seeded = await provisionInternalPharmacyForOrganization(orgId);
      if (seeded?.internalPharmacist) {
        internalPharmacyCredentials = {
          email: seeded.internalPharmacist.email,
          password: seeded.internalPharmacist.password,
          role: seeded.internalPharmacist.role,
          userId: seeded.internalPharmacist.userId,
        };
      }
      if (seeded?.internalPharmacist) {
        await UserModel.updateMany(
          { orgId: oid, role: { $in: PHARMACY_ROLES } },
          { $set: { status: "active" } }
        );
      }
    } catch (seedErr) {
      console.warn("[admin/facilities/approve] internal pharmacy seed skipped:", seedErr.message);
    }

    console.log("[admin/facilities/approve] facility activated:", orgId);

    return res.status(200).json({
      success: true,
      message: "Facility approved. Organization admin and pharmacy accounts are now active.",
      status: FACILITY_STATUS.ACTIVE,
      organization: updated,
      internalPharmacyCredentials,
    });
  } catch (error) {
    console.error("[admin/facilities/approve]", error);
    return res.status(500).json({
      success: false,
      message: "Unable to approve facility. Please try again.",
    });
  }
};

/**
 * POST /api/admin/facilities/:id/reject
 * Reject a pending facility and keep pharmacy / admin accounts locked.
 */
exports.rejectFacility = async (req, res) => {
  try {
    const orgId = String(req.params.id || req.params.orgId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(400).json({ success: false, message: "Invalid facility id" });
    }

    const oid = new mongoose.Types.ObjectId(orgId);
    const existing = await Organization.findById(oid).lean();
    if (!existing) {
      return res.status(404).json({ success: false, message: "Facility not found" });
    }

    if (isOrganizationApproved(existing.status)) {
      return res.status(409).json({
        success: false,
        message: "Approved facilities cannot be rejected via this endpoint.",
      });
    }

    const reason =
      req.body?.reason != null ? String(req.body.reason).trim().slice(0, 2000) : "";

    const updated = await Organization.findByIdAndUpdate(
      oid,
      {
        $set: {
          status: FACILITY_STATUS.REJECTED,
          ...(reason ? { rejectionReason: reason } : {}),
        },
      },
      { new: true }
    ).lean();

    await UserModel.updateMany(
      { orgId: oid, role: { $in: ["Organization Admin", ...PHARMACY_ROLES] } },
      { $set: { status: "pending" } }
    );
    await Pharmacy.updateMany(
      { orgId: oid },
      { $set: { status: "Inactive", facilityApprovalLocked: true } }
    );

    console.log("[admin/facilities/reject] facility rejected:", orgId);

    return res.status(200).json({
      success: true,
      message: "Facility registration rejected.",
      status: FACILITY_STATUS.REJECTED,
      organization: updated,
      rejectionReason: reason || null,
    });
  } catch (error) {
    console.error("[admin/facilities/reject]", error);
    return res.status(500).json({
      success: false,
      message: "Unable to reject facility. Please try again.",
    });
  }
};

/** Backward-compatible alias used by legacy server.js routes. */
exports.approveOrganizationBySuperAdmin = exports.approveFacility;
