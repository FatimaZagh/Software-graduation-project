const mongoose = require("mongoose");
const prescriptionDispensing = require("../services/prescriptionDispensingService");
const { RX_REQUIRED_MESSAGE } = require("../utils/drugPrescriptionClassification");

function sendRxError(res, err) {
  const status = err.statusCode || 403;
  return res.status(status).json({
    code: err.code || "PRESCRIPTION_REQUIRED",
    message: err.message || RX_REQUIRED_MESSAGE,
  });
}

/** GET /api/patient-portal/:patientUserId/dispensing-prescriptions */
async function listPatientPrescriptions(req, res) {
  try {
    const list = await prescriptionDispensing.listPatientDispensingPrescriptions(req.patientUserId);
    res.json({ prescriptions: list });
  } catch (e) {
    console.error("[dispensing-prescriptions]", e);
    res.status(500).json({ message: e.message || "Error loading prescriptions" });
  }
}

/** POST /api/patient-portal/:patientUserId/pharmacy/purchase */
async function postPharmacyPurchase(req, res) {
  try {
    const {
      drugId,
      medicationName,
      quantity,
      pharmacyId,
      orgId,
      paymentStatus,
      cardLastFour,
      cardholderName,
      locale,
      patientLocale,
      prescriptionId,
      medicationId,
    } = req.body;
    const pharmacyInventoryService = require("../services/pharmacyInventoryService");
    const request = await pharmacyInventoryService.createPatientMedicationRequest({
      patientUserId: req.patientUserId,
      pharmacyId,
      drugId,
      medicationName,
      quantity: quantity != null ? quantity : 1,
      orgId: orgId || req.query.orgId,
      paymentStatus,
      cardLastFour,
      cardholderName,
      patientLocale: patientLocale || locale || req.headers["x-locale"] || "en",
      prescriptionId,
      medicationId,
    });
    res.status(201).json({
      ok: true,
      message: "Medication request submitted to the selected pharmacy.",
      request,
    });
  } catch (e) {
    if (e.code === "PRESCRIPTION_REQUIRED" || e.code === "PRESCRIPTION_QUANTITY_EXCEEDED") {
      return sendRxError(res, e);
    }
    const status = e.statusCode || 500;
    res.status(status).json({ message: e.message || "Purchase failed" });
  }
}

/** GET /api/patient-portal/:patientUserId/pharmacy/catalog?q= */
async function getPharmacyCatalog(req, res) {
  try {
    const orgId = String(req.query.orgId || "").trim();
    if (orgId && mongoose.Types.ObjectId.isValid(orgId)) {
      const routing = require("../services/pharmacyRoutingService");
      const ctx = await routing.resolveOrgClinicContext(orgId, req.query.clinicId);
      if (ctx.scenario === "A") {
        const data = await routing.getInternalPharmacyCatalog(orgId, { drugId: req.query.drugId });
        return res.json(data.items);
      }
    }
    const list = await prescriptionDispensing.searchCatalogForPatient(req.query.q);
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: e.message || "Error loading catalog" });
  }
}

/** POST /api/doctor/dispensing-prescriptions */
async function createDoctorPrescription(req, res) {
  try {
    const { orgId, doctorUserId, doctorProfile, user } = req.doctorScope;
    const {
      patientUserId,
      patientName,
      items,
      issueDate,
      expiryDate,
      expiryDays,
      appointmentId,
      electronicSignature,
    } = req.body;
    if (!patientUserId) return res.status(400).json({ message: "patientUserId required" });

    let expiry = expiryDate;
    if (!expiry && expiryDays != null) {
      const d = new Date();
      d.setDate(d.getDate() + Number(expiryDays) || 30);
      expiry = d;
    }

    const result = await prescriptionDispensing.createDispensingPrescription({
      orgId,
      doctorUserId,
      doctorDisplayName: doctorProfile?.displayName || user?.name || "Doctor",
      patientUserId,
      patientDisplayName: patientName,
      items,
      issueDate,
      expiryDate: expiry,
      appointmentId,
      electronicSignature,
    });
    res.status(201).json(result);
  } catch (e) {
    const status = e.statusCode || 500;
    res.status(status).json({ message: e.message || "Error creating prescription" });
  }
}

/** POST validate only — for UI pre-check */
async function postValidatePurchase(req, res) {
  try {
    const { drugId, medicationName, quantity } = req.body;
    const result = await prescriptionDispensing.validatePatientPurchase({
      patientUserId: req.patientUserId,
      drugId,
      medicationName,
      quantity: quantity != null ? quantity : 1,
    });
    res.json({ valid: true, ...result });
  } catch (e) {
    if (e.code === "PRESCRIPTION_REQUIRED" || e.code === "PRESCRIPTION_QUANTITY_EXCEEDED") {
      return sendRxError(res, e);
    }
    res.status(e.statusCode || 500).json({ message: e.message });
  }
}

module.exports = {
  listPatientPrescriptions,
  postPharmacyPurchase,
  getPharmacyCatalog,
  createDoctorPrescription,
  postValidatePurchase,
};
