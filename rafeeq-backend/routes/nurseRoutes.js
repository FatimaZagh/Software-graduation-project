const express = require("express");
const ctrl = require("../controllers/nursePortalController");
const { requireNurse, hasPermission } = require("../middleware/nurseAuth");

const router = express.Router();

router.use(requireNurse);

router.get("/dashboard", ctrl.getDashboard);

router.get("/patients", hasPermission("view_medical_notes"), ctrl.searchPatients);
router.get("/patients/:patientId/clinical-summary", hasPermission("view_medical_notes"), ctrl.getPatientClinicalSummary);
router.get("/patients/:patientId/file", hasPermission("view_medical_notes"), ctrl.getPatientFile);

router.post("/vitals/:patientId", hasPermission("view_medical_notes"), ctrl.postVitals);
router.put("/vitals/:patientId/:vitalId", hasPermission("view_medical_notes"), ctrl.putVitals);

router.get("/queue/today", hasPermission("manage_appointments"), ctrl.getTodayQueue);
router.post("/visits/:visitId/check-in", hasPermission("manage_appointments"), ctrl.checkInVisit);
router.post("/visits/:visitId/triage", hasPermission("manage_appointments"), ctrl.triageVisit);

router.post("/notes", hasPermission("view_medical_notes"), ctrl.postNursingNote);
router.post("/medications/log", hasPermission("view_medical_notes"), ctrl.logMedication);

router.post("/labs/request", hasPermission("view_medical_notes"), ctrl.requestLab);
router.put("/labs/:labId/upload", hasPermission("view_medical_notes"), ctrl.uploadLabResults);
router.get("/lab-requests/incoming", hasPermission("view_medical_notes"), ctrl.listIncomingLabRequests);
router.put("/lab-requests/:id/submit", hasPermission("view_medical_notes"), ctrl.submitIncomingLabReport);
router.get("/labs/patient/:patientId", hasPermission("view_medical_notes"), ctrl.listPatientLabs);

router.post("/alerts/dispatch", hasPermission("manage_appointments"), ctrl.dispatchAlert);

router.get("/profile", ctrl.getProfile);
router.put("/profile", ctrl.putProfile);
router.post("/profile/password", ctrl.changePassword);
router.post("/leave", ctrl.requestLeave);
router.post("/attendance/check-in", ctrl.attendanceToggle);
router.post("/attendance/check-out", ctrl.attendanceToggle);

module.exports = router;
