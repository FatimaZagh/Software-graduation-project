const mongoose = require("mongoose");
const Drug = require("../models/drug");
const Pharmacy = require("../models/pharmacy");

const INVENTORY_STATUS = {
  AVAILABLE: "Available",
  LOW_STOCK: "Low Stock",
  OUT_OF_STOCK: "Out of Stock",
};

function computeStatus(quantity) {
  if (quantity <= 0) return INVENTORY_STATUS.OUT_OF_STOCK;
  if (quantity <= 2) return INVENTORY_STATUS.LOW_STOCK;
  return INVENTORY_STATUS.AVAILABLE;
}

const { seedGlobalDrugs, buildInventoryRows } = require("./seedGlobalDrugs");

/**
 * Ensure a pharmacy document has a full embedded inventory (runs once when empty).
 */
async function ensurePharmacyInventory(pharmacy) {
  if (pharmacy.inventory && pharmacy.inventory.length > 0) {
    return pharmacy;
  }

  const drugs = await Drug.find({}).select("_id").lean();
  if (drugs.length === 0) {
    await seedGlobalDrugs();
    const retry = await Drug.find({}).select("_id").lean();
    if (retry.length === 0) {
      const err = new Error("Global drug catalog is empty.");
      err.statusCode = 503;
      throw err;
    }
    pharmacy.inventory = buildInventoryRows(retry);
  } else {
    pharmacy.inventory = buildInventoryRows(drugs);
  }

  await pharmacy.save();
  return pharmacy;
}

/**
 * Create pharmacy with full inventory seeded once at registration.
 */
async function createPharmacy({ name, latitude, longitude, status = "Active", userId = null, address = "" }) {
  if (userId) {
    const existing = await Pharmacy.findOne({ userId: String(userId) });
    if (existing) {
      if (!existing.inventory || existing.inventory.length === 0) {
        await ensurePharmacyInventory(existing);
        return { pharmacy: existing, seededCount: existing.inventory.length };
      }
      const err = new Error("Pharmacy already exists for this user.");
      err.statusCode = 409;
      err.existingPharmacy = existing;
      throw err;
    }
  }

  const drugs = await Drug.find({}).select("_id").lean();
  if (drugs.length === 0) {
    await seedGlobalDrugs();
  }
  const drugsAfterSeed = await Drug.find({}).select("_id").lean();
  if (drugsAfterSeed.length === 0) {
    const err = new Error("Global drug catalog is empty.");
    err.statusCode = 503;
    throw err;
  }

  const pharmacy = await Pharmacy.create({
    name: String(name).trim(),
    latitude: Number(latitude),
    longitude: Number(longitude),
    status: status || "Active",
    userId: userId ? String(userId) : null,
    address: address != null ? String(address).trim() : "",
    inventory: buildInventoryRows(drugsAfterSeed),
  });

  return { pharmacy, seededCount: pharmacy.inventory.length };
}

/**
 * Register an independent external pharmacy document (no org / clinic linkage).
 */
async function registerExternalPharmacy({
  name,
  latitude,
  longitude,
  status = "Active",
  facilityApprovalLocked = false,
  phone = "",
  address = "",
  operatingHours = "",
  licenseNumber = "",
  userId = null,
}) {
  const { pharmacy, seededCount } = await createPharmacy({
    name,
    latitude,
    longitude,
    status,
    userId: userId != null ? String(userId) : null,
    address,
  });

  pharmacy.pharmacyType = "External";
  pharmacy.facilityApprovalLocked = facilityApprovalLocked;
  pharmacy.orgId = null;
  pharmacy.clinicId = null;
  pharmacy.phone = phone;
  pharmacy.licenseNumber = licenseNumber;
  pharmacy.operatingHours = operatingHours || pharmacy.operatingHours;
  await pharmacy.save();

  return { pharmacy, seededCount };
}

async function getPharmacyByUserId(userId) {
  if (!userId) return null;
  let pharmacy = await Pharmacy.findOne({ userId: String(userId) });
  if (!pharmacy) {
    const User = require("../models/User");
    const user = await User.findById(userId).select("role orgId clinicId").lean();
    if (user?.role === "InternalPharmacist" && user.orgId) {
      pharmacy = await Pharmacy.findOne({
        orgId: user.orgId,
        pharmacyType: "Internal",
      });
      if (pharmacy && !pharmacy.userId) {
        pharmacy.userId = String(userId);
        await pharmacy.save();
      }
    }
  }
  if (!pharmacy) return null;
  if (!pharmacy.inventory || pharmacy.inventory.length === 0) {
    return ensurePharmacyInventory(pharmacy);
  }
  return pharmacy;
}

