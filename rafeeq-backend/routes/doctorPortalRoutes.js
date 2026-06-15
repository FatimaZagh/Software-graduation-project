const express = require("express");
const ctrl = require("../controllers/doctorPortalController");
const adrCtrl = require("../controllers/adverseReportController");

const router = express.Router({ mergeParams: true });

router.param("doctorUserId", ctrl.validateDoctorUser);

router.get("/:doctorUserId/profile", ctrl.getProfile);
router.put("/:doctorUserId/profile", ctrl.putProfile);
router.get("/:doctorUserId/clinic-services", ctrl.getClinicServices);
router.put("/:doctorUserId/clinic-services", ctrl.putClinicServices);

router.get("/:doctorUserId/appointments", ctrl.getAppointments);
router.patch("/:doctorUserId/appointments/:appointmentId/booking", ctrl.patchAppointmentBooking);
router.patch("/:doctorUserId/appointments/:appointmentId/reschedule", ctrl.patchAppointmentReschedule);
router.patch("/:doctorUserId/appointments/:appointmentId/visit", ctrl.patchAppointmentVisit);

router.get("/:doctorUserId/waiting-list", ctrl.getWaitingList);

router.get("/:doctorUserId/patient/:patientUserId/preconsult", ctrl.getPreconsult);

router.get("/:doctorUserId/session/:appointmentId", ctrl.getSession);
router.put("/:doctorUserId/session/:appointmentId", ctrl.putSession);

router.post("/:doctorUserId/prescriptions", ctrl.postPrescription);

router.get("/:doctorUserId/chat/patients", ctrl.getChatPatients);
router.get("/:doctorUserId/chat/:patientUserId/messages", ctrl.getChatMessages);
router.post("/:doctorUserId/chat/:patientUserId/messages", ctrl.postChatMessage);

router.get("/:doctorUserId/reviews", ctrl.getReviews);
router.get("/:doctorUserId/analytics", ctrl.getAnalytics);
router.get("/:doctorUserId/statistics", ctrl.getAnalytics);

router.get("/:doctorUserId/notifications", ctrl.getNotifications);
router.patch("/:doctorUserId/notifications/:notificationId/read", ctrl.patchNotificationRead);

router.get("/:doctorUserId/adverse-reports", adrCtrl.listDoctorReports);
router.patch("/:doctorUserId/adverse-reports/:reportId", adrCtrl.updateDoctorAction);
router.post(
  "/:doctorUserId/adverse-reports/:reportId/propose-suspension",
  adrCtrl.proposeMedicationSuspension
);

module.exports = router;
