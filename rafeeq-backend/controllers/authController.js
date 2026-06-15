const https = require("https");
const mongoose = require("mongoose");
const jwt = require("jsonwebtoken");
const { OAuth2Client } = require("google-auth-library");

const UserModel = require("../models/User");
const Patient = require("../models/patient");
const HealthProfile = require("../models/healthProfile");
const PatientMedicalProfile = require("../models/patientMedicalProfile");
const PatientMedicalFile = require("../models/patientMedicalFile");
const Organization = require("../models/Organization");
const Pharmacy = require("../models/pharmacy");
const Admin = require("../models/admin");
const {
  FACILITY_STATUS,
  isOrganizationApproved,
  isOrganizationLoginBlocked,
} = require("../utils/organizationStatus");
const Doctor = require("../models/doctor");
const Clinic = require("../models/clinic");
const { hashPassword, verifyPassword } = require("../utils/password");
const { ensureUserOrgId } = require("../utils/doctorOrgScope");

const JWT_SECRET =
  process.env.JWT_SECRET || "CHANGE_ME_RAFEEQ_JWT_SECRET_GENERATE_STRONG_VALUE_FOR_PRODUCTION";
const PLATFORM_SUPER_ADMIN_LOGIN = String(process.env.PLATFORM_SUPER_ADMIN_LOGIN || "admin").trim();
const PLATFORM_SUPER_ADMIN_PASSWORD = String(process.env.PLATFORM_SUPER_ADMIN_PASSWORD || "12345");
const GOOGLE_WEB_CLIENT_ID = String(process.env.GOOGLE_WEB_CLIENT_ID || "").trim();

function normalizeRole(input) {
  const r = String(input || "").trim();
  const map = {
    OrgAdmin: "Organization Admin",
    OrganizationAdmin: "Organization Admin",
    "Organization Admin": "Organization Admin",
    LabTechnician: "Lab Technician",
    "Lab Technician": "Lab Technician",
    InternTrainee: "Intern/Trainee",
    "Intern/Trainee": "Intern/Trainee",
    StaffOperations: "Staff/Operations",
    "Staff/Operations": "Staff/Operations",
    InternalPharmacist: "InternalPharmacist",
  };
  return map[r] || r;
}

function escapeRegex(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function findUserByEmailInsensitive(email) {
  const e = String(email || "").trim().toLowerCase();
  if (!e) return null;
  return UserModel.findOne({ email: new RegExp(`^${escapeRegex(e)}$`, "i") }).lean();
}

function httpsGetJson(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let raw = "";
        res.on("data", (c) => {
          raw += c;
        });
        res.on("end", () => {
          try {
            resolve(JSON.parse(raw));
          } catch (err) {
            reject(err);
          }
        });
      })
      .on("error", reject);
  });
}

async function verifyGoogleIdToken(idToken) {
  if (!GOOGLE_WEB_CLIENT_ID) {
    throw new Error("GOOGLE_WEB_CLIENT_ID is not configured on the server");
  }
  const client = new OAuth2Client(GOOGLE_WEB_CLIENT_ID);
  const ticket = await client.verifyIdToken({
    idToken: String(idToken),
    audience: GOOGLE_WEB_CLIENT_ID,
  });
  const p = ticket.getPayload();
  if (!p?.sub) throw new Error("Invalid Google token payload");
  return {
    sub: String(p.sub),
    email: String(p.email || "").trim().toLowerCase(),
    name: String(p.name || "").trim(),
    picture: String(p.picture || "").trim(),
  };
}

async function verifyFacebookAccessToken(accessToken) {
  const tok = encodeURIComponent(String(accessToken || ""));
  const url = `https://graph.facebook.com/me?fields=id,name,email&access_token=${tok}`;
  const data = await httpsGetJson(url);
  if (data.error) {
    throw new Error(data.error.message || "Facebook token invalid");
  }
  return {
    id: String(data.id),
    email: String(data.email || "").trim().toLowerCase(),
    name: String(data.name || "").trim(),
  };
}

const PHARMACY_PENDING_EN =
  "Login unauthorized. This pharmacy is pending super-admin approval.";
