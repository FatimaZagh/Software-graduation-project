const express = require("express");
const ctrl = require("../controllers/paymentController");

const router = express.Router();

router.get("/saved-cards", (req, res) => ctrl.getSavedCards(req, res));
router.get("/history", (req, res) => ctrl.getPaymentHistory(req, res));
router.post("/saved-cards", (req, res) => ctrl.saveCard(req, res));
router.post("/checkout", (req, res) => ctrl.processCheckout(req, res));

module.exports = router;
