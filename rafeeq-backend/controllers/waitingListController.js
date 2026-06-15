const mongoose = require("mongoose");
const WaitingListEntry = require("../models/waitingListEntry");
const { enrichWaitingListEntries } = require("../utils/waitingListHelpers");

function resolvePatientUserId(req) {
  return String(
    req.query?.patientUserId ||
      req.query?.patientId ||
      req.body?.patientUserId ||
      req.body?.patientId ||
      req.params?.patientUserId ||
      ""
  ).trim();
}

/** GET /api/waiting-list/my-entries?patientUserId= */
async function getMyWaitingListEntries(req, res) {
  try {
    const patientUserId = resolvePatientUserId(req);
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "patientUserId is required" });
    }

    const entries = await WaitingListEntry.find({
      patientUserId,
      status: "Active",
    })
      .sort({ watchSlotDate: 1, watchSlotTime: 1, createdAt: 1 })
      .lean();

    const waitingLists = await enrichWaitingListEntries(entries);

    return res.json({
      success: true,
      entries: waitingLists,
      waitingLists,
    });
  } catch (error) {
    console.error("[getMyWaitingListEntries]", error);
    return res.status(500).json({ message: "Error loading waiting list entries" });
  }
}

/** DELETE /api/waiting-list/leave/:entryId?patientUserId= */
async function leaveWaitingList(req, res) {
  try {
    const entryId = String(req.params.entryId || "").trim();
    const patientUserId = resolvePatientUserId(req);

    if (!mongoose.Types.ObjectId.isValid(entryId)) {
      return res.status(400).json({ success: false, message: "Invalid waiting list entry id" });
    }
    if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ success: false, message: "patientUserId is required" });
    }

    const entry = await WaitingListEntry.findOneAndDelete({
      _id: entryId,
      patientUserId,
      status: "Active",
    }).lean();

    if (!entry) {
      return res.status(404).json({
        success: false,
        message: "Waiting list entry not found or already removed",
      });
    }

    return res.json({
      success: true,
      message: "You have left the waiting list for this slot.",
      data: entry,
    });
  } catch (error) {
    console.error("[leaveWaitingList]", error);
    return res.status(500).json({ success: false, message: "Internal server error" });
  }
}

module.exports = {
  getMyWaitingListEntries,
  leaveWaitingList,
};
