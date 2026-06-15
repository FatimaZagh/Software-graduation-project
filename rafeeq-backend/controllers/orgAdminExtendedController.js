const mongoose = require("mongoose");
const UserModel = require("../models/User");
const Patient = require("../models/patient");
const Doctor = require("../models/doctor");
const Department = require("../models/department");
const StaffProfile = require("../models/staffProfile");
const Invoice = require("../models/invoice");
const UnifiedLeaveRequest = require("../models/LeaveRequest");
const leaveRequestController = require("./leaveRequestController");
const AuditLog = require("../models/auditLog");
const MedicalRecord = require("../models/medicalRecord");
const AppointmentModel = require("../models/appointment");
const Payment = require("../models/payment");
const Organization = require("../models/Organization");
const UserNotification = require("../models/userNotification");
const PatientNotification = require("../models/patientNotification");
const { writeAuditLog } = require("../utils/auditLogger");

function safeConsultationFee(doctor) {
  if (!doctor) return 0;
  const raw = doctor.consultationFee ?? doctor.clinicServicesConfig?.consultationFee;
  if (raw == null || raw === "") return 0;
  const fee = Number(raw);
  return Number.isFinite(fee) ? fee : 0;
}

const STAFF_ROLES = [
  "Doctor",
  "Nurse",
  "Lab Technician",
  "Radiologist",
  "Pharmacist",
  "Intern/Trainee",
  "Staff/Operations",
];

function clientIp(req) {
  return (
    String(req?.headers?.["x-forwarded-for"] || "")
      .split(",")[0]
      .trim() ||
    req?.socket?.remoteAddress ||
    ""
  );
}

async function audit(req, scoped, action, targetId, targetType, successStatus = true, metadata = {}) {
  await writeAuditLog({
    orgId: scoped.orgId,
    userId: scoped.user._id,
    action,
    targetId,
    targetType,
    req,
    successStatus,
    metadata,
  });
}

/** GET /dashboard/stats */
async function getDashboardStats(req, res, scoped) {
  const orgId = scoped.orgId;
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);

  const [paymentsToday, pendingInvoices, appointmentsToday, pendingDoctorLeave, pendingStaffLeave, staffCount, patientCount] =
    await Promise.all([
      Payment.aggregate([
        { $match: { orgId, paidAt: { $gte: startOfDay }, status: /paid/i } },
        { $group: { _id: null, total: { $sum: "$amount" } } },
      ]),
      Invoice.countDocuments({ orgId, status: "Pending" }),
      AppointmentModel.countDocuments({ orgId, createdAt: { $gte: startOfDay } }),
      UnifiedLeaveRequest.countDocuments({ orgId, applicantRole: "Doctor", status: "Pending" }),
      UnifiedLeaveRequest.countDocuments({ orgId, applicantRole: "Staff", status: "Pending" }),
      UserModel.countDocuments({ orgId, role: { $in: STAFF_ROLES }, status: "active" }),
      Patient.countDocuments({ orgId }),
    ]);

  const topDocRow = await Doctor.find({ orgId }).sort({ updatedAt: -1 }).limit(1).lean();
  let topDoctorName = "—";
  if (topDocRow[0]) {
    const du = await UserModel.findById(topDocRow[0].userId).select("name").lean();
    topDoctorName = topDocRow[0].displayName || du?.name || "—";
  }

  res.json({
    revenueToday: paymentsToday[0]?.total || 0,
    pendingInvoices,
    appointmentsToday,
    pendingLeaveRequests: pendingDoctorLeave + pendingStaffLeave,
    activeStaff: staffCount,
    registeredPatients: patientCount,
    topDoctorName,
    currency: (await Organization.findById(orgId).select("adminSettings.defaultCurrency").lean())?.adminSettings
      ?.defaultCurrency || "ILS",
  });
}

