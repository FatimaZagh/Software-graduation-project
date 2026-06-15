const mongoose = require("mongoose");
const UserModel = require("../models/User");
const Organization = require("../models/Organization");

const TECH_ROLES = ["Lab Technician", "Radiologist"];

async function requireTechnician(req, res, next) {
  try {
    const userId = String(req.headers["x-user-id"] || "").trim();
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(401).json({ message: "x-user-id required" });
    }

    const user = await UserModel.findById(userId).lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    if (!TECH_ROLES.includes(user.role)) {
      return res.status(403).json({ message: "Lab Technician or Radiologist role required" });
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

    req.technicianScope = {
      user,
      orgId,
      userId,
      clinicId: user.clinicId ? String(user.clinicId) : "",
      role: user.role,
    };
    return next();
  } catch (e) {
    console.error("[requireTechnician]", e);
    return res.status(500).json({ message: "Auth check failed" });
  }
}

module.exports = { requireTechnician, TECH_ROLES };
