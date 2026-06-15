const crypto = require("crypto");
const mongoose = require("mongoose");
const Drug = require("../models/drug");
const DispensingPrescription = require("../models/dispensingPrescription");
const DispensingPrescriptionItem = require("../models/dispensingPrescriptionItem");
const DispensingTransaction = require("../models/dispensingTransaction");
const { RX_REQUIRED_MESSAGE } = require("../utils/drugPrescriptionClassification");
const pharmacyInventoryService = require("./pharmacyInventoryService");

const RX_BLOCK = {
  code: "PRESCRIPTION_REQUIRED",
  message: RX_REQUIRED_MESSAGE,
};

function rxError(message, statusCode = 403) {
  const err = new Error(message || RX_REQUIRED_MESSAGE);
  err.statusCode = statusCode;
  err.code = "PRESCRIPTION_REQUIRED";
  return err;
}

function normalizeQty(value) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.floor(n);
}

async function nextPrescriptionCode() {
  const count = await DispensingPrescription.countDocuments();
  return `Rx-${1000 + count + 1}`;
}

function issueElectronicSignature(doctorUserId, patientUserId, issueDate) {
  const secret = String(process.env.JWT_SECRET || "rafeeq-rx-signing").trim();
  return crypto
    .createHmac("sha256", secret)
    .update(`${doctorUserId}:${patientUserId}:${new Date(issueDate).toISOString()}`)
    .digest("hex")
    .slice(0, 24);
}

function resolvePrescriptionIsActive(prescription, items) {
  if (prescription.status !== "Active") return false;
  if (prescription.expiryDate && new Date(prescription.expiryDate) < new Date()) return false;
  return (items || []).some((it) => Number(it.remainingQuantity) > 0);
}

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

/** Mark Active prescriptions past expiry_date as Expired. */
async function expireStalePrescriptions(patientUserId = null) {
  const now = new Date();
  const filter = { status: "Active", expiryDate: { $lt: now } };
  if (patientUserId && mongoose.Types.ObjectId.isValid(patientUserId)) {
    filter.patientUserId = patientUserId;
  }
  const result = await DispensingPrescription.updateMany(filter, { $set: { status: "Expired" } });
  return result.modifiedCount || 0;
}

async function maybeCompletePrescription(prescriptionId) {
  const items = await DispensingPrescriptionItem.find({ prescriptionId }).lean();
  if (!items.length) return;
  const allDone = items.every((it) => Number(it.remainingQuantity) <= 0);
  if (allDone) {
    await DispensingPrescription.updateOne(
      { _id: prescriptionId, status: "Active" },
      { $set: { status: "Completed" } }
    );
  }
}

async function getDrugByIdOrName({ drugId, medicationName }) {
  if (drugId && mongoose.Types.ObjectId.isValid(drugId)) {
    return Drug.findById(drugId).lean();
  }
  const name = String(medicationName || "").trim();
  if (!name) return null;
  const rx = new RegExp(`^${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`, "i");
  return Drug.findOne({ name: rx }).lean();
}

/**
 * Validate whether a patient may purchase/dispense a quantity of a drug.
 */