async function enrichDepartmentsWithSupervisor(list) {
  const doctorIds = [
    ...new Set(
      list
        .map((d) => d.supervisorDoctorId)
        .filter((id) => id && mongoose.Types.ObjectId.isValid(String(id)))
        .map((id) => String(id))
    ),
  ];
  const users = doctorIds.length
    ? await UserModel.find({ _id: { $in: doctorIds } }).select("name email role profileImageUrl").lean()
    : [];
  const userMap = Object.fromEntries(users.map((u) => [String(u._id), u]));
  return list.map((d) => ({
    ...d,
    clinics: Array.isArray(d.clinics) ? d.clinics : [],
    supervisorDoctor: d.supervisorDoctorId ? userMap[String(d.supervisorDoctorId)] || null : null,
  }));
}

/** Departments — supervisor + embedded clinics */
async function listDepartments(req, res, scoped) {
  const list = await Department.find({ orgId: scoped.orgId }).sort({ name: 1 }).lean();
  res.json(await enrichDepartmentsWithSupervisor(list));
}

async function createDepartment(req, res, scoped) {
  const name = String(req.body.name || "").trim();
  if (!name) return res.status(400).json({ message: "name required" });

  const supervisorDoctorId = mongoose.Types.ObjectId.isValid(req.body.supervisorDoctorId)
    ? req.body.supervisorDoctorId
    : null;
  if (supervisorDoctorId) {
    const docUser = await UserModel.findOne({
      _id: supervisorDoctorId,
      orgId: scoped.orgId,
      role: "Doctor",
      status: "active",
    }).lean();
    if (!docUser) return res.status(400).json({ message: "Supervisor must be an active doctor in this facility" });
  }

  const doc = await Department.create({
    orgId: scoped.orgId,
    name,
    description: String(req.body.description || ""),
    supervisorDoctorId,
    clinics: [],
  });
  await audit(req, scoped, "Create Department", doc._id, "Department");
  const [enriched] = await enrichDepartmentsWithSupervisor([doc.toObject()]);
  res.status(201).json(enriched);
}

async function updateDepartment(req, res, scoped) {
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: "Invalid id" });

  const patch = {};
  if (req.body.name != null) patch.name = String(req.body.name).trim();
  if (req.body.description != null) patch.description = String(req.body.description);
  if (req.body.supervisorDoctorId !== undefined) {
    if (req.body.supervisorDoctorId && !mongoose.Types.ObjectId.isValid(req.body.supervisorDoctorId)) {
      return res.status(400).json({ message: "Invalid supervisorDoctorId" });
    }
    if (req.body.supervisorDoctorId) {
      const docUser = await UserModel.findOne({
        _id: req.body.supervisorDoctorId,
        orgId: scoped.orgId,
        role: "Doctor",
        status: "active",
      }).lean();
      if (!docUser) return res.status(400).json({ message: "Supervisor must be an active doctor in this facility" });
    }
    patch.supervisorDoctorId = req.body.supervisorDoctorId || null;
  }

  const updated = await Department.findOneAndUpdate({ _id: id, orgId: scoped.orgId }, { $set: patch }, { new: true }).lean();
  if (!updated) return res.status(404).json({ message: "Not found" });
  await audit(req, scoped, "Edit Department", id, "Department");
  const [enriched] = await enrichDepartmentsWithSupervisor([updated]);
  res.json(enriched);
}

async function deleteDepartment(req, res, scoped) {
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: "Invalid id" });
  await Department.deleteOne({ _id: id, orgId: scoped.orgId });
  await audit(req, scoped, "Delete Department", id, "Department");
  res.json({ ok: true });
}

/** POST /departments/:departmentId/clinics — nested clinic inside department */
async function addDepartmentClinic(req, res, scoped) {
  const { departmentId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(departmentId)) {
    return res.status(400).json({ message: "Invalid departmentId" });
  }

  const name = String(req.body.name || "").trim();
  if (!name) return res.status(400).json({ message: "Clinic name required" });

  const clinicEntry = {
    name,
    phone: String(req.body.phone || ""),
    roomNumber: String(req.body.roomNumber || ""),
    createdAt: new Date(),
  };

  const updated = await Department.findOneAndUpdate(
    { _id: departmentId, orgId: scoped.orgId },
    { $push: { clinics: clinicEntry } },
    { new: true }
  ).lean();

  if (!updated) return res.status(404).json({ message: "Department not found" });

  await audit(req, scoped, "Add Department Clinic", departmentId, "Department", true, { clinicName: name });
  const [enriched] = await enrichDepartmentsWithSupervisor([updated]);
  res.status(201).json(enriched);
}