const PHARMACY_PENDING_AR =
  "تسجيل الدخول غير متاح. هذه الصيدلية بانتظار موافقة المسؤول الرئيسي على المنشأة.";
const PHARMACY_REJECTED_EN =
  "Login unauthorized. This pharmacy's facility registration was rejected by the Super Admin.";
const PHARMACY_REJECTED_AR =
  "تسجيل الدخول غير متاح. تم رفض تسجيل المنشأة التابعة لهذه الصيدلية من قِبل المسؤول الرئيسي.";

const PHARMACY_ROLES = new Set(["Pharmacist", "InternalPharmacist"]);

async function loadOrganizationStatus(orgIdOut) {
  if (!orgIdOut || !mongoose.Types.ObjectId.isValid(orgIdOut)) return "";
  try {
    const orgRow = await Organization.findById(orgIdOut).select("status").lean();
    return orgRow && orgRow.status != null ? String(orgRow.status) : "";
  } catch (_) {
    return "";
  }
}

async function guardPharmacyFacilityApproval(user, roleOut, orgIdOut, res) {
  if (!PHARMACY_ROLES.has(roleOut)) return true;

  let orgStatus = await loadOrganizationStatus(orgIdOut);
  if (!orgStatus && user?._id) {
    try {
      const linked = await Pharmacy.findOne({ userId: String(user._id) }).select("orgId facilityApprovalLocked").lean();
      if (linked?.orgId) {
        orgIdOut = String(linked.orgId);
        orgStatus = await loadOrganizationStatus(orgIdOut);
      }
      if (linked?.facilityApprovalLocked === true && !isOrganizationApproved(orgStatus)) {
        orgStatus = orgStatus || FACILITY_STATUS.PENDING;
      }
    } catch (_) {}
  }

  if (!orgStatus || isOrganizationApproved(orgStatus)) return true;

  if (String(orgStatus) === FACILITY_STATUS.REJECTED) {
    res.status(403).json({
      message: PHARMACY_REJECTED_EN,
      messageAr: PHARMACY_REJECTED_AR,
      facilityStatus: FACILITY_STATUS.REJECTED,
    });
    return false;
  }

  if (isOrganizationLoginBlocked(orgStatus)) {
    res.status(403).json({
      message: PHARMACY_PENDING_EN,
      messageAr: PHARMACY_PENDING_AR,
      facilityStatus: orgStatus || FACILITY_STATUS.PENDING,
    });
    return false;
  }

  return true;
}

