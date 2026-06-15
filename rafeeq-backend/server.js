/** Load OPENROUTER_API_KEY and other secrets before routes/controllers. */
require("./config/loadEnv");

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const jwt = require("jsonwebtoken");

const app = express();

/** Hardcoded platform Super Admin (not stored in MongoDB). Override via env in production. */
const PLATFORM_SUPER_ADMIN_LOGIN = String(process.env.PLATFORM_SUPER_ADMIN_LOGIN || "admin").trim();
const PLATFORM_SUPER_ADMIN_PASSWORD = String(process.env.PLATFORM_SUPER_ADMIN_PASSWORD || "12345");
const JWT_SECRET =
  process.env.JWT_SECRET ||
  "CHANGE_ME_RAFEEQ_JWT_SECRET_GENERATE_STRONG_VALUE_FOR_PRODUCTION";

// Flutter Web / device testing — allow browser clients to reach this API origin
app.use(cors());
app.use(express.json({ limit: "60mb" }));

// Super Admin API — mount before any other /api routes so paths cannot be shadowed
const superAdminRouter = require("./routes/superadmin");
const adminFacilitiesRoutes = require("./routes/adminFacilitiesRoutes");
const superAdminController = require("./controllers/superAdminController");
const facilityApprovalController = require("./controllers/facilityApprovalController");
const { superAdminGate } = require("./middleware/superAdminGate");
const {
  isOrganizationApproved,
  approvedOrganizationQuery,
  activeOrganizationQuery,
  pendingOrganizationQuery,
} = require("./utils/organizationStatus");
app.get("/api/superadmin/health", (_req, res) =>
  res.json({ ok: true, service: "superadmin" })
);
app.get(
  "/api/superadmin/organizations",
  superAdminGate,
  superAdminController.getOrganizations
);
app.get(
  "/api/superadmin/organizations/",
  superAdminGate,
  superAdminController.getOrganizations
);
app.get(
  "/api/superadmin/pending-applications",
  superAdminGate,
  superAdminController.getPendingApplications
);
app.get(
  "/api/superadmin/financial-ledger",
  superAdminGate,
  superAdminController.getFinancialLedger
);
app.use("/api/superadmin", superAdminGate, superAdminRouter);
app.use("/api/super-admin", superAdminGate, superAdminRouter);
app.use("/api/admin/facilities", superAdminGate, adminFacilitiesRoutes);
console.log("[server] Super Admin API mounted at /api/superadmin (early)");
console.log("[server] Facility approval API mounted at /api/admin/facilities");

// الاتصال بقاعدة البيانات
// تأكدي أن السطر مكتوب هكذا بالضبط
// غيري السطر القديم لهذا السطر
mongoose.connect("mongodb://127.0.0.1:27017/rafeeq_db")
  .then(async () => {
    console.log("Connected to MongoDB...");
    await seedClinicsIfEmpty();
    await migrateLegacyDoctorStaffCollection();
    await seedHospitalDoctorRoster();
    const { runPharmacyStartupSeeds } = require("./services/seedGlobalDrugs");
    await runPharmacyStartupSeeds();
  })
  .catch(err => console.error("Could not connect to MongoDB...", err));

const pharmacyRoutes = require("./routes/pharmacyRoutes");
const UserModel = require("./models/User");
const { ALLOWED_ROLES } = require("./models/User");

const AppointmentModel = require("./models/appointment");
const MedicalRecord = require("./models/medicalRecord");
const Patient = require("./models/patient");
const HealthProfile = require("./models/healthProfile");
const Payment = require("./models/payment");
const Clinic = require("./models/clinic");
const Doctor = require("./models/doctor");
const DoctorLeaveRequest = require("./models/doctorLeaveRequest");
const PatientMedication = require("./models/patientMedication");
const UserNotification = require("./models/userNotification");
const PatientNotification = require("./models/patientNotification");
const Organization = require("./models/Organization");
const Admin = require("./models/admin");
const RegistrationRequest = require("./models/registrationRequest");
const regReqAdminCtrl = require("./controllers/registrationRequestAdminController");
const adverseReportCtrl = require("./controllers/adverseReportController");
const prescriptionCtrl = require("./controllers/prescriptionController");
const appointmentCtrl = require("./controllers/appointmentController");
const patientPortalRoutes = require("./routes/patientPortalRoutes");
const doctorPortalRoutes = require("./routes/doctorPortalRoutes");
const nurseRoutes = require("./routes/nurseRoutes");
const { blockNurseForbiddenRoutes } = require("./middleware/nurseAuth");
const { blockDoctorForbiddenRoutes } = require("./middleware/doctorAuth");
const doctorRoutes = require("./routes/doctorRoutes");
const appointmentRoutes = require("./routes/appointmentRoutes");
const waitingListRoutes = require("./routes/waitingListRoutes");
const paymentRoutes = require("./routes/paymentRoutes");
const {
  computeSlots,
  loadBookedSlots,
  normalizeSlotTime,
  findWorkDayForDate,
  generateAvailableSlotsForDoctor,
} = require("./utils/appointmentSlots");
const { activeSlotOccupancyQuery } = require("./utils/appointmentStatus");
const createOrgAdminExtendedRouter = require("./routes/orgAdminExtendedRoutes");
const createLeaveRouter = require("./routes/leaveRoutes");
const leaveRequestController = require("./controllers/leaveRequestController");
const { createLeaveAuthMiddleware } = require("./middleware/leaveAuth");
const orgAdminExtendedController = require("./controllers/orgAdminExtendedController");
const { normalizeDateToYmd, stripDoctorTitle } = require("./utils/doctorPortalHelpers");
const { resolveHospitalClinicId, clearHospitalClinicCache } = require("./utils/hospitalClinic");
const doctorPortalCtrl = require("./controllers/doctorPortalController");
const { loginAuthHandler, registerPatientAuthHandler } = require("./controllers/authController");
const { registerStaffPublic } = require("./controllers/staffRegistrationController");
const authRoutes = require("./routes/auth");
const fileRoutes = require("./routes/files");
const { requireNurse } = require("./middleware/nurseAuth");
const { updateAuthProfile } = require("./controllers/nursePortalController");
const { hashPassword } = require("./utils/password");

function normalizeRole(input) {
  const r = String(input || "").trim();
  const map = {
    OrgAdmin: "Organization Admin",
    OrganizationAdmin: "Organization Admin",
    "Organization Admin": "Organization Admin",
    LabTechnician: "Lab Technician",
    "Lab Technician": "Lab Technician",
    InternTrainee: "Intern/Trainee",
    "Intern/Trainee": "Intern/Trainee",
    StaffOperations: "Staff/Operations",
    "Staff/Operations": "Staff/Operations",
  };
  return map[r] || r;
}

function isStaffRole(role) {
  const r = normalizeRole(role);
  return [
    "Organization Admin",
    "Doctor",
    "Nurse",
    "Lab Technician",
    "Radiologist",
    "Pharmacist",
    "InternalPharmacist",
    "Intern/Trainee",
    "Staff/Operations",
  ].includes(r);
}

function isAllowedRole(role) {
  const r = normalizeRole(role);
  return isStaffRole(r) || r === "Patient";
}

const {
  buildPharmacySignupPayload,
  extractClinicIdFromBody,
  extractOrgIdFromBody,
  validatePharmacySignup,
} = require("./utils/pharmacyRegistrationValidation");

async function requireAuth(req, res) {
  const userId = String(req.header("x-user-id") || req.query.userId || "").trim();
  if (!mongoose.Types.ObjectId.isValid(userId)) {
    res.status(401).json({ message: "User id required (x-user-id or ?userId=)" });
    return null;
  }
  const u = await UserModel.findById(userId).lean();
  if (!u) {
    res.status(401).json({ message: "User not found" });
    return null;
  }
  // Backfill orgId for Organization Admins created via legacy linkage table.
  if ((!u.orgId || !mongoose.Types.ObjectId.isValid(String(u.orgId))) && normalizeRole(u.role) === "Organization Admin") {
    try {
      const a = await Admin.findOne({ userId: u._id }).select("orgId").lean();
      if (a?.orgId && mongoose.Types.ObjectId.isValid(String(a.orgId))) {
        u.orgId = a.orgId;
        // Best-effort persist for future requests.
        await UserModel.updateOne({ _id: u._id }, { $set: { orgId: a.orgId } });
      }
    } catch (_) {}
  }
  return u;
}

function getRequestOrgId(req, user) {
  // For Organization Admin, never trust an explicit orgId header/query param.
  // Always scope to the orgId bound to the authenticated admin user.
  if (normalizeRole(user?.role) === "Organization Admin") {
    if (user?.orgId && mongoose.Types.ObjectId.isValid(String(user.orgId))) {
      return new mongoose.Types.ObjectId(String(user.orgId));
    }
    return null;
  }

  const explicit = String(req.header("x-org-id") || req.query.orgId || "").trim();
  if (explicit && mongoose.Types.ObjectId.isValid(explicit)) {
    return new mongoose.Types.ObjectId(explicit);
  }
  if (user?.orgId && mongoose.Types.ObjectId.isValid(String(user.orgId))) {
    return new mongoose.Types.ObjectId(String(user.orgId));
  }
  return null;
}

async function requireOrgScope(req, res) {
  const user = await requireAuth(req, res);
  if (!user) return null;
  const orgId = getRequestOrgId(req, user);
  if (!orgId) {
    res.status(403).json({ message: "orgId is required for this request" });
    return null;
  }
  return { user, orgId };
}

async function requireSuperAdmin(req, res) {
  const authHeader = String(req.header("authorization") || "").trim();
  if (authHeader.startsWith("Bearer ")) {
    try {
      const decoded = jwt.verify(authHeader.slice("Bearer ".length).trim(), JWT_SECRET);
      if (decoded.typ === "platform_super" && decoded.role === "SuperAdmin") {
        console.log("[super-admin-auth] platform JWT accepted");
        return {
          role: "SuperAdmin",
          platformSuperAdmin: true,
          email: PLATFORM_SUPER_ADMIN_LOGIN,
        };
      }
      console.log("[super-admin-auth] JWT payload not platform Super Admin");
      res.status(403).json({ message: "Not a platform Super Admin token" });
      return null;
    } catch (e) {
      console.log("[super-admin-auth] JWT rejected:", e.message);
      res.status(401).json({ message: "Invalid or expired token" });
      return null;
    }
  }

  const auth = await requireAuth(req, res);
  if (!auth) return null;
  if (normalizeRole(auth.role) !== "SuperAdmin") {
    res.status(403).json({ message: "SuperAdmin role required" });
    return null;
  }
  return auth;
}

async function requireOrgAdmin(req, res) {
  const scoped = await requireOrgScope(req, res);
  if (!scoped) return null;
  // Allow either:
  // - users.role === "Organization Admin" bound to orgId
  // - users.role === "Admin" with an Admin record bound to orgId (legacy)
  if (normalizeRole(scoped.user.role) === "Organization Admin") {
    if (!scoped.user.orgId || String(scoped.user.orgId) !== String(scoped.orgId)) {
      res.status(403).json({ message: "Org scope mismatch" });
      return null;
    }
    return scoped;
  }
  if (scoped.user.role === "Admin") {
    const a = await Admin.findOne({ userId: scoped.user._id, orgId: scoped.orgId }).lean();
    if (!a) {
      res.status(403).json({ message: "Admin is not assigned to this facility" });
      return null;
    }
    return scoped;
  }
  res.status(403).json({ message: "Org admin role required" });
  return null;
}