/** Staff roster */
async function listStaff(req, res, scoped) {
  const q = String(req.query.q || "").trim().toLowerCase();
  const users = await UserModel.find({ orgId: scoped.orgId, role: { $in: STAFF_ROLES } })
    .select("name email role status clinicId profileImageUrl")
    .lean();
  const profiles = await StaffProfile.find({ orgId: scoped.orgId }).lean();
  const profileByUser = Object.fromEntries(profiles.map((p) => [String(p.userId), p]));
  let rows = users.map((u) => ({
    ...u,
    profile: profileByUser[String(u._id)] || null,
  }));
  if (q) {
    rows = rows.filter(
      (r) =>
        String(r.name || "").toLowerCase().includes(q) ||
        String(r.email || "").toLowerCase().includes(q) ||
        String(r.role || "").toLowerCase().includes(q)
    );
  }
  res.json(rows);
}

async function upsertStaffProfile(req, res, scoped) {
  const { userId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(userId)) return res.status(400).json({ message: "Invalid userId" });
  const user = await UserModel.findOne({ _id: userId, orgId: scoped.orgId, role: { $in: STAFF_ROLES } });
  if (!user) return res.status(404).json({ message: "Staff user not found" });

  const patch = {
    orgId: scoped.orgId,
    userId,
    salary: Number(req.body.salary) || 0,
    specialty: String(req.body.specialty || ""),
    shiftHours: {
      start: String(req.body.shiftHours?.start || "08:00"),
      end: String(req.body.shiftHours?.end || "17:00"),
    },
    permissions: Array.isArray(req.body.permissions) ? req.body.permissions.map(String) : [],
    departmentId: mongoose.Types.ObjectId.isValid(req.body.departmentId) ? req.body.departmentId : null,
    loginDisabled: Boolean(req.body.loginDisabled),
  };
  if (Array.isArray(req.body.uploadedDocs)) {
    patch.uploadedDocs = req.body.uploadedDocs.map((d) => ({
      docType: d.docType,
      fileUrl: String(d.fileUrl || "").slice(0, 14 * 1024 * 1024),
    }));
  }

  const doc = await StaffProfile.findOneAndUpdate({ userId }, { $set: patch }, { upsert: true, new: true }).lean();

  if (patch.loginDisabled) {
    await UserModel.updateOne({ _id: userId }, { $set: { status: "pending" } });
  } else if (user.status === "pending" && req.body.activateLogin) {
    await UserModel.updateOne({ _id: userId }, { $set: { status: "active" } });
  }

  await audit(req, scoped, "Update Staff Profile", userId, "Staff");
  res.json(doc);
}

