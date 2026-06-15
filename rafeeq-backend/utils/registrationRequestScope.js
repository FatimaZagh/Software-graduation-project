const mongoose = require("mongoose");
const Clinic = require("../models/clinic");
const Organization = require("../models/Organization");
const RegistrationRequest = require("../models/registrationRequest");
const UserModel = require("../models/User");
const Doctor = require("../models/doctor");
const { hashPassword, isBcryptHash } = require("./password");
const {
  buildScheduleFromRegistration,
  dynamicScheduleToWorkSchedule,
  isDynamicScheduleMap,
} = require("./dynamicSchedule");
const { resolveDoctorFacilityBinding } = require("./doctorFacilityBinding");

function toObjectId(id) {
  const s = String(id || "").trim();
  if (!mongoose.Types.ObjectId.isValid(s)) return null;
  return new mongoose.Types.ObjectId(s);
}

async function buildPendingRegistrationQuery(adminOrgId) {
  const oid = toObjectId(adminOrgId);
  if (!oid) return { status: "pending", _id: null };

  const clinicIds = await Clinic.find({ orgId: oid }).distinct("_id");
  const clinicMatch = clinicIds.length ? { $in: clinicIds } : oid;

  return {
    status: "pending",
    $or: [
      { orgId: oid },
      { doctorClinicId: clinicMatch },
      { clinicId: clinicMatch },
      { doctorClinicId: oid },
      { clinicId: oid },
    ],
  };
}

async function findPendingRegistrationById(requestId, adminOrgId) {
  const rid = toObjectId(requestId);
  if (!rid) return null;
  const filter = await buildPendingRegistrationQuery(adminOrgId);
  return RegistrationRequest.findOne({ ...filter, _id: rid })
    .select("+password +passwordHash")
    .lean();
}

async function resolveEffectiveOrgId(rr, fallbackOrgId) {
  const direct = toObjectId(rr?.orgId);
  if (direct) {
    const orgDoc = await Organization.findById(direct).select("_id").lean();
    if (orgDoc) return direct;
  }

  const clinicRef = toObjectId(rr?.doctorClinicId) || toObjectId(rr?.clinicId);
  if (clinicRef) {
    const clinic = await Clinic.findById(clinicRef).select("orgId").lean();
    if (clinic?.orgId) return toObjectId(clinic.orgId);
  }

  return toObjectId(fallbackOrgId);
}

function resolvePassword(rr) {
  if (rr?.passwordHash && isBcryptHash(rr.passwordHash)) {
    return rr.passwordHash;
  }
  const plain = String(rr?.password || "").trim();
  if (plain) {
    if (isBcryptHash(plain)) return plain;
    return hashPassword(plain);
  }
  throw new Error(
    "Registration request is missing password credentials. Reject this request and ask the applicant to register again."
  );
}

async function mapDoctorFromRequest(rr, effectiveOrgId, clinicId, userId) {
  const p = rr.doctorProfile && typeof rr.doctorProfile === "object" ? rr.doctorProfile : {};
  const facility = await resolveDoctorFacilityBinding({
    orgId: effectiveOrgId,
    clinicId: clinicId || rr.clinicId,
    doctorClinicId: rr.doctorClinicId,
    currentClinic: p.currentClinic,
    clinicName: p.currentClinic,
  });
  const specialty = p.specialty || rr.doctorSpecialization || "";
  const years = p.yearsOfExperience ?? rr.doctorYearsExperience ?? 0;
  const docs = p.documents && typeof p.documents === "object" ? p.documents : {};
  const certUrls = [docs.certificatesUrl, ...(rr.doctorCertificatesBase64 || [])].filter(Boolean);
  const workingDays = Array.isArray(p.workingDays) ? p.workingDays : [];
  const workingHours = p.workingHours || { start: "09:00", end: "17:00" };
  let schedule;
  if (isDynamicScheduleMap(p.dynamicSchedule)) {
    const workSchedule = Array.isArray(p.workSchedule) && p.workSchedule.length
      ? p.workSchedule
      : dynamicScheduleToWorkSchedule(p.dynamicSchedule);
    schedule = { dynamicSchedule: p.dynamicSchedule, workSchedule };
  } else {
    schedule = buildScheduleFromRegistration({
      workingDays,
      workingHours,
      workSchedule: p.workSchedule,
    });
  }

  console.log("[approve-registration] doctor facility binding:", {
    requestId: String(rr._id),
    orgId: facility.orgId ? String(facility.orgId) : null,
    clinicId: facility.clinicId ? String(facility.clinicId) : null,
    currentClinic: facility.currentClinic,
  });

  return {
    orgId: facility.orgId || effectiveOrgId,
    clinicId: facility.clinicId || clinicId,
    userId,
    status: "approved",
    fullName: p.fullName || rr.name || "",
    displayName: p.fullName || rr.name || "",
    email: rr.email || "",
    phone: p.phone || rr.phone || "",
    gender: p.gender || "",
    birthDate: p.birthDate || null,
    residentialAddress: p.residentialAddress || "",
    nationality: p.nationality || "",
    specialty,
    specialization: specialty,
    yearsOfExperience: years,
    yearsExperience: years,
    licenseNumber: p.licenseNumber || "",
    qualifications: Array.isArray(p.qualifications) ? p.qualifications : [],
    education: p.education || "",
    currentClinic: facility.currentClinic || p.currentClinic || facility.orgName || "",
    bio: p.bio || "",
    consultationFee: p.consultationFee ?? 0,
    workingDays,
    workingHours,
    dynamicSchedule: schedule.dynamicSchedule,
    workSchedule: schedule.workSchedule,
    languages: Array.isArray(p.languages) ? p.languages : [],
    sessionType: p.sessionType || "In-person",
    documents: docs,
    profileImageUrl: rr.profileImageUrl || "",
    profileImageBase64: rr.profileImageUrl || "",
    certificateFilesBase64: certUrls.map((x) => String(x).slice(0, 500_000)),
    signatureImageBase64: rr.doctorSignatureBase64 || "",
  };
}

