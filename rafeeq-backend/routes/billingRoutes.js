const express = require("express");
const ctrl = require("../controllers/billingController");
const { requireDoctor } = require("../middleware/doctorAuth");

/**
 * Doctor-facing billing routes mounted at /api/billing
 */
function createBillingRouter() {
  const router = express.Router();

  function wrap(fn) {
    return async (req, res) => {
      try {
        await fn(req, res);
      } catch (e) {
        console.error("[billing]", e);
        if (!res.headersSent) {
          res.status(500).json({ success: false, message: e.message || "Server error" });
        }
      }
    };
  }

  router.use(requireDoctor);
  router.get("/consultation-fee", wrap(ctrl.getDoctorFee));
  router.post("/deduct-session", wrap(ctrl.deductSession));

  return router;
}

module.exports = createBillingRouter;
