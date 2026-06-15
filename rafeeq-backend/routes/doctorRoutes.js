const express = require("express");
const ctrl = require("../controllers/doctorWorkspaceController");
const adrCtrl = require("../controllers/adverseReportController");
const adrCdss = require("../controllers/adverseReportCdssController");
const precLifecycle = require("../controllers/prescriptionLifecycleController");
const scheduleCtrl = require("../controllers/scheduleChangeRequestController");
const leaveCtrl = require("../controllers/doctorLeaveRequestController");
const diagnosticCtrl = require("../controllers/diagnosticWorkflowController");
const appointmentCtrl = require("../controllers/appointmentController");
const rxDispenseCtrl = require("../controllers/prescriptionDispensingController");
const { requireDoctor } = require("../middleware/doctorAuth");

const router = express.Router();

function wrap(fn) {
  return async (req, res) => {
    try {
      await fn(req, res);
    } catch (e) {
      console.error("[doctor-workspace]", e);
      res.status(500).json({ message: e.message || "Server error" });
    }
  };
}

router.use(requireDoctor);

router.post("/appointments/force-accept", wrap(appointmentCtrl.forceAcceptFromWaitlist));

router.get("/dashboard/stats", wrap(ctrl.getDashboardStats));
router.get("/queue/today", wrap(ctrl.getTodayQueue));
router.put("/availability", wrap(ctrl.putAvailability));
router.get("/profile", wrap(ctrl.getProfile));

router.get("/patients", wrap(ctrl.listPatients));
router.get("/patients/:patientUserId", wrap(ctrl.getPatientEmr));
router.get("/drugs", wrap(ctrl.searchDrugs));

router.post("/diagnoses", wrap(ctrl.postDiagnosis));
router.post("/prescriptions", wrap(ctrl.postPrescription));
router.post("/dispensing-prescriptions", wrap(rxDispenseCtrl.createDoctorPrescription));
router.put("/prescriptions/:id/stop", wrap(ctrl.stopPrescription));
router.post("/prescriptions/:id/stop", wrap(precLifecycle.stopPatientMedication));
router.post("/prescriptions/:id/modify", wrap(precLifecycle.modifyPatientMedication));
router.post("/lab-requests", wrap(ctrl.postLabRequest));
router.post("/radiology-requests", wrap(ctrl.postRadiologyRequest));
router.get("/lab-results/completed", wrap(diagnosticCtrl.doctorCompletedLab));
router.get("/radiology-results/completed", wrap(diagnosticCtrl.doctorCompletedRadiology));
router.get("/diagnostic-unread-counts", wrap(diagnosticCtrl.doctorUnreadCounts));
router.patch("/lab-results/:id/read", wrap(diagnosticCtrl.markLabRead));
router.patch("/radiology-results/:id/read", wrap(diagnosticCtrl.markRadiologyRead));
router.post("/doctor-notes", wrap(ctrl.postDoctorNote));

router.get("/appointments", wrap(ctrl.getAppointments));
router.put("/appointments/:id/status", wrap(ctrl.putAppointmentStatus));

router.post("/nurse-notify", wrap(ctrl.postNurseNotify));
router.post("/clinical/safety-check", wrap(ctrl.postSafetyCheck));

/** ADR reports — same logic as /api/doctor-portal/:id/adverse-reports (x-user-id scoped). */
router.get("/adverse-reports", wrap(async (req, res) => {
  req.doctorUserId = req.doctorScope.doctorUserId;
  return adrCtrl.listDoctorReports(req, res);
}));
router.patch("/adverse-reports/:reportId", wrap(async (req, res) => {
  req.doctorUserId = req.doctorScope.doctorUserId;
  return adrCtrl.updateDoctorAction(req, res);
}));
router.post("/adverse-reports/:reportId/propose-suspension", wrap(async (req, res) => {
  req.doctorUserId = req.doctorScope.doctorUserId;
  return adrCtrl.proposeMedicationSuspension(req, res);
}));

router.get("/adverse-reports/:reportId/detail", wrap((req, res) => adrCdss.getReportDetail(req, res)));
router.patch("/adverse-reports/:reportId/workflow", wrap((req, res) => adrCdss.patchWorkflowStatus(req, res)));
router.post("/adverse-reports/:reportId/mark-emergency", wrap((req, res) => adrCdss.markEmergency(req, res)));
router.post("/adverse-reports/:reportId/stop-medication", wrap((req, res) => adrCdss.stopMedicationForReport(req, res)));
router.post("/adverse-reports/:reportId/modify-medication", wrap((req, res) => adrCdss.modifyMedicationForReport(req, res)));
router.post("/adverse-reports/:reportId/replace-medication", wrap((req, res) => adrCdss.replaceMedicationForReport(req, res)));
router.post("/adverse-reports/:reportId/schedule-urgent-visit", wrap((req, res) => adrCdss.scheduleUrgentVisit(req, res)));
router.post("/adverse-reports/:reportId/er-redirect", wrap((req, res) => adrCdss.setErRedirect(req, res)));
router.post("/adverse-reports/:reportId/clinical-notes", wrap((req, res) => adrCdss.appendClinicalNotes(req, res)));
router.post("/adverse-reports/:reportId/allergy-profile", wrap((req, res) => adrCdss.saveAllergyProfile(req, res)));

router.post("/patient-medications/:id/stop", wrap(precLifecycle.stopPatientMedication));
router.post("/patient-medications/:id/modify", wrap(precLifecycle.modifyPatientMedication));

router.post("/schedule-request", wrap(scheduleCtrl.postScheduleRequest));
router.post("/leave-request", wrap(leaveCtrl.postLeaveRequest));

module.exports = router;
