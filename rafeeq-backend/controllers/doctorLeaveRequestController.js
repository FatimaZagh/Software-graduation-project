const mongoose = require("mongoose");
const leaveRequestController = require("./leaveRequestController");

const LEAVE_TYPES = [
  "Annual Leave",
  "Sick Leave",
  "Short Permission / Emergency Leave",
];

/** GET /api/admin/doctor-leave-requests — unified leaverequests collection */
async function listDoctorLeaveForAdmin(req, res, scoped) {
  req.query = {
    ...(req.query || {}),
    applicantRole: "Doctor",
    status: req.query?.status || "Pending",
  };
  return leaveRequestController.listAllLeaveRequests(req, res, scoped);
}

/** PATCH /api/admin/doctor-leave-requests/:id */
async function decideDoctorLeave(req, res, scoped) {
  return leaveRequestController.updateLeaveStatus(req, res, scoped);
}

/** POST /api/doctor/leave-request — legacy doctor portal path */
async function postLeaveRequest(req, res) {
  const { orgId, doctorUserId, user } = req.doctorScope;
  req.body = {
    ...(req.body || {}),
    leaveType: req.body?.type || req.body?.leaveType,
    startDate: req.body?.startDate || req.body?.fromDate,
    endDate: req.body?.endDate || req.body?.toDate,
    clinicId: req.body?.clinicId || user?.clinicId || null,
  };
  req.headers = req.headers || {};
  if (orgId && !req.header("x-org-id")) {
    req.headers["x-org-id"] = String(orgId);
  }
  return leaveRequestController.submitLeaveRequest(req, res, {
    user: { ...user, _id: doctorUserId, role: "Doctor" },
    orgId,
    clinicId: req.body.clinicId && mongoose.Types.ObjectId.isValid(String(req.body.clinicId))
      ? new mongoose.Types.ObjectId(String(req.body.clinicId))
      : null,
  });
}

module.exports = {
  postLeaveRequest,
  listDoctorLeaveForAdmin,
  decideDoctorLeave,
  LEAVE_TYPES,
};