/** Patients — clinic-scoped directory for org admin (GET /api/patients/clinic, /api/admin/patients) */
async function getClinicPatients(req, res, scoped) {
  req.user = req.user || scoped?.user;
  const q = String(req.query.q || "").trim().toLowerCase();

  const rawUserClinicId = req.user?.clinicId;
  const userClinicIdStr =
    rawUserClinicId != null && String(rawUserClinicId).trim() !== ""
      ? String(rawUserClinicId).trim()
      : "";

  if (userClinicIdStr && !mongoose.Types.ObjectId.isValid(userClinicIdStr)) {
    return res.status(400).json({ message: "Invalid or missing clinic reference id." });
  }

  let clinicId = null;
  if (userClinicIdStr && mongoose.Types.ObjectId.isValid(userClinicIdStr)) {
    clinicId = new mongoose.Types.ObjectId(userClinicIdStr);
  } else {
    clinicId = resolveAdminClinicId(req, scoped);
  }

  if (!clinicId || !mongoose.Types.ObjectId.isValid(String(clinicId))) {
    return res.status(400).json({ message: "Invalid or missing clinic reference id." });
  }

  const filter = { orgId: scoped.orgId, clinicId };

  const patients = await Patient.find(filter).sort({ fullName: 1 }).limit(500).lean();
  const userIds = patients.map((p) => p.userId).filter(Boolean);
  const users = await UserModel.find({ _id: { $in: userIds } })
    .select("name email phoneNumber phone profileImageUrl")
    .lean();
  const userMap = Object.fromEntries(users.map((u) => [String(u._id), u]));

  const apptFilter = {
    orgId: scoped.orgId,
    clinicId,
    patientId: { $in: userIds },
    doctorUserId: { $exists: true, $ne: null },
  };

  const appts = await AppointmentModel.find(apptFilter)
    .sort({ createdAt: -1 })
    .select("patientId doctorUserId doctorName createdAt")
    .lean();

  const doctorUserIds = [...new Set(appts.map((a) => String(a.doctorUserId)).filter(Boolean))];
  const [doctorUsers, doctorProfiles] = await Promise.all([
    UserModel.find({ _id: { $in: doctorUserIds } }).select("name").lean(),
    Doctor.find({ userId: { $in: doctorUserIds } }).select("userId displayName fullName").lean(),
  ]);
  const doctorUserNameById = Object.fromEntries(doctorUsers.map((u) => [String(u._id), u.name || ""]));
  const doctorProfileByUserId = Object.fromEntries(
    doctorProfiles.map((d) => [String(d.userId), d.displayName || d.fullName || ""])
  );

  const assignedDoctorByPatient = {};
  for (const appt of appts) {
    const pid = String(appt.patientId || "");
    if (!pid || assignedDoctorByPatient[pid]) continue;
    const did = String(appt.doctorUserId || "");
    const doctorName =
      String(appt.doctorName || "").trim() ||
      doctorProfileByUserId[did] ||
      doctorUserNameById[did] ||
      "";
    assignedDoctorByPatient[pid] = {
      doctorUserId: appt.doctorUserId || null,
      doctorName,
      assignedDoctorName: doctorName,
    };
  }

  let rows = patients.map((p) => {
    const u = userMap[String(p.userId)] || {};
    const assigned = assignedDoctorByPatient[String(p.userId)] || {};
    const email = String(p.email || u.email || "").trim();
    const phone = String(p.phone || u.phoneNumber || u.phone || "").trim();
    const fullName = String(p.fullName || u.name || "").trim();
    const patientUserId = String(p.userId || "");
    return {
      _id: p._id,
      id: patientUserId,
      userId: p.userId,
      patientId: patientUserId,
      fullName,
      name: fullName,
      username: email || patientUserId,
      email,
      phone,
      contact: { email, phone },
      bloodType: p.bloodType || "",
      clinicId: p.clinicId ? String(p.clinicId) : null,
      assignedDoctorName: assigned.assignedDoctorName || "",
      doctorName: assigned.doctorName || "",
      user: u,
    };
  });

  if (q) {
    rows = rows.filter(
      (r) =>
        String(r.fullName || "").toLowerCase().includes(q) ||
        String(r.email || "").toLowerCase().includes(q) ||
        String(r.phone || "").toLowerCase().includes(q) ||
        String(r.assignedDoctorName || r.doctorName || "").toLowerCase().includes(q)
    );
  }

  return res.status(200).json(rows);
}

async function listPatients(req, res, scoped) {
  return getClinicPatients(req, res, scoped);
}

function resolveAdminClinicId(req, scoped) {
  const adminUser = req.user || scoped?.user;
  const fromUser = adminUser?.clinicId;
  if (fromUser && mongoose.Types.ObjectId.isValid(String(fromUser))) {
    return new mongoose.Types.ObjectId(String(fromUser));
  }
  const fromQuery = String(req.query?.clinicId || req.header("x-clinic-id") || "").trim();
  if (fromQuery && mongoose.Types.ObjectId.isValid(fromQuery)) {
    return new mongoose.Types.ObjectId(fromQuery);
  }
  return null;
}

function resolveAppointmentStatus(row) {
  const status = String(row?.status || "").trim();
  if (status) return status;
  const booking = String(row?.bookingStatus || "").trim();
  return booking || "booked";
}

