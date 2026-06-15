const mongoose = require("mongoose");
const AppointmentModel = require("../models/appointment");
const HealthProfile = require("../models/healthProfile");
const PatientMedicalProfile = require("../models/patientMedicalProfile");
const WaitingListEntry = require("../models/waitingListEntry");
const PharmacyMedication = require("../models/pharmacyMedication");
const NearbyPharmacy = require("../models/nearbyPharmacy");
const MedicationRequest = require("../models/medicationRequest");
const PatientNotification = require("../models/patientNotification");
const UserNotification = require("../models/userNotification");
const ChatMessage = require("../models/chatMessage");
const ElectronicPrescription = require("../models/electronicPrescription");
const LabResult = require("../models/labResult");
const VisitRating = require("../models/visitRating");
const MedicationReminder = require("../models/medicationReminder");
const Payment = require("../models/payment");
const Patient = require("../models/patient");
const { replyAsync: chatbotReplyAsync } = require("../services/medicationChatbot");
const { promoteNextFromWaitlist } = require("../services/waitlistPromotion");

const UserModel = mongoose.model("users");
const Doctor = require("../models/doctor");
const Clinic = require("../models/clinic");
const { encryptMessage } = require("../utils/chatCrypto");
const { resolveChatOrgId, buildBidirectionalChatQuery, mapChatMessageRow } = require("../utils/chatThread");

const SLOT_TIMES = [
  "09:00 AM",
  "10:00 AM",
  "11:00 AM",
  "12:00 PM",
  "02:00 PM",
  "03:00 PM",
  "04:00 PM",
];

function addDays(d, n) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

