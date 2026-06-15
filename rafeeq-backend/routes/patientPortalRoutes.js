const express = require("express");
const ctrl = require("../controllers/patientPortalController");
const rxCtrl = require("../controllers/prescriptionDispensingController");
const routeCtrl = require("../controllers/pharmacyRoutingController");
const diagnosticCtrl = require("../controllers/diagnosticWorkflowController");
const medicalRecordsCtrl = require("../controllers/patientMedicalRecordsController");

const router = express.Router();

router.param("patientUserId", ctrl.validatePatientUser);
router.param("patientId", ctrl.validatePatientUser);

router.get("/:patientUserId/health-profile", ctrl.getHealthProfile);
router.put("/:patientUserId/health-profile", ctrl.putHealthProfile);
router.get("/:patientUserId/medical-records", medicalRecordsCtrl.getMedicalRecords);

router.get("/:patientUserId/booking/suggest", ctrl.getBookingSuggest);
router.post("/:patientUserId/booking/waiting-list", ctrl.postWaitingList);
router.patch("/:patientUserId/appointments/:appointmentId/cancel", ctrl.cancelAppointmentAndNotify);

router.get("/:patientUserId/notifications", ctrl.getNotifications);
router.patch("/:patientUserId/notifications/:notificationId/read", ctrl.patchNotificationRead);

router.get("/:patientUserId/pharmacy/search", ctrl.getPharmacySearch);
router.get("/:patientUserId/pharmacy/catalog", rxCtrl.getPharmacyCatalog);
router.get("/:patientUserId/pharmacy/routing", routeCtrl.getPharmacyRouting);
router.get("/:patientUserId/pharmacy/internal-catalog", routeCtrl.getInternalCatalog);
router.get("/:patientUserId/pharmacy/external-holding", routeCtrl.getExternalHolding);
router.get("/:patientUserId/pharmacy/nearby", ctrl.getNearbyPharmacies);
router.post("/:patientUserId/pharmacy/validate-purchase", rxCtrl.postValidatePurchase);
router.post("/:patientUserId/pharmacy/purchase", rxCtrl.postPharmacyPurchase);
router.get("/:patientUserId/pharmacy/requests", ctrl.getMedicationRequests);
router.get("/:patientUserId/pharmacy/backorders", ctrl.getPatientBackorders);
router.post("/:patientUserId/pharmacy/request", ctrl.postMedicationRequest);
router.get("/:patientUserId/dispensing-prescriptions", rxCtrl.listPatientPrescriptions);

router.get("/:patientUserId/chat/doctors", ctrl.getChatDoctors);
router.get("/:patientUserId/chat/:doctorUserId/messages", ctrl.getChatMessagesPrivate);
router.post("/:patientUserId/chat/:doctorUserId/messages", ctrl.postChatMessagePrivate);

router.get("/:patientUserId/prescriptions", ctrl.getPrescriptions);
router.post("/:patientUserId/prescriptions", ctrl.postPrescriptionDemo);

router.get("/:patientUserId/labs", ctrl.getLabResults);
router.get("/:patientUserId/diagnostic-results", diagnosticCtrl.patientDiagnosticResults);
router.post("/:patientUserId/labs", ctrl.postLabResultDemo);

router.post("/:patientUserId/ratings", ctrl.postVisitRating);
router.get("/:patientUserId/ratings", ctrl.getVisitRatings);

router.post("/:patientUserId/chatbot/medications", ctrl.postMedicationChatbot);

router.get("/:patientUserId/reminders", ctrl.getReminders);
router.post("/:patientUserId/reminders", ctrl.postReminder);
router.put("/:patientUserId/reminders/:reminderId", ctrl.putReminder);
router.delete("/:patientUserId/reminders/:reminderId", ctrl.deleteReminder);
router.post("/:patientUserId/reminders/:reminderId/dose", ctrl.postReminderDoseTaken);

router.get("/:patientUserId/analytics", ctrl.getAnalytics);

module.exports = router;