async function getPharmacyById(pharmacyId) {
  if (!mongoose.Types.ObjectId.isValid(pharmacyId)) return null;
  return Pharmacy.findById(pharmacyId);
}

function countInventoryByStatus(inventory) {
  let availableDrugs = 0;
  let lowStockItems = 0;
  let outOfStockItems = 0;

  for (const row of inventory) {
    if (row.status === INVENTORY_STATUS.AVAILABLE) availableDrugs += 1;
    else if (row.status === INVENTORY_STATUS.LOW_STOCK) lowStockItems += 1;
    else if (row.status === INVENTORY_STATUS.OUT_OF_STOCK) outOfStockItems += 1;
  }

  return { availableDrugs, lowStockItems, outOfStockItems };
}

async function getDashboardStats(pharmacyId) {
  const pharmacy = await getPharmacyById(pharmacyId);
  if (!pharmacy) return null;

  const totalDrugs = await Drug.countDocuments();
  const counts = countInventoryByStatus(pharmacy.inventory);

  return {
    pharmacyId: pharmacy._id.toString(),
    pharmacyName: pharmacy.name,
    totalDrugs,
    availableDrugs: counts.availableDrugs,
    lowStockItems: counts.lowStockItems,
    outOfStockItems: counts.outOfStockItems,
  };
}

async function listInventory(pharmacyId, { limit = 50, offset = 0 } = {}) {
  const pharmacy = await Pharmacy.findById(pharmacyId).populate("inventory.drug_id", "name category requiresPrescription");
  if (!pharmacy) return { count: 0, rows: [] };

  const sorted = [...pharmacy.inventory].sort(
    (a, b) => new Date(b.last_updated) - new Date(a.last_updated)
  );
  const slice = sorted.slice(offset, offset + limit);

  const rows = slice.map((item) => ({
    id: item._id,
    pharmacy_id: pharmacy._id,
    drug_id: item.drug_id?._id || item.drug_id,
    quantity: item.quantity,
    price: item.price ?? 0,
    manufacturer: item.manufacturer ?? "Rafeeq Pharma",
    expiryDate: item.expiryDate,
    status: item.status,
    last_updated: item.last_updated,
    drug: item.drug_id && typeof item.drug_id === "object"
      ? {
          id: item.drug_id._id,
          name: item.drug_id.name,
          category: item.drug_id.category,
          requiresPrescription: Boolean(item.drug_id.requiresPrescription),
        }
      : null,
  }));

  return { count: pharmacy.inventory.length, rows };
}

function appendInventoryLog(pharmacy, { action, drugId, drugName, quantityChange, previousQty, newQty, performedBy, note }) {
  pharmacy.inventoryLogs = pharmacy.inventoryLogs || [];
  pharmacy.inventoryLogs.unshift({
    action,
    drug_id: drugId,
    drugName,
    quantityChange,
    previousQty,
    newQty,
    performedBy: performedBy || "",
    note: note || "",
    createdAt: new Date(),
  });
  if (pharmacy.inventoryLogs.length > 500) {
    pharmacy.inventoryLogs = pharmacy.inventoryLogs.slice(0, 500);
  }
}

/**
 * Decrease stock on embedded inventory. Prevents negative quantity.
 */
