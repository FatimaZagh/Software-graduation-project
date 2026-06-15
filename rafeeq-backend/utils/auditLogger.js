const AuditLog = require("../models/auditLog");

async function writeAuditLog({ orgId, userId, action, targetId, targetType, req, successStatus = true, metadata = {} }) {
  try {
    const ip =
      String(req?.headers?.["x-forwarded-for"] || "")
        .split(",")[0]
        .trim() ||
      req?.socket?.remoteAddress ||
      "";
    await AuditLog.create({
      orgId,
      userId,
      action,
      targetId: targetId != null ? String(targetId) : "",
      targetType: targetType || "",
      ipAddress: ip,
      successStatus: Boolean(successStatus),
      metadata,
    });
  } catch (e) {
    console.error("[audit]", e.message);
  }
}

module.exports = { writeAuditLog };