async function enrichClinicAppointments(list) {
  if (!list.length) return [];

  const patientUserIds = [
    ...new Set(list.map((a) => a.patientId).filter(Boolean).map((id) => String(id))),
  ];
  const doctorUserIds = [
    ...new Set(list.map((a) => a.doctorUserId).filter(Boolean).map((id) => String(id))),
  ];
  const allUserIds = [...new Set([...patientUserIds, ...doctorUserIds])];

  const [patients, doctors, users] = await Promise.all([
    patientUserIds.length
      ? Patient.find({ userId: { $in: patientUserIds } })
          .select("userId fullName phone")
          .lean()
      : [],
    doctorUserIds.length
      ? Doctor.find({ userId: { $in: doctorUserIds } })
          .select("userId fullName displayName specialty specialization")
          .lean()
      : [],
    allUserIds.length
      ? UserModel.find({ _id: { $in: allUserIds } })
          .select("name email phone")
          .lean()
      : [],
  ]);

  const patientByUserId = Object.fromEntries(patients.map((p) => [String(p.userId), p]));
  const doctorByUserId = Object.fromEntries(doctors.map((d) => [String(d.userId), d]));
  const userById = Object.fromEntries(users.map((u) => [String(u._id), u]));

  return list.map((row) => {
    const patientUserId = row.patientId ? String(row.patientId) : "";
    const doctorUserId = row.doctorUserId ? String(row.doctorUserId) : "";
    const patient = patientByUserId[patientUserId];
    const doctor = doctorByUserId[doctorUserId];
    const patientUser = userById[patientUserId];
    const doctorUser = userById[doctorUserId];

    const patientName =
      String(row.patientName || "").trim() ||
      patient?.fullName ||
      patientUser?.name ||
      "—";
    const patientPhone = patient?.phone || patientUser?.phone || "";
    const doctorName =
      String(row.doctorName || "").trim() ||
      doctor?.fullName ||
      doctor?.displayName ||
      doctorUser?.name ||
      "—";
    const doctorSpecialty = doctor?.specialty || doctor?.specialization || "";

    return {
      _id: row._id,
      patientName,
      patientPhone,
      doctorName,
      doctorSpecialty,
      date: row.date || "",
      time: row.time || "",
      status: resolveAppointmentStatus(row),
    };
  });
}

/** GET /api/admin/appointments — clinic-scoped appointment roster for org admin */
async function getClinicAppointments(req, res, scoped) {
  req.user = req.user || scoped?.user;

  const q = { orgId: scoped.orgId };
  const clinicId = resolveAdminClinicId(req, scoped);
  if (clinicId) q.clinicId = clinicId;

  const status = String(req.query?.status || "").trim().toLowerCase();
  if (status === "cancelled" || status === "canceled") {
    q.$or = [
      { status: { $in: ["cancelled_by_doctor", "cancelled_by_patient", "Cancelled", "cancelled"] } },
      { bookingStatus: { $in: ["cancelled_by_doctor", "cancelled_by_patient"] } },
    ];
  } else if (status) {
    q.status = status;
  }

  const list = await AppointmentModel.find(q)
    .sort({ date: -1, time: -1, cancelledAt: -1, createdAt: -1 })
    .limit(200)
    .lean();

  const payload = await enrichClinicAppointments(list);
  return res.status(200).json(payload);
}

/** Appointments — delegates to clinic-scoped handler */
async function listAppointments(req, res, scoped) {
  return getClinicAppointments(req, res, scoped);
}

/** Staff leave — unified leaverequests collection */
async function listStaffLeave(req, res, scoped) {
  req.query = {
    ...(req.query || {}),
    applicantRole: "Staff",
    status: req.query?.status || "Pending",
  };
  return leaveRequestController.listAllLeaveRequests(req, res, scoped);
}

async function decideStaffLeave(req, res, scoped) {
  return leaveRequestController.updateLeaveStatus(req, res, scoped);
}

/** Medical records */
async function listMedicalRecords(req, res, scoped) {
  const list = await MedicalRecord.find({ orgId: scoped.orgId }).sort({ updatedAt: -1 }).limit(200).lean();
  res.json(list);
}

const billing = require("../services/billingService");