function safeConsultationFee(doctor) {
  if (!doctor) return 0;
  const raw = doctor.consultationFee ?? doctor.clinicServicesConfig?.consultationFee;
  if (raw == null || raw === "") return 0;
  const fee = Number(raw);
  return Number.isFinite(fee) ? fee : 0;
}

function mapDoctorBookingRow(d, u) {
  const name =
    d.displayName && String(d.displayName).trim()
      ? String(d.displayName).trim()
      : u?.name || "Doctor";
  return {
    _id: d._id,
    userId: d.userId,
    name,
    specialty: d.specialization || "",
    yearsExperience: d.yearsExperience ?? 0,
    consultationFee: safeConsultationFee(d),
    clinicId: d.clinicId || null,
    profileImageUrl: u?.profileImageUrl || d.profileImageBase64 || "",
  };
}

function resolveOrgIdFromQuery(query = {}) {
  const raw = String(query.orgId || query.facilityId || query.organizationId || "").trim();
  if (!mongoose.Types.ObjectId.isValid(raw)) return null;
  return new mongoose.Types.ObjectId(raw);
}

/** Public booking roster: active doctors for an organization (optional clinic branch filter). */
async function listBookingDoctors(orgId, clinicId = null) {
  if (!orgId) return [];
  const orgOid =
    orgId instanceof mongoose.Types.ObjectId
      ? orgId
      : mongoose.Types.ObjectId.isValid(String(orgId))
        ? new mongoose.Types.ObjectId(String(orgId))
        : null;
  if (!orgOid) return [];

  const activeUsers = await UserModel.find({
    orgId: orgOid,
    role: "Doctor",
    status: "active",
  })
    .select("_id")
    .lean();
  const userIdSet = new Set(activeUsers.map((u) => String(u._id)));

  const doctorsInOrg = await Doctor.find({ orgId: orgOid }).select("userId").lean();
  for (const row of doctorsInOrg) {
    if (row.userId) userIdSet.add(String(row.userId));
  }

  const activeIds = [...userIdSet].map((id) => new mongoose.Types.ObjectId(id));
  if (!activeIds.length) return [];

  const filter = { userId: { $in: activeIds } };
  if (clinicId && mongoose.Types.ObjectId.isValid(String(clinicId))) {
    const clinicOid = new mongoose.Types.ObjectId(String(clinicId));
    filter.$or = [
      { clinicId: clinicOid },
      { clinicId: null },
      { clinicId: { $exists: false } },
    ];
  }

  const list = await Doctor.find(filter).sort({ displayName: 1 }).lean();
  const out = [];
  const seen = new Set();
  for (const d of list) {
    const uid = String(d.userId || "");
    if (!uid || seen.has(uid)) continue;
    const u = await UserModel.findById(d.userId)
      .select("name email role status orgId profileImageUrl")
      .lean();
    if (!u || u.role !== "Doctor" || u.status !== "active") continue;
    const userOrg = u.orgId ? String(u.orgId) : "";
    const docOrg = d.orgId ? String(d.orgId) : "";
    if (userOrg && userOrg !== String(orgOid) && docOrg !== String(orgOid)) continue;
    seen.add(uid);
    out.push(mapDoctorBookingRow(d, u));
  }
  return out;
}

/** Merge legacy doctorstaffs documents into doctors, then drop the old collection. */
async function migrateLegacyDoctorStaffCollection() {
  try {
    const db = mongoose.connection.db;
    if (!db) return;
    const cols = await db.listCollections({ name: "doctorstaffs" }).toArray();
    if (!cols.length) return;
    const col = db.collection("doctorstaffs");
    const hospitalId = await resolveHospitalClinicId();
    const doctorUsers = await UserModel.find({ role: "Doctor" }).lean();
    const rows = await col.find({}).toArray();
    for (const row of rows) {
      let uid = row.userId;
      if (!uid && row.name) {
        const a = stripDoctorTitle(row.name);
        const hit = doctorUsers.find((d) => stripDoctorTitle(d.name || "") === a);
        if (hit) uid = hit._id;
      }
      if (!uid) continue;
      const existing = await Doctor.findOne({ userId: uid }).lean();
      const spec = row.specialty ? String(row.specialty) : "";
      if (!existing) {
        await Doctor.create({
          userId: uid,
          displayName: row.name || "Doctor",
          specialization: spec,
          ...(hospitalId ? { clinicId: hospitalId } : {}),
        });
      } else {
        await Doctor.updateOne(
          { userId: uid },
          {
            $set: {
              clinicId: hospitalId || existing.clinicId,
              ...(spec && !existing.specialization ? { specialization: spec } : {}),
            },
          }
        );
      }
    }
    await col.drop().catch(() => col.deleteMany({}));
  } catch (e) {
    console.error("migrateLegacyDoctorStaffCollection:", e.message);
  }
}

/** Demo roster when the doctors collection is empty (dev / first run). */
async function seedHospitalDoctorRoster() {
  try {
    const hid = await resolveHospitalClinicId();
    if (!hid) return;
    if ((await Doctor.countDocuments({})) > 0) return;
    const roster = [
      { name: "Dr. Ahmed Hassan", email: "doctor.ahmed@rafeeq.demo", specialization: "General Medicine" },
      { name: "Dr. Sara Mahmoud", email: "doctor.sara@rafeeq.demo", specialization: "Pediatrics" },
      { name: "Dr. Layla Farid", email: "doctor.layla@rafeeq.demo", specialization: "Internal Medicine" },
      { name: "Dr. Omar Khalil", email: "doctor.omar@rafeeq.demo", specialization: "Cardiology" },
    ];
    for (const r of roster) {
      let u = await UserModel.findOne({ email: r.email }).lean();
      if (!u) {
        const doc = await UserModel.create({
          name: r.name,
          email: r.email,
          role: "Doctor",
          password: hashPassword("demo"),
          clinicId: hid,
        });
        u = doc.toObject();
      } else {
        await UserModel.updateOne(
          { _id: u._id },
          { $set: { role: "Doctor", clinicId: u.clinicId || hid } }
        );
      }
      await Doctor.create({
        userId: u._id,
        displayName: r.name,
        specialization: r.specialization,
        clinicId: hid,
      });
    }
    console.log("Seeded hospital doctor roster (demo accounts).");
  } catch (e) {
    console.error("seedHospitalDoctorRoster:", e.message);
  }
}

async function ensurePatientForUser(userId) {
  let p = await Patient.findOne({ userId }).lean();
  if (p) return p;
  const user = await UserModel.findById(userId).lean();
  if (!user) return null;
  const created = await Patient.create({
    userId,
    fullName: user.name || "Patient",
    email: user.email || "",
    bloodType: "—",
    weightKg: null,
    lastCheckupLabel: "—",
  });
  return created.toObject();
}

function combinedDateTime(dateStr, timeStr) {
  if (!dateStr) return new Date(0);
  const parts = String(dateStr).split("-").map((x) => parseInt(x, 10));
  if (parts.length !== 3 || parts.some((n) => Number.isNaN(n))) return new Date(0);
  const [y, mo, d] = parts;
  let hh = 12;
  let mm = 0;
  const t = String(timeStr || "").trim();
  const m24 = t.match(/^(\d{1,2}):(\d{2})$/);
  if (m24) {
    hh = parseInt(m24[1], 10);
    mm = parseInt(m24[2], 10);
  } else {
    const m = t.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
    if (m) {
      hh = parseInt(m[1], 10);
      mm = parseInt(m[2], 10);
      const ap = m[3].toUpperCase();
      if (ap === "PM" && hh !== 12) hh += 12;
      if (ap === "AM" && hh === 12) hh = 0;
    }
  }
  return new Date(y, mo - 1, d, hh, mm, 0, 0);
}

async function seedClinicsIfEmpty() {
  try {
    const firstOrg = await Organization.findOne(approvedOrganizationQuery())
      .sort({ name: 1 })
      .select("_id")
      .lean();
    const orgId = firstOrg?._id;
    if (orgId) {
      await Clinic.updateMany(
        { $or: [{ orgId: null }, { orgId: { $exists: false } }] },
        { $set: { orgId } }
      );
    }
    if ((await Clinic.countDocuments()) === 0 && orgId) {
      await Clinic.create({
        orgId,
        name: "Rafeeq Clinic — Main Branch",
        address: "King Fahd Road, Building 12",
        city: "Riyadh",
        phone: "+966112345678",
        features: ["Laboratory", "Radiology"],
        services: ["Laboratory", "Radiology", "Clinical Lab", "X-Ray"],
        hasLab: true,
        hasRadio: true,
      });
      await Clinic.create({
        orgId,
        name: "Rafeeq Clinic — North Branch",
        address: "Northern Ring Rd, Exit 5",
        city: "Riyadh",
        phone: "+966118765432",
        features: ["Laboratory", "Radiology"],
        services: ["Laboratory", "Radiology", "Clinical Lab", "X-Ray"],
        hasLab: true,
        hasRadio: true,
      });
      clearHospitalClinicCache();
    }
    await backfillClinicServices();
  } catch (e) {
    console.error("seedClinicsIfEmpty:", e.message);
  }
}

async function backfillClinicServices() {
  try {
    const legacy = await Clinic.find({
      $or: [{ services: { $exists: false } }, { services: { $size: 0 } }],
    }).lean();
    for (const c of legacy) {
      const org = c.orgId
        ? await Organization.findById(c.orgId).select("activeModules").lean()
        : null;
      const patch = enrichClinicRecord(c, Boolean(org?.activeModules?.labRadiology));
      await Clinic.updateOne(
        { _id: c._id },
        {
          $set: {
            services: patch.services,
            features: patch.features,
            hasLab: patch.hasLab,
            hasRadio: patch.hasRadio,
          },
        }
      );
    }
  } catch (e) {
    console.warn("backfillClinicServices:", e.message);
  }
}

async function listAppointmentsJson() {
  try {
    return await AppointmentModel.find()
      .populate("patientId", "name email role")
      .populate("clinicId", "name phone address city")
      .lean();
  } catch (e) {
    return AppointmentModel.find().lean();
  }
}

// --- Patient API — :id is always the users collection _id (patientUserId) ---
// Specific paths MUST be registered before /api/patients/:id
const mapsDirectionsCtrl = require("./controllers/mapsDirectionsController");
app.get("/api/maps/directions", mapsDirectionsCtrl.getDrivingDirections);

