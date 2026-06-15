const express = require("express");
const ctrl = require("../controllers/diagnosticWorkflowController");
const { requireTechnician } = require("../middleware/technicianAuth");

const router = express.Router();

function wrap(fn) {
  return async (req, res) => {
    try {
      await fn(req, res);
    } catch (e) {
      console.error("[diagnostic]", e);
      res.status(500).json({ message: e.message || "Server error" });
    }
  };
}

router.use(requireTechnician);

router.get("/lab/pending", wrap(ctrl.listPendingLab));
router.get("/radiology/pending", wrap(ctrl.listPendingRadiology));
router.get("/lab/completed", wrap(ctrl.listCompletedLab));
router.get("/radiology/completed", wrap(ctrl.listCompletedRadiology));
router.get("/lab/:id", wrap(ctrl.getLabOrder));
router.get("/radiology/:id", wrap(ctrl.getRadiologyOrder));
router.put("/lab/:id/submit", wrap(ctrl.submitLab));
router.put("/radiology/:id/submit", wrap(ctrl.submitRadiology));

module.exports = router;