async function validatePatientPurchase({
  patientUserId,
  drugId,
  medicationName,
  quantity,
  prescriptionId = null,
  medicationId = null,
}) {
  const qty = normalizeQty(quantity);
  if (!qty) {
    const err = new Error("quantity must be a positive number.");
    err.statusCode = 400;
    throw err;
  }

  const drug = await getDrugByIdOrName({ drugId, medicationName });
  if (!drug) {
    const err = new Error("Medication not found in catalog.");
    err.statusCode = 404;
    throw err;
  }

  if (!drug.requiresPrescription) {
    return { allowed: true, requiresPrescription: false, drug, quantity: qty };
  }

  await expireStalePrescriptions(patientUserId);
  const now = new Date();
  const patientOid = new mongoose.Types.ObjectId(patientUserId);
  const drugOid = drug._id;

  const activePrescriptions = await DispensingPrescription.find({
    patientUserId: patientOid,
    status: "Active",
    expiryDate: { $gte: now },
  })
    .sort({ issueDate: -1 })
    .lean();

  if (!activePrescriptions.length) {
    throw rxError();
  }

  const prescriptionIds = activePrescriptions.map((p) => p._id);

  const resolvedDrugId =
    medicationId && mongoose.Types.ObjectId.isValid(String(medicationId))
      ? new mongoose.Types.ObjectId(String(medicationId))
      : drugOid;

  const itemQuery = {
    prescriptionId: { $in: prescriptionIds },
    drugId: resolvedDrugId,
    itemStatus: "Active",
    remainingQuantity: { $gt: 0 },
  };

  if (prescriptionId && mongoose.Types.ObjectId.isValid(String(prescriptionId))) {
    itemQuery.prescriptionId = new mongoose.Types.ObjectId(String(prescriptionId));
  }

  const item = await DispensingPrescriptionItem.findOne(itemQuery).lean();

  if (!item) {
    throw rxError();
  }

  if (Number(item.remainingQuantity) < qty) {
    const err = new Error(
      `Requested quantity (${qty}) exceeds remaining prescription allowance (${item.remainingQuantity}).`
    );
    err.statusCode = 409;
    err.code = "PRESCRIPTION_QUANTITY_EXCEEDED";
    throw err;
  }

  const prescription = activePrescriptions.find((p) => String(p._id) === String(item.prescriptionId));

  return {
    allowed: true,
    requiresPrescription: true,
    drug,
    quantity: qty,
    prescriptionId: item.prescriptionId,
    prescriptionItemId: item._id,
    remainingQuantity: item.remainingQuantity,
    prescription,
  };
}

async function recordDispensingOnItem({ prescriptionItemId, quantity }) {
  const item = await DispensingPrescriptionItem.findById(prescriptionItemId);
  if (!item) {
    const err = new Error("Prescription item not found.");
    err.statusCode = 404;
    throw err;
  }

  const qty = normalizeQty(quantity);
  if (!qty) throw rxError("Invalid quantity.", 400);

  if (Number(item.remainingQuantity) < qty) {
    const err = new Error(
      `Cannot dispense ${qty} units. Remaining allowance: ${item.remainingQuantity}.`
    );
    err.statusCode = 409;
    err.code = "PRESCRIPTION_QUANTITY_EXCEEDED";
    throw err;
  }

  item.dispensedQuantity = Number(item.dispensedQuantity) + qty;
  item.remainingQuantity = Math.max(0, Number(item.prescribedQuantity) - Number(item.dispensedQuantity));
  if (item.remainingQuantity <= 0) {
    item.remainingQuantity = 0;
    item.itemStatus = "Fully Dispensed";
  }
  await item.save();
  await maybeCompletePrescription(item.prescriptionId);
  return item.toObject();
}

/**
 * Full controlled purchase: validate Rx → update item → inventory → transaction.
 */
