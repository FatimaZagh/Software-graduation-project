const RegistrationRequest = require("../models/registrationRequest");
const {
  buildPendingRegistrationQuery,
  findPendingRegistrationById,
  approveRegistrationRequest,
} = require("../utils/registrationRequestScope");

/** GET /api/admin/pending-registrations (and legacy /pending-requests, /requests) */
async function listPending(req, res, scoped) {
  try {
    const filter = await buildPendingRegistrationQuery(scoped.orgId);
    const list = await RegistrationRequest.find(filter)
      .sort({ createdAt: -1 })
      .limit(500)
      .lean();

    const rows = list.map((row) => {
      const out = { ...row };
      if (out.doctorProfile && typeof out.doctorProfile === "object") {
        const p = { ...out.doctorProfile };
        const raw = p.consultationFee;
        p.consultationFee = raw != null && raw !== "" ? Number(raw) || 0 : 0;
        out.doctorProfile = p;
      }
      return out;
    });

    res.json(rows);
  } catch (e) {
    console.error("[admin/pending-registrations]", e);
    res.status(500).json({ success: false, message: e.message || "Error loading pending registrations" });
  }
}

/** POST /api/admin/pending-registrations/:requestId/approve */
async function approve(req, res, scoped) {
  const requestId = String(req.params.requestId || "").trim();
  const rr = await findPendingRegistrationById(requestId, scoped.orgId);
  if (!rr) return res.status(404).json({ message: "Request not found" });

  try {
    const { newUser } = await approveRegistrationRequest(rr, scoped.orgId);
    console.log("[approve-registration] success userId=%s email=%s role=%s", String(newUser._id), newUser.email, newUser.role);
    res.json({ message: "Approved", userId: String(newUser._id) });
  } catch (e) {
    console.error("[approve-registration] failed:", e.message);
    if (e.message && e.message.includes("password credentials")) {
      return res.status(400).json({ message: e.message });
    }
    throw e;
  }
}

/** POST /api/admin/pending-registrations/:requestId/reject */
async function reject(req, res, scoped) {
  const requestId = String(req.params.requestId || "").trim();
  const rr = await findPendingRegistrationById(requestId, scoped.orgId);
  if (!rr) return res.status(404).json({ message: "Request not found" });
  await RegistrationRequest.deleteOne({ _id: rr._id });
  res.json({ message: "Rejected" });
}

module.exports = { listPending, approve, reject };