const pharmacyRoutingCtrl = require("./controllers/pharmacyRoutingController");
app.get("/api/pharmacies/search-by-drug", pharmacyRoutingCtrl.searchPharmaciesByDrug);
const pharmacyController = require("./controllers/pharmacyController");
app.post("/api/pharmacies", pharmacyController.registerExternalPharmacyWithPharmacist);
app.post("/api/pharmacies/register", pharmacyController.registerExternalPharmacy);
app.get("/api/patient/purchases/:patientUserId", pharmacyRoutingCtrl.listPatientPurchases);
const patientPortalCtrl = require("./controllers/patientPortalController");
app.get(
  "/api/patient/backorders/:patientUserId",
  (req, res, next) => patientPortalCtrl.validatePatientUser(req, res, next, req.params.patientUserId),
  patientPortalCtrl.getPatientBackorders
);
const patientPaymentsCtrl = require("./controllers/patientPaymentsController");
app.get("/api/patient/payments/:patientUserId", patientPaymentsCtrl.getPatientPayments);
app.get("/api/patient/payments", patientPaymentsCtrl.getPatientPayments);
const patientMedicalRecordsCtrl = require("./controllers/patientMedicalRecordsController");
app.get(
  "/api/patient-portal/:patientId/medical-records",
  patientMedicalRecordsCtrl.getMedicalRecords
);
app.get(
  "/api/patient-portal/:patientUserId/medical-records",
  patientMedicalRecordsCtrl.getMedicalRecords
);
app.get(
  "/api/patient/medical-records/:id",
  patientMedicalRecordsCtrl.getMedicalRecords
);
app.get("/api/patient/medical-records", patientMedicalRecordsCtrl.getMedicalRecords);

// Org-admin clinic patient directory — MUST be before /api/patients/:id (otherwise "clinic" is parsed as :id).
app.get("/api/patients/clinic", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    await orgAdminExtendedController.getClinicPatients(req, res, scoped);
  } catch (e) {
    console.error("[patients/clinic]", e);
    if (!res.headersSent) {
      res.status(500).json({ message: e.message || "Server error" });
    }
  }
});

app.get("/api/patients/profile/:id", async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid id" });
    }
    const patient = await ensurePatientForUser(id);
    if (!patient) return res.status(404).json({ message: "User not found" });
    const user = await UserModel.findById(id).lean();
    res.json({
      userId: id,
      fullName: patient.fullName,
      email: patient.email,
      phone: patient.phone,
      address: patient.address ?? "",
      gender: patient.gender ?? "",
      age: patient.age ?? null,
      profileImage: patient.profileImage ?? "",
      defaultBranch: patient.defaultBranch,
      accountName: user?.name,
      accountEmail: user?.email,
      role: user?.role,
    });
  } catch (error) {
    res.status(500).json({ message: "Error fetching profile" });
  }
});

app.put("/api/patients/profile/:id", async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid id" });
    }
    await ensurePatientForUser(id);

    const {
      fullName,
      phone,
      address,
      gender,
      age,
      profileImage,
      defaultBranch,
      accountName,
      accountEmail,
      newPassword,
    } = req.body;

    const updates = {};
    if (fullName != null) updates.fullName = String(fullName).trim();
    if (phone != null) updates.phone = String(phone).trim();
    if (address != null) updates.address = String(address).trim();
    if (gender != null) updates.gender = String(gender).trim();
    if (age != null && age !== "") {
      const n = Number(age);
      updates.age = Number.isNaN(n) ? null : n;
    } else if (age === "" || age === null) {
      updates.age = null;
    }
    if (profileImage != null) {
      const s = String(profileImage);
      updates.profileImage = s.length > 1_200_000 ? s.slice(0, 1_200_000) : s;
    }
    if (defaultBranch != null) {
      updates.defaultBranch = String(defaultBranch).trim();
    }
    if (accountEmail != null) updates.email = String(accountEmail).trim();

    const updated = await Patient.findOneAndUpdate(
      { userId: id },
      { $set: updates },
      { new: true }
    ).lean();

    if (accountName != null || accountEmail != null || newPassword != null) {
      const u = {};
      if (accountName != null) u.name = String(accountName).trim();
      if (accountEmail != null) u.email = String(accountEmail).trim();
      if (newPassword != null && String(newPassword).trim() !== "") {
        u.password = String(newPassword).trim();
      }
      if (Object.keys(u).length) await UserModel.findByIdAndUpdate(id, { $set: u });
    }

    const user = await UserModel.findById(id).lean();
    res.json({
      userId: id,
      fullName: updated.fullName,
      email: updated.email,
      phone: updated.phone,
      address: updated.address ?? "",
      gender: updated.gender ?? "",
      age: updated.age ?? null,
      profileImage: updated.profileImage ?? "",
      defaultBranch: updated.defaultBranch,
      accountName: user?.name,
      accountEmail: user?.email,
      role: user?.role,
    });
  } catch (error) {
    res.status(500).json({ message: "Error updating profile" });
  }
});

app.get("/api/patients/medical-records/:id", async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid id" });
    }
    const user = await UserModel.findById(id).lean();
    if (!user) return res.status(404).json({ message: "User not found" });

    const appts = await AppointmentModel.find({ patientId: id }).select("_id").lean();
    const apptIds = appts.map((a) => a._id);
    let records = [];
    if (apptIds.length > 0) {
      records = await MedicalRecord.find({ appointmentId: { $in: apptIds } })
        .populate(
          "appointmentId",
          "date time doctorName patientName status branch"
        )
        .sort({ createdAt: -1 })
        .lean();
    }

    if (records.length === 0) {
      records = [
        {
          _id: null,
          isSample: true,
          diagnosis: "No visits on file yet.",
          prescription: [],
          notes: "Complete a visit with your doctor to see records here.",
          appointmentId: null,
        },
      ];
    }

    res.json(records);
  } catch (error) {
    res.status(500).json({ message: "Error fetching medical records" });
  }
});

app.get("/api/patients/payments/:id", async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid id" });
    }
    const user = await UserModel.findById(id).lean();
    if (!user) return res.status(404).json({ message: "User not found" });

    let list = await Payment.find({ patientUserId: id })
      .sort({ paidAt: -1 })
      .lean();

    if (list.length === 0) {
      list = [
        {
          _id: null,
          isSample: true,
          amount: 150,
          currency: "ILS",
          description: "General consultation (sample)",
          status: "Paid",
          paidAt: new Date().toISOString(),
        },
        {
          _id: null,
          isSample: true,
          amount: 85,
          currency: "ILS",
          description: "Lab work — CBC (sample)",
          status: "Paid",
          paidAt: new Date(Date.now() - 86400000 * 14).toISOString(),
        },
      ];
    }

    res.json(list);
  } catch (error) {
    res.status(500).json({ message: "Error fetching payments" });
  }
});

function enrichClinicRecord(clinic, orgHasLabRad) {
  const features = Array.isArray(clinic.features) ? clinic.features.map(String) : [];
  let services = Array.isArray(clinic.services) ? clinic.services.map(String) : [];

  const featureHasLab = features.some((f) => /^(laboratory|clinical lab)$/i.test(String(f).trim()));
  const featureHasRadio = features.some((f) => /^(radiology|x-ray)$/i.test(String(f).trim()));

  if (services.length === 0) {
    if (clinic.hasLab === true || featureHasLab) services.push("Laboratory");
    if (clinic.hasRadio === true || featureHasRadio) services.push("Radiology");
    if (services.length === 0 && orgHasLabRad) {
      services = ["Laboratory", "Radiology", "Clinical Lab", "X-Ray"];
    }
  }

  const serviceHasLab = services.some((s) => ["Laboratory", "Clinical Lab"].includes(String(s).trim()));
  const serviceHasRadio = services.some((s) => ["Radiology", "X-Ray"].includes(String(s).trim()));

  let hasLab = clinic.hasLab === true || featureHasLab || serviceHasLab;
  let hasRadio = clinic.hasRadio === true || featureHasRadio || serviceHasRadio;

  if (!hasLab && !hasRadio && features.length === 0 && services.length === 0 && orgHasLabRad) {
    hasLab = true;
    hasRadio = true;
    services = ["Laboratory", "Radiology", "Clinical Lab", "X-Ray"];
  }

  return { ...clinic, features, services, hasLab, hasRadio };
}

function clinicMatchesLaboratory(clinic) {
  if (clinic.hasLab === true) return true;
  const services = Array.isArray(clinic.services) ? clinic.services : [];
  return services.some((s) => ["Laboratory", "Clinical Lab"].includes(String(s).trim()));
}

function clinicMatchesRadiology(clinic) {
  if (clinic.hasRadio === true) return true;
  const services = Array.isArray(clinic.services) ? clinic.services : [];
  return services.some((s) => ["Radiology", "X-Ray"].includes(String(s).trim()));
}

app.get("/api/clinics", async (req, res) => {
  try {
    const orgIdStr = String(req.query.orgId || "").trim();
    const orgId =
      orgIdStr && mongoose.Types.ObjectId.isValid(orgIdStr)
        ? new mongoose.Types.ObjectId(orgIdStr)
        : null;
    if (!orgId) return res.status(400).json({ message: "orgId is required" });

    const capability = String(req.query.capability || req.query.service || req.query.role || "")
      .trim()
      .toLowerCase();

    const [list, org] = await Promise.all([
      Clinic.find({ orgId }).sort({ name: 1 }).lean(),
      Organization.findById(orgId).select("activeModules moduleKeys").lean(),
    ]);

    const orgHasLabRad = Boolean(org?.activeModules?.labRadiology);

    let enriched = list.map((c) => enrichClinicRecord(c, orgHasLabRad));

    if (["laboratory", "lab", "lab technician", "lab_technician"].includes(capability)) {
      enriched = enriched.filter(clinicMatchesLaboratory);
    } else if (["radiology", "radiologist", "radio", "x-ray", "xray"].includes(capability)) {
      enriched = enriched.filter(clinicMatchesRadiology);
    }

    res.json(enriched);
  } catch (e) {
    res.status(500).json({ message: "Error listing clinics" });
  }
});

/** Public landing: every clinic branch under active tenants (no auth). */
app.get("/api/clinics/all", async (req, res) => {
  try {
    const activeOrgs = await Organization.find(activeOrganizationQuery())
      .select("_id name logoUrl address city location description phone")
      .lean();
    const orgById = Object.fromEntries(
      activeOrgs.map((o) => [String(o._id), o])
    );
    const orgIds = activeOrgs.map((o) => o._id);
    const clinics = await Clinic.find({ orgId: { $in: orgIds } })
      .sort({ name: 1 })
      .lean();

    const orgIdsWithClinics = new Set(clinics.map((c) => String(c.orgId || "")));

    const list = clinics.map((c) => {
      const oid = String(c.orgId || "");
      const org = orgById[oid] || {};
      const orgName = String(org.name || "").trim();
      const logo = String(org.logoUrl || "").trim();
      const orgCity = String(org.city || org.location?.city || "").trim();
      const orgAddr = String(org.address || org.location?.address || "").trim();
      const line = [
        String(c.address || "").trim(),
        String(c.city || "").trim(),
      ]
        .filter(Boolean)
        .join(" • ");
      const orgLine = [
        orgAddr,
        orgCity,
      ]
        .filter(Boolean)
        .join(" • ");
      return {
        kind: "clinic",
        _id: c._id,
        clinicId: c._id,
        orgId: c.orgId,
        name: c.name,
        address: String(c.address || ""),
        city: String(c.city || ""),
        phone: String(c.phone || ""),
        subtitle: line || orgLine || orgName,
        logoUrl: logo,
        organizationName: orgName,
        organizationDescription: String(org.description || "").trim(),
      };
    });

    for (const org of activeOrgs) {
      const oid = String(org._id);
      if (orgIdsWithClinics.has(oid)) continue;
      const orgCity = String(org.city || org.location?.city || "").trim();
      const orgAddr = String(org.address || org.location?.address || "").trim();
      const orgLine = [orgAddr, orgCity].filter(Boolean).join(" • ");
      list.push({
        kind: "organization",
        _id: org._id,
        orgId: org._id,
        name: String(org.name || "").trim(),
        address: orgAddr,
        city: orgCity,
        phone: String(org.phone || "").trim(),
        subtitle: orgLine || String(org.name || "").trim(),
        logoUrl: String(org.logoUrl || "").trim(),
        organizationName: String(org.name || "").trim(),
        organizationDescription: String(org.description || "").trim(),
      });
    }

    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error listing clinics" });
  }
});