async function finishAuthenticatedUserLogin(user, res) {
  const roleOut = normalizeRole(user.role);
  const status = user.status || "active";
  let orgIdOut = user.orgId ? String(user.orgId) : "";
  if ((!orgIdOut || !mongoose.Types.ObjectId.isValid(orgIdOut)) && roleOut === "Organization Admin") {
    try {
      const a = await Admin.findOne({ userId: user._id }).select("orgId").lean();
      if (a?.orgId && mongoose.Types.ObjectId.isValid(String(a.orgId))) {
        orgIdOut = String(a.orgId);
        await UserModel.updateOne({ _id: user._id }, { $set: { orgId: a.orgId } });
      }
    } catch (_) {}
  }

  const pendingFacilityRegistrationMessage =
    "Your facility registration request is still pending approval from the Super Admin.";
  const rejectedFacilityRegistrationMessage =
    "Your facility registration was rejected by the Super Admin.";

  if (roleOut === "Organization Admin") {
    const orgStatus = await loadOrganizationStatus(orgIdOut);
    if (orgStatus === FACILITY_STATUS.REJECTED) {
      return res.status(403).json({
        message: rejectedFacilityRegistrationMessage,
        facilityStatus: FACILITY_STATUS.REJECTED,
      });
    }
    const orgPending = orgStatus === FACILITY_STATUS.PENDING;
    if (status === "pending" || orgPending) {
      return res.status(403).json({
        message: pendingFacilityRegistrationMessage,
        facilityStatus: FACILITY_STATUS.PENDING,
      });
    }
  }

  const pharmacyAllowed = await guardPharmacyFacilityApproval(user, roleOut, orgIdOut, res);
  if (!pharmacyAllowed) return;

  if (PHARMACY_ROLES.has(roleOut) && status !== "active") {
    return res.status(403).json({
      message: PHARMACY_PENDING_EN,
      messageAr: PHARMACY_PENDING_AR,
      facilityStatus: FACILITY_STATUS.PENDING,
      userStatus: status,
    });
  }

  if (status !== "active") {
    let orgName = "your facility";
    try {
      if (orgIdOut && mongoose.Types.ObjectId.isValid(orgIdOut)) {
        const org = await Organization.findById(orgIdOut).select("name").lean();
        if (org?.name) orgName = String(org.name);
      }
    } catch (_) {}
    if (status === "pending") {
      return res.status(403).json({
        message: `Your account is awaiting approval from the ${orgName} Admin.`,
        status,
        orgId: orgIdOut,
      });
    }
    return res.status(403).json({ message: "Your account is not active.", status });
  }

  const payload = {
    message: "Login successful",
    role: roleOut,
    id: user._id.toString(),
    orgId: orgIdOut,
    status,
    name: user.name || "",
    profileImageUrl: user.profileImageUrl || "",
  };
  if (user.clinicId && mongoose.Types.ObjectId.isValid(String(user.clinicId))) {
    payload.clinicId = String(user.clinicId);
  }

  if (
    orgIdOut &&
    mongoose.Types.ObjectId.isValid(orgIdOut) &&
    ["Doctor", "Nurse", "Organization Admin", "Lab Technician", "Radiologist", "Pharmacist", "InternalPharmacist"].includes(
      roleOut
    )
  ) {
    payload.token = jwt.sign(
      {
        typ: "staff_session",
        id: user._id.toString(),
        role: roleOut,
        orgId: orgIdOut,
      },
      JWT_SECRET,
      { expiresIn: "12h", subject: String(user._id) }
    );
  }

  return res.status(200).json(payload);
}

async function loginAuthHandler(req, res) {
  try {
    const loginMethod = String(req.body?.loginMethod || "email").toLowerCase();
    const emailRaw = String(req.body?.email ?? "").trim();
    const pass = String(req.body?.password ?? "");
    const idToken = req.body?.idToken;
    const accessToken = req.body?.accessToken;

    if (emailRaw === PLATFORM_SUPER_ADMIN_LOGIN && pass === PLATFORM_SUPER_ADMIN_PASSWORD) {
      const token = jwt.sign(
        { typ: "platform_super", role: "SuperAdmin" },
        JWT_SECRET,
        { expiresIn: "8h", subject: "rafeeq-platform-super-admin" }
      );
      console.log("[login] Platform Super Admin success (hardcoded credentials, not DB)");
      return res.status(200).json({
        message: "Login successful",
        role: "SuperAdmin",
        id: "",
        orgId: "",
        status: "active",
        profileImageUrl: "",
        token,
        platformSuperAdmin: true,
      });
    }

    if (loginMethod === "email") {
      if (!emailRaw || !pass) {
        return res.status(400).json({ message: "email and password are required" });
      }
      console.log("[login] attempt for email:", emailRaw);
      const user = await findUserByEmailInsensitive(emailRaw);
      console.log(
        "[login] user found in DB:",
        user
          ? {
              id: String(user._id),
              email: user.email,
              role: user.role,
              status: user.status || "active",
              hasPassword: !!String(user.password || "").length,
            }
          : null
      );
      if (!user) {
        console.log("[login] no user record for:", emailRaw);
        return res.status(401).json({ message: "Invalid email or password" });
      }
      const passwordOk = verifyPassword(user.password, pass);
      if (!passwordOk) {
        console.log("[login] password verification failed for:", emailRaw, "status:", user.status);
        return res.status(401).json({ message: "Invalid email or password" });
      }
      console.log("[login] password OK, finishing session for role:", user.role);
      return finishAuthenticatedUserLogin(user, res);
    }

    if (loginMethod === "google") {
      if (!idToken) return res.status(400).json({ message: "idToken is required for Google login" });
      let g;
      try {
        g = await verifyGoogleIdToken(idToken);
      } catch (e) {
        return res.status(401).json({ message: `Google verification failed: ${e.message}` });
      }
      let user = await UserModel.findOne({ googleId: g.sub }).lean();
      if (!user && g.email) {
        user = await findUserByEmailInsensitive(g.email);
        if (user && !user.googleId) {
          await UserModel.updateOne({ _id: user._id }, { $set: { googleId: g.sub, loginMethod: "google" } });
          user = await UserModel.findById(user._id).lean();
        }
      }
      if (!user) {
        return res.status(404).json({ message: "No account found for this Google profile. Please register first." });
      }
      return finishAuthenticatedUserLogin(user, res);
    }

    if (loginMethod === "facebook") {
      if (!accessToken) {
        return res.status(400).json({ message: "accessToken is required for Facebook login" });
      }
      let fb;
      try {
        fb = await verifyFacebookAccessToken(accessToken);
      } catch (e) {
        return res.status(401).json({ message: `Facebook verification failed: ${e.message}` });
      }
      let user = await UserModel.findOne({ facebookId: fb.id }).lean();
      if (!user && fb.email) {
        user = await findUserByEmailInsensitive(fb.email);
        if (user && !user.facebookId) {
          await UserModel.updateOne({ _id: user._id }, { $set: { facebookId: fb.id, loginMethod: "facebook" } });
          user = await UserModel.findById(user._id).lean();
        }
      }
      if (!user) {
        return res.status(404).json({
          message: "No account found for this Facebook profile. Please register first (email on Facebook required).",
        });
      }
      return finishAuthenticatedUserLogin(user, res);
    }

    return res.status(400).json({ message: `Unsupported loginMethod: ${loginMethod}` });
  } catch (error) {
    console.error("[auth/login]", error);
    return res.status(500).json({ message: "Error logging in" });
  }
}