async function purchaseMedication({
  patientUserId,
  orgId = null,
  drugId,
  medicationName,
  quantity,
  pharmacyId,
  performedBy = "",
  source = "patient_purchase",
}) {
  const validation = await validatePatientPurchase({
    patientUserId,
    drugId,
    medicationName,
    quantity,
  });

  const resolvedDrugId = validation.drug._id;
  let prescriptionItemId = validation.prescriptionItemId || null;
  let prescriptionId = validation.prescriptionId || null;

  if (validation.requiresPrescription) {
    const updatedItem = await recordDispensingOnItem({
      prescriptionItemId: validation.prescriptionItemId,
      quantity: validation.quantity,
    });
    prescriptionItemId = updatedItem._id;
    prescriptionId = updatedItem.prescriptionId;
  }

  const Pharmacy = require("../models/pharmacy");
  const routing = require("./pharmacyRoutingService");

  let resolvedPharmacyId = pharmacyId;
  if (!resolvedPharmacyId || !mongoose.Types.ObjectId.isValid(resolvedPharmacyId)) {
    if (orgId && mongoose.Types.ObjectId.isValid(orgId)) {
      const matrix = await routing.getPurchaseRoutingMatrix(orgId, null, { drugId: resolvedDrugId });
      if (matrix.scenario === "A" && matrix.internalInStock && matrix.internalPharmacy?.pharmacyId) {
        resolvedPharmacyId = matrix.internalPharmacy.pharmacyId;
      } else if (matrix.externalPharmacies?.length) {
        resolvedPharmacyId = matrix.externalPharmacies[0].pharmacyId;
      }
    }
    if (!resolvedPharmacyId || !mongoose.Types.ObjectId.isValid(resolvedPharmacyId)) {
      const pharmacies = await Pharmacy.find({ status: { $in: ["Active", "active", null] } })
        .sort({ updatedAt: -1 })
        .limit(20)
        .lean();
      const drugOid = new mongoose.Types.ObjectId(resolvedDrugId);
      for (const ph of pharmacies) {
        const row = (ph.inventory || []).find(
          (r) => r.drug_id && String(r.drug_id) === String(drugOid) && Number(r.quantity) >= validation.quantity
        );
        if (row) {
          resolvedPharmacyId = ph._id;
          break;
        }
      }
    }
  }

  let inventoryResult = null;
  if (resolvedPharmacyId && mongoose.Types.ObjectId.isValid(resolvedPharmacyId)) {
    inventoryResult = await pharmacyInventoryService.dispenseDrug({
      pharmacyId: resolvedPharmacyId,
      drugId: resolvedDrugId,
      amount: validation.quantity,
      performedBy,
      skipPrescriptionValidation: true,
    });
  }

  let transaction = null;
  if (validation.requiresPrescription && prescriptionId && prescriptionItemId) {
    transaction = await DispensingTransaction.create({
      prescriptionId,
      prescriptionItemId,
      patientUserId,
      pharmacyId:
        resolvedPharmacyId && mongoose.Types.ObjectId.isValid(resolvedPharmacyId)
          ? resolvedPharmacyId
          : null,
      drugId: resolvedDrugId,
      drugName: validation.drug.name,
      quantity: validation.quantity,
      performedBy,
      source,
    });
  }

  const phDoc =
    resolvedPharmacyId && mongoose.Types.ObjectId.isValid(resolvedPharmacyId)
      ? await Pharmacy.findById(resolvedPharmacyId).lean()
      : null;

  let doctorName = "";
  if (validation.requiresPrescription && prescriptionId) {
    doctorName = await routing.resolveDoctorNameForPrescription(prescriptionId);
  }

  const purchaseLedger = await routing.recordPatientPurchase({
    patientUserId,
    orgId,
    drug: validation.drug,
    quantity: validation.quantity,
    pharmacy: phDoc || { name: "Pharmacy", pharmacyType: "External" },
    requiresPrescription: validation.requiresPrescription,
    prescribingDoctorName: doctorName,
    prescriptionId,
    source,
  });

  return {
    ok: true,
    requiresPrescription: validation.requiresPrescription,
    drug: validation.drug,
    quantity: validation.quantity,
    prescriptionId,
    prescriptionItemId,
    inventory: inventoryResult,
    transaction: transaction ? transaction.toObject() : null,
    purchase: purchaseLedger.toObject(),
    pharmacy: phDoc
      ? { id: phDoc._id, name: phDoc.name, pharmacyType: phDoc.pharmacyType || "External" }
      : null,
  };
}

/**
 * Pharmacy dispense with optional patient + Rx validation.
 */
async function dispenseWithValidation({
  pharmacyId,
  drugId,
  amount,
  performedBy = "",
  patientUserId = null,
}) {
  const qty = normalizeQty(amount);
  if (!qty) {
    const err = new Error("Dispense amount must be a positive number.");
    err.statusCode = 400;
    throw err;
  }

  const drug = await Drug.findById(drugId).lean();
  if (!drug) {
    const err = new Error("Drug not found.");
    err.statusCode = 404;
    throw err;
  }

  if (drug.requiresPrescription) {
    if (!patientUserId) {
      throw rxError("patientUserId is required for prescription-only medications.", 400);
    }
    const validation = await validatePatientPurchase({
      patientUserId,
      drugId,
      quantity: qty,
    });
    await recordDispensingOnItem({
      prescriptionItemId: validation.prescriptionItemId,
      quantity: qty,
    });

    const inventoryResult = await pharmacyInventoryService.dispenseDrug({
      pharmacyId,
      drugId,
      amount: qty,
      performedBy,
      skipPrescriptionValidation: true,
    });

    const tx = await DispensingTransaction.create({
      prescriptionId: validation.prescriptionId,
      prescriptionItemId: validation.prescriptionItemId,
      patientUserId,
      pharmacyId,
      drugId,
      drugName: drug.name,
      quantity: qty,
      performedBy,
      source: "pharmacy_dispense",
    });

    return { inventory: inventoryResult, transaction: tx.toObject(), validation };
  }

  const inventoryResult = await pharmacyInventoryService.dispenseDrug({
    pharmacyId,
    drugId,
    amount: qty,
    performedBy,
    skipPrescriptionValidation: true,
  });
  return { inventory: inventoryResult, transaction: null, validation: { requiresPrescription: false } };
}