/** Billing / invoices */
async function listInvoices(req, res, scoped) {
  try {
    const ledger = await billing.listOrgLedger(scoped.orgId);
    res.json(
      ledger.map((row) => ({
        ...row,
        amount: Number(row.amount) || 0,
      }))
    );
  } catch (e) {
    console.error("[admin/billing/ledger]", e);
    res.status(500).json({ success: false, message: e.message || "Error loading billing ledger" });
  }
}

async function createInvoice(req, res, scoped) {
  const { patientUserId, amount, status, insuranceCompany, discountApplied, paymentMethod, description } = req.body;
  if (!mongoose.Types.ObjectId.isValid(patientUserId)) return res.status(400).json({ message: "patientUserId required" });
  const doc = await Invoice.create({
    orgId: scoped.orgId,
    patientUserId,
    amount: Number(amount) || 0,
    status: status === "Paid" ? "Paid" : "Pending",
    insuranceCompany: String(insuranceCompany || ""),
    discountApplied: Number(discountApplied) || 0,
    paymentMethod: String(paymentMethod || ""),
    description: String(description || ""),
  });
  await audit(req, scoped, "Create Invoice", doc._id, "Invoice");
  res.status(201).json(doc.toObject());
}

async function getBillingMetrics(req, res, scoped) {
  try {
    const metrics = await billing.getOrgBillingMetrics(scoped.orgId);
    res.json({
      success: true,
      ...metrics,
      totalPaid: Number(metrics.totalPaid) || 0,
      totalPending: Number(metrics.totalPending) || 0,
      totalMonthlyClinicRevenue: Number(metrics.totalMonthlyClinicRevenue) || 0,
      totalRevenuePool: Number(metrics.totalRevenuePool) || 0,
      commissionRate: Number(metrics.commissionRate) || 0.2,
      lateCycles: 0,
    });
  } catch (e) {
    console.error("[admin/billing/metrics]", e);
    res.status(500).json({ success: false, message: e.message || "Error loading billing metrics" });
  }
}

/** Permissions matrix */
async function getPermissions(req, res, scoped) {
  const org = await Organization.findById(scoped.orgId).select("rolePermissionMatrix").lean();
  const matrix = org?.rolePermissionMatrix || {};
  res.json({ matrix: matrix instanceof Map ? Object.fromEntries(matrix) : matrix });
}

async function updatePermissions(req, res, scoped) {
  const matrix = req.body.matrix;
  if (!matrix || typeof matrix !== "object") return res.status(400).json({ message: "matrix object required" });
  await Organization.updateOne({ _id: scoped.orgId }, { $set: { rolePermissionMatrix: matrix } });
  await audit(req, scoped, "Update Permissions", scoped.orgId, "Organization");
  res.json({ ok: true });
}

/** Inventory snapshot */
async function getInventory(req, res, scoped) {
  const org = await Organization.findById(scoped.orgId).select("inventorySnapshot activeModules").lean();
  res.json({
    snapshot: org?.inventorySnapshot || {},
    modules: org?.activeModules || {},
  });
}

async function updateInventory(req, res, scoped) {
  await Organization.updateOne(
    { _id: scoped.orgId },
    { $set: { inventorySnapshot: req.body.snapshot || {} } }
  );
  await audit(req, scoped, "Update Inventory", scoped.orgId, "Organization");
  res.json({ ok: true });
}

/** Audit logs read-only */
async function listAuditLogs(req, res, scoped) {
  const list = await AuditLog.find({ orgId: scoped.orgId }).sort({ createdAt: -1 }).limit(300).lean();
  const userIds = [...new Set(list.map((l) => String(l.userId)))];
  const users = await UserModel.find({ _id: { $in: userIds } }).select("name email role").lean();
  const userMap = Object.fromEntries(users.map((u) => [String(u._id), u]));
  res.json(
    list.map((l) => ({
      ...l,
      user: userMap[String(l.userId)] || null,
      ipAddress: l.ipAddress,
    }))
  );
}

