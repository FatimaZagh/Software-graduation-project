const express = require("express");
const superAdminController = require("../controllers/superAdminController");
const facilityApprovalController = require("../controllers/facilityApprovalController");

const router = express.Router();

// Level 1 — organizations / clinics (with and without trailing slash)
router.get("/organizations", superAdminController.getOrganizations);
router.get("/organizations/", superAdminController.getOrganizations);
router.get("/organizations/pending", superAdminController.listPendingOrganizations);
router.get("/organizations/pending/", superAdminController.listPendingOrganizations);
router.get("/pending-orgs", superAdminController.listPendingOrganizations);

// Facility approval (aliases for /api/admin/facilities)
router.get("/facilities/pending", facilityApprovalController.listPendingFacilities);
router.get("/facilities/:id", facilityApprovalController.getFacilityForReview);
router.post("/facilities/:id/approve", facilityApprovalController.approveFacility);
router.post("/facilities/:id/reject", facilityApprovalController.rejectFacility);
router.post("/organizations/:orgId/approve", facilityApprovalController.approveFacility);
router.post("/organizations/:orgId/reject", facilityApprovalController.rejectFacility);

// Pending registration & staff queues (super-admin actions)
router.post(
  "/pending-registrations/:requestId/approve",
  superAdminController.approvePendingRegistration
);
router.post(
  "/pending-registrations/:requestId/reject",
  superAdminController.rejectPendingRegistration
);
router.post("/pending-staff/:userId/approve", superAdminController.approvePendingStaffUser);
router.post("/pending-staff/:userId/reject", superAdminController.rejectPendingStaffUser);

// Level 4 — global queues & billing
router.get("/pending-applications", superAdminController.getPendingApplications);
router.get("/medical-orders-feed", superAdminController.getMedicalOrdersFeed);
router.get("/medical-orders", superAdminController.getMedicalOrdersFeed);
router.get("/financial-ledger", superAdminController.getFinancialLedger);
router.get("/ledger", superAdminController.getFinancialLedger);

// Pharmacy drill-down (super-admin read-only analytics)
router.get("/pharmacies/:pharmacyId/details", superAdminController.getPharmacyDetails);

// Level 2 — clinic/org staff (orgId and clinicId aliases)
router.get("/organizations/:orgId", superAdminController.getOrganizationDetail);
router.get("/organizations/:orgId/staff", superAdminController.getClinicStaff);

// Level 3 — staff CRUD
router.get("/organizations/:orgId/staff/:userId", superAdminController.getStaffMember);
router.put("/organizations/:orgId/staff/:userId", superAdminController.updateStaffMember);
router.patch("/organizations/:orgId/staff/:userId/status", superAdminController.updateStaffStatus);
router.put("/staff/:staffId", superAdminController.updateStaffMember);

module.exports = router;