async function dispenseDrug({ pharmacyId, drugId, amount = 1, performedBy = "", session = null }) {
  const sold = Number(amount);
  if (!Number.isFinite(sold) || sold <= 0) {
    const err = new Error("Dispense amount must be a positive number.");
    err.statusCode = 400;
    throw err;
  }

  if (!mongoose.Types.ObjectId.isValid(pharmacyId) || !mongoose.Types.ObjectId.isValid(drugId)) {
    const err = new Error("Invalid pharmacyId or drugId.");
    err.statusCode = 400;
    throw err;
  }

  const query = Pharmacy.findById(pharmacyId);
  if (session) query.session(session);
  const pharmacy = await query;
  if (!pharmacy) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  const drugOid = new mongoose.Types.ObjectId(drugId);
  const item = pharmacy.inventory.find((row) => row.drug_id.equals(drugOid));

  if (!item) {
    const err = new Error("Drug not found in pharmacy inventory.");
    err.statusCode = 404;
    throw err;
  }

  if (item.quantity < sold) {
    const err = new Error(`Insufficient stock. Available: ${item.quantity}`);
    err.statusCode = 409;
    throw err;
  }

  const prevQty = item.quantity;
  const drugDoc = await Drug.findById(drugOid).lean();
  const drugName = drugDoc?.name || "Unknown";

  item.quantity -= sold;
  item.status = computeStatus(item.quantity);
  item.last_updated = new Date();

  appendInventoryLog(pharmacy, {
    action: "Dispense",
    drugId: drugOid,
    drugName,
    quantityChange: -sold,
    previousQty: prevQty,
    newQty: item.quantity,
    performedBy,
    note: "Medication request approval",
  });

  if (session) await pharmacy.save({ session });
  else await pharmacy.save();

  return {
    id: item._id,
    pharmacy_id: pharmacy._id,
    drug_id: item.drug_id,
    quantity: item.quantity,
    status: item.status,
    last_updated: item.last_updated,
  };
}

async function listAllDrugs() {
  return Drug.find({}).sort({ category: 1, name: 1 }).lean();
}

async function updateInventoryItem(pharmacyId, drugId, updates, performedBy = "") {
  const pharmacy = await Pharmacy.findById(pharmacyId).populate("inventory.drug_id", "name");
  if (!pharmacy) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  const drugOid = new mongoose.Types.ObjectId(drugId);
  const item = pharmacy.inventory.find((row) => {
    const id = row.drug_id?._id || row.drug_id;
    return id && new mongoose.Types.ObjectId(id).equals(drugOid);
  });
  if (!item) {
    const err = new Error("Drug not found in pharmacy inventory.");
    err.statusCode = 404;
    throw err;
  }

  const prevQty = item.quantity;
  const drugName = item.drug_id?.name || "Unknown";

  if (updates.quantity != null) {
    const q = Math.max(0, Number(updates.quantity));
    item.quantity = q;
    item.status = computeStatus(q);
  }
  if (updates.price != null) item.price = Number(updates.price);
  if (updates.manufacturer != null) item.manufacturer = String(updates.manufacturer);
  if (updates.expiryDate != null) item.expiryDate = new Date(updates.expiryDate);
  item.last_updated = new Date();

  const action = updates.quantity != null && updates.quantity > prevQty ? "Restock" : "Adjustment";
  appendInventoryLog(pharmacy, {
    action,
    drugId: drugOid,
    drugName,
    quantityChange: item.quantity - prevQty,
    previousQty: prevQty,
    newQty: item.quantity,
    performedBy,
    note: updates.note || "",
  });

  await pharmacy.save();
  return item;
}

async function deleteInventoryItem(pharmacyId, drugId, performedBy = "") {
  const pharmacy = await Pharmacy.findById(pharmacyId);
  if (!pharmacy) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  const drugOid = new mongoose.Types.ObjectId(drugId);
  const idx = pharmacy.inventory.findIndex((row) => row.drug_id.equals(drugOid));
  if (idx < 0) {
    const err = new Error("Drug not found in pharmacy inventory.");
    err.statusCode = 404;
    throw err;
  }

  const removed = pharmacy.inventory[idx];
  const drugDoc = await Drug.findById(drugOid).lean();
  appendInventoryLog(pharmacy, {
    action: "Adjustment",
    drugId: drugOid,
    drugName: drugDoc?.name || "Unknown",
    quantityChange: -removed.quantity,
    previousQty: removed.quantity,
    newQty: 0,
    performedBy,
    note: "Removed from inventory",
  });

  pharmacy.inventory.splice(idx, 1);
  await pharmacy.save();
  return { ok: true };
}