function formatYMD(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

async function seedPharmacyIfEmpty() {
  const c = await PharmacyMedication.countDocuments();
  if (c > 0) return;
  await PharmacyMedication.insertMany([
    { name: "Paracetamol", genericName: "Acetaminophen", strength: "500 mg", form: "Tablet", inStock: true, stockUnits: 200, aisle: "A1" },
    { name: "Ibuprofen", genericName: "Ibuprofen", strength: "400 mg", form: "Tablet", inStock: true, stockUnits: 120, aisle: "A2" },
    { name: "Amoxicillin", genericName: "Amoxicillin", strength: "250 mg", form: "Capsule", inStock: false, stockUnits: 0, aisle: "B1" },
    { name: "Vitamin D3", genericName: "Cholecalciferol", strength: "1000 IU", form: "Tablet", inStock: true, stockUnits: 80, aisle: "C3" },
  ]);
}

async function seedNearbyIfEmpty() {
  const c = await NearbyPharmacy.countDocuments();
  if (c > 0) return;
  await NearbyPharmacy.insertMany([
    { name: "Al-Nahdi Pharmacy", address: "Ring Road, 2.1 km", distanceKm: 2.1, phone: "9200XXXXXX" },
    { name: "Extra Pharmacy", address: "Main St, 3.4 km", distanceKm: 3.4, phone: "9200YYYYYY" },
  ]);
}

async function ensureHealthProfile(userId) {
  let h = await HealthProfile.findOne({ userId }).lean();
  if (h) return h;
  const created = await HealthProfile.create({ userId });
  return created.toObject();
}

function uniqueStrings(list) {
  const seen = new Set();
  const out = [];
  for (const raw of list) {
    const s = String(raw || "").trim();
    if (!s) continue;
    const key = s.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(s);
  }
  return out;
}

function mergeAllergyStrings(health, medical) {
  const items = [];
  if (Array.isArray(health?.allergies)) items.push(...health.allergies);
  const al = medical?.allergies;
  if (al && typeof al === "object") {
    for (const key of ["medications", "foods", "materials"]) {
      if (Array.isArray(al[key])) items.push(...al[key]);
    }
  }
  return uniqueStrings(items);
}

function parseBloodPressure(bpRaw) {
  const raw = String(bpRaw || "").trim();
  const match = raw.match(/^(\d{2,3})\s*\/\s*(\d{2,3})$/);
  if (!match) return { systolic: null, diastolic: null };
  return { systolic: Number(match[1]), diastolic: Number(match[2]) };
}

function latestNurseVitalsEntry(timeline) {
  if (!Array.isArray(timeline) || !timeline.length) return null;
  return [...timeline].sort(
    (a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime()
  )[0];
}

async function buildDigitalHealthProfileView(userId) {
  const [health, medical] = await Promise.all([
    ensureHealthProfile(userId),
    PatientMedicalProfile.findOne({ userId }).lean(),
  ]);

  const chronicDiseases = uniqueStrings([
    ...(Array.isArray(health?.chronicDiseases) ? health.chronicDiseases : []),
    ...(Array.isArray(medical?.chronicDiseases) ? medical.chronicDiseases : []),
  ]);
  const pastSurgeries = uniqueStrings([
    ...(Array.isArray(health?.pastSurgeries) ? health.pastSurgeries : []),
    ...(Array.isArray(medical?.pastSurgeries) ? medical.pastSurgeries : []),
  ]);
  const allergies = mergeAllergyStrings(health, medical);
  const bloodType = String(medical?.bloodType || health?.bloodType || "").trim();

  const latest = latestNurseVitalsEntry(medical?.vitalsTimeline);
  const bp = parseBloodPressure(latest?.bloodPressure);

  const latestNurseVitals = {
    heightCm: latest?.height ?? health?.heightCm ?? medical?.height ?? null,
    weightKg: latest?.weight ?? health?.weightKg ?? medical?.weight ?? null,
    bloodPressureSystolic: bp.systolic ?? health?.bloodPressureSystolic ?? null,
    bloodPressureDiastolic: bp.diastolic ?? health?.bloodPressureDiastolic ?? null,
    pulseBpm: latest?.pulse ?? null,
    temperatureC: latest?.temperature ?? null,
    bloodPressureDisplay: latest?.bloodPressure || null,
    recordedAt: latest?.createdAt || null,
  };

  return {
    ...health,
    bloodType,
    chronicDiseases,
    pastSurgeries,
    allergies,
    allergiesDisplay: allergies.length ? allergies.join(", ") : "",
    latestNurseVitals,
    readOnly: true,
  };
}

function resolvePatientPortalOrgId(user, req) {
  const queryOrgId = String(req.query.orgId || req.body?.orgId || "").trim();
  const userOrgId = user?.orgId ? String(user.orgId) : "";

  // Tenant/facility context from the app (landing selection) takes precedence when valid.
  if (queryOrgId && mongoose.Types.ObjectId.isValid(queryOrgId)) {
    return queryOrgId;
  }
  if (userOrgId && mongoose.Types.ObjectId.isValid(userOrgId)) {
    return userOrgId;
  }
  return "";
}

exports.validatePatientUser = async (req, res, next, id) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid patientUserId" });
    }
    const u = await UserModel.findById(id).lean();
    if (!u) return res.status(404).json({ message: "User not found" });
    if (u.role !== "Patient") {
      return res.status(403).json({ message: "Patient role required" });
    }

    // Patient portal: verify role only — do not enforce org-admin-style ownership checks.
    // Patients may browse pharmacies and facility services while tenant orgId differs from registration org.
    const effectiveOrgId = resolvePatientPortalOrgId(u, req);

    req.patientUserId = id;
    req.patientUser = u;
    req.patientOrgId = effectiveOrgId || null;
    if (effectiveOrgId) {
      req.query.orgId = effectiveOrgId;
    }
    next();
  } catch (e) {
    res.status(500).json({ message: "Auth check failed" });
  }
};

exports.getHealthProfile = async (req, res) => {
  try {
    const view = await buildDigitalHealthProfileView(req.patientUserId);
    res.json(view);
  } catch (e) {
    res.status(500).json({ message: "Error loading health profile" });
  }
};

