const mongoose = require("mongoose");
const Organization = require("../models/Organization");
const Clinic = require("../models/clinic");
const Pharmacy = require("../models/pharmacy");
const Drug = require("../models/drug");
const PatientMedicationPurchase = require("../models/patientMedicationPurchase");
const DispensingPrescription = require("../models/dispensingPrescription");

const DEFAULT_RANGE_KM = 30;

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function inventoryRowForDrug(pharmacy, drugId) {
  const drugOid = String(drugId);
  return (pharmacy.inventory || []).find((row) => row.drug_id && String(row.drug_id) === drugOid);
}

function mapPharmacySummary(ph, drugId, patientLat, patientLng) {
  const row = drugId ? inventoryRowForDrug(ph, drugId) : null;
  const qty = row ? Number(row.quantity) : 0;
  let distanceKm = null;
  if (
    patientLat != null &&
    patientLng != null &&
    ph.latitude != null &&
    ph.longitude != null
  ) {
    distanceKm = Number(
      haversineKm(patientLat, patientLng, Number(ph.latitude), Number(ph.longitude)).toFixed(2)
    );
  }
  return {
    pharmacyId: ph._id,
    name: ph.name,
    pharmacyType: ph.pharmacyType || "External",
    address: ph.address || "",
    phone: ph.phone || "",
    latitude: ph.latitude,
    longitude: ph.longitude,
    distanceKm,
    stockQuantity: qty,
    inStock: qty > 0,
    hasDrug: drugId ? Boolean(row) : true,
  };
}

async function resolveOrgClinicContext(orgId, clinicId = null) {
  if (!orgId || !mongoose.Types.ObjectId.isValid(orgId)) {
    return { scenario: "B", hasInternalPharmacy: false, internalPharmacy: null, org: null, clinic: null };
  }

  const org = await Organization.findById(orgId).lean();
  if (!org) {
    return { scenario: "B", hasInternalPharmacy: false, internalPharmacy: null, org: null, clinic: null };
  }

  let clinic = null;
  if (clinicId && mongoose.Types.ObjectId.isValid(clinicId)) {
    clinic = await Clinic.findOne({ _id: clinicId, orgId }).lean();
  } else {
    clinic = await Clinic.findOne({ orgId, hasInternalPharmacy: true }).lean();
  }

  const hasInternal =
    (clinic?.hasInternalPharmacy === true || org.hasInternalPharmacy === true) &&
    org.activeModules?.pharmacy === true;

  let internalPharmacy = null;
  const internalId = clinic?.internalPharmacyId || org.internalPharmacyId;
  if (hasInternal && internalId) {
    internalPharmacy = await Pharmacy.findById(internalId).lean();
  }

  if (hasInternal && !internalPharmacy) {
    internalPharmacy = await Pharmacy.findOne({ orgId, pharmacyType: "Internal" }).lean();
  }

  const scenario = hasInternal && internalPharmacy ? "A" : "B";

  return {
    scenario,
    hasInternalPharmacy: Boolean(internalPharmacy),
    internalPharmacy: internalPharmacy
      ? {
          pharmacyId: internalPharmacy._id,
          name: internalPharmacy.name,
          pharmacyType: "Internal",
          address: internalPharmacy.address || "",
        }
      : null,
    org,
    clinic,
  };
}

async function getInternalPharmacyCatalog(orgId, { drugId = null, limit = 80 } = {}) {
  const ctx = await resolveOrgClinicContext(orgId);
  if (!ctx.internalPharmacy) {
    return { items: [], pharmacy: null, scenario: ctx.scenario };
  }

  const ph = await Pharmacy.findById(ctx.internalPharmacy.pharmacyId).populate("inventory.drug_id", "name category requiresPrescription").lean();
  if (!ph) return { items: [], pharmacy: null, scenario: ctx.scenario };

  const drugOid = drugId && mongoose.Types.ObjectId.isValid(drugId) ? String(drugId) : null;
  const items = [];

  for (const row of ph.inventory || []) {
    const drug = row.drug_id && typeof row.drug_id === "object" ? row.drug_id : null;
    if (!drug) continue;
    if (drugOid && String(drug._id) !== drugOid) continue;

    items.push({
      _id: drug._id,
      id: drug._id,
      name: drug.name,
      category: drug.category,
      requiresPrescription: Boolean(drug.requiresPrescription),
      inStock: Number(row.quantity) > 0,
      stockQuantity: Number(row.quantity) || 0,
      price: row.price ?? 0,
      pharmacyId: ph._id,
      pharmacyName: ph.name,
      pharmacyType: "Internal",
    });
    if (items.length >= limit) break;
  }

  return {
    scenario: "A",
    pharmacy: mapPharmacySummary(ph, drugId),
    items,
  };
}