async function addInventoryDrug(pharmacyId, { drugId, quantity = 10, price, manufacturer, expiryDate }, performedBy = "") {
  const pharmacy = await Pharmacy.findById(pharmacyId);
  if (!pharmacy) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  const drugOid = new mongoose.Types.ObjectId(drugId);
  const exists = pharmacy.inventory.some((row) => row.drug_id.equals(drugOid));
  if (exists) {
    const err = new Error("Drug already in inventory.");
    err.statusCode = 409;
    throw err;
  }

  const drugDoc = await Drug.findById(drugOid).lean();
  if (!drugDoc) {
    const err = new Error("Drug not found in global catalog.");
    err.statusCode = 404;
    throw err;
  }

  const q = Math.max(0, Number(quantity));
  const item = {
    drug_id: drugOid,
    quantity: q,
    price: price != null ? Number(price) : 15,
    manufacturer: manufacturer || "Rafeeq Pharma",
    expiryDate: expiryDate ? new Date(expiryDate) : new Date(Date.now() + 365 * 86400000),
    status: computeStatus(q),
    last_updated: new Date(),
  };
  pharmacy.inventory.push(item);

  appendInventoryLog(pharmacy, {
    action: "Restock",
    drugId: drugOid,
    drugName: drugDoc.name,
    quantityChange: q,
    previousQty: 0,
    newQty: q,
    performedBy,
    note: "Added to inventory",
  });

  await pharmacy.save();
  return item;
}

async function createNewDrugForPharmacy(pharmacyId, body, performedBy = "") {
  const { inferRequiresPrescription } = require("../utils/drugPrescriptionClassification");
  const name = String(body.name || "").trim();
  const category = String(body.category || "Other").trim();
  if (!name) {
    const err = new Error("Drug name is required.");
    err.statusCode = 400;
    throw err;
  }

  const requiresPrescription =
    body.requiresPrescription === true || body.requiresPrescription === "true"
      ? true
      : body.requiresPrescription === false || body.requiresPrescription === "false"
        ? false
        : inferRequiresPrescription(name, category);

  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  let drug = await Drug.findOne({ name: { $regex: new RegExp(`^${escaped}$`, "i") } });
  if (!drug) {
    drug = await Drug.create({ name, category, requiresPrescription });
  } else {
    drug.category = category;
    drug.requiresPrescription = requiresPrescription;
    await drug.save();
  }

  return addInventoryDrug(
    pharmacyId,
    {
      drugId: drug._id.toString(),
      quantity: body.quantity,
      price: body.price,
      manufacturer: body.manufacturer,
      expiryDate: body.expiryDate,
    },
    performedBy
  );
}

async function getInventoryLogs(pharmacyId, { limit = 100 } = {}) {
  const pharmacy = await Pharmacy.findById(pharmacyId).select("inventoryLogs").lean();
  if (!pharmacy) return [];
  return (pharmacy.inventoryLogs || []).slice(0, limit);
}

async function getAnalytics(pharmacyId) {
  const pharmacy = await Pharmacy.findById(pharmacyId).populate("inventory.drug_id", "name category requiresPrescription");
  if (!pharmacy) return null;

  const byCategory = {};
  const lowStock = [];
  const outOfStock = [];

  for (const item of pharmacy.inventory) {
    const cat = item.drug_id?.category || "Other";
    byCategory[cat] = (byCategory[cat] || 0) + item.quantity;
    const row = {
      name: item.drug_id?.name || "Unknown",
      quantity: item.quantity,
      status: item.status,
    };
    if (item.status === INVENTORY_STATUS.LOW_STOCK) lowStock.push(row);
    if (item.status === INVENTORY_STATUS.OUT_OF_STOCK) outOfStock.push(row);
  }

  const topSelling = [...pharmacy.inventory]
    .sort((a, b) => b.quantity - a.quantity)
    .slice(0, 8)
    .map((item) => ({
      name: item.drug_id?.name || "Unknown",
      quantity: item.quantity,
      category: item.drug_id?.category || "",
    }));

  return {
    categoryStock: Object.entries(byCategory).map(([category, totalQty]) => ({ category, totalQty })),
    topInStock: topSelling,
    lowStock,
    outOfStock,
  };
}