exports.putHealthProfile = async (req, res) => {
  try {
    await ensureHealthProfile(req.patientUserId);
    const allowed = [
      "chronicDiseases",
      "allergies",
      "pastSurgeries",
      "heightCm",
      "weightKg",
      "bloodPressureSystolic",
      "bloodPressureDiastolic",
      "glucoseMgDl",
      "bloodType",
      "lastCheckupLabel",
    ];
    const $set = {};
    for (const k of allowed) {
      if (Object.prototype.hasOwnProperty.call(req.body, k)) {
        $set[k] = req.body[k];
      }
    }
    const updated = await HealthProfile.findOneAndUpdate(
      { userId: req.patientUserId },
      { $set },
      { new: true }
    ).lean();
    res.json(updated);
  } catch (e) {
    res.status(500).json({ message: "Error saving health profile" });
  }
};

exports.getBookingSuggest = async (req, res) => {
  try {
    const start = addDays(new Date(), 1);
    const suggestions = [];
    for (let day = 0; day < 14; day++) {
      const d = addDays(start, day);
      const dateStr = formatYMD(d);
      for (const time of SLOT_TIMES) {
        const count = await AppointmentModel.countDocuments({
          date: dateStr,
          time,
          status: { $nin: ["Cancelled"] },
        });
        suggestions.push({ date: dateStr, time, currentBookings: count });
      }
    }
    suggestions.sort((a, b) => a.currentBookings - b.currentBookings);
    res.json({ nearestAvailable: suggestions.slice(0, 8), generatedAt: new Date().toISOString() });
  } catch (e) {
    res.status(500).json({ message: "Error suggesting slots" });
  }
};

exports.postWaitingList = async (req, res) => {
  try {
    const { preferredDate, preferredTime, watchSlotDate, watchSlotTime, notes } = req.body;
    const entry = await WaitingListEntry.create({
      patientUserId: req.patientUserId,
      preferredDate: preferredDate || "",
      preferredTime: preferredTime || "",
      watchSlotDate: watchSlotDate || "",
      watchSlotTime: watchSlotTime || "",
      notes: notes || "",
    });
    res.status(201).json(entry);
  } catch (e) {
    res.status(500).json({ message: "Error joining waiting list" });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const list = await PatientNotification.find({ patientUserId: req.patientUserId })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading notifications" });
  }
};

exports.patchNotificationRead = async (req, res) => {
  try {
    const notificationId = req.params.notificationId;
    const n = await PatientNotification.findOneAndUpdate(
      { _id: notificationId, patientUserId: req.patientUserId },
      { read: true },
      { new: true }
    ).lean();
    if (!n) return res.status(404).json({ message: "Notification not found" });
    res.json(n);
  } catch (e) {
    res.status(500).json({ message: "Error updating notification" });
  }
};

exports.getPharmacySearch = async (req, res) => {
  try {
    await seedPharmacyIfEmpty();
    const q = String(req.query.q || "").trim();
    if (!q) {
      const all = await PharmacyMedication.find().limit(50).lean();
      return res.json(all);
    }
    const rx = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
    const list = await PharmacyMedication.find({
      $or: [{ name: rx }, { genericName: rx }],
    })
      .limit(30)
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error searching pharmacy" });
  }
};

exports.getNearbyPharmacies = async (req, res) => {
  try {
    await seedNearbyIfEmpty();
    const list = await NearbyPharmacy.find().sort({ distanceKm: 1 }).lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading nearby pharmacies" });
  }
};

exports.getMedicationRequests = async (req, res) => {
  try {
    const { formatMedicationRequestRecord } = require("../services/pharmacyInventoryService");
    const list = await MedicationRequest.find({ patientUserId: req.patientUserId })
      .sort({ updatedAt: -1 })
      .limit(100)
      .lean();
    res.json({
      requests: list.map((row) => formatMedicationRequestRecord(row)).filter(Boolean),
    });
  } catch (e) {
    res.status(500).json({ message: "Error loading medication requests" });
  }
};

