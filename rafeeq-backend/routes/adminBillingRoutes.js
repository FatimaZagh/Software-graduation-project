const express = require("express");
const billingCtrl = require("../controllers/billingController");
const orgCtrl = require("../controllers/orgAdminExtendedController");

/**
 * Org-admin billing API — mounted at /api/admin/billing
 * Matches Flutter: GET /ledger, GET /metrics, payroll preview/generate
 */
function createAdminBillingRouter(deps) {
  const router = express.Router();
  const { requireOrgAdmin } = deps;

  function wrap(handler) {
    return async (req, res) => {
      try {
        const scoped = await requireOrgAdmin(req, res);
        if (!scoped) return;
        await handler(req, res, scoped);
      } catch (e) {
        console.error("[admin/billing]", e);
        if (!res.headersSent) {
          res.status(e.status || 500).json({
            success: false,
            message: e.message || "Server error",
          });
        }
      }
    };
  }

  router.get("/ledger", wrap(billingCtrl.getLedger));
  router.get("/metrics", wrap(billingCtrl.getMetrics));
  router.get("/invoices", wrap(orgCtrl.listInvoices));
  router.post("/invoices", wrap(orgCtrl.createInvoice));
  router.get("/payroll/preview", wrap(billingCtrl.previewPayroll));
  router.post("/payroll/generate", wrap(billingCtrl.generatePayroll));
  router.get("/payroll/slips", wrap(billingCtrl.listPayrollSlips));

  return router;
}

module.exports = createAdminBillingRouter;
