const express = require("express");
const ctrl = require("../controllers/leaveRequestController");
const { createLeaveAuthMiddleware } = require("../middleware/leaveAuth");

/**
 * Unified leave requests — mounted at /api/leaves
 */
function createLeaveRouter(deps) {
  const router = express.Router();
  const { requireAuth, requireOrgAdmin } = deps;
  const authMiddleware = createLeaveAuthMiddleware(requireAuth);

  function wrap(handler, { admin = false } = {}) {
    return async (req, res) => {
      try {
        let scoped;
        if (admin) {
          scoped = await requireOrgAdmin(req, res);
        } else {
          scoped = await ctrl.requireLeaveApplicantScope(req, res, requireAuth);
        }
        if (!scoped) return;
        await handler(req, res, scoped);
      } catch (e) {
        console.error("[leaves]", e);
        if (!res.headersSent) {
          res.status(e.status || 500).json({
            success: false,
            message: e.message || "Server error",
          });
        }
      }
    };
  }

  router.post("/request", wrap(ctrl.submitLeaveRequest));
  router.get("/my-requests", authMiddleware, ctrl.getMyRequests);
  router.get("/all", wrap(ctrl.listAllLeaveRequests, { admin: true }));
  router.put("/:id/status", wrap(ctrl.updateLeaveStatus, { admin: true }));

  return router;
}

module.exports = createLeaveRouter;
