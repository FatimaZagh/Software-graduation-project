const mongoose = require("mongoose");
const ScheduleChangeRequest = require("../models/scheduleChangeRequest");
const Doctor = require("../models/doctor");
const UserModel = require("../models/User");
const UserNotification = require("../models/userNotification");
const {
  resolveSchedulePayload,
  deriveWorkingHours,
  enrichScheduleRequestForAdmin,
} = require("../utils/dynamicSchedule");

async function notifyOrgAdmins(orgId, title, body, meta) {
  const admins = await UserModel.find({
    orgId,
    role: "Organization Admin",
    status: "active",
  })
    .select("_id")
    .lean();
  for (const a of admins) {
    await UserNotification.create({
      orgId,
      userId: a._id,
      role: "orgadmin",
      type: "schedule_change_request",
      title,
      body,
      read: false,
      meta,
    });
  }
}

/** POST /api/doctor/schedule-request */
async function postScheduleRequest(req, res) {
  const { orgId, doctorUserId, user, doctorProfile } = req.doctorScope;
  const { dynamicSchedule, workSchedule: schedule } = resolveSchedulePayload(req.body);
  if (!schedule.length) {
    return res.status(400).json({ message: "proposedSchedule (Mon–Sun map) or work schedule is required" });
  }

  const existing = await ScheduleChangeRequest.findOne({
    doctorUserId,
    orgId,
    status: "pending",
  }).lean();
  if (existing) {
    return res.status(409).json({
      message: "You already have a pending schedule change request awaiting clinic admin approval.",
    });
  }

  const workingHours = deriveWorkingHours(schedule);
  const doc = await ScheduleChangeRequest.create({
    orgId,
    doctorUserId,
    doctorDisplayName: doctorProfile?.displayName || user?.name || "Doctor",
    dynamicSchedule,
    proposedSchedule: schedule,
    requestedHours: schedule,
    workingHours,
    status: "pending",
  });

  await notifyOrgAdmins(
    orgId,
    "Doctor schedule change request",
    `${doc.doctorDisplayName} requested updated working hours.`,
    { requestId: String(doc._id), doctorUserId: String(doctorUserId) }
  );

  res.status(201).json({
    message: "Schedule change request submitted for admin approval",
    requestId: String(doc._id),
    status: "pending",
  });
}

/** GET /api/admin/schedule-change-requests — full schedule payloads for admin review UI */
async function listPendingForAdmin(req, res, scoped) {
  const list = await ScheduleChangeRequest.find({ orgId: scoped.orgId, status: "pending" })
    .select(
      "orgId doctorUserId doctorDisplayName dynamicSchedule proposedSchedule requestedHours workingHours status createdAt updatedAt"
    )
    .sort({ createdAt: -1 })
    .limit(200)
    .lean();
  res.json(list.map(enrichScheduleRequestForAdmin));
}

/** POST /api/admin/schedule-change-requests/:requestId/approve */
async function approveScheduleRequest(req, res, scoped) {
  try {
    const requestId = String(req.params.requestId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(requestId)) {
      return res.status(400).json({ message: "Invalid requestId" });
    }

    const rr = await ScheduleChangeRequest.findOne({
      _id: requestId,
      orgId: scoped.orgId,
      status: "pending",
    });

    if (!rr) {
      return res.status(404).json({ message: "Pending schedule request not found" });
    }

    const schedule = rr.proposedSchedule?.length ? rr.proposedSchedule : rr.requestedHours || [];
    const workingHours = rr.workingHours || deriveWorkingHours(schedule);
    const dynamicSchedule =
      rr.dynamicSchedule && Object.keys(rr.dynamicSchedule).length
        ? rr.dynamicSchedule
        : undefined;

    const doctorSet = {
      workSchedule: schedule,
      workingHours,
      workingDays: schedule.map((d) => d.dayName || String(d.dayOfWeek)).filter(Boolean),
    };
    if (dynamicSchedule) doctorSet.dynamicSchedule = dynamicSchedule;

    await Doctor.updateOne({ userId: rr.doctorUserId }, { $set: doctorSet });

    await ScheduleChangeRequest.updateOne(
      { _id: requestId, orgId: scoped.orgId, status: "pending" },
      {
        $set: {
          status: "approved",
          reviewedByAdminUserId: scoped.user._id,
          reviewedAt: new Date(),
        },
      }
    );

    await UserNotification.create({
      orgId: scoped.orgId,
      userId: rr.doctorUserId,
      role: "Doctor",
      type: "schedule_change_approved",
      title: "Schedule approved",
      body: "Your working hours update has been approved by the clinic administrator.",
      read: false,
      meta: { requestId: String(rr._id) },
    });

    res.json({ message: "Schedule approved and applied", requestId: String(rr._id) });
  } catch (e) {
    console.error("[schedule-approve]", e);
    res.status(500).json({ message: e.message || "Error approving schedule request" });
  }
}

/** POST /api/admin/schedule-change-requests/:requestId/reject */
async function rejectScheduleRequest(req, res, scoped) {
  const requestId = String(req.params.requestId || "").trim();
  if (!mongoose.Types.ObjectId.isValid(requestId)) {
    return res.status(400).json({ message: "Invalid requestId" });
  }

  const rr = await ScheduleChangeRequest.findOneAndUpdate(
    { _id: requestId, orgId: scoped.orgId, status: "pending" },
    {
      $set: {
        status: "rejected",
        reviewedByAdminUserId: scoped.user._id,
        reviewedAt: new Date(),
        rejectionReason: req.body?.rejectionReason != null ? String(req.body.rejectionReason) : "",
      },
    },
    { new: true }
  ).lean();

  if (!rr) return res.status(404).json({ message: "Pending schedule request not found" });

  await UserNotification.create({
    orgId: scoped.orgId,
    userId: rr.doctorUserId,
    role: "Doctor",
    type: "schedule_change_rejected",
    title: "Schedule change declined",
    body: rr.rejectionReason || "Your schedule change request was not approved.",
    read: false,
    meta: { requestId: String(rr._id) },
  });

  res.json({ message: "Schedule request rejected", requestId: String(rr._id) });
}

module.exports = {
  postScheduleRequest,
  listPendingForAdmin,
  approveScheduleRequest,
  rejectScheduleRequest,
};
