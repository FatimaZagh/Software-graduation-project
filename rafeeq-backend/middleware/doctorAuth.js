const mongoose = require("mongoose");
const UserModel = require("../models/User");
const Doctor = require("../models/doctor");

const DOCTOR_FORBIDDEN_PREFIXES = [
  "/api/admin",
  "/api/superadmin",
  "/api/super-admin",
  "/api/org-admin/staff-requests",
  "/api/admin/approve",
  "/api/admin/pending",
  "/api/admin/invoices",
  "/api/admin/billing",
  "/api/admin/permissions",
  "/api/admin/staff",
  "/api/admin/system-config",
  "/api/admin/organizations",
  "/api/debug/set-user-org",
];

const DOCTOR_FORBIDDEN_PATTERNS = [
  { method: "DELETE", pattern: /\/users\//i },
  { method: "DELETE", pattern: /organization/i },
  { method: "POST", pattern: /invoice/i },
  { method: "PUT", pattern: /permissions/i },
  { method: "PATCH", pattern: /system-config/i },
  { method: "POST", pattern: /approve-org/i },
  { method: "POST", pattern: /register\/staff/i },
];

function resolveOrgId(req, user) {
  const header = String(req.headers["x-org-id"] || "").trim();
  const query = String(req.query?.orgId || "").trim();
  if (header && mongoose.Types.ObjectId.isValid(header)) return new mongoose.Types.ObjectId(header);
  if (query && mongoose.Types.ObjectId.isValid(query)) return new mongoose.Types.ObjectId(query);
  if (user?.orgId && mongoose.Types.ObjectId.isValid(String(user.orgId))) {
    return new mongoose.Types.ObjectId(String(user.orgId));
  }
  return null;
}

async function blockDoctorForbiddenRoutes(req, res, next) {
  try {
    const userId = String(req.headers["x-user-id"] || "").trim();
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) return next();
    const user = await UserModel.findById(userId).select("role status").lean();
    if (!user || user.role !== "Doctor" || user.status !== "active") return next();

    const path = String(req.originalUrl || req.url || "").split("?")[0];
    if (DOCTOR_FORBIDDEN_PREFIXES.some((p) => path.startsWith(p))) {
      return res.status(403).json({
        message: "Forbidden: doctors cannot access billing, admin, or system configuration.",
        code: "DOCTOR_FORBIDDEN",
      });
    }
    for (const rule of DOCTOR_FORBIDDEN_PATTERNS) {
      if (req.method === rule.method && rule.pattern.test(path)) {
        return res.status(403).json({ message: "Forbidden action for doctor role.", code: "DOCTOR_FORBIDDEN" });
      }
    }
    return next();
  } catch (_) {
    return next();
  }
}

async function requireDoctor(req, res, next) {
  try {
    const userId = String(req.headers["x-user-id"] || "").trim();
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(401).json({ message: "x-user-id required" });
    }
    const user = await UserModel.findById(userId).lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    if (user.role !== "Doctor") return res.status(403).json({ message: "Doctor role required" });
    if (user.status !== "active") {
      return res.status(403).json({ message: "Doctor account is not active", status: user.status });
    }
    const { resolveDoctorOrgId, ensureUserOrgId } = require("../utils/doctorOrgScope");
    const orgId = (await resolveDoctorOrgId(req, user)) || resolveOrgId(req, user);
    if (!orgId) return res.status(403).json({ message: "orgId is required" });
    await ensureUserOrgId(user._id, orgId);
    if (user.orgId && String(user.orgId) !== String(orgId)) {
      return res.status(403).json({ message: "Org scope mismatch" });
    }

    let doctorProfile = await Doctor.findOne({ userId })
      .select("consultationFee clinicServicesConfig clinicId orgId displayName fullName")
      .lean();
    if (!doctorProfile) {
      doctorProfile = (
        await Doctor.create({
          userId,
          orgId,
          displayName: user.name || "Doctor",
          email: user.email || "",
          clinicId: user.clinicId || undefined,
          consultationFee: 100,
        })
      ).toObject();
    } else if (orgId && !doctorProfile.orgId) {
      await Doctor.updateOne({ userId }, { $set: { orgId } });
      doctorProfile = await Doctor.findOne({ userId }).lean();
    }

    req.doctorScope = { user, orgId, doctorProfile, doctorUserId: userId };
    next();
  } catch (e) {
    console.error("[doctor-auth]", e);
    res.status(500).json({ message: "Doctor auth failed" });
  }
}

module.exports = { requireDoctor, blockDoctorForbiddenRoutes, resolveOrgId };
