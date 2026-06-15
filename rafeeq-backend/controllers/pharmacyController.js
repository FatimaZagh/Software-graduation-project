const mongoose = require("mongoose");
const UserModel = require("../models/User");
const pharmacyService = require("../services/pharmacyInventoryService");
const { hashPassword } = require("../utils/password");

function sendError(res, err, fallback = "Request failed") {
  const status = err.statusCode || 500;
  res.status(status).json({ message: err.message || fallback });
}

function parseObjectId(value, label) {
  const id = String(value || "").trim();
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return { error: `${label} must be a valid MongoDB ObjectId` };
  }
  return { id };
}

async function createPharmacy(req, res) {
  try {
    const { name, latitude, longitude, status, userId } = req.body;
    if (!name || String(name).trim().length === 0) {
      return res.status(400).json({ message: "name is required" });
    }
    if (
      latitude == null ||
      longitude == null ||
      Number.isNaN(Number(latitude)) ||
      Number.isNaN(Number(longitude))
    ) {
      return res.status(400).json({ message: "latitude and longitude are required" });
    }

    const { pharmacy, seededCount } = await pharmacyService.createPharmacy({
      name,
      latitude,
      longitude,
      status,
      userId: userId || req.header("x-user-id"),
      address: req.body.address,
    });

    res.status(201).json({
      pharmacy,
      inventorySeeded: seededCount,
      message: `Pharmacy created with ${seededCount} inventory records.`,
    });
  } catch (err) {
    sendError(res, err, "Error creating pharmacy");
  }
}

/** POST /api/pharmacies/register — independent external pharmacy (no organization). */
async function registerExternalPharmacy(req, res) {
  try {
    const {
      name,
      latitude,
      longitude,
      status,
      facilityApprovalLocked,
      pharmacyType,
      phone,
      address,
      operatingHours,
      licenseNumber,
    } = req.body;

    if (!name || String(name).trim().length === 0) {
      return res.status(400).json({ message: "name is required" });
    }
    if (
      latitude == null ||
      longitude == null ||
      Number.isNaN(Number(latitude)) ||
      Number.isNaN(Number(longitude))
    ) {
      return res.status(400).json({ message: "latitude and longitude are required" });
    }

    const type = String(pharmacyType || "External").trim();
    if (type !== "External") {
      return res.status(400).json({ message: "Only External pharmacies can register via this endpoint" });
    }

    const { pharmacy, seededCount } = await pharmacyService.registerExternalPharmacy({
      name: String(name).trim(),
      latitude: Number(latitude),
      longitude: Number(longitude),
      status: status != null ? String(status) : "Active",
      facilityApprovalLocked: facilityApprovalLocked === true,
      phone: phone != null ? String(phone) : "",
      address: address != null ? String(address) : "",
      operatingHours: operatingHours != null ? String(operatingHours) : "",
      licenseNumber: licenseNumber != null ? String(licenseNumber) : "",
    });

    res.status(201).json({
      message: "External Pharmacy registered successfully!",
      pharmacyId: String(pharmacy._id),
      pharmacy,
      inventorySeeded: seededCount,
    });
  } catch (err) {
    sendError(res, err, "Error registering external pharmacy");
  }
}