function str(v) {
  return v == null ? "" : String(v).trim();
}

function numOrNull(v) {
  if (v == null || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function parseDate(v) {
  if (v == null || v === "") return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function splitList(v) {
  if (Array.isArray(v)) return v.map((x) => str(x)).filter(Boolean);
  if (typeof v === "string") {
    return v
      .split(/[,;\n]+/)
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [];
}

/** Max data-URL length per file (separate Mongo documents; BSON max 16MB per doc). */
const MAX_MEDICAL_FILE_DATA_URL_LENGTH = 14 * 1024 * 1024;

function isAllowedMedicalDataUrl(url) {
  const u = String(url || "");
  return /^data:(application\/pdf|image\/(png|jpeg));base64,/i.test(u);
}

async function resolvePatientClinicId(orgId, body) {
  const raw = str(body?.clinicId || body?.branchId || "");
  if (raw && mongoose.Types.ObjectId.isValid(raw)) {
    return new mongoose.Types.ObjectId(raw);
  }
  if (!orgId) return null;
  const first = await Clinic.findOne({ orgId }).sort({ createdAt: 1 }).select("_id").lean();
  return first?._id || null;
}

async function registerPatientAuthHandler(req, res) {
  try {
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const loginMethod = str(body.loginMethod).toLowerCase() || "email";

    if (!["email", "google", "facebook"].includes(loginMethod)) {
      return res.status(400).json({ message: "Invalid loginMethod" });
    }

    let emailNorm = str(body.email).toLowerCase();
    let fullName = str(body.fullName) || str(body.name);
    let googleSub;
    let facebookId;
    let profileImageUrl = str(body.profileImageUrl);
    let passwordHash = "";

    if (loginMethod === "email") {
      const password = str(body.password);
      const confirm = str(body.confirmPassword);
      if (!fullName) return res.status(400).json({ message: "fullName is required" });
      if (!emailNorm) return res.status(400).json({ message: "email is required" });
      if (!password) return res.status(400).json({ message: "password is required" });
      if (password !== confirm) return res.status(400).json({ message: "password and confirmPassword must match" });
      passwordHash = hashPassword(password);
    } else if (loginMethod === "google") {
      if (!body.idToken) return res.status(400).json({ message: "idToken is required" });
      let g;
      try {
        g = await verifyGoogleIdToken(body.idToken);
      } catch (e) {
        return res.status(401).json({ message: `Google verification failed: ${e.message}` });
      }
      googleSub = g.sub;
      if (!emailNorm) emailNorm = g.email;
      if (!fullName) fullName = g.name;
      if (!emailNorm) return res.status(400).json({ message: "Google account has no email; cannot register." });
      if (g.picture && !profileImageUrl) profileImageUrl = g.picture;
    } else if (loginMethod === "facebook") {
      if (!body.accessToken) return res.status(400).json({ message: "accessToken is required" });
      let fb;
      try {
        fb = await verifyFacebookAccessToken(body.accessToken);
      } catch (e) {
        return res.status(401).json({ message: `Facebook verification failed: ${e.message}` });
      }
      facebookId = fb.id;
      if (!emailNorm) emailNorm = fb.email;
      if (!fullName) fullName = fb.name;
      if (!emailNorm) {
        return res.status(400).json({ message: "Facebook account has no email permission; cannot register." });
      }
    }

    const emailEsc = escapeRegex(emailNorm);
    const dup = await UserModel.findOne({ email: new RegExp(`^${emailEsc}$`, "i") }).lean();
    if (dup) {
      return res.status(409).json({ message: "An account with this email already exists" });
    }

    let resolvedOrgId = null;
    const requestedOrgId = str(body.orgId);
    if (requestedOrgId && mongoose.Types.ObjectId.isValid(requestedOrgId)) {
      resolvedOrgId = new mongoose.Types.ObjectId(requestedOrgId);
    }

    const phoneNumber = str(body.phoneNumber);
    const gender = str(body.gender);
    const dateOfBirth = parseDate(body.dateOfBirth);
    const identityNumber = str(body.identityNumber);
    const maritalStatus = str(body.maritalStatus);

    const img = profileImageUrl.length > 1_200_000 ? profileImageUrl.slice(0, 1_200_000) : profileImageUrl;

    const userDoc = {
      orgId: resolvedOrgId,
      status: "active",
      name: fullName,
      email: emailNorm,
      role: "Patient",
      password: passwordHash,
      profileImageUrl: img,
      phoneNumber,
      loginMethod,
      gender,
      dateOfBirth,
      identityNumber,
      maritalStatus,
    };
    if (googleSub) userDoc.googleId = googleSub;
    if (facebookId) userDoc.facebookId = facebookId;

    const newUser = await UserModel.create(userDoc);

    const addr = body.address && typeof body.address === "object" ? body.address : {};
    const city = str(addr.city);
    const residentialAddress = str(addr.residentialAddress);
    const detailedAddress = str(addr.detailedAddress);

    const ec = body.emergencyContact && typeof body.emergencyContact === "object" ? body.emergencyContact : {};
    const emergencyContact = {
      name: str(ec.name),
      phone: str(ec.phone),
      relationship: str(ec.relationship),
    };

    const mh = body.medicalHistory && typeof body.medicalHistory === "object" ? body.medicalHistory : {};
    const chronicDiseases = Array.isArray(mh.chronicDiseases)
      ? mh.chronicDiseases.map((x) => str(x)).filter(Boolean)
      : splitList(mh.chronicDiseases);

    const al = mh.allergies && typeof mh.allergies === "object" ? mh.allergies : {};
    const allergies = {
      medications: Array.isArray(al.medications) ? al.medications.map((x) => str(x)).filter(Boolean) : splitList(al.medications),
      foods: Array.isArray(al.foods) ? al.foods.map((x) => str(x)).filter(Boolean) : splitList(al.foods),
      materials: Array.isArray(al.materials) ? al.materials.map((x) => str(x)).filter(Boolean) : splitList(al.materials),
    };

    const currentMedications = Array.isArray(mh.currentMedications)
      ? mh.currentMedications.map((x) => str(x)).filter(Boolean)
      : splitList(mh.currentMedications);
    const pastSurgeries = Array.isArray(mh.pastSurgeries)
      ? mh.pastSurgeries.map((x) => str(x)).filter(Boolean)
      : splitList(mh.pastSurgeries);
    const familyMedicalHistory = Array.isArray(mh.familyMedicalHistory)
      ? mh.familyMedicalHistory.map((x) => str(x)).filter(Boolean)
      : splitList(mh.familyMedicalHistory);
    const medicalHistoryNotes = str(mh.medicalHistoryNotes);

    const vit = body.vitals && typeof body.vitals === "object" ? body.vitals : {};
    const bloodType = str(vit.bloodType);
    const height = numOrNull(vit.height);
    const weight = numOrNull(vit.weight);

    const sh = body.socialHabits && typeof body.socialHabits === "object" ? body.socialHabits : {};
    const socialHabits = {
      smoking: Boolean(sh.smoking),
      alcohol: Boolean(sh.alcohol),
    };

    const pregnancyStatus =
      typeof body.pregnancyStatus === "boolean"
        ? body.pregnancyStatus
          ? "yes"
          : "no"
        : str(body.pregnancyStatus);
    const lastClinicVisit = parseDate(body.lastClinicVisit);

    const medicalFilesIn = Array.isArray(body.medicalFiles) ? body.medicalFiles : [];
    const medicalFilesMeta = [];
    for (const f of medicalFilesIn.slice(0, 20)) {
      if (!f || typeof f !== "object") continue;
      const fileUrl = str(f.fileUrl);
      const fileType = str(f.fileType) || "application/octet-stream";
      const originalName = str(f.originalName) || str(f.name) || "upload";
      if (!fileUrl) continue;
      if (fileUrl.length > MAX_MEDICAL_FILE_DATA_URL_LENGTH) {
        return res.status(400).json({
          message: `Medical file "${originalName}" is too large. Maximum per file is about 10–11 MB after encoding (server limit).`,
        });
      }
      if (!isAllowedMedicalDataUrl(fileUrl)) {
        return res.status(400).json({
          message: `Medical file "${originalName}" must be PDF or PNG/JPEG (data URL with correct MIME).`,
        });
      }
      medicalFilesMeta.push({ fileUrl, fileType, originalName });
    }

    const resolvedClinicId = await resolvePatientClinicId(resolvedOrgId, body);

    await Patient.create({
      orgId: resolvedOrgId,
      clinicId: resolvedClinicId,
      userId: newUser._id,
      fullName,
      email: emailNorm,
      phone: phoneNumber,
      bloodType,
      weightKg: weight,
      heightCm: height,
      gender,
      age: null,
      lastCheckupLabel: lastClinicVisit ? lastClinicVisit.toISOString().slice(0, 10) : "",
      address: [residentialAddress, detailedAddress, city].filter(Boolean).join(", "),
      profileImage: img,
    });

    await PatientMedicalProfile.create({
      userId: newUser._id,
      orgId: resolvedOrgId,
      city,
      residentialAddress,
      detailedAddress,
      emergencyContact,
      bloodType,
      height,
      weight,
      chronicDiseases,
      allergies,
      currentMedications,
      pastSurgeries,
      medicalHistoryNotes,
      familyMedicalHistory,
      socialHabits,
      pregnancyStatus,
      lastClinicVisit,
      medicalFiles: [],
    });

    for (const mf of medicalFilesMeta) {
      await PatientMedicalFile.create({
        userId: newUser._id,
        orgId: resolvedOrgId,
        fileUrl: mf.fileUrl,
        fileType: mf.fileType,
        originalName: mf.originalName,
        uploadedAt: new Date(),
      });
    }

    await HealthProfile.updateOne(
      { userId: newUser._id },
      {
        $setOnInsert: { userId: newUser._id },
        $set: {
          orgId: resolvedOrgId,
          bloodType,
          weightKg: weight,
          heightCm: height,
          chronicDiseases,
          allergies: [...allergies.medications, ...allergies.foods, ...allergies.materials],
          pastSurgeries,
        },
      },
      { upsert: true }
    );

    return res.status(201).json({
      message: "Patient account created",
      userId: String(newUser._id),
      orgId: resolvedOrgId ? String(resolvedOrgId) : "",
      role: "Patient",
    });
  } catch (e) {
    console.error("[auth/register]", e);
    if (e && e.code === 11000) {
      return res.status(409).json({ message: "Duplicate key (email or provider id)" });
    }
    return res.status(500).json({ message: "Error registering patient" });
  }
}

module.exports = {
  loginAuthHandler,
  registerPatientAuthHandler,
};
