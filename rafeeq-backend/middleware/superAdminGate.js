const jwt = require("jsonwebtoken");

const JWT_SECRET =
  process.env.JWT_SECRET ||
  "CHANGE_ME_RAFEEQ_JWT_SECRET_GENERATE_STRONG_VALUE_FOR_PRODUCTION";
const PLATFORM_SUPER_ADMIN_LOGIN = String(
  process.env.PLATFORM_SUPER_ADMIN_LOGIN || "admin"
).trim();

async function superAdminGate(req, res, next) {
  const authHeader = String(req.header("authorization") || "").trim();
  if (!authHeader.startsWith("Bearer ")) {
    return res
      .status(401)
      .json({ success: false, message: "Platform Super Admin Bearer token required" });
  }
  try {
    const decoded = jwt.verify(
      authHeader.slice("Bearer ".length).trim(),
      JWT_SECRET
    );
    if (decoded.typ === "platform_super" && decoded.role === "SuperAdmin") {
      req.superAdmin = {
        role: "SuperAdmin",
        platformSuperAdmin: true,
        email: PLATFORM_SUPER_ADMIN_LOGIN,
      };
      return next();
    }
    return res.status(403).json({ message: "Not a platform Super Admin token" });
  } catch (e) {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}

module.exports = { superAdminGate };
