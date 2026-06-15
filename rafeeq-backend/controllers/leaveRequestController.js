const mongoose = require("mongoose");
const LeaveRequest = require("../models/LeaveRequest");
const UserModel = require("../models/User");
const Patient = require("../models/patient");
const Doctor = require("../models/doctor");
const UserNotification = require("../models/userNotification");

const ALLOWED_LEAVE_TYPES = [
  "Sick Leave",
  "Casual",
  "Annual Leave",
  "Emergency Leave",
  "Short Permission",
];

function normalizeStatus(raw) {
  const v = String(raw || "").trim();
  if (/^approved$/i.test(v)) return "Approved";
  if (/^rejected$/i.test(v)) return "Rejected";
  if (/^pending$/i.test(v)) return "Pending";
  return null;
}

function normalizeApplicantRole(userRole) {
  const role = String(userRole || "").trim();
  if (role === "Doctor") return "Doctor";
  if (role === "Patient") return "Patient";
  return "Staff";
}

function resolveAdminClinicId(req, scoped) {
  const fromQuery = String(req.query?.clinicId || req.header("x-clinic-id") || "").trim();
  if (fromQuery && mongoose.Types.ObjectId.isValid(fromQuery)) {
    return new mongoose.Types.ObjectId(fromQuery);
  }
  const userClinic = scoped?.user?.clinicId;
  if (userClinic && mongoose.Types.ObjectId.isValid(String(userClinic))) {
    return new mongoose.Types.ObjectId(String(userClinic));
  }
  return null;
}

/** Resolve org for doctors, patients, and staff submitting leave. */
async function resolveApplicantOrgId(req, user) {
  const explicit = String(req.header("x-org-id") || req.query.orgId || req.body?.orgId || "").trim();
  if (explicit && mongoose.Types.ObjectId.isValid(explicit)) {
    return new mongoose.Types.ObjectId(explicit);
  }
  if (user?.orgId && mongoose.Types.ObjectId.isValid(String(user.orgId))) {
    return new mongoose.Types.ObjectId(String(user.orgId));
  }
  if (String(user?.role || "") === "Patient") {
    const patient = await Patient.findOne({ userId: user._id }).select("orgId").lean();
    if (patient?.orgId && mongoose.Types.ObjectId.isValid(String(patient.orgId))) {
      return new mongoose.Types.ObjectId(String(patient.orgId));
    }
  }
  if (String(user?.role || "") === "Doctor") {
    const doctor = await Doctor.findOne({ userId: user._id }).select("orgId clinicId").lean();
    if (doctor?.orgId && mongoose.Types.ObjectId.isValid(String(doctor.orgId))) {
      return new mongoose.Types.ObjectId(String(doctor.orgId));
    }
  }
  return null;
}

/** Resolve clinic/facility for leave submissions (doctors, staff, patients). */
async function resolveApplicantClinicId(req, user, body = {}) {
  const payload = body && typeof body === "object" ? body : {};
  const fromBody = String(payload.clinicId || payload.facilityId || "").trim();
  if (fromBody && mongoose.Types.ObjectId.isValid(fromBody)) {
    return new mongoose.Types.ObjectId(fromBody);
  }

  if (String(user?.role || "") === "Doctor") {
    const doctor = await Doctor.findOne({ userId: user._id }).select("clinicId").lean();
    if (doctor?.clinicId && mongoose.Types.ObjectId.isValid(String(doctor.clinicId))) {
      return new mongoose.Types.ObjectId(String(doctor.clinicId));
    }
  }

  if (String(user?.role || "") === "Patient") {
    const patient = await Patient.findOne({ userId: user._id }).select("defaultBranch clinicId").lean();
    const clinicRef = patient?.clinicId || patient?.defaultBranch;
    if (clinicRef && mongoose.Types.ObjectId.isValid(String(clinicRef))) {
      return new mongoose.Types.ObjectId(String(clinicRef));
    }
  }

  return null;
}

async function requireLeaveApplicantScope(req, res, requireAuth) {
  const user = await requireAuth(req, res);
  if (!user) return null;
  const orgId = await resolveApplicantOrgId(req, user);
  if (!orgId) {
    res.status(403).json({ message: "orgId is required for leave requests" });
    return null;
  }
  const clinicId = await resolveApplicantClinicId(req, user, req.body || {});
  return { user, orgId, clinicId };
}