/** Public clinic + parent org snapshot for deep links / guest browse (no auth). */
app.get("/api/clinics/:clinicId/profile", async (req, res) => {
  try {
    const { clinicId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.status(400).json({ message: "Invalid clinicId" });
    }
    const clinic = await Clinic.findById(clinicId).lean();
    if (!clinic || !clinic.orgId) {
      return res.status(404).json({ message: "Clinic not found" });
    }
    const org = await Organization.findById(clinic.orgId)
      .select("name logoUrl address city location specialty theme activeModules subscriptionType status")
      .lean();
    if (!org || !isOrganizationApproved(org.status)) {
      return res.status(404).json({ message: "Facility not available" });
    }
    const city = String(
      clinic.city || org.city || org.location?.city || ""
    ).trim();
    const address = String(
      clinic.address || org.address || org.location?.address || ""
    ).trim();
    res.json({
      clinic: {
        _id: clinic._id,
        name: clinic.name,
        address: String(clinic.address || ""),
        city: String(clinic.city || ""),
        phone: String(clinic.phone || ""),
      },
      organization: org,
      displayLocation: [
        address,
        city,
      ]
        .filter(Boolean)
        .join(" • "),
      logoUrl: String(org.logoUrl || ""),
    });
  } catch (e) {
    res.status(500).json({ message: "Error loading clinic profile" });
  }
});

/** Book appointment: roster from `doctors` collection filtered by organization. */
app.get("/api/doctors", async (req, res) => {
  try {
    const orgId = resolveOrgIdFromQuery(req.query);
    if (!orgId) return res.json([]);
    const clinicId = String(req.query.clinicId || "").trim();
    const doctors = await listBookingDoctors(
      orgId,
      mongoose.Types.ObjectId.isValid(clinicId) ? clinicId : null
    );
    res.json(doctors);
  } catch (e) {
    console.error("[api/doctors]", e);
    res.json([]);
  }
});

/** GET specialties for booking filter at a clinic/org */
app.get("/api/clinics/:clinicId/specialties", async (req, res) => {
  try {
    const { clinicId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.json([]);
    }
    const orgId = resolveOrgIdFromQuery(req.query);
    if (!orgId) return res.json([]);
    const doctors = await listBookingDoctors(orgId, clinicId);
    const specs = [
      ...new Set(
        doctors.map((d) => String(d.specialty || "").trim()).filter(Boolean)
      ),
    ].sort();
    res.json(specs);
  } catch (e) {
    res.status(500).json({ message: "Error listing specialties" });
  }
});

/** Enhanced booking: list doctors with photo/specialty and available slots by date. */
app.get("/api/clinics/:clinicId/doctors/availability", async (req, res) => {
  try {
    const { clinicId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.status(400).json({ message: "Invalid clinicId" });
    }
    const orgId = resolveOrgIdFromQuery(req.query);
    if (!orgId) return res.json([]);

    const clinic = await Clinic.findOne({ _id: clinicId, orgId }).lean();
    if (!clinic) return res.json([]);
    const date = normalizeDateToYmd(req.query.date) || "";
    if (!date) return res.status(400).json({ message: "Query param date=YYYY-MM-DD is required" });

    const specialtyFilter = String(req.query.specialty || req.query.department || "").trim().toLowerCase();
    const doctorUserIdFilter = String(req.query.doctorUserId || "").trim();

    let doctors = await listBookingDoctors(orgId, clinicId);
    if (specialtyFilter) {
      doctors = doctors.filter(
        (d) => String(d.specialty || "").toLowerCase() === specialtyFilter
      );
    }
    if (doctorUserIdFilter && mongoose.Types.ObjectId.isValid(doctorUserIdFilter)) {
      doctors = doctors.filter((d) => String(d.userId) === doctorUserIdFilter);
    }

    const out = [];
    const { isDateBlocked } = require("./utils/dynamicSchedule");

    for (const d of doctors) {
      const doc = await Doctor.findOne({ userId: d.userId }).lean();
      if (isDateBlocked(doc?.bookingBlocklist, date)) {
        out.push({ ...d, availableSlots: [], onLeave: true });
        continue;
      }
      const slotResult = await generateAvailableSlotsForDoctor(AppointmentModel, {
        orgId,
        doctorUserId: d.userId,
        dateYmd: date,
        workSchedule: doc?.workSchedule,
        bookingBlocklist: doc?.bookingBlocklist,
        isDateBlockedFn: isDateBlocked,
      });
      if (slotResult.onLeave) {
        out.push({ ...d, availableSlots: [], onLeave: true, hasSchedule: false });
        continue;
      }
      out.push({
        ...d,
        availableSlots: slotResult.availableSlots,
        dayOfWeek: slotResult.dayOfWeek,
        hasSchedule: slotResult.hasSchedule,
        onLeave: false,
      });
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ message: "Error listing availability" });
  }
});

app.get("/api/clinics/:clinicId/doctors", async (req, res) => {
  try {
    const { clinicId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.status(400).json({ message: "Invalid clinicId" });
    }
    const orgId = resolveOrgIdFromQuery(req.query);
    if (!orgId) return res.json([]);

    const clinic = await Clinic.findOne({ _id: clinicId, orgId }).lean();
    if (!clinic) return res.json([]);
    res.json(await listBookingDoctors(orgId, clinicId));
  } catch (e) {
    console.error("[api/clinics/:clinicId/doctors]", e);
    res.json([]);
  }
});

app.get("/api/patients/:id/medications", prescriptionCtrl.getActiveMedications);
app.post("/api/patients/:id/medications/:medId/start", prescriptionCtrl.startMedication);
app.post("/api/prescriptions/:id/start", prescriptionCtrl.startMedication);
app.get("/api/patients/:id/stopped-medication-alerts", prescriptionCtrl.getStoppedMedicationAlerts);
app.post(
  "/api/patients/:id/stopped-medication-alerts/:alertId/acknowledge",
  prescriptionCtrl.acknowledgeStoppedAlert
);
/** Alias for stopped alerts (query: patientUserId) */
app.get("/api/prescriptions/stopped-alerts", prescriptionCtrl.getStoppedMedicationAlerts);

app.get("/api/adverse-reports/options", adverseReportCtrl.getFormOptions);

app.post("/api/patients/:id/adverse-reports", adverseReportCtrl.reportAdverseEffect);
app.get("/api/patients/:id/adverse-reports", adverseReportCtrl.listPatientReports);

app.patch("/api/patients/:id/medications/:medId", async (req, res) => {
  try {
    const { id, medId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id) || !mongoose.Types.ObjectId.isValid(medId)) {
      return res.status(400).json({ message: "Invalid id" });
    }
    const { active } = req.body;
    const med = await PatientMedication.findOne({
      _id: medId,
      patientUserId: id,
    });
    if (!med) return res.status(404).json({ message: "Medication not found" });
    if (med.status === "Stopped") {
      return res.status(400).json({ message: "Medication was stopped by your doctor" });
    }
    const {
      expireMedicationIfNeeded,
      serializeMedication,
    } = require("./services/medicationLifecycle");
    await expireMedicationIfNeeded(med);
    if (med.status === "Expired") {
      return res.status(400).json({ message: "Medication course has expired" });
    }
    if (active != null) {
      const wantActive = Boolean(active);
      if (wantActive && !med.startDate) {
        return res.status(400).json({
          message: "Use POST /medications/:medId/start to begin this medication course",
        });
      }
      med.active = wantActive;
      if (wantActive) med.status = "Active";
    }
    await med.save();
    res.json(serializeMedication(med));
  } catch (e) {
    res.status(500).json({ message: "Error updating medication" });
  }
});

app.get("/api/patients/:id", async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid id" });
    }
    const patient = await ensurePatientForUser(id);
    if (!patient) return res.status(404).json({ message: "User not found" });
    res.json(patient);
  } catch (error) {
    res.status(500).json({ message: "Error fetching patient" });
  }
});

app.get("/api/patients/:id/my-bookings", appointmentCtrl.getPatientMyBookings);
app.get("/api/patients/:patientUserId/my-bookings", appointmentCtrl.getPatientMyBookings);

app.get("/api/patients/:id/appointments", async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid id" });
    }
    const user = await UserModel.findById(id).lean();
    if (!user) return res.status(404).json({ message: "User not found" });

    const list = await AppointmentModel.find({ patientId: id }).lean();
    const now = new Date();
    const upcoming = [];
    const past = [];
    for (const a of list) {
      const dt = combinedDateTime(a.date, a.time);
      const status = String(a.status || "");
      const cancelledByDoctor = status === "cancelled_by_doctor";
      const cancelledByPatient = status === "cancelled_by_patient";
      const done =
        status === "Completed" ||
        status === "Cancelled" ||
        cancelledByPatient ||
        status === "Terminated";
      const needsReschedule = a.bookingStatus === "reschedule_requested";
      if (cancelledByDoctor && a.cancelAlertDismissed) {
        past.push(a);
        continue;
      }
      if (cancelledByDoctor || needsReschedule || (!done && dt >= now)) upcoming.push(a);
      else past.push(a);
    }
    upcoming.sort(
      (a, b) => combinedDateTime(a.date, a.time) - combinedDateTime(b.date, b.time)
    );
    past.sort(
      (a, b) => combinedDateTime(b.date, b.time) - combinedDateTime(a.date, a.time)
    );
    res.json({ upcoming, past });
  } catch (error) {
    res.status(500).json({ message: "Error fetching patient appointments" });
  }
});

// Appointments — GET all documents as JSON (legacy path)
app.get("/appointments", async (req, res) => {
  try {
    const appointments = await listAppointmentsJson();
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ message: "Error fetching appointments" });
  }
});

// Alias under /api for proxies and consistent clients (e.g. Doctor Dashboard Flutter)
app.get("/api/appointments", async (req, res) => {
  try {
    const appointments = await listAppointmentsJson();
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ message: "Error fetching appointments" });
  }
});

