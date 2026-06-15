const mongoose = require("mongoose");
const UserModel = require("../models/User");
const Patient = require("../models/patient");
const Clinic = require("../models/clinic");
const Organization = require("../models/Organization");

function str(v) {
  return v == null ? "" : String(v).trim();
}

async function enrichDiagnosticOrders(orders, { includeDoctor = true, includeClinic = true } = {}) {
  if (!Array.isArray(orders) || orders.length === 0) return [];

  const patientIds = [...new Set(orders.map((o) => String(o.patientUserId || "")).filter(Boolean))];
  const doctorIds = includeDoctor
    ? [...new Set(orders.map((o) => String(o.doctorUserId || o.requestedBy || "")).filter(Boolean))]
    : [];
  const clinicIds = includeClinic
    ? [...new Set(orders.map((o) => String(o.clinicId || "")).filter(Boolean))]
    : [];
  const orgIds = includeClinic
    ? [...new Set(orders.map((o) => String(o.orgId || "")).filter(Boolean))]
    : [];

  const [users, patients, doctors, clinics, orgs] = await Promise.all([
    patientIds.length
      ? UserModel.find({ _id: { $in: patientIds } }).select("name email gender dateOfBirth phoneNumber").lean()
      : [],
    patientIds.length ? Patient.find({ userId: { $in: patientIds } }).lean() : [],
    doctorIds.length ? UserModel.find({ _id: { $in: doctorIds } }).select("name email").lean() : [],
    clinicIds.length ? Clinic.find({ _id: { $in: clinicIds } }).select("name").lean() : [],
    orgIds.length ? Organization.find({ _id: { $in: orgIds } }).select("name").lean() : [],
  ]);

  const userById = Object.fromEntries(users.map((u) => [String(u._id), u]));
  const patientByUser = Object.fromEntries(patients.map((p) => [String(p.userId), p]));
  const doctorById = Object.fromEntries(doctors.map((d) => [String(d._id), d]));
  const clinicById = Object.fromEntries(clinics.map((c) => [String(c._id), c]));
  const orgById = Object.fromEntries(orgs.map((o) => [String(o._id), o]));

  return orders.map((raw) => {
    const o = { ...raw };
    const pid = String(o.patientUserId || "");
    const user = userById[pid] || {};
    const pat = patientByUser[pid] || {};
    const did = String(o.doctorUserId || o.requestedBy || "");
    const doc = doctorById[did] || {};
    const cid = String(o.clinicId || "");
    const clinic = clinicById[cid] || {};

    o.patient = {
      id: pid,
      patientId: pat._id ? String(pat._id) : pid,
      fullName: str(pat.fullName) || str(user.name) || "Patient",
      age: pat.age != null ? pat.age : null,
      gender: str(pat.gender) || str(user.gender) || "",
      email: str(user.email),
      phone: str(user.phoneNumber),
    };
    if (includeDoctor) {
      o.doctorName = str(doc.name) || "Doctor";
    }
    if (includeClinic) {
      const org = orgById[String(o.orgId || "")] || {};
      o.clinicName = str(clinic.name) || str(org.name) || "";
    }
    return o;
  });
}

module.exports = { enrichDiagnosticOrders, str };
