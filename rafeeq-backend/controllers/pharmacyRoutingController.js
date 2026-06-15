const mongoose = require("mongoose");
const routing = require("../services/pharmacyRoutingService");
const prescriptionDispensing = require("../services/prescriptionDispensingService");
const { RX_REQUIRED_MESSAGE } = require("../utils/drugPrescriptionClassification");

function orgIdFromRequest(req) {
  return String(req.query.orgId || req.body?.orgId || "").trim();
}

function sendRxError(res, err) {
  return res.status(err.statusCode || 403).json({
    code: err.code || "PRESCRIPTION_REQUIRED",
    message: err.message || RX_REQUIRED_MESSAGE,
  });
}

/** GET /api/patient-portal/:patientUserId/pharmacy/routing */
async function getPharmacyRouting(req, res) {
  try {
    const orgId = orgIdFromRequest(req);
    if (!orgId) return res.status(403).json({ message: "orgId is required" });
    const clinicId = String(req.query.clinicId || "").trim() || null;
    const drugId = String(req.query.drugId || "").trim() || null;
    const patientLat = req.query.lat != null ? Number(req.query.lat) : null;
    const patientLng = req.query.lng != null ? Number(req.query.lng) : null;

    const matrix = await routing.getPurchaseRoutingMatrix(orgId, clinicId, {
      drugId,
      patientLat,
      patientLng,
    });
    res.json(matrix);
  } catch (e) {
    res.status(500).json({ message: e.message || "Error resolving pharmacy routing" });
  }
}

/** GET /api/patient-portal/:patientUserId/pharmacy/internal-catalog */
async function getInternalCatalog(req, res) {
  try {
    const orgId = orgIdFromRequest(req);
    if (!orgId) return res.status(403).json({ message: "orgId is required" });
    const drugId = String(req.query.drugId || "").trim() || null;
    const data = await routing.getInternalPharmacyCatalog(orgId, { drugId });
    res.json(data);
  } catch (e) {
    res.status(500).json({ message: e.message || "Error loading internal catalog" });
  }
}

/** GET /api/patient-portal/:patientUserId/pharmacy/external-holding */
async function getExternalHolding(req, res) {
  try {
    const orgId = orgIdFromRequest(req);
    const drugId = String(req.query.drugId || "").trim();
    if (!drugId) return res.status(400).json({ message: "drugId is required" });
    const list = await routing.findExternalPharmaciesHoldingDrug({
      orgId: orgId || null,
      drugId,
      patientLat: req.query.lat != null ? Number(req.query.lat) : null,
      patientLng: req.query.lng != null ? Number(req.query.lng) : null,
    });
    res.json({ pharmacies: list });
  } catch (e) {
    res.status(500).json({ message: e.message || "Error loading external pharmacies" });
  }
}

/** GET /api/pharmacies/search-by-drug */
async function searchPharmaciesByDrug(req, res) {
  try {
    const drugId = String(req.query.drugId || "").trim();
    if (!drugId) return res.status(400).json({ message: "drugId is required" });
    const lat = Number(req.query.lat ?? req.query.latitude);
    const lng = Number(req.query.lng ?? req.query.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ message: "lat and lng query parameters are required" });
    }
    const radiusKm = Number(req.query.radiusKm ?? req.query.radius ?? 10);
    const excludePharmacyId = String(req.query.excludePharmacyId || "").trim() || null;
    const orgId = orgIdFromRequest(req) || null;

    const result = await routing.searchPharmaciesByDrug({
      orgId,
      drugId,
      patientLat: lat,
      patientLng: lng,
      radiusKm,
      excludePharmacyId,
    });
    res.json(result);
  } catch (e) {
    res.status(500).json({ message: e.message || "Error searching pharmacies by drug" });
  }
}

/** GET /api/patient/purchases/:patientUserId */
async function listPatientPurchases(req, res) {
  try {
    const { patientUserId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(patientUserId)) {
      return res.status(400).json({ message: "Invalid patientUserId" });
    }
    const orgId = orgIdFromRequest(req);
    const purchases = await routing.listPatientPurchases(patientUserId, { orgId: orgId || null });
    res.json({ purchases });
  } catch (e) {
    res.status(500).json({ message: e.message || "Error loading purchases" });
  }
}

module.exports = {
  getPharmacyRouting,
  getInternalCatalog,
  getExternalHolding,
  searchPharmaciesByDrug,
  listPatientPurchases,
};