// Legacy alias — delegate to slot-aware booking controller
app.post("/appointments/book", (req, res) => appointmentCtrl.bookAppointment(req, res));

// Optional: seed sample appointments (only when collection is empty, unless ?force=true)
app.post("/appointments/seed", async (req, res) => {
  try {
    const force = req.query.force === "true";
    const count = await AppointmentModel.countDocuments();
    if (count > 0 && !force) {
      return res.json({
        message: "Appointments already exist; skip seed. Use ?force=true to add samples anyway.",
        count,
        inserted: 0,
      });
    }
    const samples = [
      {
        patientName: "Ahmad Ali",
        time: "09:00 AM",
        date: "2026-04-02",
        status: "Waiting",
        bookingStatus: "Accepted",
        doctorName: "Dr. Ahmed Hassan",
        branch: "Rafeeq Clinic — Main Branch",
      },
      {
        patientName: "Sara Khaled",
        time: "10:30 AM",
        date: "2026-04-02",
        status: "Waiting",
        bookingStatus: "Accepted",
        doctorName: "Dr. Sara Mahmoud",
        branch: "Rafeeq Clinic — Main Branch",
      },
      {
        patientName: "Omar Hassan",
        time: "11:15 AM",
        date: "2026-04-03",
        status: "Waiting",
        bookingStatus: "Pending",
        doctorName: "Dr. Layla Farid",
        branch: "Rafeeq Clinic — North Branch",
      },
    ];
    const created = await AppointmentModel.insertMany(samples);
    res.status(201).json({
      message: "Sample appointments inserted",
      inserted: created.length,
    });
  } catch (error) {
    res.status(500).json({ message: "Error seeding appointments" });
  }
});

async function updateAppointmentStatusHandler(req, res) {
  try {
    const { appointmentId, status } = req.body;
    if (!appointmentId) {
      return res.status(400).json({ message: "appointmentId is required" });
    }
    const newStatus = status != null ? status : "Completed";
    const updated = await AppointmentModel.findByIdAndUpdate(
      appointmentId,
      { status: newStatus },
      { new: true }
    );
    if (!updated) {
      return res.status(404).json({ message: "Appointment not found" });
    }
    res.json(updated);
  } catch (error) {
    res.status(500).json({ message: "Error updating appointment status" });
  }
}

app.put("/appointments/update-status", updateAppointmentStatusHandler);
app.put("/api/appointments/update-status", updateAppointmentStatusHandler);

async function createMedicalRecordHandler(req, res) {
  try {
    const { appointmentId, diagnosis, prescription, notes } = req.body;
    if (!appointmentId || diagnosis == null || String(diagnosis).trim() === "") {
      return res.status(400).json({
        message: "appointmentId and diagnosis are required",
      });
    }
    const record = new MedicalRecord({
      appointmentId,
      diagnosis: String(diagnosis).trim(),
      prescription: Array.isArray(prescription) ? prescription : [],
      notes: notes != null ? String(notes) : "",
    });
    await record.save();
    res.status(201).json(record);
  } catch (error) {
    res.status(500).json({ message: "Error creating medical record" });
  }
}

app.post("/medical-records/create", createMedicalRecordHandler);
app.post("/api/medical-records/create", createMedicalRecordHandler);

app.post("/api/auth/login", loginAuthHandler);
app.post("/api/auth/register", registerPatientAuthHandler);
app.use("/api/auth", authRoutes);
app.use("/api/files", fileRoutes);
app.put("/api/auth/profile/update", requireNurse, updateAuthProfile);

// 2. إضافة مسار الـ Signup (هذا هو الجزء الذي كان ينقصك)
app.post("/signup", async (req, res) => {
  try {
    const {
      orgId,
      organizationName,
      organizationLogoUrl,
      organizationAddress,
      organizationCity,
      subscriptionType,
      activeModules,
      theme,
      name,
      email,
      role,
      password,
      profileImageUrl,
      patientHealth,
      doctorClinicId,
      doctorSpecialization,
      doctorYearsExperience,
      doctorCertificatesBase64,
      doctorSignatureBase64,
      phone,
      pharmacyName,
      address,
      city,
      licenseNumber,
      operatingHours,
      is24Hours,
      licenseImage,
      latitude,
      longitude,
      pharmacyProfile,
    } = req.body;

    const normalizedRole = normalizeRole(role);
    if (!isAllowedRole(normalizedRole) || !ALLOWED_ROLES.includes(normalizedRole)) {
      return res.status(400).json({ message: `Unsupported role: ${String(role)}` });
    }

    const img = profileImageUrl != null ? String(profileImageUrl) : "";
    const safeImg = img.length > 1_200_000 ? img.slice(0, 1_200_000) : img;

    let resolvedOrgId = extractOrgIdFromBody(req.body);
    let resolvedClinicId = extractClinicIdFromBody(req.body);

    const pharmacyValidation = validatePharmacySignup({
      body: req.body,
      normalizedRole,
      resolvedOrgId,
      resolvedClinicId,
    });
    if (!pharmacyValidation.ok) {
      return res.status(pharmacyValidation.status || 400).json({ message: pharmacyValidation.message });
    }

    resolvedOrgId = pharmacyValidation.resolvedOrgId;
    resolvedClinicId = pharmacyValidation.resolvedClinicId;
    const pharmacyPayload = pharmacyValidation.pharmacyPayload || buildPharmacySignupPayload(req.body);
    const pharmacyType = pharmacyValidation.pharmacyType || pharmacyPayload.pharmacyType || "External";
    const isExternalPharmacist = pharmacyValidation.isExternalPharmacist;

    if (normalizedRole === "Organization Admin") {
      const orgName = organizationName != null ? String(organizationName).trim() : "";
      if (!orgName) return res.status(400).json({ message: "organizationName is required for Organization Admin" });

      const createdOrg = await Organization.create({
        name: orgName,
        logoUrl: organizationLogoUrl != null ? String(organizationLogoUrl) : "",
        subscriptionType: subscriptionType != null ? String(subscriptionType) : "Free",
        activeModules: activeModules && typeof activeModules === "object" ? activeModules : undefined,
        theme: theme && typeof theme === "object" ? theme : undefined,
        status: "pending",
      });
      resolvedOrgId = createdOrg._id;
    }

    // Staff join requests MUST select a facility explicitly (except independent external pharmacies).
    if (isStaffRole(normalizedRole) && normalizedRole !== "Organization Admin" && !isExternalPharmacist) {
      if (!resolvedOrgId) {
        return res.status(400).json({ message: "orgId is required for staff registration" });
      }
      const org = await Organization.findById(resolvedOrgId).lean();
      if (!org) return res.status(400).json({ message: "Organization not found" });
      if (!isOrganizationApproved(org.status)) {
        return res.status(403).json({
          message: "This facility is not yet approved. Staff cannot register until Super Admin approval.",
          facilityStatus: org.status || "pending",
        });
      }
    }

    // Staff Request-Approval (pre-account): create RegistrationRequests, not users.
    if (
      isStaffRole(normalizedRole) &&
      normalizedRole !== "Organization Admin" &&
      normalizedRole !== "Patient" &&
      !isExternalPharmacist
    ) {
      const org = await Organization.findById(resolvedOrgId).select("name").lean();

      const yrs =
        doctorYearsExperience != null && doctorYearsExperience !== ""
          ? Number(doctorYearsExperience)
          : 0;
      const certFiles = Array.isArray(doctorCertificatesBase64)
        ? doctorCertificatesBase64.map((x) => String(x).slice(0, 500_000))
        : [];
      const sig =
        doctorSignatureBase64 != null ? String(doctorSignatureBase64).slice(0, 500_000) : "";

      const clinicOid =
        doctorClinicId && mongoose.Types.ObjectId.isValid(String(doctorClinicId))
          ? new mongoose.Types.ObjectId(String(doctorClinicId))
          : normalizedRole === "Pharmacist" && resolvedClinicId
            ? resolvedClinicId
            : null;

      const reqDoc = await RegistrationRequest.create({
        orgId: resolvedOrgId,
        status: "pending",
        name,
        email,
        role: normalizedRole,
        password,
        profileImageUrl: safeImg,
        phone: phone != null ? String(phone) : "",
        doctorClinicId: clinicOid,
        clinicId: clinicOid,
        doctorSpecialization: doctorSpecialization != null ? String(doctorSpecialization) : "",
        doctorYearsExperience: Number.isNaN(yrs) ? 0 : yrs,
        doctorCertificatesBase64: certFiles,
        doctorSignatureBase64: sig,
        pharmacyProfile: {
          pharmacyName: String(pharmacyPayload.pharmacyName || "").trim(),
          address: String(pharmacyPayload.address || "").trim(),
          city: String(pharmacyPayload.city || "").trim(),
          licenseNumber: String(pharmacyPayload.licenseNumber || "").trim(),
          operatingHours: String(pharmacyPayload.operatingHours || "").trim(),
          is24Hours: pharmacyPayload.is24Hours === true,
          licenseImage: String(pharmacyPayload.licenseImage || "").slice(0, 500_000),
          latitude:
            pharmacyPayload.latitude != null && !Number.isNaN(Number(pharmacyPayload.latitude))
              ? Number(pharmacyPayload.latitude)
              : null,
          longitude:
            pharmacyPayload.longitude != null && !Number.isNaN(Number(pharmacyPayload.longitude))
              ? Number(pharmacyPayload.longitude)
              : null,
          phone: String(pharmacyPayload.phone || phone || "").trim(),
          pharmacyType: pharmacyType === "Internal" ? "Internal" : "External",
        },
      });

      // Notify org admins
      try {
        const admins = await UserModel.find({
          role: "Organization Admin",
          orgId: resolvedOrgId,
          status: "active",
        })
          .select("_id")
          .lean();
        for (const a of admins) {
          await UserNotification.create({
            orgId: resolvedOrgId,
            userId: a._id,
            role: "orgadmin",
            type: "registration_request",
            title: "New staff registration request",
            body: `${String(name || "Staff")} requested access to ${org?.name || "your facility"} as ${String(
              normalizedRole
            )}`,
            read: false,
            meta: { registrationRequestId: String(reqDoc._id) },
          });
        }
      } catch (_) {}

      return res.status(200).json({
        message: `Your request has been sent to ${(org?.name || "the facility")} Admin for approval.`,
        requestId: String(reqDoc._id),
        status: "pending",
        orgId: resolvedOrgId ? String(resolvedOrgId) : "",
      });
    }

    if (isExternalPharmacist) {
      const emailNorm = email != null ? String(email).trim().toLowerCase() : "";
      if (!emailNorm) return res.status(400).json({ message: "email is required" });
      const emailEsc = emailNorm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const dup = await UserModel.findOne({ email: new RegExp(`^${emailEsc}$`, "i") }).lean();
      if (dup) {
        return res.status(409).json({ message: "An account with this email already exists" });
      }

      const newUser = await UserModel.create({
        orgId: null,
        status: "pending",
        name,
        email: emailNorm,
        role: "Pharmacist",
        password: password != null && String(password).length > 0 ? hashPassword(String(password)) : "",
        profileImageUrl: safeImg,
        phoneNumber: phone != null ? String(phone) : "",
      });

      try {
        const { provisionExternalPharmacyFromProfile } = require("./services/internalPharmacyProvisioning");
        await provisionExternalPharmacyFromProfile({
          orgId: null,
          userId: newUser._id,
          profile: pharmacyPayload,
        });
      } catch (phErr) {
        console.warn("[signup/external-pharmacy]", phErr.message);
      }

      return res.status(200).json({
        message: "Independent pharmacy registration submitted. Awaiting platform approval.",
        userId: String(newUser._id),
        status: "pending",
        orgId: "",
      });
    }

    let initialUserStatus = "active";
    if (normalizedRole === "Organization Admin" && resolvedOrgId) {
      const orgForAdmin = await Organization.findById(resolvedOrgId).select("status").lean();
      if (!isOrganizationApproved(orgForAdmin?.status)) {
        initialUserStatus = "pending";
      }
    }

    const newUser = await UserModel.create({
      orgId: resolvedOrgId,
      status: initialUserStatus,
      name,
      email,
      role: normalizedRole,
      password: password != null && String(password).length > 0 ? hashPassword(String(password)) : "",
      profileImageUrl: safeImg,
    });

    // Create a linked Admin record immediately for facility admins.
    if (normalizedRole === "Organization Admin") {
      try {
        await Admin.updateOne(
          { userId: newUser._id },
          {
            $set: {
              userId: newUser._id,
              orgId: resolvedOrgId,
              email: String(email || ""),
              name: String(name || ""),
              role: "Organization Admin",
            },
          },
          { upsert: true }
        );
      } catch (_) {}
    }
    if (normalizedRole === "Patient") {
      const h = patientHealth && typeof patientHealth === "object" ? patientHealth : {};
      const bloodType = h.bloodType != null ? String(h.bloodType).trim() : "";
      const weightKg = h.weightKg != null && h.weightKg !== "" ? Number(h.weightKg) : null;
      let patientClinicId = null;
      const bodyClinicId = String(req.body?.clinicId || req.body?.branchId || "").trim();
      if (bodyClinicId && mongoose.Types.ObjectId.isValid(bodyClinicId)) {
        patientClinicId = new mongoose.Types.ObjectId(bodyClinicId);
      } else if (resolvedOrgId) {
        const firstClinic = await Clinic.findOne({ orgId: resolvedOrgId })
          .sort({ createdAt: 1 })
          .select("_id")
          .lean();
        patientClinicId = firstClinic?._id || null;
      }
      await Patient.create({
        orgId: resolvedOrgId,
        clinicId: patientClinicId,
        userId: newUser._id,
        fullName: name,
        email: email || "",
        bloodType,
        weightKg: Number.isNaN(weightKg) ? null : weightKg,
        lastCheckupLabel: h.lastCheckupLabel != null ? String(h.lastCheckupLabel) : "",
        profileImage: safeImg,
      });
      await HealthProfile.updateOne(
        { userId: newUser._id },
        {
          $setOnInsert: { userId: newUser._id },
          $set: {
            orgId: resolvedOrgId,
            bloodType,
            weightKg: Number.isNaN(weightKg) ? null : weightKg,
            heightCm:
              h.heightCm != null && h.heightCm !== "" && !Number.isNaN(Number(h.heightCm))
                ? Number(h.heightCm)
                : null,
            chronicDiseases: Array.isArray(h.chronicDiseases) ? h.chronicDiseases : [],
            allergies: Array.isArray(h.allergies) ? h.allergies : [],
            pastSurgeries: Array.isArray(h.pastSurgeries) ? h.pastSurgeries : [],
          },
        },
        { upsert: true }
      );
    }
    if (normalizedRole === "Doctor") {
      const hid = await resolveHospitalClinicId();
      const selected =
        doctorClinicId && mongoose.Types.ObjectId.isValid(String(doctorClinicId))
          ? new mongoose.Types.ObjectId(String(doctorClinicId))
          : hid;
      if (selected) {
        await UserModel.updateOne({ _id: newUser._id }, { $set: { clinicId: selected } });
      }
      const yrs =
        doctorYearsExperience != null && doctorYearsExperience !== ""
          ? Number(doctorYearsExperience)
          : 0;
      const certFiles = Array.isArray(doctorCertificatesBase64)
        ? doctorCertificatesBase64.map((x) => String(x).slice(0, 500_000))
        : [];
      const sig =
        doctorSignatureBase64 != null ? String(doctorSignatureBase64).slice(0, 500_000) : "";
      await Doctor.updateOne(
        { userId: newUser._id },
        {
          $set: {
            orgId: resolvedOrgId,
            displayName: name,
            specialization: doctorSpecialization != null ? String(doctorSpecialization) : "",
            yearsExperience: Number.isNaN(yrs) ? 0 : yrs,
            profileImageBase64: safeImg,
            signatureImageBase64: sig,
            certificateFilesBase64: certFiles,
            ...(selected ? { clinicId: selected } : {}),
          },
          $setOnInsert: { userId: newUser._id },
        },
        { upsert: true }
      );
    }

    // Staff approvals are now handled via RegistrationRequests (pre-account).

    res.status(200).json({
      message: "Account created",
      orgId: resolvedOrgId ? String(resolvedOrgId) : "",
      status: newUser.status || "active",
    });
  } catch (error) {
    res.status(500).send("Error saving user");
  }
});

