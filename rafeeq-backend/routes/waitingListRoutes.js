const express = require("express");
const ctrl = require("../controllers/waitingListController");

const router = express.Router();

router.get("/my-entries", (req, res) => ctrl.getMyWaitingListEntries(req, res));
router.delete("/leave/:entryId", (req, res) => ctrl.leaveWaitingList(req, res));

module.exports = router;