async function findExternalPharmaciesHoldingDrug({
  orgId,
  drugId,
  patientLat = null,
  patientLng = null,
  maxKm = DEFAULT_RANGE_KM,
  excludePharmacyId = null,
}) {
  if (!drugId || !mongoose.Types.ObjectId.isValid(drugId)) {
    return [];
  }

  const drugOid = new mongoose.Types.ObjectId(drugId);
  const excludeId = excludePharmacyId && mongoose.Types.ObjectId.isValid(excludePharmacyId)
    ? String(excludePharmacyId)
    : null;

  const filter = {
    pharmacyType: "External",
    status: { $in: ["Active", "active", null] },
    "inventory.drug_id": drugOid,
    "inventory.quantity": { $gt: 0 },
  };
  if (orgId && mongoose.Types.ObjectId.isValid(orgId)) {
    filter.$or = [{ orgId: new mongoose.Types.ObjectId(orgId) }, { orgId: null }, { orgId: { $exists: false } }];
  }

  const pharmacies = await Pharmacy.find(filter).lean();
  const out = [];

  for (const ph of pharmacies) {
    if (excludeId && String(ph._id) === excludeId) continue;
    if (ph.pharmacyType === "Internal") continue;
    const row = inventoryRowForDrug(ph, drugId);
    if (!row || Number(row.quantity) <= 0) continue;
    const summary = mapPharmacySummary(ph, drugId, patientLat, patientLng);
    if (summary.distanceKm != null && summary.distanceKm > maxKm) continue;
    out.push(summary);
  }

  out.sort((a, b) => {
    if (a.distanceKm == null && b.distanceKm == null) return 0;
    if (a.distanceKm == null) return 1;
    if (b.distanceKm == null) return -1;
    return a.distanceKm - b.distanceKm;
  });

  return out;
}

/**
 * Geospatial search for external pharmacies stocking a drug (failover from clinic pharmacy).
 */
async function searchPharmaciesByDrug({
  orgId = null,
  drugId,
  patientLat,
  patientLng,
  radiusKm = 10,
  excludePharmacyId = null,
}) {
  const maxKm = Math.min(Math.max(Number(radiusKm) || 10, 1), 50);
  const drug = drugId && mongoose.Types.ObjectId.isValid(drugId) ? await Drug.findById(drugId).lean() : null;
  const pharmacies = await findExternalPharmaciesHoldingDrug({
    orgId,
    drugId,
    patientLat,
    patientLng,
    maxKm,
    excludePharmacyId,
  });

  return {
    drug: drug ? { id: drug._id, name: drug.name, requiresPrescription: drug.requiresPrescription } : null,
    searchCenter: { latitude: patientLat, longitude: patientLng },
    radiusKm: maxKm,
    excludePharmacyId: excludePharmacyId || null,
    pharmacies,
    total: pharmacies.length,
  };
}