app.post("/login", loginAuthHandler);

/** Map facility registration module keys to legacy activeModules booleans. */
function moduleKeysToActiveModules(arr) {
  const keys = new Set(
    (Array.isArray(arr) ? arr : [])
      .map((x) => String(x || "").trim().toLowerCase())
      .filter(Boolean)
  );
  const keyStr = [...keys].join(" ");
  return {
    pharmacy: keys.has("pharmacy"),
    labRadiology:
      keys.has("labradiology") ||
      keys.has("lab_radiology") ||
      /\blab\b/.test(keyStr) ||
      keys.has("radiology"),
    internsTrainees:
      keys.has("internstrainees") ||
      keys.has("interns_trainees") ||
      keys.has("intern") ||
      keys.has("trainee"),
    emergency: keys.has("emergency"),
  };
}

/** Dedicated facility + primary admin onboarding (no org header). */
app.post("/api/organizations/register", async (req, res) => {
  try {
    const {
      name,
      logoUrl,
      phone,
      address,
      city,
      mapUrl,
      latitude,
      longitude,
      description,
      activeModuleKeys,
      hasInternalPharmacy,
      adminName,
      adminEmail,
      adminPassword,
    } = req.body;

    const orgName = name != null ? String(name).trim() : "";
    if (!orgName) return res.status(400).json({ message: "Clinic name is required" });

    const emailNorm = adminEmail != null ? String(adminEmail).trim().toLowerCase() : "";
    if (!emailNorm) return res.status(400).json({ message: "Admin email is required" });

    const pass = adminPassword != null ? String(adminPassword) : "";
    if (!pass) return res.status(400).json({ message: "Admin password is required" });

    const ownerName = adminName != null ? String(adminName).trim() : "";
    if (!ownerName) return res.status(400).json({ message: "Admin name is required" });

    const emailEsc = emailNorm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const dupUser = await UserModel.findOne({
      email: new RegExp(`^${emailEsc}$`, "i"),
    }).lean();
    if (dupUser) {
      console.log("[facility-register] reject duplicate email", emailNorm);
      return res.status(409).json({ message: "An account with this email already exists" });
    }

    const dupOrg = await Organization.findOne({ name: orgName }).lean();
    if (dupOrg) {
      console.log("[facility-register] reject duplicate org name", orgName);
      return res.status(409).json({ message: "A facility with this name already exists" });
    }

    const modKeys = Array.isArray(activeModuleKeys)
      ? activeModuleKeys.map((x) => String(x).trim()).filter(Boolean).slice(0, 32)
      : [];
    const activeModulesObj = moduleKeysToActiveModules(modKeys);

    const addr = address != null ? String(address).trim() : "";
    const cityStr = city != null ? String(city).trim() : "";
    const img = logoUrl != null ? String(logoUrl) : "";
    const safeImg = img.length > 1_800_000 ? img.slice(0, 1_800_000) : img;

    let latVal = null;
    let lngVal = null;
    if (latitude != null && longitude != null) {
      const lat = Number(latitude);
      const lng = Number(longitude);
      if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
        latVal = lat;
        lngVal = lng;
      }
    }
    const mapUrlRaw = mapUrl != null ? String(mapUrl).trim() : "";
    const mapUrlFinal =
      mapUrlRaw ||
      (latVal != null && lngVal != null
        ? `https://www.google.com/maps?q=${latVal},${lngVal}`
        : "");

    const internalPharmacy =
      hasInternalPharmacy === true ||
      hasInternalPharmacy === "true" ||
      (activeModulesObj.pharmacy && modKeys.includes("pharmacy"));

    const createdOrg = await Organization.create({
      name: orgName,
      logoUrl: safeImg,
      phone: phone != null ? String(phone).trim() : "",
      address: addr,
      city: cityStr,
      location: { address: addr, city: cityStr },
      mapUrl: mapUrlFinal,
      latitude: latVal,
      longitude: lngVal,
      description: description != null ? String(description).slice(0, 50_000) : "",
      moduleKeys: modKeys,
      activeModules: activeModulesObj,
      hasInternalPharmacy: Boolean(internalPharmacy && activeModulesObj.pharmacy),
      status: "pending",
      subscriptionType: "Free",
    });

    const newUser = await UserModel.create({
      orgId: createdOrg._id,
      status: "pending",
      name: ownerName,
      email: emailNorm,
      role: "Organization Admin",
      password: hashPassword(pass),
      profileImageUrl: "",
    });

    await Admin.updateOne(
      { userId: newUser._id },
      {
        $set: {
          userId: newUser._id,
          orgId: createdOrg._id,
          email: emailNorm,
          name: ownerName,
          role: "Organization Admin",
        },
      },
      { upsert: true }
    );

    // Internal pharmacy + pharmacist accounts are provisioned only after Super Admin approval.
    if (createdOrg.hasInternalPharmacy && activeModulesObj.pharmacy) {
      try {
        const Clinic = require("./models/clinic");
        await Clinic.create({
          orgId: createdOrg._id,
          name: orgName,
          address: addr,
          city: cityStr,
          phone: phone != null ? String(phone).trim() : "",
          hasInternalPharmacy: true,
        });
      } catch (clinicErr) {
        console.warn("[facility-register] clinic shell:", clinicErr.message);
      }
    }

    console.log("[facility-register] ok org=", String(createdOrg._id), "user=", String(newUser._id), "name=", orgName);

    return res.status(201).json({
      message: "Facility registration submitted. Awaiting Super Admin approval.",
      userId: newUser._id.toString(),
      orgId: createdOrg._id.toString(),
      organization: createdOrg.toObject(),
      status: "pending",
      internalPharmacyCredentials: null,
      note: "Pharmacy credentials will be issued after Super Admin approves this facility.",
    });
  } catch (e) {
    console.error("[facility-register]", e.message);
    if (e && e.code === 11000) {
      return res.status(409).json({ message: "Duplicate facility name or email" });
    }
    return res.status(500).json({ message: "Error registering facility" });
  }
});