async function getNotifications(pharmacyId) {
  const pharmacy = await Pharmacy.findById(pharmacyId).populate("inventory.drug_id", "name");
  if (!pharmacy) return [];

  const alerts = [];
  const now = new Date();

  for (const item of pharmacy.inventory) {
    const name = item.drug_id?.name || "Unknown";
    if (item.status === INVENTORY_STATUS.LOW_STOCK) {
      alerts.push({ type: "low_stock", severity: "warning", message: `${name} is low stock (${item.quantity} left)`, drugId: item.drug_id._id });
    }
    if (item.status === INVENTORY_STATUS.OUT_OF_STOCK) {
      alerts.push({ type: "out_of_stock", severity: "error", message: `${name} is out of stock`, drugId: item.drug_id._id });
    }
    if (item.expiryDate && new Date(item.expiryDate) < now) {
      alerts.push({ type: "expired", severity: "error", message: `${name} batch expired`, drugId: item.drug_id._id });
    } else if (item.expiryDate) {
      const days = (new Date(item.expiryDate) - now) / 86400000;
      if (days < 60) {
        alerts.push({ type: "expiring_soon", severity: "warning", message: `${name} expires in ${Math.ceil(days)} days`, drugId: item.drug_id._id });
      }
    }
  }

  const MedicationRequest = require("../models/medicationRequest");
  const pendingFilter = { status: "Pending" };
  if (pharmacyId && mongoose.Types.ObjectId.isValid(pharmacyId)) {
    pendingFilter.pharmacyId = new mongoose.Types.ObjectId(pharmacyId);
  }
  const pending = await MedicationRequest.find(pendingFilter).sort({ createdAt: -1 }).limit(10).lean();
  for (const req of pending) {
    alerts.push({
      type: "patient_request",
      severity: "info",
      message: `Patient medication request: ${req.medicationName}`,
      requestId: req._id,
    });
  }

  return alerts;
}

async function updatePharmacySettings(pharmacyId, settings) {
  const pharmacy = await Pharmacy.findById(pharmacyId);
  if (!pharmacy) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  if (settings.name != null) pharmacy.name = String(settings.name).trim();
  if (settings.phone != null) pharmacy.phone = String(settings.phone);
  if (settings.address != null) pharmacy.address = String(settings.address).trim();
  if (settings.operatingHours != null) pharmacy.operatingHours = String(settings.operatingHours);
  if (settings.licenseNumber != null) pharmacy.licenseNumber = String(settings.licenseNumber);
  if (settings.latitude != null) pharmacy.latitude = Number(settings.latitude);
  if (settings.longitude != null) pharmacy.longitude = Number(settings.longitude);

  await pharmacy.save();
  return pharmacy;
}

async function getPharmacyDetails(pharmacyId) {
  return Pharmacy.findById(pharmacyId).populate("inventory.drug_id", "name category").lean();
}

async function getPharmacistProfile(userId) {
  const User = require("../models/User");
  if (!mongoose.Types.ObjectId.isValid(userId)) return null;
  const user = await User.findById(userId).lean();
  if (!user) return null;
  let pharmacy = await Pharmacy.findOne({ userId: String(userId) }).lean();
  if (!pharmacy && user.role === "InternalPharmacist" && user.orgId) {
    pharmacy = await Pharmacy.findOne({ orgId: user.orgId, pharmacyType: "Internal" }).lean();
  }
  return {
    userId: user._id,
    name: user.name || user.email,
    email: user.email,
    phone: user.phoneNumber || pharmacy?.phone || "",
    profileImageUrl: user.profileImageUrl || "",
    role: user.role,
    licenseNumber: pharmacy?.licenseNumber || "",
    pharmacyName: pharmacy?.name || "",
    pharmacyId: pharmacy?._id?.toString() || "",
    operatingHours: pharmacy?.operatingHours || "",
    address: pharmacy?.address || "",
    latitude: pharmacy?.latitude ?? null,
    longitude: pharmacy?.longitude ?? null,
  };
}

async function updatePharmacistUserProfile(userId, body = {}) {
  const User = require("../models/User");
  if (!mongoose.Types.ObjectId.isValid(userId)) {
    const err = new Error("Invalid user id.");
    err.statusCode = 400;
    throw err;
  }
  const user = await User.findById(userId);
  if (!user) {
    const err = new Error("User not found.");
    err.statusCode = 404;
    throw err;
  }
  if (user.role !== "Pharmacist" && user.role !== "InternalPharmacist") {
    const err = new Error("Only pharmacist accounts can use this endpoint.");
    err.statusCode = 403;
    throw err;
  }

  if (body.name != null) user.name = String(body.name).trim();
  if (body.email != null) user.email = String(body.email).trim().toLowerCase();
  const phoneVal = body.phone != null ? body.phone : body.phoneNumber;
  if (phoneVal != null) user.phoneNumber = String(phoneVal).trim();

  const imgRaw = body.profileImageUrl != null ? body.profileImageUrl : body.profileImageBase64;
  if (imgRaw != null) {
    const img = String(imgRaw);
    user.profileImageUrl = img.length > 1_200_000 ? img.slice(0, 1_200_000) : img;
  }

  await user.save();
  return getPharmacistProfile(userId);
}

