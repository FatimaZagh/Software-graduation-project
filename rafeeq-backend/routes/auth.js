const express = require("express");
const { registerDoctorPublic } = require("../controllers/doctorRegistrationController");
const { registerStaffPublic } = require("../controllers/staffRegistrationController");
const pharmacyController = require("../controllers/pharmacyController");

const router = express.Router();

router.post("/register/doctor", (req, res) => registerDoctorPublic(req, res));
router.post("/register/staff", (req, res) => registerStaffPublic(req, res));
router.post("/register-pharmacy", pharmacyController.registerExternalPharmacyWithPharmacist);

module.exports = router;