/** Broadcast */
async function sendBroadcast(req, res, scoped) {
  const { audience, title, body } = req.body;
  const t = String(title || "").trim();
  const b = String(body || "").trim();
  if (!t || !b) return res.status(400).json({ message: "title and body required" });

  let count = 0;
  if (audience === "patients" || audience === "all") {
    const patients = await Patient.find({ orgId: scoped.orgId }).select("userId").lean();
    for (const p of patients) {
      if (!p.userId) continue;
      await PatientNotification.create({
        patientUserId: p.userId,
        orgId: scoped.orgId,
        title: t,
        body: b,
        type: "admin_broadcast",
        read: false,
      });
      count++;
    }
  }
  if (audience === "staff" || audience === "all") {
    const staff = await UserModel.find({ orgId: scoped.orgId, role: { $in: STAFF_ROLES }, status: "active" })
      .select("_id")
      .lean();
    for (const s of staff) {
      await UserNotification.create({
        userId: s._id,
        orgId: scoped.orgId,
        title: t,
        body: b,
        type: "admin_broadcast",
        read: false,
      });
      count++;
    }
  }
  await audit(req, scoped, "Broadcast", "", "Notification", true, { audience, count });
  res.json({ ok: true, delivered: count });
}

/** System config */
async function getSystemConfig(req, res, scoped) {
  const org = await Organization.findById(scoped.orgId).lean();
  if (!org) return res.status(404).json({ message: "Organization not found" });
  res.json({
    name: org.name,
    logoUrl: org.logoUrl,
    adminSettings: org.adminSettings || {},
    theme: org.theme || {},
  });
}

async function updateSystemConfig(req, res, scoped) {
  const patch = {};
  if (req.body.adminSettings) patch.adminSettings = req.body.adminSettings;
  if (req.body.logoUrl != null) patch.logoUrl = String(req.body.logoUrl).slice(0, 14 * 1024 * 1024);
  if (req.body.name) patch.name = String(req.body.name).trim();
  if (req.body.theme) patch.theme = req.body.theme;
  await Organization.updateOne({ _id: scoped.orgId }, { $set: patch });
  await audit(req, scoped, "Update System Config", scoped.orgId, "Organization");
  res.json({ ok: true });
}

/** Doctors for dropdowns — includes safe consultationFee for billing UI */
async function listDoctors(req, res, scoped) {
  try {
    const doctors = await UserModel.find({ orgId: scoped.orgId, role: "Doctor", status: "active" })
      .select("name email role status clinicId profileImageUrl")
      .lean();
    const userIds = doctors.map((d) => d._id).filter(Boolean);
    const profiles = userIds.length
      ? await Doctor.find({ userId: { $in: userIds } })
          .select("userId displayName fullName consultationFee specialization clinicServicesConfig")
          .lean()
      : [];
    const profileByUser = Object.fromEntries(profiles.map((p) => [String(p.userId), p]));

    res.json(
      doctors.map((u) => {
        const doc = profileByUser[String(u._id)];
        const fee = doc ? safeConsultationFee(doc) : 0;
        return {
          _id: String(u._id),
          userId: String(u._id),
          name: doc?.displayName || doc?.fullName || u.name || "Doctor",
          email: u.email || "",
          role: u.role || "Doctor",
          status: u.status || "active",
          specialty: doc?.specialization || doc?.specialty || "",
          consultationFee: fee,
          profileImageUrl: u.profileImageUrl || "",
        };
      })
    );
  } catch (e) {
    console.error("[admin/doctors]", e);
    res.status(500).json({ success: false, message: e.message || "Error loading doctors" });
  }
}

module.exports = {
  getDashboardStats,
  listDepartments,
  createDepartment,
  updateDepartment,
  deleteDepartment,
  addDepartmentClinic,
  listStaff,
  upsertStaffProfile,
  listPatients,
  getClinicPatients,
  getClinicAppointments,
  listAppointments,
  listStaffLeave,
  decideStaffLeave,
  listMedicalRecords,
  listInvoices,
  createInvoice,
  getBillingMetrics,
  getPermissions,
  updatePermissions,
  getInventory,
  updateInventory,
  listAuditLogs,
  sendBroadcast,
  getSystemConfig,
  updateSystemConfig,
  listDoctors,
};
