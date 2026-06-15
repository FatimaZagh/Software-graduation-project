const mongoose = require("mongoose");
const Staff = require("../models/Staff");
const STAFF_SPECIALTIES = Staff.STAFF_SPECIALTIES || [];
const STAFF_ROLES = Staff.STAFF_ROLES || ["Nurse"];
const UserModel = require("../models/User");
const Organization = require("../models/Organization");
const StaffProfile = require("../models/staffProfile");
const UserNotification = require("../models/userNotification");
const { hashPassword } = require("../utils/password");
const { writeAuditLog } = require("../utils/auditLogger");

const PHASE2_KEYS = [
  "role",
  "permissions",
  "orgId",
  "branchId",
  "departmentId",
  "supervisorDoctorId",
  "salary",
  "workingDaysAndHours",
  "employeeStatus",
  "accountStatus",
  "userId",
  "rejectionReason",
  "reviewedByAdminUserId",
  "reviewedAt",
];

function str(v) {
  return v == null ? "" : String(v).trim();
}

function parseDate(v) {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function stripPhase2(body) {
  const out = { ...body };
  for (const k of PHASE2_KEYS) delete out[k];
  delete out.password;
  return out;
}

/** POST /api/auth/register/staff — public nurse/clinical staff application */
async function registerStaffPublic(req, res) {
  try {
    const raw = req.body || {};
    const orgIdRaw = str(raw.orgId || raw.targetOrgId || raw.organizationId || raw.facilityId);
    if (!mongoose.Types.ObjectId.isValid(orgIdRaw)) {
      return res.status(400).json({ message: "Valid orgId is required" });
    }
    /** Read before stripPhase2 — stripPhase2 intentionally removes password from the payload copy */
    const password = str(raw.password);
    const body = stripPhase2(raw);
    const targetOrgId = orgIdRaw;

    const org = await Organization.findById(targetOrgId).lean();
    if (!org) return res.status(404).json({ message: "Organization not found" });

    const firstName = str(body.firstName);
    const fatherName = str(body.fatherName);
    const lastName = str(body.lastName);
    const username = str(body.username).toLowerCase();
    const email = str(body.email).toLowerCase();
    const fullName =
      str(body.fullName) || [firstName, fatherName, lastName].filter(Boolean).join(" ").replace(/\s+/g, " ").trim();

    if (!firstName || !lastName) return res.status(400).json({ message: "firstName and lastName are required" });
    if (!username) return res.status(400).json({ message: "username is required" });
    if (!email) return res.status(400).json({ message: "email is required" });
    if (password.length < 6) return res.status(400).json({ message: "password must be at least 6 characters" });

    const passwordHash = hashPassword(password);
    if (!passwordHash) {
      return res.status(400).json({ message: "Unable to process password" });
    }

    const specialty = STAFF_SPECIALTIES.includes(str(body.specialtyOrDepartment))
      ? str(body.specialtyOrDepartment)
      : "General";
    const staffRole = STAFF_ROLES.includes(str(raw.role)) ? str(raw.role) : "Nurse";
    const license = str(body.licenseNumber || body.nursingLicenseNumber);

    const [dupEmail, dupUser, dupUsername] = await Promise.all([
      Staff.findOne({ email }).lean(),
      UserModel.findOne({ email }).lean(),
      Staff.findOne({ username }).lean(),
    ]);
    if (dupEmail || dupUser) return res.status(409).json({ message: "Email already registered" });
    if (dupUsername) return res.status(409).json({ message: "Username already taken" });

    const ec = body.emergencyContact && typeof body.emergencyContact === "object" ? body.emergencyContact : {};

    const profileImage = str(body.profileImage || body.profileImageUrl);
    const safeImg = profileImage.length > 14 * 1024 * 1024 ? profileImage.slice(0, 14 * 1024 * 1024) : profileImage;

    const ecName = str(ec.name || ec.fullName);

    const doc = await Staff.create({
      orgId: targetOrgId,
      targetOrgId,
      fullName,
      firstName,
      fatherName,
      lastName,
      username,
      email,
      phone: str(body.phone),
      passwordHash,
      profileImage: safeImg,
      gender: str(body.gender),
      birthDate: parseDate(body.birthDate),
      employeeId: str(body.employeeId),
      specialtyOrDepartment: specialty,
      experienceYears: Number(body.experienceYears) || 0,
      educationLevel: ["Diploma", "BSc", "MSc"].includes(str(body.educationLevel)) ? str(body.educationLevel) : "Diploma",
      university: str(body.university),
      licenseNumber: license,
      nursingLicenseNumber: license,
      licenseExpiryDate: parseDate(body.licenseExpiryDate),
      employmentType: ["Full-Time", "Part-Time", "Shifts"].includes(str(body.employmentType))
        ? str(body.employmentType)
        : "Full-Time",
      residentialAddress: str(body.residentialAddress),
      city: str(body.city),
      emergencyContact: {
        name: ecName,
        fullName: ecName,
        phone: str(ec.phone),
        relationship: str(ec.relationship),
      },
      role: staffRole,
      accountStatus: "Pending",
      employeeStatus: "Active",
    });

    try {
      const admins = await UserModel.find({
        role: "Organization Admin",
        orgId: targetOrgId,
        status: "active",
      })
        .select("_id")
        .lean();
      const fullName = `${firstName} ${lastName}`.trim();
      for (const a of admins) {
        await UserNotification.create({
          orgId: targetOrgId,
          userId: a._id,
          role: "orgadmin",
          type: "staff_registration",
          title: "New nurse registration",
          body: `${fullName} applied for clinical staff registration.`,
          read: false,
          meta: { staffId: String(doc._id) },
        });
      }
    } catch (_) {}

    return res.status(201).json({
      message:
        "Your registration profile has been recorded successfully. Your account is currently Pending approval from the Clinic Administrator.",
      staffId: String(doc._id),
      orgId: String(doc.orgId),
      accountStatus: "Pending",
    });
  } catch (error) {
    console.error("DETAILED REGISTRATION ERROR:", error);
    if (error && error.code === 11000) {
      const field = error.keyPattern?.email ? "email" : error.keyPattern?.username ? "username" : "field";
      return res.status(409).json({ message: `Duplicate ${field} already registered`, details: error.message });
    }
    if (error && error.name === "ValidationError") {
      const details = Object.values(error.errors || {}).map((err) => err.message);
      return res.status(400).json({
        message: "Staff registration validation failed",
        details: details.length ? details : error.message,
      });
    }
    return res.status(500).json({
      message: "Error submitting staff registration",
      details: error?.message || String(error),
    });
  }
}

/** GET /api/admin/pending-staff */
async function listPendingStaff(req, res, scoped) {
  const list = await Staff.find({
    $or: [{ orgId: scoped.orgId }, { targetOrgId: scoped.orgId }],
    accountStatus: "Pending",
  })
    .sort({ createdAt: -1 })
    .limit(500)
    .lean();

  res.json(
    list.map((s) => ({
      ...s,
      passwordHash: undefined,
      fullName: `${s.firstName} ${s.lastName}`.trim(),
    }))
  );
}

/** PUT /api/admin/approve-staff/:staffId */
async function approveStaff(req, res, scoped) {
  const { staffId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(staffId)) {
    return res.status(400).json({ message: "Invalid staffId" });
  }

  const staff = await Staff.findOne({
    _id: staffId,
    $or: [{ orgId: scoped.orgId }, { targetOrgId: scoped.orgId }],
    accountStatus: "Pending",
  });

  if (!staff) return res.status(404).json({ message: "Pending application not found" });

  const action = str(req.body.action || req.body.decision).toLowerCase();
  const isReject = action === "reject" || action === "rejected";

  if (isReject) {
    staff.accountStatus = "Rejected";
    staff.rejectionReason = str(req.body.rejectionReason);
    staff.reviewedByAdminUserId = scoped.user._id;
    staff.reviewedAt = new Date();
    await staff.save();

    await writeAuditLog({
      orgId: scoped.orgId,
      userId: scoped.user._id,
      action: "Reject Staff Registration",
      targetId: staffId,
      targetType: "Staff",
      req,
      successStatus: true,
    });

    const out = staff.toObject();
    delete out.passwordHash;
    return res.json(out);
  }

  const permissions = Array.isArray(req.body.permissions)
    ? req.body.permissions.map(String)
    : ["nurse_access", "view_medical_notes", "manage_appointments"];
  const departmentId = mongoose.Types.ObjectId.isValid(req.body.departmentId) ? req.body.departmentId : null;
  const supervisorDoctorId = mongoose.Types.ObjectId.isValid(req.body.supervisorDoctorId)
    ? req.body.supervisorDoctorId
    : null;
  const branchId = mongoose.Types.ObjectId.isValid(req.body.branchId) ? req.body.branchId : null;
  const salary = req.body.salary != null && req.body.salary !== "" ? Number(req.body.salary) : null;
  const workingDaysAndHours = Array.isArray(req.body.workingDaysAndHours)
    ? req.body.workingDaysAndHours.map((w) => ({
        day: str(w.day),
        startTime: str(w.startTime) || "08:00",
        endTime: str(w.endTime) || "17:00",
      }))
    : [];

  if (supervisorDoctorId) {
    const doc = await UserModel.findOne({
      _id: supervisorDoctorId,
      orgId: scoped.orgId,
      role: "Doctor",
      status: "active",
    }).lean();
    if (!doc) return res.status(400).json({ message: "Supervisor must be an active doctor in this facility" });
  }

  const fullName = `${staff.firstName} ${staff.lastName}`.trim();
  const newUser = await UserModel.create({
    orgId: scoped.orgId,
    status: "active",
    name: fullName,
    email: staff.email,
    role: "Nurse",
    password: staff.passwordHash,
    profileImageUrl: staff.profileImage || "",
    phoneNumber: staff.phone || "",
    gender: staff.gender || "",
    dateOfBirth: staff.birthDate,
    clinicId: branchId,
  });

  const primaryShift = workingDaysAndHours[0] || { startTime: "08:00", endTime: "17:00" };

  await StaffProfile.findOneAndUpdate(
    { userId: newUser._id },
    {
      $set: {
        orgId: scoped.orgId,
        userId: newUser._id,
        salary: salary ?? 0,
        specialty: staff.specialtyOrDepartment,
        shiftHours: { start: primaryShift.startTime, end: primaryShift.endTime },
        permissions,
        departmentId,
        loginDisabled: false,
      },
    },
    { upsert: true, new: true }
  );

  staff.userId = newUser._id;
  staff.orgId = scoped.orgId;
  staff.role = "Nurse";
  staff.permissions = permissions;
  staff.departmentId = departmentId;
  staff.supervisorDoctorId = supervisorDoctorId;
  staff.branchId = branchId;
  staff.salary = salary;
  staff.workingDaysAndHours = workingDaysAndHours;
  staff.employeeStatus = "Active";
  staff.accountStatus = "Approved";
  staff.reviewedByAdminUserId = scoped.user._id;
  staff.reviewedAt = new Date();
  await staff.save();

  await writeAuditLog({
    orgId: scoped.orgId,
    userId: scoped.user._id,
    action: "Approve Staff Registration",
    targetId: staffId,
    targetType: "Staff",
    req,
    successStatus: true,
    metadata: { newUserId: String(newUser._id) },
  });

  const out = staff.toObject();
  delete out.passwordHash;
  return res.json({ staff: out, user: { id: String(newUser._id), email: newUser.email, role: newUser.role } });
}

module.exports = {
  registerStaffPublic,
  listPendingStaff,
  approveStaff,
};
