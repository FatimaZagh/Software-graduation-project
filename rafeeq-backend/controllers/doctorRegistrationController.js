const mongoose = require("mongoose");
const RegistrationRequest = require("../models/registrationRequest");
const UserModel = require("../models/User");
const Doctor = require("../models/doctor");
const UserNotification = require("../models/userNotification");
const { hashPassword } = require("../utils/password");
const { storeDoctorDocument } = require("../utils/doctorDocumentStorage");
const { buildScheduleFromRegistration } = require("../utils/dynamicSchedule");
const {
  logDoctorRegistrationPayload,
  resolveDoctorFacilityBinding,
} = require("../utils/doctorFacilityBinding");

const PHASE2_KEYS = [
  "status",
  "userId",
  "reviewedByAdminUserId",
  "reviewedAt",
  "rejectionReason",
  "accountStatus",
  "employeeStatus",
  "permissions",
  "salary",
  "workingDaysAndHours",
  "departmentId",
  "supervisorDoctorId",
];

const SPECIALTIES = [
  "General Practice",
  "Cardiology",
  "Dentistry",
  "Dermatology",
  "Pediatrics",
  "Orthopedics",
  "Neurology",
  "Psychiatry",
  "Radiology",
  "Surgery",
  "Emergency Medicine",
  "Other",
];

const SESSION_TYPES = ["In-person", "Online", "Both"];
const LICENSE_RE = /^[a-zA-Z0-9-]+$/;

function str(v) {
  return v == null ? "" : String(v).trim();
}

function sanitizeText(v, max = 8000) {
  return str(v).slice(0, max);
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
  delete out.passwordHash;
  return out;
}

function parseStringArray(v) {
  if (Array.isArray(v)) return v.map((x) => sanitizeText(x, 120)).filter(Boolean);
  if (typeof v === "string" && v.includes(",")) {
    return v.split(",").map((x) => sanitizeText(x, 120)).filter(Boolean);
  }
  return [];
}

function normalizeSessionType(v) {
  const s = str(v);
  if (SESSION_TYPES.includes(s)) return s;
  if (/online/i.test(s) && /person/i.test(s)) return "Both";
  if (/online/i.test(s)) return "Online";
  return "In-person";
}

async function notifyOrgAdmins(orgId, title, body, meta) {
  try {
    const admins = await UserModel.find({
      role: "Organization Admin",
      orgId,
      status: "active",
    })
      .select("_id")
      .lean();
    for (const a of admins) {
      await UserNotification.create({
        orgId,
        userId: a._id,
        role: "orgadmin",
        type: "registration_request",
        title,
        body,
        read: false,
        meta,
      });
    }
  } catch (e) {
    console.error("[doctor-register] notify admins failed:", e.message);
  }
}

