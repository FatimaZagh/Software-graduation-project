const express = require("express");
const ctrl = require("../controllers/appointmentController");

const router = express.Router();

router.post("/book", (req, res) => ctrl.bookAppointment(req, res));
router.get("/available-dates", (req, res) => ctrl.getAvailableDates(req, res));
router.get("/doctor-active-days/:doctorId", (req, res) => ctrl.getDoctorActiveDays(req, res));
router.get("/available-slots", (req, res) => ctrl.getAvailableSlots(req, res));
router.get("/slots", (req, res) => ctrl.getAvailableSlots(req, res));
router.post("/slots/:slotId/waiting-list", (req, res) => ctrl.postSlotWaitingList(req, res));
router.delete("/slots/:slotId/waiting-list", (req, res) => ctrl.leaveSlotWaitingList(req, res));
router.delete("/waiting-list/:entryId", (req, res) => ctrl.leaveWaitingListEntry(req, res));
router.patch("/:id/dismiss-cancel-alert", (req, res) => ctrl.dismissCancelAlert(req, res));
router.patch("/:id/cancel-by-doctor", (req, res) => ctrl.cancelByDoctor(req, res));
router.patch("/:id/cancel-by-patient", (req, res) => ctrl.cancelByPatient(req, res));
router.patch("/:id/postpone", (req, res) => ctrl.postponeAppointment(req, res));
router.patch("/:id/reschedule", (req, res) => ctrl.rescheduleAppointment(req, res));

module.exports = router;