async function assertDoctorOwnsPatient(doctorUserId, patientUserId, orgId) {
  const AppointmentModel = require("../models/appointment");
  const { appointmentMatchQuery } = require("../utils/doctorPortalHelpers");
  const Doctor = require("../models/doctor");
  const UserModel = require("../models/User");

  const doc = await Doctor.findOne({ userId: doctorUserId }).lean();
  const u = await UserModel.findById(doctorUserId).select("name").lean();
  const q = appointmentMatchQuery(doctorUserId, doc?.displayName, u?.name);
  q.orgId = orgId;
  q.patientId = patientUserId;

  const hasAppt = await AppointmentModel.exists(q);
  if (hasAppt) return true;

  const legacyRx = await require("../models/prescription").exists({
    doctorUserId,
    patientUserId,
    orgId,
  });
  if (legacyRx) return true;

  const dispensingRx = await DispensingPrescription.exists({
    doctorUserId,
    patientUserId,
    orgId,
  });
  return Boolean(dispensingRx);
}

async function createDispensingPrescription({
  orgId,
  doctorUserId,
  doctorDisplayName,
  patientUserId,
  patientDisplayName = "",
  items,
  issueDate,
  expiryDate,
  appointmentId = null,
  electronicSignature = null,
}) {
  if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
    const err = new Error("patientUserId required");
    err.statusCode = 400;
    throw err;
  }

  const owns = await assertDoctorOwnsPatient(doctorUserId, patientUserId, orgId);
  if (!owns) {
    const err = new Error("You may only prescribe for your own patients.");
    err.statusCode = 403;
    throw err;
  }

  const lines = Array.isArray(items) ? items : [];
  if (!lines.length) {
    const err = new Error("At least one prescription item is required.");
    err.statusCode = 400;
    throw err;
  }

  const issue = issueDate ? new Date(issueDate) : new Date();
  const expiry = expiryDate ? new Date(expiryDate) : new Date(issue.getTime() + 30 * 24 * 60 * 60 * 1000);
  if (expiry <= issue) {
    const err = new Error("expiryDate must be after issueDate.");
    err.statusCode = 400;
    throw err;
  }

  const UserModel = require("../models/User");
  let resolvedPatientName = String(patientDisplayName || "").trim();
  if (!resolvedPatientName) {
    const patientUser = await UserModel.findById(patientUserId).select("name").lean();
    resolvedPatientName = patientUser?.name || "";
  }

  const prescriptionCode = await nextPrescriptionCode();
  const signature =
    electronicSignature ||
    issueElectronicSignature(doctorUserId, patientUserId, issue);

  const prescription = await DispensingPrescription.create({
    orgId,
    patientUserId,
    doctorUserId,
    doctorDisplayName: doctorDisplayName || "",
    patientDisplayName: resolvedPatientName,
    prescriptionCode,
    electronicSignature: signature,
    issueDate: issue,
    expiryDate: expiry,
    status: "Active",
    appointmentId:
      appointmentId && mongoose.Types.ObjectId.isValid(appointmentId) ? appointmentId : null,
  });

  const { parseDurationInDays } = require("./medicationLifecycle");
  const createdItems = [];
  for (const line of lines) {
    const drugId = line.drugId;
    if (!drugId || !mongoose.Types.ObjectId.isValid(drugId)) {
      const err = new Error("Each item requires a valid drugId.");
      err.statusCode = 400;
      throw err;
    }
    let qty = normalizeQty(line.prescribedQuantity ?? line.quantity);
    if (!qty && line.duration) {
      qty = normalizeQty(parseDurationInDays(line.duration, line.durationInDays));
    }
    if (!qty) {
      const err = new Error("prescribedQuantity must be a positive number.");
      err.statusCode = 400;
      throw err;
    }
    const drug = await Drug.findById(drugId).lean();
    if (!drug) {
      const err = new Error(`Drug not found: ${drugId}`);
      err.statusCode = 404;
      throw err;
    }

    const instructions = String(
      line.instructions ||
        [line.dosage, line.frequency, line.duration].filter(Boolean).join(" · ")
    ).trim();

    const item = await DispensingPrescriptionItem.create({
      prescriptionId: prescription._id,
      drugId: drug._id,
      drugName: drug.name,
      instructions,
      prescribedQuantity: qty,
      dispensedQuantity: 0,
      remainingQuantity: qty,
      itemStatus: "Active",
    });
    createdItems.push(item.toObject());
  }

  return {
    prescription: prescription.toObject(),
    items: createdItems,
    prescriptionId: prescriptionCode,
    electronicSignature: signature,
  };
}