exports.getPatientBackorders = async (req, res) => {
  try {
    const { listPatientActiveBackorders } = require("../services/pharmacyInventoryService");
    const backorders = await listPatientActiveBackorders(req.patientUserId);
    res.json({ backorders, total: backorders.length });
  } catch (e) {
    const status = e.statusCode || 500;
    res.status(status).json({ message: e.message || "Error loading active backorders" });
  }
};

exports.postMedicationRequest = async (req, res) => {
  try {
    const { medicationName, quantity, notifyWhenInStock, notes, drugId, pharmacyId, orgId, paymentStatus, cardLastFour, cardholderName, locale, patientLocale, prescriptionId, medicationId } = req.body;
    if (!pharmacyId) {
      return res.status(400).json({ message: "pharmacyId is required" });
    }
    if (!medicationName && !drugId) {
      return res.status(400).json({ message: "medicationName or drugId required" });
    }

    const { createPatientMedicationRequest } = require("../services/pharmacyInventoryService");
    const request = await createPatientMedicationRequest({
      patientUserId: req.patientUserId,
      pharmacyId,
      drugId,
      medicationName,
      quantity: quantity != null ? Number(quantity) || 1 : 1,
      orgId: orgId || req.query.orgId,
      notes: notes || "",
      notifyWhenInStock: Boolean(notifyWhenInStock),
      paymentStatus,
      cardLastFour,
      cardholderName,
      patientLocale: patientLocale || locale || req.headers["x-locale"] || "en",
      prescriptionId,
      medicationId,
    });
    res.status(201).json({ request });
  } catch (e) {
    if (e.code === "PRESCRIPTION_REQUIRED" || e.code === "PRESCRIPTION_QUANTITY_EXCEEDED") {
      return res.status(e.statusCode || 403).json({
        code: e.code,
        message: e.message,
      });
    }
    if (e.statusCode && e.statusCode < 500) {
      return res.status(e.statusCode).json({ message: e.message });
    }
    res.status(500).json({ message: e.message || "Error creating medication request" });
  }
};

exports.getChatDoctors = async (req, res) => {
  try {
    const clinicId = String(req.query.clinicId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.status(400).json({ message: "clinicId query param required" });
    }
    const clinic = await Clinic.findById(clinicId).lean();
    if (!clinic) return res.status(404).json({ message: "Clinic not found" });
    const docs = await Doctor.find({ clinicId }).sort({ displayName: 1 }).lean();
    const out = [];
    for (const d of docs) {
      const u = await UserModel.findById(d.userId).select("name email profileImageUrl role").lean();
      if (!u || u.role !== "Doctor") continue;
      out.push({
        userId: String(d.userId),
        name: (d.displayName || u.name || "Doctor").toString(),
        specialty: d.specialization || "",
        profileImageUrl: u.profileImageUrl || d.profileImageBase64 || "",
      });
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ message: "Error listing doctors" });
  }
};

exports.getChatMessagesPrivate = async (req, res) => {
  try {
    const { doctorUserId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(doctorUserId)) {
      return res.status(400).json({ message: "Invalid doctorUserId" });
    }
    const doctor = await UserModel.findById(doctorUserId).lean();
    if (!doctor || doctor.role !== "Doctor") return res.status(404).json({ message: "Doctor not found" });

    const filter = buildBidirectionalChatQuery(req.patientUserId, doctorUserId);
    const list = await ChatMessage.find(filter).sort({ createdAt: 1 }).limit(200).lean();
    res.json(list.map(mapChatMessageRow));
  } catch (e) {
    console.error("getChatMessagesPrivate", e);
    res.status(500).json({ message: "Error loading chat" });
  }
};

