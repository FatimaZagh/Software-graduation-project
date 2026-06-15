const express = require("express");
const facilityApprovalController = require("../controllers/facilityApprovalController");

const router = express.Router();

/**
 * Super Admin facility approval workflow.
 * Mounted at /api/admin/facilities (protected by superAdminGate in server.js).
 */
router.get("/pending", facilityApprovalController.listPendingFacilities);
router.get("/:id", facilityApprovalController.getFacilityForReview);
router.post("/:id/approve", facilityApprovalController.approveFacility);
router.post("/:id/reject", facilityApprovalController.rejectFacility);

module.exports = router;