async function listPatientDispensingPrescriptions(patientUserId) {
  await expireStalePrescriptions(patientUserId);
  const UserModel = require("../models/User");
  const patientUser = await UserModel.findById(patientUserId).select("name").lean();
  const fallbackPatientName = patientUser?.name || "";

  const prescriptions = await DispensingPrescription.find({ patientUserId })
    .sort({ issueDate: -1 })
    .limit(100)
    .lean();

  const ids = prescriptions.map((p) => p._id);
  const items = await DispensingPrescriptionItem.find({ prescriptionId: { $in: ids } }).lean();
  const byRx = new Map();
  for (const it of items) {
    const key = String(it.prescriptionId);
    if (!byRx.has(key)) byRx.set(key, []);
    byRx.get(key).push(it);
  }

  return prescriptions.map((p) => {
    const rxItems = byRx.get(String(p._id)) || [];
    const medications = rxItems.map((it) => ({
      id: it._id,
      drugId: it.drugId,
      medicationName: it.drugName,
      quantityAllowed: it.prescribedQuantity,
      quantityDispensed: it.dispensedQuantity,
      remainingPendingQuantity: it.remainingQuantity,
      instructions: it.instructions || "",
      isFullyFulfilled: Number(it.remainingQuantity) <= 0 || it.itemStatus === "Fully Dispensed",
      itemStatus: it.itemStatus,
      // Legacy aliases for existing clients
      prescribedQuantity: it.prescribedQuantity,
      dispensedQuantity: it.dispensedQuantity,
      remainingQuantity: it.remainingQuantity,
    }));

    return {
      id: p._id,
      prescriptionId: p.prescriptionCode || `Rx-${String(p._id).slice(-4).toUpperCase()}`,
      patientId: p.patientUserId,
      patientName: p.patientDisplayName || fallbackPatientName,
      doctorId: p.doctorUserId,
      doctorName: p.doctorDisplayName || "Physician",
      prescribingDoctor: p.doctorDisplayName || "Physician",
      createdAt: p.issueDate,
      issueDate: p.issueDate,
      expiryDate: p.expiryDate,
      status: p.status,
      electronicSignature: p.electronicSignature || "",
      isActive: resolvePrescriptionIsActive(p, rxItems),
      medications,
      items: medications,
    };
  });
}

async function searchCatalogForPatient(q) {
  const term = String(q || "").trim();
  const filter = term
    ? { name: new RegExp(term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i") }
    : {};
  const drugs = await Drug.find(filter).sort({ name: 1 }).limit(50).lean();
  return drugs.map((d) => ({
    _id: d._id,
    id: d._id,
    name: d.name,
    category: d.category,
    requiresPrescription: Boolean(d.requiresPrescription),
    inStock: true,
    strength: "",
    form: "Tablet",
  }));
}

module.exports = {
  RX_BLOCK,
  RX_REQUIRED_MESSAGE,
  expireStalePrescriptions,
  validatePatientPurchase,
  purchaseMedication,
  dispenseWithValidation,
  createDispensingPrescription,
  listPatientDispensingPrescriptions,
  searchCatalogForPatient,
  getDrugByIdOrName,
};
