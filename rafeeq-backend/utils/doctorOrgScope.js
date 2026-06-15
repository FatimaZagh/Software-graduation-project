const mongoose = require("mongoose");
const Doctor = require("../models/doctor");
const UserModel = require("../models/User");

/**
 * Resolve org scope for a doctor from request headers/query or persisted records.
 */
async function resolveDoctorOrgId(req, user) {
  const header = String(req.headers?.["x-org-id"] || "").trim();
  const query = String(req.query?.orgId || "").trim();
  const body = String(req.body?.orgId || "").trim();

  const candidates = [header, query, body, user?.orgId ? String(user.orgId) : ""];
  for (const c of candidates) {
    if (c && mongoose.Types.ObjectId.isValid(c)) {
      return new mongoose.Types.ObjectId(c);
    }
  }

  if (user?._id) {
    const d = await Doctor.findOne({ userId: user._id }).select("orgId").lean();
    if (d?.orgId && mongoose.Types.ObjectId.isValid(String(d.orgId))) {
      return new mongoose.Types.ObjectId(String(d.orgId));
    }
  }

  return null;
}

async function ensureUserOrgId(userId, orgId) {
  if (!userId || !orgId) return;
  await UserModel.updateOne(
    { _id: userId, $or: [{ orgId: { $exists: false } }, { orgId: null }] },
    { $set: { orgId } }
  );
}

module.exports = { resolveDoctorOrgId, ensureUserOrgId };