exports.postChatMessagePrivate = async (req, res) => {
  try {
    const { doctorUserId } = req.params;
    const { body } = req.body;
    if (!mongoose.Types.ObjectId.isValid(doctorUserId)) {
      return res.status(400).json({ message: "Invalid doctorUserId" });
    }
    const orgId = resolveChatOrgId(req);
    if (!orgId) {
      return res.status(403).json({ message: "orgId is required" });
    }
    if (!body || !String(body).trim()) {
      return res.status(400).json({ message: "body required" });
    }
    const doctor = await UserModel.findById(doctorUserId).lean();
    if (!doctor || doctor.role !== "Doctor") return res.status(404).json({ message: "Doctor not found" });

    const enc = encryptMessage(String(body).trim(), req.patientUserId, doctorUserId);
    const msg = await ChatMessage.create({
      orgId,
      senderId: req.patientUserId,
      receiverId: doctorUserId,
      senderRole: "patient",
      receiverRole: "doctor",
      bodyEnc: enc,
      body: "",
    });
    // Notify doctor
    await UserNotification.create({
      userId: doctorUserId,
      role: "Doctor",
      type: "message",
      title: `${req.patientUser?.name || "A patient"} sent you a message`,
      body: String(body).trim().slice(0, 120),
      read: false,
      meta: {
        patientUserId: String(req.patientUserId),
        senderId: String(req.patientUserId),
        receiverId: String(doctorUserId),
      },
    });
    const row = mapChatMessageRow(msg.toObject());
    if (!row.body) {
      const plain = String(body).trim();
      row.body = plain;
      row.text = plain;
      row.message = plain;
      row.content = plain;
    }
    res.status(201).json(row);
  } catch (e) {
    res.status(500).json({ message: "Error sending message" });
  }
};

exports.getPrescriptions = async (req, res) => {
  try {
    const orgId = String(req.query.orgId || "").trim();
    if (!orgId || !mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(403).json({ message: "orgId is required" });
    }
    const list = await ElectronicPrescription.find({ orgId, patientUserId: req.patientUserId })
      .sort({ createdAt: -1 })
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading prescriptions" });
  }
};

exports.postPrescriptionDemo = async (req, res) => {
  try {
    const { doctorName, items, signatureImageBase64 } = req.body;
    const doc = await ElectronicPrescription.create({
      orgId: req.patientUser?.orgId || null,
      patientUserId: req.patientUserId,
      doctorName: doctorName || "Dr. Demo",
      items: Array.isArray(items) ? items : [],
      signatureImageBase64: signatureImageBase64 ? String(signatureImageBase64).slice(0, 500000) : "",
    });
    res.status(201).json(doc);
  } catch (e) {
    res.status(500).json({ message: "Error saving prescription" });
  }
};

exports.getLabResults = async (req, res) => {
  try {
    const orgId = String(req.query.orgId || "").trim();
    if (!orgId || !mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(403).json({ message: "orgId is required" });
    }
    const list = await LabResult.find({ orgId, patientUserId: req.patientUserId })
      .sort({ createdAt: -1 })
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading lab results" });
  }
};

exports.postLabResultDemo = async (req, res) => {
  try {
    const { title, mimeType, fileBase64 } = req.body;
    if (!title) return res.status(400).json({ message: "title required" });
    const doc = await LabResult.create({
      orgId: req.patientUser?.orgId || null,
      patientUserId: req.patientUserId,
      title: String(title).trim(),
      mimeType: mimeType || "application/pdf",
      fileBase64: fileBase64 ? String(fileBase64).slice(0, 800000) : "",
    });
    await PatientNotification.create({
      patientUserId: req.patientUserId,
      type: "lab_result",
      title: "A new lab result was uploaded",
      body: String(title).trim().slice(0, 120),
      read: false,
      meta: { labResultId: String(doc._id) },
    });
    res.status(201).json(doc);
  } catch (e) {
    res.status(500).json({ message: "Error saving lab result" });
  }
};