function parseLeaveDate(value, fieldName) {
  if (value == null || value === "") {
    throw Object.assign(new Error(`${fieldName} is required`), { status: 400 });
  }
  const d = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(d.getTime())) {
    throw Object.assign(new Error(`${fieldName} must be a valid date`), { status: 400 });
  }
  return d;
}

function formatRow(row, applicant, doctorProfile) {
  const u = applicant || {};
  const d = doctorProfile || {};
  const displayName = u.name || d.fullName || d.name || u.email || "Applicant";
  return {
    ...row,
    id: String(row._id),
    _id: row._id,
    applicantName: displayName,
    applicantEmail: u.email || d.email || "",
    doctorName: d.fullName || d.name || u.name || "",
    doctorEmail: d.email || u.email || "",
    fromDate: row.startDate,
    toDate: row.endDate,
    type: row.leaveType,
    leaveType: row.leaveType,
    clinicId: row.clinicId ? String(row.clinicId) : null,
  };
}

async function enrichLeaveRows(list) {
  if (!list.length) return [];

  const applicantIds = [...new Set(list.map((r) => String(r.applicantId)).filter(Boolean))];
  const [users, doctors] = await Promise.all([
    UserModel.find({ _id: { $in: applicantIds } })
      .select("name email role")
      .lean(),
    Doctor.find({ userId: { $in: applicantIds } })
      .select("userId fullName email clinicId")
      .lean(),
  ]);

  const userMap = Object.fromEntries(users.map((u) => [String(u._id), u]));
  const doctorMap = Object.fromEntries(doctors.map((d) => [String(d.userId), d]));

  return list.map((row) =>
    formatRow(row, userMap[String(row.applicantId)], doctorMap[String(row.applicantId)])
  );
}

function buildAdminLeaveQuery(req, scoped) {
  const statusRaw = String(req.query?.status || "Pending").trim();
  const q = { orgId: scoped.orgId };

  if (statusRaw && !/^all$/i.test(statusRaw)) {
    const normalized = normalizeStatus(statusRaw);
    if (normalized) q.status = normalized;
  }

  const roleFilter = String(req.query?.applicantRole || "").trim();
  if (roleFilter) q.applicantRole = roleFilter;

  const clinicId = resolveAdminClinicId(req, scoped);
  if (clinicId) q.clinicId = clinicId;

  return q;
}

async function notifyOrgAdmins(orgId, title, body, meta) {
  const admins = await UserModel.find({
    orgId,
    role: "Organization Admin",
    status: "active",
  })
    .select("_id")
    .lean();
  for (const admin of admins) {
    await UserNotification.create({
      orgId,
      userId: admin._id,
      role: "orgadmin",
      type: "leave_request",
      title,
      body,
      read: false,
      meta,
    });
  }
}

/** POST /api/leaves/request */
async function submitLeaveRequest(req, res, scoped) {
  const { user, orgId, clinicId } = scoped;
  const body = req.body || {};
  const leaveTypeRaw = String(body.leaveType || body.type || "Casual").trim();
  const leaveType = leaveTypeRaw || "Casual";
  const reason = body.reason != null ? String(body.reason).trim() : "";

  const startDate = parseLeaveDate(body.startDate || body.fromDate, "startDate");
  const endDate = parseLeaveDate(body.endDate || body.toDate, "endDate");
  if (startDate > endDate) {
    return res.status(400).json({ message: "startDate must be on or before endDate" });
  }

  const applicantRole = normalizeApplicantRole(user.role);
  const resolvedClinicId =
    clinicId || (await resolveApplicantClinicId(req, user, body));

  const doc = await LeaveRequest.create({
    orgId,
    clinicId: resolvedClinicId || null,
    applicantId: user._id,
    applicantRole,
    leaveType,
    reason,
    startDate,
    endDate,
    status: "Pending",
  });

  await notifyOrgAdmins(
    orgId,
    "New leave request",
    `${user.name || applicantRole} submitted ${leaveType}.`,
    {
      requestId: String(doc._id),
      applicantId: String(user._id),
      applicantRole,
      clinicId: resolvedClinicId ? String(resolvedClinicId) : null,
    }
  );

  res.status(201).json({
    success: true,
    message: "Leave request submitted",
    request: formatRow(doc.toObject(), user),
  });
}

