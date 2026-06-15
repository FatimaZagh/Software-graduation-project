const mongoose = require("mongoose");
const LabRequest = require("../models/labRequest");
const RadiologyRequest = require("../models/radiologyRequest");
const Prescription = require("../models/prescription");
const ElectronicPrescription = require("../models/electronicPrescription");
const Organization = require("../models/Organization");
const Clinic = require("../models/clinic");
const UserModel = require("../models/User");

const DEFAULT_LIMIT = 200;
const MAX_LIMIT = 500;

function clampLimit(raw) {
  const n = parseInt(raw, 10);
  if (!Number.isFinite(n) || n < 1) return DEFAULT_LIMIT;
  return Math.min(n, MAX_LIMIT);
}

function toIsoDate(value) {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function normalizeFeedStatus(orderType, rawStatus, extras = {}) {
  const s = String(rawStatus || "").trim();
  if (orderType === "LAB_TEST") {
    if (s === "Completed") return "Completed";
    if (s === "Sample-Collected") return "Pending";
    return "Requested";
  }
  if (orderType === "IMAGING") {
    if (s === "Completed") return "Completed";
    if (s === "Scheduled") return "Pending";
    if (s === "Cancelled") return "Completed";
    return "Requested";
  }
  if (orderType === "PRESCRIPTION") {
    if (s === "Discontinued" || s === "Expired" || s === "Cancelled") return "Completed";
    if (extras.syncedToPharmacy === true) return "Pending";
    return "Requested";
  }
  return "Requested";
}

function formatInitiator(user, fallbackName) {
  const name = (user?.name || fallbackName || user?.email || "").trim();
  if (!name) return "Clinical staff";
  const role = String(user?.role || "").trim();
  if (role === "Doctor") return `Dr. ${name}`;
  if (role === "Nurse") return `Nurse ${name}`;
  if (role === "Lab Technician") return `Lab Tech ${name}`;
  if (role === "Radiologist") return `Radiology Tech ${name}`;
  if (role) return `${role} ${name}`;
  return name;
}

function prescriptionTitle(doc) {
  const items = Array.isArray(doc.items) ? doc.items : [];
  if (items.length > 0) {
    const names = items.map((i) => i?.name).filter(Boolean);
    if (names.length === 1) return names[0];
    if (names.length > 1) return `${names[0]} +${names.length - 1} more`;
  }
  const med = doc.medicationName?.trim();
  if (med) return med;
  return "E-Prescription";
}

async function loadNameMaps(docs) {
  const orgIds = new Set();
  const clinicIds = new Set();
  const userIds = new Set();

  for (const d of docs) {
    if (d.orgId) orgIds.add(String(d.orgId));
    if (d.clinicId) clinicIds.add(String(d.clinicId));
    if (d.patientUserId) userIds.add(String(d.patientUserId));
    if (d.doctorUserId) userIds.add(String(d.doctorUserId));
    if (d.requestedBy) userIds.add(String(d.requestedBy));
  }

  const validObjectIds = (ids) =>
    [...ids].filter((id) => mongoose.Types.ObjectId.isValid(id)).map((id) => new mongoose.Types.ObjectId(id));

  const [orgs, clinics, users] = await Promise.all([
    orgIds.size
      ? Organization.find({ _id: { $in: validObjectIds(orgIds) } })
          .select("name")
          .lean()
      : [],
    clinicIds.size
      ? Clinic.find({ _id: { $in: validObjectIds(clinicIds) } })
          .select("name orgId")
          .lean()
      : [],
    userIds.size
      ? UserModel.find({ _id: { $in: validObjectIds(userIds) } })
          .select("name email role orgId clinicId")
          .lean()
      : [],
  ]);

  const orgNameById = new Map(orgs.map((o) => [String(o._id), o.name || "Facility"]));
  const clinicById = new Map(clinics.map((c) => [String(c._id), c]));
  const userById = new Map(users.map((u) => [String(u._id), u]));

  const extraOrgIds = new Set();
  const extraClinicIds = new Set();
  for (const u of users) {
    if (u.orgId) extraOrgIds.add(String(u.orgId));
    if (u.clinicId) extraClinicIds.add(String(u.clinicId));
  }

  const [extraOrgs, extraClinics] = await Promise.all([
    extraOrgIds.size
      ? Organization.find({ _id: { $in: validObjectIds(extraOrgIds) } })
          .select("name")
          .lean()
      : [],
    extraClinicIds.size
      ? Clinic.find({ _id: { $in: validObjectIds(extraClinicIds) } })
          .select("name orgId")
          .lean()
      : [],
  ]);

  for (const o of extraOrgs) orgNameById.set(String(o._id), o.name || "Facility");
  for (const c of extraClinics) clinicById.set(String(c._id), c);

  return { orgNameById, clinicById, userById };
}

function resolveLocation(doc, maps, initiatorUser) {
  const clinicId = doc.clinicId || initiatorUser?.clinicId;
  const orgId = doc.orgId || initiatorUser?.orgId || (clinicId ? maps.clinicById.get(String(clinicId))?.orgId : null);
  const clinic = clinicId ? maps.clinicById.get(String(clinicId)) : null;
  const clinicName = clinic?.name || "";
  const orgName =
    (orgId ? maps.orgNameById.get(String(orgId)) : null) ||
    (clinic?.orgId ? maps.orgNameById.get(String(clinic.orgId)) : null) ||
    "";
  return {
    clinicName: clinicName || orgName || "—",
    facilityName: orgName || clinicName || "—",
  };
}

function mapLabRow(doc, maps) {
  const initiatorUser =
    maps.userById.get(String(doc.requestedBy || "")) ||
    maps.userById.get(String(doc.doctorUserId || ""));
  const location = resolveLocation(doc, maps, initiatorUser);
  const createdAt = toIsoDate(doc.createdAt);
  return {
    id: String(doc._id),
    orderType: "LAB_TEST",
    requestTypeLabel: "LAB TEST",
    title: doc.testName || "Lab test",
    detail: doc.testType || "",
    rawStatus: doc.status || "Requested",
    status: normalizeFeedStatus("LAB_TEST", doc.status),
    initiatorName: formatInitiator(initiatorUser),
    initiatorRole: initiatorUser?.role || "Doctor",
    patientUserId: doc.patientUserId ? String(doc.patientUserId) : "",
    clinicName: location.clinicName,
    facilityName: location.facilityName,
    orgId: doc.orgId ? String(doc.orgId) : "",
    createdAt,
  };
}

function mapImagingRow(doc, maps) {
  const initiatorUser =
    maps.userById.get(String(doc.requestedBy || "")) ||
    maps.userById.get(String(doc.doctorUserId || ""));
  const location = resolveLocation(doc, maps, initiatorUser);
  const createdAt = toIsoDate(doc.createdAt);
  const modality = doc.modality || "Imaging";
  return {
    id: String(doc._id),
    orderType: "IMAGING",
    requestTypeLabel: "IMAGING",
    title: doc.studyName || "Imaging study",
    detail: modality,
    rawStatus: doc.status || "Requested",
    status: normalizeFeedStatus("IMAGING", doc.status),
    initiatorName: formatInitiator(initiatorUser),
    initiatorRole: initiatorUser?.role || "Doctor",
    patientUserId: doc.patientUserId ? String(doc.patientUserId) : "",
    clinicName: location.clinicName,
    facilityName: location.facilityName,
    orgId: doc.orgId ? String(doc.orgId) : "",
    createdAt,
  };
}

function mapPrescriptionRow(doc, maps, { electronic = false } = {}) {
  const initiatorUser = maps.userById.get(String(doc.doctorUserId || ""));
  const location = resolveLocation(doc, maps, initiatorUser);
  const createdAt = toIsoDate(doc.createdAt);
  const fallbackName = doc.doctorDisplayName || doc.doctorName || "";
  return {
    id: String(doc._id),
    orderType: "PRESCRIPTION",
    requestTypeLabel: "PRESCRIPTION",
    title: prescriptionTitle(doc),
    detail: electronic ? "Electronic prescription" : "Clinical prescription",
    rawStatus: doc.status || "Active",
    status: normalizeFeedStatus("PRESCRIPTION", doc.status, { syncedToPharmacy: doc.syncedToPharmacy }),
    initiatorName: formatInitiator(initiatorUser, fallbackName),
    initiatorRole: initiatorUser?.role || "Doctor",
    patientUserId: doc.patientUserId ? String(doc.patientUserId) : "",
    clinicName: location.clinicName,
    facilityName: location.facilityName,
    orgId: doc.orgId ? String(doc.orgId) : "",
    createdAt,
  };
}

/**
 * Aggregates lab, imaging, and e-prescription activity for the Super Admin live feed.
 */
async function buildMedicalOrdersFeed({ limit = DEFAULT_LIMIT } = {}) {
  const perSource = clampLimit(limit);

  const [labs, imaging, prescriptions, electronicRx] = await Promise.all([
    LabRequest.find().sort({ createdAt: -1 }).limit(perSource).lean(),
    RadiologyRequest.find().sort({ createdAt: -1 }).limit(perSource).lean(),
    Prescription.find().sort({ createdAt: -1 }).limit(perSource).lean(),
    ElectronicPrescription.find().sort({ createdAt: -1 }).limit(perSource).lean(),
  ]);

  const allRaw = [...labs, ...imaging, ...prescriptions, ...electronicRx];
  const maps = await loadNameMaps(allRaw);

  const allOrders = [
    ...labs.map((d) => mapLabRow(d, maps)),
    ...imaging.map((d) => mapImagingRow(d, maps)),
    ...prescriptions.map((d) => mapPrescriptionRow(d, maps)),
    ...electronicRx.map((d) => mapPrescriptionRow(d, maps, { electronic: true })),
  ].sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

  const trimmed = allOrders.slice(0, perSource);

  const summary = {
    total: trimmed.length,
    labTests: trimmed.filter((o) => o.orderType === "LAB_TEST").length,
    imaging: trimmed.filter((o) => o.orderType === "IMAGING").length,
    prescriptions: trimmed.filter((o) => o.orderType === "PRESCRIPTION").length,
    requested: trimmed.filter((o) => o.status === "Requested").length,
    pending: trimmed.filter((o) => o.status === "Pending").length,
    completed: trimmed.filter((o) => o.status === "Completed").length,
  };

  return {
    allOrders: trimmed,
    summary,
    fetchedAt: new Date().toISOString(),
  };
}

async function buildPlatformAdminStats() {
  const [clinics, systemUsers, doctors, totalPatients] = await Promise.all([
    Clinic.countDocuments(),
    UserModel.countDocuments({
      role: {
        $nin: ["Patient", "SuperAdmin"],
      },
    }),
    UserModel.countDocuments({ role: "Doctor" }),
    UserModel.countDocuments({ role: "Patient" }),
  ]);

  return {
    clinics,
    systemUsers,
    doctors,
    totalPatients,
  };
}

module.exports = {
  buildMedicalOrdersFeed,
  buildPlatformAdminStats,
  clampLimit,
};
