const mongoose = require("mongoose");
const UserModel = require("../models/User");
const StaffProfile = require("../models/staffProfile");
const Organization = require("../models/Organization");

const NURSE_FORBIDDEN_PATH_PREFIXES = [
  "/api/admin",
  "/api/super-admin",
  "/api/org-admin/staff-requests",
  "/api/admin/approve",
  "/api/admin/pending",
  "/api/admin/invoices",
  "/api/admin/billing",
  "/api/admin/permissions",
  "/api/admin/staff",
  "/signup",
];

const NURSE_FORBIDDEN_METHOD_PATHS = [
  { method: "DELETE", pattern: /medical/i },
  { method: "DELETE", pattern: /patient/i },
  { method: "POST", pattern: /invoice/i },
  { method: "PUT", pattern: /permissions/i },
  { method: "PATCH", pattern: /price/i },
];

function pathMatchesForbidden(urlPath) {
  const p = String(urlPath || "").split("?")[0];
  if (NURSE_FORBIDDEN_PATH_PREFIXES.some((pre) => p.startsWith(pre))) return true;
  return false;
}

/** Global guard: reject nurses on admin/billing/staff-management routes */
async function blockNurseForbiddenRoutes(req, res, next) {
  try {
    const userId = String(req.headers["x-user-id"] || req.query.userId || "").trim();
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) return next();

    const user = await UserModel.findById(userId).select("role status").lean();
    if (!user || user.role !== "Nurse" || user.status !== "active") return next();

    const path = req.originalUrl || req.url || "";
    if (pathMatchesForbidden(path)) {
      return res.status(403).json({
        message: "Forbidden: nurses cannot access staff, billing, permissions, or system configuration endpoints.",
        code: "NURSE_FORBIDDEN",
      });
    }

    for (const rule of NURSE_FORBIDDEN_METHOD_PATHS) {
      if (req.method === rule.method && rule.pattern.test(path)) {
        return res.status(403).json({
          message: "Forbidden action for nurse role.",
          code: "NURSE_FORBIDDEN",
        });
      }
    }

    return next();
  } catch (_) {
    return next();
  }
}

/**
 * Require active nurse scoped to org via x-user-id + x-org-id (or user.orgId).
 * Attaches req.nurseScope = { user, orgId, profile, permissions }
 */
async function requireNurse(req, res, next) {
  try {
    const userId = String(req.headers["x-user-id"] || req.query.userId || "").trim();
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(401).json({ message: "x-user-id required" });
    }

    const user = await UserModel.findById(userId).lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    if (user.role !== "Nurse") {
      return res.status(403).json({ message: "Nurse role required" });
    }
    if (user.status !== "active") {
      return res.status(403).json({ message: "Account is not active" });
    }

    let orgId = String(req.headers["x-org-id"] || req.query.orgId || user.orgId || "").trim();
    if (!orgId || !mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(403).json({ message: "orgId is required" });
    }
    if (user.orgId && String(user.orgId) !== orgId) {
      return res.status(403).json({ message: "Org scope mismatch" });
    }

    const org = await Organization.findById(orgId).select("_id name").lean();
    if (!org) return res.status(404).json({ message: "Organization not found" });

    const profile = await StaffProfile.findOne({ userId, orgId }).lean();
    const permissions = profile?.permissions?.length
      ? profile.permissions
      : ["nurse_access", "view_medical_notes", "manage_appointments"];

    req.nurseScope = {
      user,
      orgId,
      userId,
      profile: profile || {},
      permissions,
    };
    return next();
  } catch (e) {
    console.error("[requireNurse]", e);
    return res.status(500).json({ message: "Auth check failed" });
  }
}

function hasPermission(permissionKey) {
  return (req, res, next) => {
    const perms = req.nurseScope?.permissions || [];
    if (perms.includes("nurse_access") || perms.includes(permissionKey)) return next();
    return res.status(403).json({
      message: `Missing permission: ${permissionKey}`,
      code: "NURSE_PERMISSION_DENIED",
    });
  };
}

const LAB_QUEUE_ROLES = ["Nurse", "Lab Technician"];

/** Nurse or lab technician — unified lab queue (GET /api/lab-requests) */
async function requireLabQueueStaff(req, res, next) {
  try {
    const userId = String(req.headers["x-user-id"] || req.query.userId || "").trim();
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(401).json({ message: "x-user-id required" });
    }

    const user = await UserModel.findById(userId).lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    if (!LAB_QUEUE_ROLES.includes(user.role)) {
      return res.status(403).json({ message: "Nurse or Lab Technician role required" });
    }
    if (user.status !== "active") {
      return res.status(403).json({ message: "Account is not active" });
    }

    let orgId = String(req.headers["x-org-id"] || req.query.orgId || user.orgId || "").trim();
    if (!orgId || !mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(403).json({ message: "orgId is required" });
    }
    if (user.orgId && String(user.orgId) !== orgId) {
      return res.status(403).json({ message: "Org scope mismatch" });
    }

    const org = await Organization.findById(orgId).select("_id name").lean();
    if (!org) return res.status(404).json({ message: "Organization not found" });

    const profile = await StaffProfile.findOne({ userId, orgId }).lean();
    const permissions = profile?.permissions?.length
      ? profile.permissions
      : ["nurse_access", "view_medical_notes", "manage_appointments"];

    req.nurseScope = {
      user,
      orgId,
      userId,
      profile: profile || {},
      permissions,
    };
    return next();
  } catch (e) {
    console.error("[requireLabQueueStaff]", e);
    return res.status(500).json({ message: "Auth check failed" });
  }
}

module.exports = {
  blockNurseForbiddenRoutes,
  requireNurse,
  requireLabQueueStaff,
  hasPermission,
  pathMatchesForbidden,
};