/** GET /api/leaves/my-requests */
async function getMyRequests(req, res) {
  try {
    const userId = req.user?.id || req.user?._id;
    if (!userId || !mongoose.Types.ObjectId.isValid(String(userId))) {
      return res.status(401).json({ message: "Authentication required" });
    }
    const requests = await LeaveRequest.find({ applicantId: userId })
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();
    return res.status(200).json(await enrichLeaveRows(requests));
  } catch (error) {
    console.error("[leaves/getMyRequests]", error);
    if (!res.headersSent) {
      res.status(500).json({ message: error.message || "Error fetching leave requests" });
    }
  }
}

/** @deprecated use getMyRequests */
async function listMyLeaveRequests(req, res, scoped) {
  req.user = req.user || scoped?.user;
  if (req.user && !req.user.id) {
    req.user.id = String(req.user._id);
  }
  return getMyRequests(req, res);
}

/** GET /api/leaves/all — org admin queue with optional clinic filter */
async function listAllLeaveRequests(req, res, scoped) {
  const q = buildAdminLeaveQuery(req, scoped);
  const list = await LeaveRequest.find(q).sort({ createdAt: -1 }).limit(500).lean();
  return res.status(200).json(await enrichLeaveRows(list));
}

/** PUT /api/leaves/:id/status */
async function updateLeaveStatus(req, res, scoped) {
  const id = String(req.params.id || "").trim();
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return res.status(400).json({ message: "Invalid leave request id" });
  }

  const status = normalizeStatus(req.body?.status);
  if (!status || !["Approved", "Rejected"].includes(status)) {
    return res.status(400).json({ message: "status must be Approved or Rejected" });
  }

  const rejectionReason =
    status === "Rejected" && req.body?.rejectionReason != null
      ? String(req.body.rejectionReason).trim()
      : "";

  const existingQuery = {
    _id: id,
    orgId: scoped.orgId,
    status: "Pending",
  };
  const clinicId = resolveAdminClinicId(req, scoped);
  if (clinicId) existingQuery.clinicId = clinicId;

  const existing = await LeaveRequest.findOne(existingQuery).lean();
  if (!existing) {
    return res.status(404).json({ message: "Pending leave request not found" });
  }

  const updated = await LeaveRequest.findOneAndUpdate(
    { _id: id, orgId: scoped.orgId },
    {
      $set: {
        status,
        rejectionReason: status === "Rejected" ? rejectionReason : "",
        decidedByAdminUserId: scoped.user._id,
        decidedAt: new Date(),
      },
    },
    { new: true }
  ).lean();

  if (status === "Approved" && existing.applicantRole === "Doctor") {
    const fromYmd = existing.startDate.toISOString().slice(0, 10);
    const toYmd = existing.endDate.toISOString().slice(0, 10);
    await Doctor.updateOne(
      { userId: existing.applicantId },
      {
        $push: {
          bookingBlocklist: {
            fromDate: fromYmd,
            toDate: toYmd,
            type: existing.leaveType || "Leave",
            leaveRequestId: existing._id,
          },
        },
      }
    );
  }

  const applicant = await UserModel.findById(existing.applicantId).select("name email role").lean();
  await UserNotification.create({
    orgId: scoped.orgId,
    userId: existing.applicantId,
    role: existing.applicantRole,
    type: status === "Approved" ? "leave_approved" : "leave_rejected",
    title: status === "Approved" ? "Leave approved" : "Leave declined",
    body:
      status === "Approved"
        ? `Your ${existing.leaveType || "leave"} request was approved.`
        : rejectionReason || "Your leave request was not approved.",
    read: false,
    meta: { requestId: String(existing._id), status },
  });

  const [formatted] = await enrichLeaveRows([updated]);
  res.json({
    success: true,
    request: formatted,
  });
}

module.exports = {
  submitLeaveRequest,
  getMyRequests,
  listMyLeaveRequests,
  listAllLeaveRequests,
  updateLeaveStatus,
  requireLeaveApplicantScope,
  enrichLeaveRows,
  buildAdminLeaveQuery,
  ALLOWED_LEAVE_TYPES,
};