// --- Organizations (tenant) discovery + admin approval ---
function formatPublicOrganizationRow(o) {
  const addrTop = String(o.address || "").trim();
  const locAddr = String(o.location?.address || "").trim();
  const cityTop = String(o.city || "").trim();
  const locCity = String(o.location?.city || "").trim();
  const city = cityTop || locCity;
  const address = addrTop || locAddr || "";
  return {
    _id: o._id,
    name: o.name,
    logoUrl: o.logoUrl ?? "",
    address,
    city,
    location: { address, city },
    description: String(o.description || "").trim(),
    status: o.status,
    specialty: o.specialty ?? "",
    theme: o.theme ?? undefined,
    subscriptionType: o.subscriptionType,
    activeModules: o.activeModules ?? undefined,
  };
}

/** Public landing: active organizations only (Our Facilities). */
app.get("/api/organizations/active", async (req, res) => {
  try {
    const docs = await Organization.find(activeOrganizationQuery()).sort({ name: 1 }).lean();
    res.json(docs.map(formatPublicOrganizationRow));
  } catch (e) {
    res.status(500).json({ message: "Error listing active organizations" });
  }
});

app.get("/api/organizations", async (req, res) => {
  try {
    const includePending = String(req.query.includePending || "") === "true";
    const q = includePending ? {} : activeOrganizationQuery();
    const docs = await Organization.find(q).sort({ name: 1 }).lean();
    res.json(docs.map(formatPublicOrganizationRow));
  } catch (e) {
    res.status(500).json({ message: "Error listing organizations" });
  }
});

app.get("/api/organizations/:orgId/theme", async (req, res) => {
  try {
    const { orgId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(orgId)) return res.status(400).json({ message: "Invalid orgId" });
    const org = await Organization.findById(orgId)
      .select("name logoUrl activeModules theme subscriptionType status")
      .lean();
    if (!org) return res.status(404).json({ message: "Organization not found" });
    res.json(org);
  } catch (e) {
    res.status(500).json({ message: "Error fetching organization" });
  }
});

/** Public: full organization document (active tenants only) for facility details. */
app.get("/api/organizations/:orgId", async (req, res) => {
  try {
    const { orgId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(orgId)) return res.status(400).json({ message: "Invalid orgId" });
    const org = await Organization.findById(orgId).lean();
    if (!org) return res.status(404).json({ message: "Organization not found" });
    if (!isOrganizationApproved(org.status)) {
      return res.status(404).json({ message: "Organization not available" });
    }
    res.json(org);
  } catch (e) {
    res.status(500).json({ message: "Error fetching organization" });
  }
});

async function approveOrganizationBySuperAdmin(req, res) {
  const sa = await requireSuperAdmin(req, res);
  if (!sa) return;
  req.superAdmin = sa;
  return facilityApprovalController.approveFacility(req, res);
}

/** Platform Super Admin: list pending clinics/tenants awaiting approval */
app.get("/api/admin/organizations/pending", async (req, res) => {
  try {
    const sa = await requireSuperAdmin(req, res);
    if (!sa) return;
    return facilityApprovalController.listPendingFacilities(req, res);
  } catch (e) {
    res.status(500).json({ message: "Error listing pending organizations" });
  }
});

/** Alias: slug matches mobile client (`superadmin` + `pending-orgs`). */
app.get("/api/superadmin/pending-orgs", async (req, res) => {
  try {
    const sa = await requireSuperAdmin(req, res);
    if (!sa) return;
    return facilityApprovalController.listPendingFacilities(req, res);
  } catch (e) {
    res.status(500).json({ message: "Error listing pending organizations" });
  }
});

app.put("/api/admin/organizations/:orgId/approve", approveOrganizationBySuperAdmin);
app.post("/api/admin/organizations/:orgId/approve", approveOrganizationBySuperAdmin);
app.post("/api/super-admin/organizations/:orgId/approve", approveOrganizationBySuperAdmin);
app.post("/api/superadmin/approve-org/:id", approveOrganizationBySuperAdmin);
app.post("/api/admin/organizations/:orgId/reject", async (req, res) => {
  const sa = await requireSuperAdmin(req, res);
  if (!sa) return;
  req.params.id = req.params.orgId;
  return facilityApprovalController.rejectFacility(req, res);
});

app.get("/api/super-admin/organizations", async (req, res) => {
  try {
    const sa = await requireSuperAdmin(req, res);
    if (!sa) return;
    const list = await Organization.find({}).sort({ createdAt: -1 }).limit(500).lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error listing organizations" });
  }
});

// --- Org Admin: staff join requests (pending approval workflow) ---
app.get("/api/org-admin/staff-requests", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    const users = await UserModel.find({
      orgId: scoped.orgId,
      status: "pending",
      role: {
        $in: [
          "Doctor",
          "Pharmacist",
          "Nurse",
          "Lab Technician",
          "Radiologist",
          "Intern/Trainee",
          "Staff/Operations",
        ],
      },
    })
      .select("name email role profileImageUrl orgId status clinicId")
      .sort({ createdAt: -1 })
      .limit(500)
      .lean();

    const out = [];
    for (const u of users) {
      const doc = u.role === "Doctor" ? await Doctor.findOne({ userId: u._id }).lean() : null;
      out.push({
        ...u,
        doctor: doc
          ? {
              specialization: doc.specialization || "",
              yearsExperience: doc.yearsExperience ?? 0,
              certificateFilesBase64: doc.certificateFilesBase64 || [],
              signatureImageBase64: doc.signatureImageBase64 || "",
            }
          : null,
      });
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ message: "Error listing staff requests" });
  }
});

// Pending registration requests (pre-account) — scoped by org + clinic footprint
app.get("/api/admin/pending-requests", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    console.log(
      "[pending-requests] adminUserId=%s header.x-org-id=%s resolvedOrgId=%s",
      String(scoped.user?._id || ""),
      String(req.header("x-org-id") || ""),
      String(scoped.orgId || "")
    );
    await regReqAdminCtrl.listPending(req, res, scoped);
  } catch (e) {
    res.status(500).json({ message: "Error listing pending requests" });
  }
});

// TEMP DEBUG: return ALL registration requests without filters.
app.get("/api/debug/all-requests", async (req, res) => {
  try {
    const list = await RegistrationRequest.find({}).sort({ createdAt: -1 }).limit(2000).lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading all requests" });
  }
});

// TEMP DEBUG: force-set a user's orgId (use carefully in dev).
// Example: POST /api/debug/set-user-org with JSON { "userId": "...", "orgId": "..." }
app.post("/api/debug/set-user-org", async (req, res) => {
  try {
    const userId = String(req.body?.userId || "").trim();
    const orgId = String(req.body?.orgId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(userId)) return res.status(400).json({ message: "Invalid userId" });
    if (!mongoose.Types.ObjectId.isValid(orgId)) return res.status(400).json({ message: "Invalid orgId" });
    const updated = await UserModel.findOneAndUpdate(
      { _id: new mongoose.Types.ObjectId(userId) },
      { $set: { orgId: new mongoose.Types.ObjectId(orgId) } },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: "User not found" });
    res.json({ message: "Updated", userId: String(updated._id), orgId: String(updated.orgId || "") });
  } catch (e) {
    res.status(500).json({ message: "Error updating user orgId" });
  }
});

app.post("/api/admin/approve-user", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    const userId = String(req.body?.userId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(userId)) return res.status(400).json({ message: "userId is required" });

    const updated = await UserModel.findOneAndUpdate(
      { _id: userId, orgId: scoped.orgId, status: "pending" },
      { $set: { status: "active" } },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: "Request not found" });
    res.json(updated);
  } catch (e) {
    res.status(500).json({ message: "Error approving user" });
  }
});

// Approve a RegistrationRequest by id (moves it to users, then deletes request)
app.post("/api/admin/approve-user/:id", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    req.params.requestId = req.params.id;
    await regReqAdminCtrl.approve(req, res, scoped);
  } catch (e) {
    res.status(500).json({ message: "Error approving user" });
  }
});

// --- RegistrationRequests (pre-account) approval flow ---
app.get("/api/admin/requests", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    await regReqAdminCtrl.listPending(req, res, scoped);
  } catch (e) {
    res.status(500).json({ message: "Error listing registration requests" });
  }
});

app.post("/api/admin/requests/:requestId/approve", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    await regReqAdminCtrl.approve(req, res, scoped);
  } catch (e) {
    res.status(500).json({ message: "Error approving request" });
  }
});

app.post("/api/admin/requests/:requestId/reject", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    await regReqAdminCtrl.reject(req, res, scoped);
  } catch (e) {
    res.status(500).json({ message: "Error rejecting request" });
  }
});

app.post("/api/org-admin/staff-requests/:userId/approve", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    const { userId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(userId)) return res.status(400).json({ message: "Invalid userId" });
    const updated = await UserModel.findOneAndUpdate(
      { _id: userId, orgId: scoped.orgId, status: "pending" },
      { $set: { status: "active" } },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: "Request not found" });

    try {
      const org = await Organization.findById(scoped.orgId).lean();
      await UserNotification.create({
        orgId: scoped.orgId,
        userId: updated._id,
        role: String(updated.role || "").toLowerCase(),
        type: "approval",
        title: "Access approved",
        body: `Congratulations! Your access to ${org?.name || "the facility"} has been approved.`,
        read: false,
        meta: { orgId: String(scoped.orgId) },
      });
    } catch (_) {}

    res.json(updated);
  } catch (e) {
    res.status(500).json({ message: "Error approving request" });
  }
});

app.post("/api/org-admin/staff-requests/:userId/reject", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    const { userId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(userId)) return res.status(400).json({ message: "Invalid userId" });

    const updated = await UserModel.findOneAndUpdate(
      { _id: userId, orgId: scoped.orgId, status: "pending" },
      { $set: { status: "rejected" } },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: "Request not found" });

    try {
      await Doctor.deleteOne({ userId: updated._id });
    } catch (_) {}

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: "Error rejecting request" });
  }
});

// --- Spec-compatible aliases (Admin Pending Approval Workflow) ---

// OrgAdmin notifications (re-use UserNotification bell)
app.get("/api/org-admin/:orgAdminUserId/notifications", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    const { orgAdminUserId } = req.params;
    if (String(orgAdminUserId) !== String(scoped.user._id)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    const list = await UserNotification.find({ userId: scoped.user._id, orgId: scoped.orgId })
      .sort({ createdAt: -1 })
      .limit(120)
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error loading notifications" });
  }
});

app.patch("/api/org-admin/:orgAdminUserId/notifications/:notificationId/read", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    const { orgAdminUserId, notificationId } = req.params;
    if (String(orgAdminUserId) !== String(scoped.user._id)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    const n = await UserNotification.findOneAndUpdate(
      { _id: notificationId, userId: scoped.user._id, orgId: scoped.orgId },
      { $set: { read: true } },
      { new: true }
    ).lean();
    if (!n) return res.status(404).json({ message: "Notification not found" });
    res.json(n);
  } catch (e) {
    res.status(500).json({ message: "Error updating notification" });
  }
});

