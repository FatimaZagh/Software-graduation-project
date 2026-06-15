const express = require("express");
const ctrl = require("../controllers/pharmacyController");

const router = express.Router();

router.post("/create", ctrl.createPharmacy);
router.post("/register", ctrl.registerExternalPharmacy);
router.get("/drugs", ctrl.listDrugs);
router.get("/medication-requests", ctrl.listMedicationRequests);
router.get("/requests", ctrl.listMedicationRequests);
router.patch("/medication-requests/:requestId", ctrl.patchMedicationRequest);
router.put("/requests/:requestId/status", ctrl.patchMedicationRequest);
router.get("/user/:userId/dashboard", ctrl.getDashboardByUser);
router.get("/user/:userId/pharmacy", ctrl.getPharmacyByUser);
router.get("/user/:userId/profile", ctrl.getProfile);
router.put("/profile", ctrl.updateProfileByUser);
router.put("/pharmacist/profile", ctrl.updatePharmacistProfile);
router.get("/:pharmacyId/dashboard", ctrl.getDashboard);
router.get("/:pharmacyId/inventory", ctrl.listInventory);
router.post("/:pharmacyId/inventory", ctrl.addInventory);
router.post("/:pharmacyId/inventory/new-drug", ctrl.createNewInventoryDrug);
router.patch("/:pharmacyId/inventory/:drugId", ctrl.updateInventory);
router.delete("/:pharmacyId/inventory/:drugId", ctrl.deleteInventory);
router.post("/:pharmacyId/dispense", ctrl.dispense);
router.get("/:pharmacyId/inventory-logs", ctrl.listInventoryLogs);
router.get("/:pharmacyId/analytics", ctrl.getAnalytics);
router.get("/:pharmacyId/notifications", ctrl.getNotifications);
router.patch("/:pharmacyId/settings", ctrl.updateSettings);
router.put("/:pharmacyId/update-profile", ctrl.updateSettings);

module.exports = router;