/** POST /api/pharmacies — external pharmacy + linked pharmacist account. */
async function registerExternalPharmacyWithPharmacist(req, res) {
  try {
    const {
      name,
      latitude,
      longitude,
      status,
      facilityApprovalLocked,
      pharmacyType,
      email,
      password,
      phone,
      fullName,
      profileImageUrl,
      address,
      operatingHours,
      licenseNumber,
      city,
    } = req.body;

    if (!name || String(name).trim().length === 0) {
      return res.status(400).json({ message: "name is required" });
    }
    if (
      latitude == null ||
      longitude == null ||
      Number.isNaN(Number(latitude)) ||
      Number.isNaN(Number(longitude))
    ) {
      return res.status(400).json({ message: "latitude and longitude are required" });
    }

    const emailNorm = email != null ? String(email).trim().toLowerCase() : "";
    if (!emailNorm) return res.status(400).json({ message: "email is required" });
    if (!password || String(password).length < 6) {
      return res.status(400).json({ message: "password must be at least 6 characters" });
    }
    if (!phone || String(phone).trim().length < 8) {
      return res.status(400).json({ message: "phone is required" });
    }

    const type = String(pharmacyType || "External").trim();
    if (type !== "External") {
      return res.status(400).json({ message: "Only External pharmacies can register via this endpoint" });
    }

    const emailEsc = emailNorm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const dup = await UserModel.findOne({ email: new RegExp(`^${emailEsc}$`, "i") }).lean();
    if (dup) {
      return res.status(409).json({ message: "An account with this email already exists" });
    }

    const displayName = String(fullName || name || "").trim() || name;
    const img = profileImageUrl != null ? String(profileImageUrl) : "";
    const safeImg = img.length > 1_200_000 ? img.slice(0, 1_200_000) : img;

    const newUser = await UserModel.create({
      orgId: null,
      status: "active",
      name: displayName,
      email: emailNorm,
      role: "Pharmacist",
      password: hashPassword(String(password)),
      profileImageUrl: safeImg,
      phoneNumber: String(phone).trim(),
    });

    const resolvedStatus = status != null ? String(status) : "Active";
    const resolvedLocked = facilityApprovalLocked === true;

    const { pharmacy, seededCount } = await pharmacyService.registerExternalPharmacy({
      name: String(name).trim(),
      latitude: Number(latitude),
      longitude: Number(longitude),
      status: resolvedStatus,
      facilityApprovalLocked: resolvedLocked,
      phone: String(phone).trim(),
      address: [address, city].filter(Boolean).join(", ").trim() || (address != null ? String(address) : ""),
      operatingHours: operatingHours != null ? String(operatingHours) : "",
      licenseNumber: licenseNumber != null ? String(licenseNumber) : "",
      userId: newUser._id,
    });

    res.status(201).json({
      message: "External pharmacy and pharmacist account registered successfully.",
      userId: String(newUser._id),
      pharmacyId: String(pharmacy._id),
      status: resolvedStatus,
      pharmacy,
      inventorySeeded: seededCount,
    });
  } catch (err) {
    sendError(res, err, "Error registering external pharmacy");
  }
}

async function getDashboard(req, res) {
  try {
    const parsed = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsed.error) return res.status(400).json({ message: parsed.error });
    const stats = await pharmacyService.getDashboardStats(parsed.id);
    if (!stats) return res.status(404).json({ message: "Pharmacy not found" });
    res.json(stats);
  } catch (err) {
    sendError(res, err, "Error loading dashboard");
  }
}

async function getDashboardByUser(req, res) {
  try {
    const userId = String(req.params.userId || "").trim();
    if (!userId) return res.status(400).json({ message: "userId is required" });
    const pharmacy = await pharmacyService.getPharmacyByUserId(userId);
    if (!pharmacy) {
      return res.status(404).json({
        message: "No pharmacy linked to this user. Create one via POST /api/pharmacy/create",
      });
    }
    const stats = await pharmacyService.getDashboardStats(pharmacy._id);
    res.json(stats);
  } catch (err) {
    sendError(res, err, "Error loading dashboard");
  }
}

async function getPharmacyByUser(req, res) {
  try {
    const userId = String(req.params.userId || "").trim();
    const pharmacy = await pharmacyService.getPharmacyByUserId(userId);
    if (!pharmacy) return res.status(404).json({ message: "Pharmacy not found" });
    res.json(pharmacy);
  } catch (err) {
    sendError(res, err, "Error loading pharmacy");
  }
}

async function listInventory(req, res) {
  try {
    const parsed = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsed.error) return res.status(400).json({ message: parsed.error });
    const limit = Math.min(Number(req.query.limit) || 200, 200);
    const offset = Number(req.query.offset) || 0;
    const result = await pharmacyService.listInventory(parsed.id, { limit, offset });
    res.json({ total: result.count, items: result.rows });
  } catch (err) {
    sendError(res, err, "Error listing inventory");
  }
}