exports.postVisitRating = async (req, res) => {
  try {
    const { appointmentId, cleanliness, punctuality, doctorBehavior, comment, doctorUserId } = req.body;
    if (cleanliness == null || punctuality == null || doctorBehavior == null) {
      return res.status(400).json({ message: "cleanliness, punctuality, doctorBehavior (1-5) required" });
    }
    const r = await VisitRating.create({
      patientUserId: req.patientUserId,
      doctorUserId:
        doctorUserId && mongoose.Types.ObjectId.isValid(String(doctorUserId))
          ? doctorUserId
          : null,
      appointmentId: appointmentId || null,
      cleanliness: Number(cleanliness),
      punctuality: Number(punctuality),
      doctorBehavior: Number(doctorBehavior),
      comment: comment || "",
    });
    res.status(201).json(r);
  } catch (e) {
    res.status(500).json({ message: "Error saving rating" });
  }
};

exports.getVisitRatings = async (req, res) => {
  try {
    const list = await VisitRating.find({ patientUserId: req.patientUserId })
      .sort({ createdAt: -1 })
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading ratings" });
  }
};

exports.postMedicationChatbot = async (req, res) => {
  try {
    const message = req.body.message || req.body.question;
    const currentMedication = String(
      req.body.currentMedication || req.body.medicationName || ""
    ).trim();
    if (!message && !currentMedication) {
      return res.status(400).json({
        answer:
          "Please select a medication or enter a question for the Rafeeq AI assistant.",
        error: true,
        source: "validation",
      });
    }
    const out = await chatbotReplyAsync({
      message,
      question: message,
      currentMedication,
      medicationName: currentMedication,
    });
    res.json(out);
  } catch (e) {
    console.error("postMedicationChatbot:", e);
    res.status(500).json({
      answer:
        "The medication assistant encountered an unexpected error. Please try again or contact your pharmacist.",
      error: true,
      source: "server_error",
      detail: e?.message,
    });
  }
};

exports.getReminders = async (req, res) => {
  try {
    const list = await MedicationReminder.find({ patientUserId: req.patientUserId }).lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading reminders" });
  }
};

exports.postReminder = async (req, res) => {
  try {
    const { medicineName, doseTimes, timezone } = req.body;
    if (!medicineName) return res.status(400).json({ message: "medicineName required" });
    const doc = await MedicationReminder.create({
      patientUserId: req.patientUserId,
      medicineName: String(medicineName).trim(),
      doseTimes: Array.isArray(doseTimes) ? doseTimes : [],
      timezone: timezone || "UTC",
    });
    res.status(201).json(doc);
  } catch (e) {
    res.status(500).json({ message: "Error creating reminder" });
  }
};

exports.putReminder = async (req, res) => {
  try {
    const { reminderId } = req.params;
    const updates = {};
    if (req.body.medicineName != null) updates.medicineName = String(req.body.medicineName).trim();
    if (req.body.doseTimes != null) updates.doseTimes = req.body.doseTimes;
    if (req.body.active != null) updates.active = Boolean(req.body.active);
    const doc = await MedicationReminder.findOneAndUpdate(
      { _id: reminderId, patientUserId: req.patientUserId },
      { $set: updates },
      { new: true }
    ).lean();
    if (!doc) return res.status(404).json({ message: "Reminder not found" });
    res.json(doc);
  } catch (e) {
    res.status(500).json({ message: "Error updating reminder" });
  }
};

exports.deleteReminder = async (req, res) => {
  try {
    const { reminderId } = req.params;
    const r = await MedicationReminder.deleteOne({
      _id: reminderId,
      patientUserId: req.patientUserId,
    });
    res.json({ deleted: r.deletedCount });
  } catch (e) {
    res.status(500).json({ message: "Error deleting reminder" });
  }
};

