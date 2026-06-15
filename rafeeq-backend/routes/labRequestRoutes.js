const express = require("express");
const ctrl = require("../controllers/nursePortalController");
const { requireLabQueueStaff, hasPermission } = require("../middleware/nurseAuth");

const router = express.Router();

router.use(requireLabQueueStaff);

/** GET /api/lab-requests — pending doctor lab orders (labrequests collection) */
router.get("/", hasPermission("view_medical_notes"), ctrl.listIncomingLabRequests);

/** Alias kept for older clients */
router.get("/incoming", hasPermission("view_medical_notes"), ctrl.listIncomingLabRequests);

/** PUT /api/lab-requests/:id/submit — finalize report (Completed + locked) */
router.put("/:id/submit", hasPermission("view_medical_notes"), ctrl.submitIncomingLabReport);

module.exports = router;