async function dispense(req, res) {
  try {
    const parsedPharmacy = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsedPharmacy.error) return res.status(400).json({ message: parsedPharmacy.error });
    const parsedDrug = parseObjectId(req.body.drugId, "drugId");
    if (parsedDrug.error) return res.status(400).json({ message: parsedDrug.error });
    const amount = req.body.amount != null ? Number(req.body.amount) : 1;
    const performedBy = req.header("x-user-id") || "";
    const patientUserId = req.body.patientUserId ? String(req.body.patientUserId) : null;

    const prescriptionDispensing = require("../services/prescriptionDispensingService");
    const result = await prescriptionDispensing.dispenseWithValidation({
      pharmacyId: parsedPharmacy.id,
      drugId: parsedDrug.id,
      amount,
      performedBy,
      patientUserId,
    });
    const stats = await pharmacyService.getDashboardStats(parsedPharmacy.id);
    res.json({
      inventory: result.inventory,
      transaction: result.transaction,
      dashboard: stats,
      message: "Drug dispensed successfully.",
    });
  } catch (err) {
    if (err.code === "PRESCRIPTION_REQUIRED" || err.code === "PRESCRIPTION_QUANTITY_EXCEEDED") {
      return res.status(err.statusCode || 403).json({
        code: err.code,
        message: err.message,
      });
    }
    sendError(res, err, "Error dispensing drug");
  }
}

async function updateInventory(req, res) {
  try {
    const parsedPharmacy = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsedPharmacy.error) return res.status(400).json({ message: parsedPharmacy.error });
    const parsedDrug = parseObjectId(req.params.drugId, "drugId");
    if (parsedDrug.error) return res.status(400).json({ message: parsedDrug.error });

    const item = await pharmacyService.updateInventoryItem(
      parsedPharmacy.id,
      parsedDrug.id,
      req.body,
      req.header("x-user-id") || ""
    );
    const stats = await pharmacyService.getDashboardStats(parsedPharmacy.id);
    res.json({ item, dashboard: stats });
  } catch (err) {
    sendError(res, err, "Error updating inventory");
  }
}

async function deleteInventory(req, res) {
  try {
    const parsedPharmacy = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsedPharmacy.error) return res.status(400).json({ message: parsedPharmacy.error });
    const parsedDrug = parseObjectId(req.params.drugId, "drugId");
    if (parsedDrug.error) return res.status(400).json({ message: parsedDrug.error });

    await pharmacyService.deleteInventoryItem(parsedPharmacy.id, parsedDrug.id, req.header("x-user-id") || "");
    const stats = await pharmacyService.getDashboardStats(parsedPharmacy.id);
    res.json({ ok: true, dashboard: stats });
  } catch (err) {
    sendError(res, err, "Error deleting inventory item");
  }
}

async function addInventory(req, res) {
  try {
    const parsedPharmacy = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsedPharmacy.error) return res.status(400).json({ message: parsedPharmacy.error });
    const parsedDrug = parseObjectId(req.body.drugId, "drugId");
    if (parsedDrug.error) return res.status(400).json({ message: parsedDrug.error });

    const item = await pharmacyService.addInventoryDrug(parsedPharmacy.id, req.body, req.header("x-user-id") || "");
    const stats = await pharmacyService.getDashboardStats(parsedPharmacy.id);
    res.json({ item, dashboard: stats });
  } catch (err) {
    sendError(res, err, "Error adding inventory item");
  }
}

async function createNewInventoryDrug(req, res) {
  try {
    const parsedPharmacy = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsedPharmacy.error) return res.status(400).json({ message: parsedPharmacy.error });

    const item = await pharmacyService.createNewDrugForPharmacy(
      parsedPharmacy.id,
      req.body,
      req.header("x-user-id") || ""
    );
    const stats = await pharmacyService.getDashboardStats(parsedPharmacy.id);
    res.json({ item, dashboard: stats, message: "Drug added to inventory." });
  } catch (err) {
    sendError(res, err, "Error creating drug and adding to inventory");
  }
}

async function listInventoryLogs(req, res) {
  try {
    const parsed = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsed.error) return res.status(400).json({ message: parsed.error });
    const logs = await pharmacyService.getInventoryLogs(parsed.id);
    res.json({ total: logs.length, logs });
  } catch (err) {
    sendError(res, err, "Error loading logs");
  }
}

async function getAnalytics(req, res) {
  try {
    const parsed = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsed.error) return res.status(400).json({ message: parsed.error });
    const data = await pharmacyService.getAnalytics(parsed.id);
    if (!data) return res.status(404).json({ message: "Pharmacy not found" });
    res.json(data);
  } catch (err) {
    sendError(res, err, "Error loading analytics");
  }
}

async function getNotifications(req, res) {
  try {
    const parsed = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsed.error) return res.status(400).json({ message: parsed.error });
    const alerts = await pharmacyService.getNotifications(parsed.id);
    res.json({ total: alerts.length, alerts });
  } catch (err) {
    sendError(res, err, "Error loading notifications");
  }
}