async function resolvePharmacyIdForStaffUser(userId, explicitPharmacyId = null) {
  const explicit = String(explicitPharmacyId || "").trim();
  if (explicit && mongoose.Types.ObjectId.isValid(explicit)) {
    const ph = await Pharmacy.findById(explicit).select("_id").lean();
    if (ph) return String(ph._id);
  }
  if (!userId) return null;
  const pharmacy = await getPharmacyByUserId(userId);
  return pharmacy?._id ? String(pharmacy._id) : null;
}

async function createPatientMedicationRequest({
  patientUserId,
  pharmacyId,
  drugId = null,
  medicationName = "",
  quantity = 1,
  orgId = null,
  notes = "",
  notifyWhenInStock = false,
  paymentStatus = "",
  cardLastFour = "",
  cardholderName = "",
  patientLocale = "en",
  prescriptionId = null,
  medicationId = null,
}) {
  const MedicationRequest = require("../models/medicationRequest");
  const prescriptionDispensing = require("./prescriptionDispensingService");

  if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
    const err = new Error("Valid patientUserId is required.");
    err.statusCode = 400;
    throw err;
  }
  if (!pharmacyId || !mongoose.Types.ObjectId.isValid(pharmacyId)) {
    const err = new Error("pharmacyId is required — select a specific pharmacy.");
    err.statusCode = 400;
    throw err;
  }
  if (!drugId && !medicationName) {
    const err = new Error("drugId or medicationName is required.");
    err.statusCode = 400;
    throw err;
  }

  const pharmacy = await Pharmacy.findById(pharmacyId).lean();
  if (!pharmacy) {
    const err = new Error("Pharmacy not found.");
    err.statusCode = 404;
    throw err;
  }

  const qty = Math.max(1, Number(quantity) || 1);
  const resolvedDrugId =
    (medicationId && mongoose.Types.ObjectId.isValid(String(medicationId))
      ? String(medicationId)
      : null) ||
    (drugId && mongoose.Types.ObjectId.isValid(String(drugId)) ? String(drugId) : null);

  const validation = await prescriptionDispensing.validatePatientPurchase({
    patientUserId,
    drugId: resolvedDrugId,
    medicationName,
    quantity: qty,
    prescriptionId,
    medicationId: resolvedDrugId,
  });

  const drug =
    validation.drug ||
    (await prescriptionDispensing.getDrugByIdOrName({
      drugId: resolvedDrugId || drugId,
      medicationName,
    }));
  const resolvedName = drug?.name || String(medicationName || "").trim();

  const orgOid =
    orgId && mongoose.Types.ObjectId.isValid(orgId)
      ? new mongoose.Types.ObjectId(orgId)
      : pharmacy.orgId && mongoose.Types.ObjectId.isValid(pharmacy.orgId)
        ? pharmacy.orgId
        : null;

  const doc = await MedicationRequest.create({
    patientUserId,
    pharmacyId: pharmacy._id,
    orgId: orgOid,
    medicationName: resolvedName,
    drugId: drug?._id || null,
    quantity: qty,
    requestedQuantity: qty,
    fulfilledQuantity: 0,
    backorderQuantity: 0,
    lineItems: [],
    status: "Pending",
    notifyWhenInStock: Boolean(notifyWhenInStock),
    notes: notes || "",
    patientPaymentStatus: String(paymentStatus || "").trim(),
    cardLastFour: String(cardLastFour || "").replace(/\D/g, "").slice(-4),
    cardholderName: String(cardholderName || "").trim(),
    patientLocale: String(patientLocale || "en").trim() || "en",
    ...(prescriptionId && mongoose.Types.ObjectId.isValid(String(prescriptionId))
      ? { prescriptionId: new mongoose.Types.ObjectId(String(prescriptionId)) }
      : {}),
    ...(validation.prescriptionItemId
      ? { prescriptionItemId: validation.prescriptionItemId }
      : {}),
  });

  return formatMedicationRequestRecord(doc.toObject());
}