/** POST /api/auth/register/doctor */
async function registerDoctorPublic(req, res) {
  try {
    const raw = req.body || {};
    logDoctorRegistrationPayload(raw);

    const password = str(raw.password);
    const body = stripPhase2(raw);

    const facility = await resolveDoctorFacilityBinding(raw);
    const { orgId, clinicId, orgName, clinicName, currentClinic } = facility;

    if (!orgId) {
      return res.status(400).json({ message: "Valid orgId (facility) is required" });
    }

    console.log("[doctor-register] resolved facility binding:", {
      orgId: String(orgId),
      clinicId: clinicId ? String(clinicId) : null,
      orgName,
      clinicName,
      currentClinic,
    });

    const fullName = sanitizeText(body.fullName || body.name, 200);
    const email = str(body.email).toLowerCase();
    const phone = sanitizeText(body.phone, 40);
    const licenseNumber = sanitizeText(body.licenseNumber, 64).toUpperCase();
    const specialty = SPECIALTIES.includes(str(body.specialty))
      ? str(body.specialty)
      : sanitizeText(body.specialty || body.specialization, 120) || "General Practice";

    if (!fullName) return res.status(400).json({ message: "fullName is required" });
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ message: "A valid email is required" });
    }
    if (!phone) return res.status(400).json({ message: "phone is required" });
    if (password.length < 6) {
      return res.status(400).json({ message: "password must be at least 6 characters" });
    }
    if (!licenseNumber) return res.status(400).json({ message: "licenseNumber is required" });
    if (!LICENSE_RE.test(licenseNumber)) {
      return res.status(400).json({ message: "licenseNumber must be alphanumeric (hyphens allowed)" });
    }

    const [dupUser, dupReqEmail, dupReqLicense, dupDoctor] = await Promise.all([
      UserModel.findOne({ email }).lean(),
      RegistrationRequest.findOne({ email, status: "pending", role: "Doctor" }).lean(),
      RegistrationRequest.findOne({
        "doctorProfile.licenseNumber": licenseNumber,
        status: "pending",
        role: "Doctor",
      }).lean(),
      Doctor.findOne({ licenseNumber }).lean(),
    ]);

    if (dupUser) return res.status(409).json({ message: "Email already registered" });
    if (dupReqEmail) {
      return res.status(409).json({ message: "A pending registration already exists for this email" });
    }
    if (dupReqLicense) {
      return res.status(409).json({ message: "License number already pending approval" });
    }
    if (dupDoctor) return res.status(409).json({ message: "License number already in use" });

    const passwordHash = hashPassword(password);
    const profileImage = sanitizeText(body.profileImageUrl || body.profileImage, 14 * 1024 * 1024);

    const requestKey = new mongoose.Types.ObjectId().toString();
    const docsIn = body.documents && typeof body.documents === "object" ? body.documents : {};
    let documents = {};
    try {
      documents = {
        idCardUrl: storeDoctorDocument(docsIn.idCardUrl || docsIn.idCard, {
          requestKey,
          fieldName: "idCard",
        }),
        medicalLicenseUrl: storeDoctorDocument(docsIn.medicalLicenseUrl || docsIn.medicalLicense, {
          requestKey,
          fieldName: "medicalLicense",
        }),
        certificatesUrl: storeDoctorDocument(docsIn.certificatesUrl || docsIn.certificates, {
          requestKey,
          fieldName: "certificates",
        }),
        cvUrl: storeDoctorDocument(docsIn.cvUrl || docsIn.cv, {
          requestKey,
          fieldName: "cv",
        }),
      };
    } catch (fileErr) {
      console.error("[doctor-register] document storage error:", fileErr);
      return res.status(400).json({ message: fileErr.message || "Invalid document upload" });
    }

    const workingDays = parseStringArray(body.workingDays);
    const workingHours = {
      start: sanitizeText(body.workingHours?.start || body.shiftStart || "09:00", 8) || "09:00",
      end: sanitizeText(body.workingHours?.end || body.shiftEnd || "17:00", 8) || "17:00",
    };
    const { dynamicSchedule, workSchedule } = buildScheduleFromRegistration({
      ...body,
      workingDays,
      workingHours,
    });

    const doctorProfile = {
      fullName,
      phone,
      gender: sanitizeText(body.gender, 32),
      birthDate: parseDate(body.birthDate),
      residentialAddress: sanitizeText(body.residentialAddress || body.address, 500),
      nationality: sanitizeText(body.nationality, 80),
      specialty,
      yearsOfExperience: Math.max(0, Number(body.yearsOfExperience ?? body.yearsExperience) || 0),
      licenseNumber,
      qualifications: parseStringArray(body.qualifications),
      education: sanitizeText(body.education || body.university, 200),
      currentClinic: sanitizeText(currentClinic || body.currentClinic || body.clinicName || clinicName || orgName, 200),
      bio: sanitizeText(body.bio, 4000),
      consultationFee: Math.max(0, Number(body.consultationFee) || 0),
      workingDays,
      workingHours,
      dynamicSchedule,
      workSchedule,
      languages: parseStringArray(body.languages),
      sessionType: normalizeSessionType(body.sessionType),
      documents,
    };

    const reqDoc = await RegistrationRequest.create({
      orgId,
      clinicId,
      doctorClinicId: clinicId,
      status: "pending",
      role: "Doctor",
      name: fullName,
      email,
      phone,
      password,
      passwordHash,
      profileImageUrl: profileImage,
      doctorProfile,
      doctorSpecialization: specialty,
      doctorYearsExperience: doctorProfile.yearsOfExperience,
      doctorCertificatesBase64: documents.certificatesUrl ? [documents.certificatesUrl] : [],
    });

    await notifyOrgAdmins(
      orgId,
      "New doctor registration",
      `${fullName} applied as ${specialty} at ${orgName || "your facility"}.`,
      { registrationRequestId: String(reqDoc._id), role: "Doctor" }
    );

    console.log("[doctor-register] pending request created:", String(reqDoc._id), email);

    return res.status(201).json({
      message: "Your doctor registration has been submitted and is pending admin approval.",
      requestId: String(reqDoc._id),
      status: "pending",
      orgId: String(orgId),
      clinicId: clinicId ? String(clinicId) : "",
    });
  } catch (e) {
    console.error("[doctor-register] validation/create error:", e);
    if (e.name === "ValidationError") {
      const details = Object.values(e.errors || {}).map((err) => err.message);
      return res.status(400).json({ message: "Validation failed", details });
    }
    if (e.code === 11000) {
      return res.status(409).json({ message: "Duplicate email or license number" });
    }
    return res.status(500).json({ message: "Error submitting doctor registration" });
  }
}

module.exports = { registerDoctorPublic, SPECIALTIES };