async function getPurchaseRoutingMatrix(orgId, clinicId, { drugId = null, patientLat = null, patientLng = null } = {}) {
  const ctx = await resolveOrgClinicContext(orgId, clinicId);
  const drug = drugId && mongoose.Types.ObjectId.isValid(drugId) ? await Drug.findById(drugId).lean() : null;

  if (ctx.scenario === "A" && ctx.internalPharmacy) {
    const ph = await Pharmacy.findById(ctx.internalPharmacy.pharmacyId).lean();
    const row = drugId ? inventoryRowForDrug(ph, drugId) : null;
    const internalStock = row ? Number(row.quantity) : 0;
    const external = internalStock <= 0 && drugId
      ? await findExternalPharmaciesHoldingDrug({ orgId, drugId, patientLat, patientLng })
      : [];

    return {
      scenario: "A",
      hasInternalPharmacy: true,
      showInternalFirst: true,
      internalPharmacy: mapPharmacySummary(ph, drugId, patientLat, patientLng),
      internalStockQuantity: internalStock,
      internalInStock: internalStock > 0,
      showExternalFallback: internalStock <= 0,
      externalPharmacies: external,
      drug: drug ? { id: drug._id, name: drug.name, requiresPrescription: drug.requiresPrescription } : null,
      message:
        internalStock > 0
          ? "Available at your clinic pharmacy."
          : "Not available in clinic pharmacy. Browse nearby pharmacies holding this item:",
    };
  }

  const external = drugId
    ? await findExternalPharmaciesHoldingDrug({ orgId, drugId, patientLat, patientLng })
    : await Pharmacy.find({ pharmacyType: "External", status: { $in: ["Active", "active", null] } })
        .limit(20)
        .lean()
        .then((list) => list.map((ph) => mapPharmacySummary(ph, drugId, patientLat, patientLng)));

  return {
    scenario: "B",
    hasInternalPharmacy: false,
    showInternalFirst: false,
    internalPharmacy: null,
    internalStockQuantity: 0,
    internalInStock: false,
    showExternalFallback: true,
    externalPharmacies: external,
    drug: drug ? { id: drug._id, name: drug.name, requiresPrescription: drug.requiresPrescription } : null,
    message: "This clinic routes purchases through registered community pharmacies.",
  };
}

async function recordPatientPurchase({
  patientUserId,
  orgId,
  drug,
  quantity,
  pharmacy,
  requiresPrescription = false,
  prescribingDoctorName = "",
  prescriptionId = null,
  source = "patient_purchase",
}) {
  const dosage = drug?.name?.includes("mg") ? drug.name.split(" ").slice(-2).join(" ") : "";
  return PatientMedicationPurchase.create({
    patientUserId,
    orgId: orgId && mongoose.Types.ObjectId.isValid(orgId) ? orgId : null,
    drugId: drug._id,
    drugName: drug.name,
    dosage,
    quantity,
    pharmacyId: pharmacy?._id || pharmacy?.pharmacyId || null,
    pharmacyName: pharmacy?.name || pharmacy?.pharmacyName || "Pharmacy",
    pharmacyType: pharmacy?.pharmacyType === "Internal" ? "Internal" : "External",
    requiresPrescription: Boolean(requiresPrescription),
    prescribingDoctorName: prescribingDoctorName || "",
    prescriptionId: prescriptionId || null,
    source,
  });
}

async function listPatientPurchases(patientUserId, { orgId = null, limit = 100 } = {}) {
  const filter = { patientUserId };
  if (orgId && mongoose.Types.ObjectId.isValid(orgId)) {
    filter.orgId = new mongoose.Types.ObjectId(orgId);
  }

  const rows = await PatientMedicationPurchase.find(filter)
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();

  return rows.map((p) => ({
    id: p._id,
    drugName: p.drugName,
    dosage: p.dosage || "",
    quantity: p.quantity,
    pharmacyName: p.pharmacyName,
    pharmacyType: p.pharmacyType,
    pharmacyLabel:
      p.pharmacyType === "Internal"
        ? `${p.pharmacyName} (Clinic Internal Pharmacy)`
        : `${p.pharmacyName} (External Community Pharmacy)`,
    purchasedAt: p.createdAt,
    requiresPrescription: p.requiresPrescription,
    prescribingDoctorName: p.prescribingDoctorName || "",
    doctorName: p.prescribingDoctorName || null,
  }));
}

async function resolveDoctorNameForPrescription(prescriptionId) {
  if (!prescriptionId) return "";
  const rx = await DispensingPrescription.findById(prescriptionId).select("doctorDisplayName").lean();
  return rx?.doctorDisplayName || "";
}

module.exports = {
  resolveOrgClinicContext,
  getInternalPharmacyCatalog,
  findExternalPharmaciesHoldingDrug,
  searchPharmaciesByDrug,
  getPurchaseRoutingMatrix,
  recordPatientPurchase,
  listPatientPurchases,
  resolveDoctorNameForPrescription,
  haversineKm,
};