exports.postReminderDoseTaken = async (req, res) => {
  try {
    const { reminderId } = req.params;
    const { scheduledFor, taken } = req.body;
    if (!scheduledFor) return res.status(400).json({ message: "scheduledFor ISO date required" });
    const log = { scheduledFor: new Date(scheduledFor), taken: taken !== false, takenAt: taken !== false ? new Date() : null };
    const doc = await MedicationReminder.findOneAndUpdate(
      { _id: reminderId, patientUserId: req.patientUserId },
      { $push: { doseLogs: log } },
      { new: true }
    ).lean();
    if (!doc) return res.status(404).json({ message: "Reminder not found" });
    res.json(doc);
  } catch (e) {
    res.status(500).json({ message: "Error logging dose" });
  }
};

exports.getAnalytics = async (req, res) => {
  try {
    const uid = req.patientUserId;
    const orgId = String(req.query.orgId || "").trim();
    if (!orgId || !mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(403).json({ message: "orgId is required" });
    }
    const visitCount = await AppointmentModel.countDocuments({ orgId, patientId: uid });
    const lastAppt = await AppointmentModel.find({ orgId, patientId: uid })
      .sort({ date: -1, time: -1 })
      .limit(1)
      .lean();
    const meds = await MedicationReminder.countDocuments({ patientUserId: uid, active: true });
    const billsAgg = await Payment.aggregate([
      { $match: { orgId: new mongoose.Types.ObjectId(orgId), patientUserId: new mongoose.Types.ObjectId(uid) } },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]);
    const totalBills = billsAgg[0]?.total || 0;
    const p = await Patient.findOne({ userId: uid }).lean();
    res.json({
      visitCount,
      lastAppointment: lastAppt[0] || null,
      activeMedicationReminders: meds,
      totalPaymentsAmount: totalBills,
      lastCheckupLabel: p?.lastCheckupLabel || null,
    });
  } catch (e) {
    res.status(500).json({ message: "Error building analytics" });
  }
};

/** When appointment cancelled — notify waiting list matching slot */
exports.cancelAppointmentAndNotify = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const appt = await AppointmentModel.findById(appointmentId).lean();
    if (!appt) return res.status(404).json({ message: "Appointment not found" });
    if (String(appt.patientId) !== String(req.patientUserId)) {
      return res.status(403).json({ message: "Not your appointment" });
    }
    await AppointmentModel.findByIdAndUpdate(appointmentId, {
      status: "cancelled_by_patient",
      bookingStatus: "cancelled_by_patient",
      cancelledAt: new Date(),
      cancelledBy: "patient",
    });

    await PatientNotification.create({
      orgId: appt.orgId,
      patientUserId: req.patientUserId,
      type: "appointment_cancelled",
      title: "Your appointment was cancelled",
      body: `Cancelled: ${appt.date} ${appt.time}`,
      read: false,
      meta: { appointmentId: String(appointmentId) },
    });

    if (appt.doctorUserId) {
      await UserNotification.create({
        orgId: appt.orgId,
        userId: appt.doctorUserId,
        role: "Doctor",
        type: "appointment_cancelled",
        title: "An appointment was cancelled",
        body: `${appt.patientName || "Patient"} · ${appt.date} ${appt.time}`,
        read: false,
        meta: { appointmentId: String(appointmentId), patientUserId: String(req.patientUserId) },
      });
    }

    let waitlistPromotion = { promoted: false };
    if (appt.doctorUserId && appt.date && appt.time) {
      waitlistPromotion = await promoteNextFromWaitlist({
        doctorUserId: String(appt.doctorUserId),
        dateYmd: appt.date,
        timeHhmm: appt.time,
        orgId: appt.orgId,
        doctorName: appt.doctorName,
        clinicId: appt.clinicId,
      });
    }

    res.json({ cancelled: true, waitlistPromotion });
  } catch (e) {
    res.status(500).json({ message: "Error cancelling appointment" });
  }
};