async function updateSettings(req, res) {
  try {
    const parsed = parseObjectId(req.params.pharmacyId, "pharmacyId");
    if (parsed.error) return res.status(400).json({ message: parsed.error });
    const pharmacy = await pharmacyService.updatePharmacySettings(parsed.id, req.body);
    res.json(pharmacy);
  } catch (err) {
    sendError(res, err, "Error updating settings");
  }
}

async function getProfile(req, res) {
  try {
    const userId = String(req.params.userId || req.header("x-user-id") || "").trim();
    const profile = await pharmacyService.getPharmacistProfile(userId);
    if (!profile) return res.status(404).json({ message: "User not found" });
    res.json(profile);
  } catch (err) {
    sendError(res, err, "Error loading profile");
  }
}

async function updatePharmacistProfile(req, res) {
  try {
    const userId = String(req.header("x-user-id") || req.body.userId || "").trim();
    if (!userId) return res.status(400).json({ message: "userId is required" });
    const profile = await pharmacyService.updatePharmacistUserProfile(userId, req.body);
    res.json({ profile, message: "Pharmacist profile updated." });
  } catch (err) {
    sendError(res, err, "Error updating pharmacist profile");
  }
}

async function updateProfileByUser(req, res) {
  try {
    const userId = String(req.header("x-user-id") || req.body.userId || "").trim();
    if (!userId) return res.status(400).json({ message: "userId is required" });
    const pharmacy = await pharmacyService.getPharmacyByUserId(userId);
    if (!pharmacy) return res.status(404).json({ message: "Pharmacy not found for this user" });
    const updated = await pharmacyService.updatePharmacySettings(pharmacy._id, req.body);
    res.json(updated);
  } catch (err) {
    sendError(res, err, "Error updating pharmacy profile");
  }
}

async function listMedicationRequests(req, res) {
  try {
    const userId = String(req.header("x-user-id") || "").trim();
    const pharmacyId = await pharmacyService.resolvePharmacyIdForStaffUser(
      userId,
      req.header("x-pharmacy-id") || req.query.pharmacyId
    );
    if (!pharmacyId) {
      return res.status(400).json({
        message: "Could not resolve pharmacy for this pharmacist session. Link a pharmacy to your account.",
      });
    }
    const requests = await pharmacyService.listMedicationRequests({
      pharmacyId,
      status: req.query.status,
    });
    res.json({ pharmacyId, total: requests.length, requests });
  } catch (err) {
    sendError(res, err, "Error loading medication requests");
  }
}

async function patchMedicationRequest(req, res) {
  try {
    const parsed = parseObjectId(req.params.requestId, "requestId");
    if (parsed.error) return res.status(400).json({ message: parsed.error });
    const status = req.body?.status ?? req.body?.bookingStatus;
    if (!status) return res.status(400).json({ message: "status is required" });
    const userId = String(req.header("x-user-id") || "").trim();
    const pharmacyId = await pharmacyService.resolvePharmacyIdForStaffUser(
      userId,
      req.header("x-pharmacy-id") || req.body?.pharmacyId
    );
    const updated = await pharmacyService.updateMedicationRequestStatus(parsed.id, status, {
      pharmacyId,
      performedBy: userId,
      cardLastFour: req.body?.cardLastFour || req.body?.card_last_four,
    });
    if (!updated) return res.status(404).json({ message: "Request not found" });
    res.json({ message: "Request status updated", request: updated, ...updated });
  } catch (err) {
    if (err.request) {
      return res.status(err.statusCode || 409).json({
        message: err.message,
        request: err.request,
        payment: err.payment || null,
      });
    }
    sendError(res, err, "Error updating request");
  }
}

async function listDrugs(_req, res) {
  try {
    const drugs = await pharmacyService.listAllDrugs();
    res.json({ total: drugs.length, drugs });
  } catch (err) {
    sendError(res, err, "Error listing drugs");
  }
}

module.exports = {
  createPharmacy,
  registerExternalPharmacy,
  registerExternalPharmacyWithPharmacist,
  getDashboard,
  getDashboardByUser,
  getPharmacyByUser,
  listInventory,
  dispense,
  updateInventory,
  deleteInventory,
  addInventory,
  createNewInventoryDrug,
  listInventoryLogs,
  getAnalytics,
  getNotifications,
  updateSettings,
  updateProfileByUser,
  updatePharmacistProfile,
  getProfile,
  listMedicationRequests,
  patchMedicationRequest,
  listDrugs,
};