/** Same payload as GET /api/doctor-portal/:doctorUserId/analytics (for Postman / legacy clients). */
app.get("/api/doctor/statistics", async (req, res) => {
  try {
    const doctorUserId = String(req.query.doctorUserId || req.query.id || "").trim();
    if (!mongoose.Types.ObjectId.isValid(doctorUserId)) {
      return res.status(400).json({
        message: "Query parameter doctorUserId (Mongo ObjectId) is required",
      });
    }
    const u = await UserModel.findById(doctorUserId).lean();
    if (!u) return res.status(404).json({ message: "User not found" });
    if (u.role !== "Doctor") {
      return res.status(403).json({ message: "Doctor role required" });
    }
    const fakeReq = { doctorUserId, doctorUser: u };
    await doctorPortalCtrl.getAnalytics(fakeReq, res);
  } catch (error) {
    res.status(500).json({ message: "Error statistics" });
  }
});

app.use(blockNurseForbiddenRoutes);
app.use(blockDoctorForbiddenRoutes);

const aiRoutes = require("./routes/aiRoutes");
app.use("/api/ai", aiRoutes);

app.use("/api/patient-portal", patientPortalRoutes);
app.use("/api/doctor-portal", doctorPortalRoutes);
app.use("/api/doctor", doctorRoutes);
// Explicit bind — clinic admin read-only appointment roster
app.get("/api/appointments/clinic", async (req, res) => {
  try {
    const scoped = await requireOrgAdmin(req, res);
    if (!scoped) return;
    await orgAdminExtendedController.getClinicAppointments(req, res, scoped);
  } catch (e) {
    console.error("[appointments/clinic]", e);
    if (!res.headersSent) {
      res.status(500).json({ message: e.message || "Server error" });
    }
  }
});
app.use("/api/appointments", appointmentRoutes);
app.use("/api/waiting-list", waitingListRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/nurse", nurseRoutes);
const labRequestRoutes = require("./routes/labRequestRoutes");
app.use("/api/lab-requests", labRequestRoutes);
app.use("/api/labrequests", labRequestRoutes);
console.log("[server] Lab queue API mounted at /api/lab-requests and /api/labrequests");
app.use("/api/diagnostic", require("./routes/diagnosticRoutes"));
app.use("/api/pharmacy", pharmacyRoutes);

const leaveRouter = createLeaveRouter({
  requireAuth,
  requireOrgAdmin,
});
const leaveAuthMiddleware = createLeaveAuthMiddleware(requireAuth);
// Explicit bind — guarantees GET /api/leaves/my-requests for Flutter leave history
app.get("/api/leaves/my-requests", leaveAuthMiddleware, leaveRequestController.getMyRequests);
app.use("/api/leaves", leaveRouter);
console.log("[server] Leave requests API mounted at /api/leaves (request, my-requests, all, status)");

const billingController = require("./controllers/billingController");
const { requireDoctor: requireDoctorForBilling } = require("./middleware/doctorAuth");
const createBillingRouter = require("./routes/billingRoutes");
const createAdminBillingRouter = require("./routes/adminBillingRoutes");

app.use("/api/billing", createBillingRouter());
// Explicit bind — guarantees POST /api/billing/deduct-session even if router mount order shifts
app.post("/api/billing/deduct-session", requireDoctorForBilling, (req, res) =>
  billingController.deductSession(req, res)
);
app.get("/api/billing/consultation-fee", requireDoctorForBilling, (req, res) =>
  billingController.getDoctorFee(req, res)
);
console.log("[server] Billing API mounted at /api/billing (GET /consultation-fee, POST /deduct-session)");

// Org-admin billing — explicit mount matches Flutter GET /api/admin/billing/ledger|metrics
app.use(
  "/api/admin/billing",
  createAdminBillingRouter({ requireOrgAdmin })
);
console.log("[server] Admin billing API mounted at /api/admin/billing (ledger, metrics, payroll)");

app.use(
  "/api/admin",
  createOrgAdminExtendedRouter({
    requireOrgAdmin,
  })
);

// JSON 404 for unknown API routes (prevents HTML error pages in Flutter)
app.use("/api", (req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

app.get("/", (req, res) => {
  res.send("Server is running");
});

async function requireAdmin(req, res) {
  const adminUserId = String(req.header("x-admin-user-id") || req.query.adminUserId || "").trim();
  if (!mongoose.Types.ObjectId.isValid(adminUserId)) {
    res.status(401).json({ message: "Admin id required (x-admin-user-id or ?adminUserId=)" });
    return null;
  }
  const u = await UserModel.findById(adminUserId).lean();
  if (!u) {
    res.status(401).json({ message: "Admin user not found" });
    return null;
  }
  if (u.role !== "Admin") {
    res.status(403).json({ message: "Admin role required" });
    return null;
  }
  return u;
}

// --- Admin: manage clinics ---
app.post("/api/admin/clinics", async (req, res) => {
  try {
    const scoped = await requireOrgScope(req, res);
    if (!scoped) return;
    if (!["Organization Admin", "Admin", "SuperAdmin"].includes(normalizeRole(scoped.user.role))) {
      return res.status(403).json({ message: "Admin role required" });
    }
    const { name, address, city, phone, hasInternalPharmacy, latitude, longitude } = req.body;
    if (!name || !String(name).trim()) return res.status(400).json({ message: "name required" });
    const wantsInternal =
      hasInternalPharmacy === true || hasInternalPharmacy === "true";
    const created = await Clinic.create({
      orgId: scoped.orgId,
      name: String(name).trim(),
      address: address != null ? String(address) : "",
      city: city != null ? String(city) : "",
      phone: phone != null ? String(phone) : "",
      hasInternalPharmacy: wantsInternal,
    });

    let internalPharmacyCredentials = null;
    if (wantsInternal) {
      try {
        const { provisionInternalPharmacy } = require("./services/internalPharmacyProvisioning");
        const bundle = await provisionInternalPharmacy({
          orgId: scoped.orgId,
          clinicId: created._id,
          pharmacyName: `${created.name} — In-House Pharmacy`,
          latitude,
          longitude,
          address: created.address,
          phone: created.phone,
        });
        if (bundle?.internalPharmacist) {
          internalPharmacyCredentials = {
            email: bundle.internalPharmacist.email,
            password: bundle.internalPharmacist.password,
            role: bundle.internalPharmacist.role,
            userId: bundle.internalPharmacist.userId,
          };
        }
      } catch (seedErr) {
        console.warn("[admin/clinics] internal pharmacy seed:", seedErr.message);
      }
    }

    clearHospitalClinicCache();
    const fresh = await Clinic.findById(created._id).lean();
    const payload = fresh || created.toObject();
    res.status(201).json({ ...payload, internalPharmacyCredentials });
  } catch (e) {
    res.status(500).json({ message: "Error creating clinic" });
  }
});

app.delete("/api/admin/clinics/:clinicId", async (req, res) => {
  try {
    const scoped = await requireOrgScope(req, res);
    if (!scoped) return;
    if (!["Organization Admin", "Admin", "SuperAdmin"].includes(normalizeRole(scoped.user.role))) {
      return res.status(403).json({ message: "Admin role required" });
    }
    const { clinicId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(clinicId)) return res.status(400).json({ message: "Invalid clinicId" });
    await Clinic.deleteOne({ _id: clinicId, orgId: scoped.orgId });
    clearHospitalClinicCache();
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: "Error deleting clinic" });
  }
});

// --- Doctor leave requests (doctor submits; admin approves) ---
app.post("/api/doctors/:doctorUserId/leave-requests", async (req, res) => {
  try {
    const { doctorUserId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(doctorUserId)) {
      return res.status(400).json({ message: "Invalid doctorUserId" });
    }
    const u = await UserModel.findById(doctorUserId).lean();
    if (!u || u.role !== "Doctor") return res.status(404).json({ message: "Doctor not found" });
    const orgId = getRequestOrgId(req, u);
    if (!orgId) return res.status(403).json({ message: "orgId is required for this request" });
    const { fromDate, toDate, reason } = req.body;
    const f = normalizeDateToYmd(fromDate);
    const t = normalizeDateToYmd(toDate);
    if (!f || !t) return res.status(400).json({ message: "fromDate and toDate (YYYY-MM-DD) required" });
    const created = await DoctorLeaveRequest.create({
      orgId,
      doctorUserId,
      clinicId: u.clinicId || null,
      fromDate: f,
      toDate: t,
      reason: reason != null ? String(reason) : "",
      status: "Pending",
    });
    res.status(201).json(created.toObject());
  } catch (e) {
    res.status(500).json({ message: "Error creating leave request" });
  }
});

app.get("/api/admin/leave-requests", async (req, res) => {
  try {
    const scoped = await requireOrgScope(req, res);
    if (!scoped) return;
    if (!["Organization Admin", "Admin", "SuperAdmin"].includes(normalizeRole(scoped.user.role))) {
      return res.status(403).json({ message: "Admin role required" });
    }
    const list = await DoctorLeaveRequest.find({ orgId: scoped.orgId, status: "Pending" })
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();
    res.json(list);
  } catch (e) {
    res.status(500).json({ message: "Error listing leave requests" });
  }
});

app.patch("/api/admin/leave-requests/:id", async (req, res) => {
  try {
    const scoped = await requireOrgScope(req, res);
    if (!scoped) return;
    if (!["Organization Admin", "Admin", "SuperAdmin"].includes(normalizeRole(scoped.user.role))) {
      return res.status(403).json({ message: "Admin role required" });
    }
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: "Invalid id" });
    const { status } = req.body;
    if (!["Approved", "Rejected"].includes(String(status))) {
      return res.status(400).json({ message: "status must be Approved or Rejected" });
    }
    const updated = await DoctorLeaveRequest.findOneAndUpdate(
      { _id: id, orgId: scoped.orgId },
      { $set: { status, decidedByAdminUserId: scoped.user._id, decidedAt: new Date() } },
      { new: true }
    ).lean();
    res.json(updated);
  } catch (e) {
    res.status(500).json({ message: "Error updating leave request" });
  }
});

// --- Test / dev: backfill internal pharmacies for existing clinics ---
app.get("/api/test/migrate-clinics", async (req, res) => {
  const allow =
    process.env.ALLOW_TEST_ROUTES === "true" ||
    process.env.NODE_ENV !== "production";
  if (!allow) {
    return res.status(404).json({ message: "Not found" });
  }
  try {
    const { migrateAllClinicsInternalPharmacy } = require("./services/migrateClinicsInternalPharmacy");
    const summary = await migrateAllClinicsInternalPharmacy();
    console.log("[migrate-clinics] via API:", summary.provisioned, "provisioned,", summary.skipped, "skipped,", summary.failed, "failed");
    res.json({
      message: "Clinic internal pharmacy migration completed",
      ...summary,
    });
  } catch (e) {
    console.error("[migrate-clinics]", e.message);
    res.status(500).json({ message: "Migration failed", error: e.message });
  }
});

app.listen(3000, () => {
  console.log("Server running on port 3000");
});