async function listMedicationRequests({ pharmacyId, status } = {}) {
  const MedicationRequest = require("../models/medicationRequest");
  if (!pharmacyId || !mongoose.Types.ObjectId.isValid(pharmacyId)) {
    const err = new Error("pharmacyId is required to list medication requests.");
    err.statusCode = 400;
    throw err;
  }
  const filter = { pharmacyId: new mongoose.Types.ObjectId(pharmacyId) };
  if (status) filter.status = String(status);
  const rows = await MedicationRequest.find(filter).sort({ createdAt: -1 }).limit(100).lean();
  return rows.map((row) => formatMedicationRequestRecord(row)).filter(Boolean);
}

function normalizeMedicationRequestStatus(input) {
  const raw = String(input || "").trim();
  const map = {
    pending: "Pending",
    approved: "Approved",
    accepted: "Approved",
    rejected: "Rejected",
    dispensed: "Dispensed",
    paid: "Paid",
    failed: "Failed",
    "partially fulfilled": "Partially Fulfilled",
    backorder: "Backorder",
  };
  return map[raw.toLowerCase()] || raw;
}

function formatMedicationRequestRecord(doc) {
  if (!doc) return null;
  const status = normalizeMedicationRequestStatus(doc.status) || "Pending";
  return {
    id: String(doc._id),
    _id: String(doc._id),
    patientUserId: doc.patientUserId ? String(doc.patientUserId) : null,
    pharmacyId: doc.pharmacyId ? String(doc.pharmacyId) : null,
    orgId: doc.orgId ? String(doc.orgId) : null,
    medicationName: doc.medicationName || "",
    drugId: doc.drugId ? String(doc.drugId) : null,
    quantity: doc.quantity ?? 1,
    requestedQuantity: doc.requestedQuantity ?? doc.quantity ?? 1,
    fulfilledQuantity: doc.fulfilledQuantity ?? 0,
    backorderQuantity: doc.backorderQuantity ?? 0,
    lineItems: Array.isArray(doc.lineItems)
      ? doc.lineItems.map((line) => ({
          id: line._id ? String(line._id) : null,
          lineType: line.lineType,
          quantity: line.quantity,
          status: line.status,
          amount: line.amount != null ? Number(line.amount) : 0,
        }))
      : [],
    status,
    amount: doc.amount != null ? Number(doc.amount) : null,
    transactionId: doc.transactionId ? String(doc.transactionId) : null,
    cardLastFour: doc.cardLastFour || "",
    patientPaymentStatus: doc.patientPaymentStatus || "",
    cardholderName: doc.cardholderName || "",
    patientLocale: doc.patientLocale || "en",
    paidAt: doc.paidAt || null,
    failureReason: doc.failureReason || "",
    notifyWhenInStock: Boolean(doc.notifyWhenInStock),
    notes: doc.notes || "",
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

async function fulfillMedicationRequest(request, performedBy = "") {
  const prescriptionDispensing = require("./prescriptionDispensingService");
  if (!request?.pharmacyId || !request?.patientUserId) {
    const err = new Error("Request is missing pharmacy or patient scope.");
    err.statusCode = 400;
    throw err;
  }
  return prescriptionDispensing.purchaseMedication({
    patientUserId: request.patientUserId,
    orgId: request.orgId ? String(request.orgId) : null,
    drugId: request.drugId,
    medicationName: request.medicationName,
    quantity: request.quantity ?? 1,
    pharmacyId: request.pharmacyId,
    performedBy: performedBy || "",
    source: "pharmacist_fulfillment",
  });
}

async function updateMedicationRequestStatus(requestId, status, { pharmacyId: scopePharmacyId, performedBy, cardLastFour } = {}) {
  const MedicationRequest = require("../models/medicationRequest");
  const PatientNotification = require("../models/patientNotification");
  const mockPaymentService = require("./mockPaymentService");
  const normalized = normalizeMedicationRequestStatus(status);
  const allowed = ["Pending", "Approved", "Rejected", "Dispensed", "Paid", "Failed", "Partially Fulfilled"];
  if (!allowed.includes(normalized)) {
    const err = new Error(`status must be one of: ${allowed.join(", ")}`);
    err.statusCode = 400;
    throw err;
  }

  if (normalized === "Approved") {
    return mockPaymentService.approveMedicationRequestWithPayment(requestId, {
      pharmacyId: scopePharmacyId,
      performedBy,
      cardLastFour,
    });
  }

  const existing = await MedicationRequest.findById(requestId).lean();
  if (!existing) return null;

  if (scopePharmacyId && existing.pharmacyId && String(existing.pharmacyId) !== String(scopePharmacyId)) {
    const err = new Error("This medication request belongs to another pharmacy.");
    err.statusCode = 403;
    throw err;
  }

  if (normalized === "Dispensed") {
    const current = normalizeMedicationRequestStatus(existing.status);
    if (current === "Paid" || current === "Partially Fulfilled") {
      return formatMedicationRequestRecord(existing);
    }
    if (current !== "Dispensed") {
      await fulfillMedicationRequest(existing, performedBy);
    }
  }

  const updated = await MedicationRequest.findByIdAndUpdate(
    requestId,
    { $set: { status: normalized } },
    { new: true, runValidators: true }
  ).lean();

  if (updated?.patientUserId && ["Rejected", "Dispensed"].includes(normalized)) {
    const label = normalized === "Rejected" ? "rejected" : "marked as dispensed";
    try {
      await PatientNotification.create({
        patientUserId: updated.patientUserId,
        type: "medication_request",
        title: "Medication request updated",
        body: `Your request for ${updated.medicationName} was ${label}.`,
        read: false,
        meta: { requestId: String(updated._id), status: normalized },
      });
    } catch (_) {}
  }

  return formatMedicationRequestRecord(updated);
}

function resolveBackorderQuantity(doc) {
  const direct = Number(doc?.backorderQuantity) || 0;
  if (direct > 0) return direct;
  const lines = Array.isArray(doc?.lineItems) ? doc.lineItems : [];
  const backLine = lines.find(
    (line) =>
      line?.lineType === "Backorder" ||
      line?.status === "Backorder" ||
      line?.status === "Awaiting Stock"
  );
  return backLine ? Math.max(0, Number(backLine.quantity) || 0) : 0;
}

async function listPatientActiveBackorders(patientUserId) {
  if (!patientUserId || !mongoose.Types.ObjectId.isValid(patientUserId)) {
    const err = new Error("Valid patientUserId is required.");
    err.statusCode = 400;
    throw err;
  }

  const MedicationRequest = require("../models/medicationRequest");

  const rows = await MedicationRequest.find({
    patientUserId: new mongoose.Types.ObjectId(patientUserId),
    $or: [
      { status: "Partially Fulfilled", backorderQuantity: { $gt: 0 } },
      { backorderQuantity: { $gt: 0 } },
      { "lineItems.status": { $in: ["Backorder", "Awaiting Stock"] } },
      { "lineItems.lineType": "Backorder" },
    ],
  })
    .sort({ updatedAt: -1 })
    .limit(50)
    .lean();

  return rows
    .map((row) => {
      const backorderQty = resolveBackorderQuantity(row);
      if (backorderQty <= 0) return null;
      const formatted = formatMedicationRequestRecord(row);
      if (!formatted) return null;
      return {
        ...formatted,
        backorderQuantity: backorderQty,
        fulfilledQuantity:
          Number(formatted.fulfilledQuantity) > 0
            ? Number(formatted.fulfilledQuantity)
            : Math.max(0, (Number(formatted.requestedQuantity) || Number(formatted.quantity) || 0) - backorderQty),
      };
    })
    .filter(Boolean);
}

module.exports = {
  INVENTORY_STATUS,
  computeStatus,
  ensurePharmacyInventory,
  createPharmacy,
  registerExternalPharmacy,
  getPharmacyByUserId,
  getPharmacyById,
  getDashboardStats,
  listInventory,
  dispenseDrug,
  listAllDrugs,
  updateInventoryItem,
  deleteInventoryItem,
  addInventoryDrug,
  createNewDrugForPharmacy,
  getInventoryLogs,
  getAnalytics,
  getNotifications,
  updatePharmacySettings,
  getPharmacyDetails,
  getPharmacistProfile,
  updatePharmacistUserProfile,
  resolvePharmacyIdForStaffUser,
  createPatientMedicationRequest,
  listMedicationRequests,
  updateMedicationRequestStatus,
  fulfillMedicationRequest,
  normalizeMedicationRequestStatus,
  formatMedicationRequestRecord,
  listPatientActiveBackorders,
};