async function approveRegistrationRequest(rr, fallbackOrgId) {
  const effectiveOrgId = await resolveEffectiveOrgId(rr, fallbackOrgId);
  if (!effectiveOrgId) {
    throw new Error("Could not resolve organization for this registration request");
  }

  let clinicId = toObjectId(rr.doctorClinicId) || toObjectId(rr.clinicId) || null;
  const p = rr.doctorProfile && typeof rr.doctorProfile === "object" ? rr.doctorProfile : {};
  const email = String(rr.email || "").trim().toLowerCase();
  const role = rr.role || "Doctor";
  const passwordHash = resolvePassword(rr);

  console.log("[approve-registration] activating account", {
    email,
    role,
    requestId: String(rr._id),
    hadPasswordHash: !!(rr.passwordHash && isBcryptHash(rr.passwordHash)),
    hadPlainPassword: !!String(rr.password || "").trim(),
  });

  const newUser = await UserModel.create({
    orgId: effectiveOrgId,
    status: "active",
    name: p.fullName || rr.name,
    email,
    role,
    password: passwordHash,
    profileImageUrl: rr.profileImageUrl || "",
    clinicId,
    phoneNumber: p.phone || rr.phone || "",
    gender: p.gender || "",
    dateOfBirth: p.birthDate || null,
  });

  if (rr.role === "Doctor") {
    const doctorFields = await mapDoctorFromRequest(rr, effectiveOrgId, clinicId, newUser._id);
    const { userId, ...doctorSetFields } = doctorFields;
    clinicId = doctorFields.clinicId || clinicId;
    if (clinicId && !newUser.clinicId) {
      await UserModel.updateOne({ _id: newUser._id }, { $set: { clinicId, orgId: doctorFields.orgId } });
    }
    await Doctor.updateOne(
      { userId: newUser._id },
      {
        $set: doctorSetFields,
        $setOnInsert: { userId: newUser._id },
      },
      { upsert: true }
    );
  }

  if (rr.role === "Pharmacist" && rr.pharmacyProfile) {
    try {
      const { provisionExternalPharmacyFromProfile } = require("../services/internalPharmacyProvisioning");
      await provisionExternalPharmacyFromProfile({
        orgId: effectiveOrgId,
        userId: newUser._id,
        profile: rr.pharmacyProfile,
      });
    } catch (phErr) {
      console.warn("[approve-registration] external pharmacy:", phErr.message);
    }
  }

  await RegistrationRequest.updateOne({ _id: rr._id }, { $set: { status: "approved" } });
  await RegistrationRequest.deleteOne({ _id: rr._id });
  return { newUser, effectiveOrgId };
}

module.exports = {
  buildPendingRegistrationQuery,
  findPendingRegistrationById,
  approveRegistrationRequest,
  resolveEffectiveOrgId,
  mapDoctorFromRequest,
};
