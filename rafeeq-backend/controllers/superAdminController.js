const mongoose = require("mongoose");
const Organization = require("../models/Organization");
const Clinic = require("../models/clinic");
const Department = require("../models/department");
const UserModel = require("../models/User");
const Doctor = require("../models/doctor");
const StaffProfile = require("../models/staffProfile");
const RegistrationRequest = require("../models/registrationRequest");
const Invoice = require("../models/invoice");
const Payment = require("../models/payment");
const Pharmacy = require("../models/pharmacy");
const MedicationRequest = require("../models/medicationRequest");
const PharmacyOrderTransaction = require("../models/pharmacyOrderTransaction");
const pharmacyInventoryService = require("../services/pharmacyInventoryService");
const {
  provisionInternalPharmacyForOrganization,
  buildInternalPharmacistEmail,
} = require("../services/internalPharmacyProvisioning");
const {
  isOrganizationApproved,
  mapStatusFilterForQuery,
  pendingOrganizationQuery,
} = require("../utils/organizationStatus");
const {
  buildMedicalOrdersFeed,
  buildPlatformAdminStats,
  clampLimit,
} = require("../utils/superAdminMedicalOrdersFeed");
const {
  approveRegistrationRequest,
  resolveEffectiveOrgId,
} = require("../utils/registrationRequestScope");

const STAFF_ROLES = [
  "Doctor",
  "Nurse",
  "Lab Technician",
  "Radiologist",
  "Pharmacist",
  "Intern/Trainee",
  "Staff/Operations",
];

const ADMIN_ROLES = ["Organization Admin"];

function pharmacySummaryRow(pharmacy, pharmacistEmail) {
  if (!pharmacy) return null;
  return {
    id: String(pharmacy._id),
    name: pharmacy.name || "Pharmacy",
    type: pharmacy.pharmacyType || "Internal",
    email: pharmacistEmail || "",
    clinicId: pharmacy.clinicId ? String(pharmacy.clinicId) : null,
    status: pharmacy.status || "Active",
  };
}

function orgListRow(org, extras = {}) {
  const pharmacies = Array.isArray(extras.pharmacies) ? extras.pharmacies.filter(Boolean) : [];
  const primaryPharmacy = pharmacies[0] || null;
  return {
    id: String(org._id),
    name: org.name || "Unnamed",
    status: org.status || "active",
    subscriptionType: org.subscriptionType || "Free",
    city: org.city || org.location?.city || "",
    address: org.address || org.location?.address || "",
    registeredAt: org.createdAt || null,
    activeModules: org.activeModules || {},
    moduleKeys: org.moduleKeys || [],
    hasInternalPharmacy: Boolean(org.hasInternalPharmacy || pharmacies.length > 0),
    pharmacies,
    pharmacy: primaryPharmacy,
    pharmacyEmail: primaryPharmacy?.email || "",
    pharmacyName: primaryPharmacy?.name || "",
  };
}

async function resolveOrgPharmacies(org) {
  const orgId = org._id;
  const pharmacyModule =
    org.activeModules?.pharmacy === true ||
    (Array.isArray(org.moduleKeys) && org.moduleKeys.includes("pharmacy"));

  if (pharmacyModule && !org.internalPharmacyId && isOrganizationApproved(org.status)) {
    try {
      await provisionInternalPharmacyForOrganization(orgId);
      org = (await Organization.findById(orgId).lean()) || org;
    } catch (e) {
      console.warn("[superadmin/organizations] pharmacy provision skipped:", org.name, e.message);
    }
  }

  const pharmacyIds = new Set();
  if (org.internalPharmacyId) pharmacyIds.add(String(org.internalPharmacyId));

  const clinics = await Clinic.find({ orgId }).select("_id name internalPharmacyId hasInternalPharmacy").lean();
  for (const c of clinics) {
    if (c.internalPharmacyId) pharmacyIds.add(String(c.internalPharmacyId));
  }

  const orgPharmacies = await Pharmacy.find({
    $or: [{ orgId }, { _id: { $in: [...pharmacyIds].filter((id) => mongoose.Types.ObjectId.isValid(id)) } }],
  }).lean();

  const unique = new Map();
  for (const p of orgPharmacies) unique.set(String(p._id), p);

  const rows = [];
  for (const pharmacy of unique.values()) {
    let pharmacistEmail = "";
    if (pharmacy.userId && mongoose.Types.ObjectId.isValid(String(pharmacy.userId))) {
      const u = await UserModel.findById(pharmacy.userId).select("email role").lean();
      if (u?.email) pharmacistEmail = u.email;
    }
    if (!pharmacistEmail) {
      const clinic = clinics.find((c) => c.internalPharmacyId && String(c.internalPharmacyId) === String(pharmacy._id));
      const clinicName = clinic?.name || org.name;
      pharmacistEmail = buildInternalPharmacistEmail(clinicName);
    }
    rows.push(pharmacySummaryRow(pharmacy, pharmacistEmail));
  }

  return rows.filter(Boolean);
}

function groupStaff(users, profiles, doctorDocs) {
  const profileByUser = new Map(profiles.map((p) => [String(p.userId), p]));
  const doctorByUser = new Map(doctorDocs.map((d) => [String(d.userId), d]));

  const enrich = (u) => ({
    id: String(u._id),
    name: u.name || "",
    email: u.email || "",
    phoneNumber: u.phoneNumber || "",
    role: u.role || "",
    status: u.status || "active",
    profileImageUrl: u.profileImageUrl || "",
    clinicId: u.clinicId ? String(u.clinicId) : null,
    profile: profileByUser.get(String(u._id)) || null,
    doctorProfile: doctorByUser.get(String(u._id)) || null,
  });

  const doctors = [];
  const nurses = [];
  const administrative = [];

  for (const u of users) {
    const row = enrich(u);
    if (u.role === "Doctor") doctors.push(row);
    else if (u.role === "Nurse") nurses.push(row);
    else administrative.push(row);
  }

  return { doctors, nurses, administrative };
}

exports.getOrganizations = async (req, res) => {
  console.log("SuperAdmin fetching logic active");
  try {
    const q = mapStatusFilterForQuery(req.query.status);
    const list = await Organization.find(q).sort({ createdAt: -1 }).limit(500).lean();
    const data = [];
    for (const org of list) {
      const pharmacies = await resolveOrgPharmacies(org);
      data.push(orgListRow(org, { pharmacies }));
    }
    return res.status(200).json({ success: true, data });
  } catch (error) {
    console.error("[superadmin/organizations]", error);
    return res.status(500).json({ success: false, message: error.message || "Error listing organizations" });
  }
};

exports.listPendingOrganizations = async (req, res) => {
  try {
    const list = await Organization.find(pendingOrganizationQuery()).sort({ createdAt: -1 }).limit(500).lean();
    const data = list.map(orgListRow);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message || "Error listing pending organizations" });
  }
};

exports.getOrganizationDetail = async (req, res) => {
  try {
    const orgId = String(req.params.orgId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(orgId)) {
      return res.status(400).json({ message: "Invalid orgId" });
    }
    const oid = new mongoose.Types.ObjectId(orgId);

    const [org, clinics, departments, staffCounts] = await Promise.all([
      Organization.findById(oid).lean(),
      Clinic.find({ orgId: oid }).sort({ name: 1 }).lean(),
      Department.find({ orgId: oid }).sort({ name: 1 }).lean(),
      UserModel.aggregate([
        { $match: { orgId: oid, role: { $in: [...STAFF_ROLES, ...ADMIN_ROLES] } } },
        { $group: { _id: "$role", count: { $sum: 1 } } },
      ]),
    ]);

    if (!org) return res.status(404).json({ message: "Organization not found" });

    const counts = Object.fromEntries(staffCounts.map((r) => [r._id, r.count]));

    res.json({
      organization: {
        ...orgListRow(org),
        phone: org.phone || "",
        description: org.description || "",
        specialty: org.specialty || "",
        theme: org.theme || {},
        adminSettings: org.adminSettings || {},
      },
      clinics: clinics.map((c) => ({
        id: String(c._id),
        name: c.name,
        address: c.address || "",
        city: c.city || "",
        phone: c.phone || "",
      })),
      departments: departments.map((d) => ({
        id: String(d._id),
        name: d.name,
        description: d.description || "",
      })),
      staffCounts: {
        doctors: counts.Doctor || 0,
        nurses: counts.Nurse || 0,
        administrative:
          (counts["Organization Admin"] || 0) +
          (counts.Pharmacist || 0) +
          (counts["Lab Technician"] || 0) +
          (counts.Radiologist || 0) +
          (counts["Intern/Trainee"] || 0) +
          (counts["Staff/Operations"] || 0),
        total: Object.values(counts).reduce((s, n) => s + n, 0),
      },
    });
  } catch (e) {
    console.error("[superadmin/org detail]", e);
    res.status(500).json({ message: "Error loading organization detail" });
  }
};

async function fetchClinicStaff(orgOrClinicId) {
  const id = String(orgOrClinicId || "").trim();
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return { error: { status: 400, message: "Invalid org/clinic id" } };
  }
  const oid = new mongoose.Types.ObjectId(id);

  let users = await UserModel.find({
    orgId: oid,
    role: { $in: STAFF_ROLES },
  })
    .select("-password")
    .sort({ role: 1, name: 1 })
    .lean();

  if (!users.length) {
    users = await UserModel.find({
      clinicId: oid,
      role: { $in: STAFF_ROLES },
    })
      .select("-password")
      .sort({ role: 1, name: 1 })
      .lean();
  }

  const userIds = users.map((u) => u._id);
  const orgKey = users[0]?.orgId || oid;
  const [profiles, doctors] = await Promise.all([
    StaffProfile.find({ orgId: orgKey, userId: { $in: userIds } }).lean(),
    Doctor.find({ orgId: orgKey, userId: { $in: userIds } }).lean(),
  ]);

  return { data: groupStaff(users, profiles, doctors), staff: users };
}

exports.getClinicStaff = async (req, res) => {
  try {
    const scopeId = req.params.orgId || req.params.clinicId;
    const result = await fetchClinicStaff(scopeId);
    if (result.error) {
      return res.status(result.error.status).json({ success: false, message: result.error.message });
    }
    return res.status(200).json({ success: true, data: result.data, staff: result.staff });
  } catch (error) {
    console.error("[superadmin/clinic-staff]", error);
    return res.status(500).json({ success: false, message: error.message || "Error listing staff" });
  }
};

exports.listOrganizationStaff = exports.getClinicStaff;

exports.getStaffMember = async (req, res) => {
  try {
    const orgId = String(req.params.orgId || "").trim();
    const userId = String(req.params.userId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(orgId) || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: "Invalid id" });
    }

    const user = await UserModel.findOne({
      _id: userId,
      orgId,
      role: { $in: STAFF_ROLES },
    })
      .select("name email role status clinicId profileImageUrl phoneNumber identityNumber gender")
      .lean();

    if (!user) return res.status(404).json({ message: "Staff member not found" });

    const [profile, doctorProfile, department] = await Promise.all([
      StaffProfile.findOne({ userId, orgId }).lean(),
      Doctor.findOne({ userId, orgId }).lean(),
      StaffProfile.findOne({ userId, orgId })
        .select("departmentId")
        .lean()
        .then(async (p) => {
          if (!p?.departmentId) return null;
          return Department.findById(p.departmentId).select("name").lean();
        }),
    ]);

    res.json({
      id: String(user._id),
      name: user.name || "",
      email: user.email || "",
      phoneNumber: user.phoneNumber || "",
      role: user.role || "",
      status: user.status || "active",
      identityNumber: user.identityNumber || "",
      gender: user.gender || "",
      profileImageUrl: user.profileImageUrl || "",
      clinicId: user.clinicId ? String(user.clinicId) : null,
      department: department ? { id: String(department._id), name: department.name } : null,
      profile: profile || null,
      doctorProfile: doctorProfile
        ? {
            specialization: doctorProfile.specialization || doctorProfile.specialty || "",
            yearsOfExperience: doctorProfile.yearsOfExperience ?? null,
            consultationFee: doctorProfile.consultationFee ?? null,
            workSchedule: doctorProfile.workSchedule || [],
            documents: doctorProfile.documents || {},
          }
        : null,
    });
  } catch (e) {
    console.error("[superadmin/staff detail]", e);
    res.status(500).json({ message: "Error loading staff member" });
  }
};

exports.updateStaffMember = async (req, res) => {
  try {
    const userId = String(req.params.userId || req.params.staffId || "").trim();
    let orgId = String(req.params.orgId || req.body.orgId || "").trim();

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: "Invalid staff id" });
    }

    let user = null;
    if (orgId && mongoose.Types.ObjectId.isValid(orgId)) {
      user = await UserModel.findOne({ _id: userId, orgId, role: { $in: STAFF_ROLES } });
    } else {
      user = await UserModel.findOne({ _id: userId, role: { $in: STAFF_ROLES } });
      if (user?.orgId) orgId = String(user.orgId);
    }

    if (!user) {
      return res.status(404).json({ success: false, message: "Staff member not found" });
    }

    const userPatch = {};
    if (req.body.name != null) userPatch.name = String(req.body.name).trim();
    if (req.body.phoneNumber != null) userPatch.phoneNumber = String(req.body.phoneNumber).trim();
    if (req.body.email != null) userPatch.email = String(req.body.email).trim();
    if (mongoose.Types.ObjectId.isValid(req.body.clinicId)) {
      userPatch.clinicId = req.body.clinicId;
    }
    if (Object.keys(userPatch).length) {
      await UserModel.updateOne({ _id: userId }, { $set: userPatch });
    }

    const profilePatch = {
      orgId,
      userId,
      specialty: req.body.specialty != null ? String(req.body.specialty) : undefined,
      salary: req.body.salary != null ? Number(req.body.salary) || 0 : undefined,
      shiftHours:
        req.body.shiftHours && typeof req.body.shiftHours === "object"
          ? {
              start: String(req.body.shiftHours.start || "08:00"),
              end: String(req.body.shiftHours.end || "17:00"),
            }
          : undefined,
      permissions: Array.isArray(req.body.permissions) ? req.body.permissions.map(String) : undefined,
      departmentId: mongoose.Types.ObjectId.isValid(req.body.departmentId) ? req.body.departmentId : undefined,
      loginDisabled: req.body.loginDisabled != null ? Boolean(req.body.loginDisabled) : undefined,
    };

    const cleanProfile = Object.fromEntries(
      Object.entries(profilePatch).filter(([, v]) => v !== undefined)
    );
    cleanProfile.orgId = orgId;
    cleanProfile.userId = userId;

    const profile = await StaffProfile.findOneAndUpdate(
      { userId },
      { $set: cleanProfile },
      { upsert: true, new: true }
    ).lean();

    if (user.role === "Doctor" && (req.body.specialization != null || req.body.consultationFee != null)) {
      await Doctor.findOneAndUpdate(
        { userId, orgId },
        {
          $set: {
            ...(req.body.specialization != null
              ? { specialization: String(req.body.specialization) }
              : {}),
            ...(req.body.consultationFee != null
              ? { consultationFee: Number(req.body.consultationFee) || 0 }
              : {}),
          },
        },
        { upsert: false }
      );
    }

    const updatedStaff = await UserModel.findById(userId).select("-password").lean();
    return res.status(200).json({ success: true, data: updatedStaff, profile });
  } catch (error) {
    console.error("[superadmin/staff update]", error);
    return res.status(500).json({ success: false, message: error.message || "Error updating staff member" });
  }
};

exports.updateStaffStatus = async (req, res) => {
  try {
    const orgId = String(req.params.orgId || "").trim();
    const userId = String(req.params.userId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(orgId) || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: "Invalid id" });
    }

    const user = await UserModel.findOne({ _id: userId, orgId, role: { $in: STAFF_ROLES } });
    if (!user) return res.status(404).json({ message: "Staff member not found" });

    if (req.body.delete === true) {
      await StaffProfile.deleteOne({ userId, orgId });
      await UserModel.updateOne({ _id: userId }, { $set: { status: "pending", loginMethod: user.loginMethod } });
      await StaffProfile.findOneAndUpdate(
        { userId },
        { $set: { loginDisabled: true } },
        { upsert: true }
      );
      return res.json({ ok: true, status: "suspended", deleted: false, loginDisabled: true });
    }

    const status = String(req.body.status || "").trim();
    if (!["active", "pending", "suspended"].includes(status)) {
      return res.status(400).json({ message: "status must be active, pending, or suspended" });
    }

    const userStatus = status === "suspended" ? "pending" : status;
    await UserModel.updateOne({ _id: userId }, { $set: { status: userStatus } });
    await StaffProfile.findOneAndUpdate(
      { userId },
      { $set: { loginDisabled: status === "suspended" } },
      { upsert: true }
    );

    res.json({ ok: true, status });
  } catch (e) {
    console.error("[superadmin/staff status]", e);
    res.status(500).json({ message: "Error updating staff status" });
  }
};

exports.getPendingApplications = async (req, res) => {
  try {
    const [pendingOrgs, pendingRegistrations, pendingStaffUsers] = await Promise.all([
      Organization.find(pendingOrganizationQuery()).sort({ createdAt: -1 }).limit(200).lean(),
      RegistrationRequest.find({ status: "pending" }).sort({ createdAt: -1 }).limit(300).lean(),
      UserModel.find({
        status: "pending",
        role: { $in: [...STAFF_ROLES, ...ADMIN_ROLES] },
      })
        .select("name email role orgId status createdAt profileImageUrl")
        .sort({ createdAt: -1 })
        .limit(300)
        .lean(),
    ]);

    const orgIds = [
      ...new Set(
        [...pendingRegistrations, ...pendingStaffUsers]
          .map((r) => r.orgId)
          .filter(Boolean)
          .map(String)
      ),
    ];
    const orgs = orgIds.length
      ? await Organization.find({ _id: { $in: orgIds } }).select("name status").lean()
      : [];
    const orgNameById = new Map(orgs.map((o) => [String(o._id), o.name]));

    res.json({
      pendingOrganizations: pendingOrgs.map(orgListRow),
      pendingRegistrations: pendingRegistrations.map((r) => ({
        id: String(r._id),
        type: "registration_request",
        name: r.name || "",
        email: r.email || "",
        role: r.role || "",
        orgId: r.orgId ? String(r.orgId) : null,
        orgName: r.orgId ? orgNameById.get(String(r.orgId)) || "" : "",
        submittedAt: r.createdAt || null,
      })),
      pendingStaff: pendingStaffUsers.map((u) => ({
        id: String(u._id),
        type: "staff_user",
        name: u.name || "",
        email: u.email || "",
        role: u.role || "",
        orgId: u.orgId ? String(u.orgId) : null,
        orgName: u.orgId ? orgNameById.get(String(u.orgId)) || "" : "",
        submittedAt: u.createdAt || null,
      })),
    });
  } catch (e) {
    console.error("[superadmin/pending-applications]", e);
    res.status(500).json({ message: "Error loading pending applications" });
  }
};

exports.getFinancialLedger = async (req, res) => {
  try {
    const [orgs, invoiceAgg, paymentAgg, recentInvoices, recentPayments] = await Promise.all([
      Organization.find({}).select("name status subscriptionType createdAt").sort({ name: 1 }).lean(),
      Invoice.aggregate([
        {
          $group: {
            _id: { orgId: "$orgId", status: "$status" },
            total: { $sum: "$amount" },
            count: { $sum: 1 },
          },
        },
      ]),
      Payment.aggregate([
        { $match: { status: /paid/i } },
        {
          $group: {
            _id: "$orgId",
            total: { $sum: "$amount" },
            count: { $sum: 1 },
          },
        },
      ]),
      Invoice.find({}).sort({ createdAt: -1 }).limit(50).lean(),
      Payment.find({}).sort({ paidAt: -1 }).limit(50).lean(),
    ]);

    const invoiceByOrg = {};
    for (const row of invoiceAgg) {
      const orgKey = String(row._id.orgId || "");
      if (!invoiceByOrg[orgKey]) invoiceByOrg[orgKey] = { paid: 0, pending: 0, invoiceCount: 0 };
      const st = String(row._id.status || "").toLowerCase();
      if (st === "paid") invoiceByOrg[orgKey].paid += row.total;
      else invoiceByOrg[orgKey].pending += row.total;
      invoiceByOrg[orgKey].invoiceCount += row.count;
    }

    const paymentByOrg = Object.fromEntries(
      paymentAgg.map((r) => [String(r._id || ""), { total: r.total, count: r.count }])
    );

    const orgNameById = new Map(orgs.map((o) => [String(o._id), o.name]));

    const entities = orgs.map((o) => {
      const key = String(o._id);
      const inv = invoiceByOrg[key] || { paid: 0, pending: 0, invoiceCount: 0 };
      const pay = paymentByOrg[key] || { total: 0, count: 0 };
      return {
        orgId: key,
        orgName: o.name,
        status: o.status,
        subscriptionType: o.subscriptionType || "Free",
        invoicesPaid: inv.paid,
        invoicesPending: inv.pending,
        paymentsCollected: pay.total,
        transactionCount: pay.count + inv.invoiceCount,
      };
    });

    const summary = {
      totalOrganizations: orgs.length,
      activeOrganizations: orgs.filter((o) => isOrganizationApproved(o.status)).length,
      totalPaymentsCollected: paymentAgg.reduce((s, r) => s + (r.total || 0), 0),
      totalInvoicesPending: invoiceAgg
        .filter((r) => String(r._id.status).toLowerCase() !== "paid")
        .reduce((s, r) => s + (r.total || 0), 0),
      currency: "ILS",
    };

    const transactions = [
      ...recentPayments.map((p) => ({
        id: String(p._id),
        type: "payment",
        orgName: orgNameById.get(String(p.orgId)) || "—",
        amount: p.amount,
        status: p.status || "Paid",
        description: p.description || "",
        date: p.paidAt || p.createdAt,
      })),
      ...recentInvoices.map((i) => ({
        id: String(i._id),
        type: "invoice",
        orgName: orgNameById.get(String(i.orgId)) || "—",
        amount: i.amount,
        status: i.status || "Pending",
        description: i.description || "",
        date: i.createdAt,
      })),
    ]
      .sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0))
      .slice(0, 60);

    return res.status(200).json({
      success: true,
      summary: {
        ...summary,
        totalPlatformRevenue: summary.totalPaymentsCollected,
        activeSubscriptions: summary.activeOrganizations,
        billingCurrency: summary.currency,
      },
      entities,
      transactions,
      recentTransactions: transactions,
    });
  } catch (error) {
    console.error("[superadmin/ledger]", error);
    return res.status(500).json({ success: false, message: error.message || "Error loading financial ledger" });
  }
};

exports.getMedicalOrdersFeed = async (req, res) => {
  try {
    const limit = clampLimit(req.query.limit);
    const [payload, platformStats] = await Promise.all([
      buildMedicalOrdersFeed({ limit }),
      buildPlatformAdminStats(),
    ]);
    return res.status(200).json({
      success: true,
      ...payload,
      platformStats,
    });
  } catch (error) {
    console.error("[superadmin/medical-orders-feed]", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Error loading medical orders feed",
    });
  }
};

exports.getPharmacyDetails = async (req, res) => {
  try {
    const pharmacyId = String(req.params.pharmacyId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(pharmacyId)) {
      return res.status(400).json({ success: false, message: "Invalid pharmacyId" });
    }

    const oid = new mongoose.Types.ObjectId(pharmacyId);
    const [pharmacy, dashboard, analytics] = await Promise.all([
      Pharmacy.findById(oid).lean(),
      pharmacyInventoryService.getDashboardStats(oid),
      pharmacyInventoryService.getAnalytics(oid),
    ]);

    if (!pharmacy) {
      return res.status(404).json({ success: false, message: "Pharmacy not found" });
    }

    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);

    const [pendingRx, processedRx, monthlySales, totalSales] = await Promise.all([
      MedicationRequest.countDocuments({ pharmacyId: oid, status: "Pending" }),
      MedicationRequest.countDocuments({
        pharmacyId: oid,
        status: { $in: ["Dispensed", "Paid", "Approved", "Partially Fulfilled"] },
      }),
      PharmacyOrderTransaction.aggregate([
        { $match: { pharmacyId: oid, status: "Paid", createdAt: { $gte: monthStart } } },
        { $group: { _id: null, total: { $sum: "$amount" }, count: { $sum: 1 } } },
      ]),
      PharmacyOrderTransaction.aggregate([
        { $match: { pharmacyId: oid, status: "Paid" } },
        { $group: { _id: null, total: { $sum: "$amount" }, count: { $sum: 1 } } },
      ]),
    ]);

    const shortages = [
      ...(analytics?.lowStock || []).map((row) => ({
        name: row.name || "Unknown",
        quantity: row.quantity ?? 0,
        status: row.status || "Low Stock",
      })),
      ...(analytics?.outOfStock || []).map((row) => ({
        name: row.name || "Unknown",
        quantity: row.quantity ?? 0,
        status: row.status || "Out of Stock",
      })),
    ];

    return res.status(200).json({
      success: true,
      data: {
        pharmacy: {
          id: String(pharmacy._id),
          name: pharmacy.name || "Pharmacy",
          email: pharmacy.pharmacistEmail || "",
          walletBalance: pharmacy.wallet_balance ?? 0,
          type: pharmacy.pharmacyType || "Internal",
          status: pharmacy.status || "Active",
        },
        sales: {
          totalSales: totalSales[0]?.total ?? 0,
          totalTransactions: totalSales[0]?.count ?? 0,
          monthlyRevenue: monthlySales[0]?.total ?? 0,
          monthlyTransactions: monthlySales[0]?.count ?? 0,
          currency: "ILS",
        },
        inventory: {
          availableDrugs: dashboard?.availableDrugs ?? 0,
          lowStockItems: dashboard?.lowStockItems ?? 0,
          outOfStockItems: dashboard?.outOfStockItems ?? 0,
          shortages,
        },
        prescriptions: {
          pending: pendingRx,
          processed: processedRx,
          total: pendingRx + processedRx,
        },
      },
    });
  } catch (error) {
    console.error("[superadmin/pharmacy-details]", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Error loading pharmacy details",
    });
  }
};

/** POST /api/superadmin/pending-registrations/:requestId/approve */
exports.approvePendingRegistration = async (req, res) => {
  try {
    const requestId = String(req.params.requestId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(requestId)) {
      return res.status(400).json({ message: "Invalid request id" });
    }

    const rr = await RegistrationRequest.findOne({ _id: requestId, status: "pending" })
      .select("+password +passwordHash")
      .lean();
    if (!rr) return res.status(404).json({ message: "Request not found" });

    const effectiveOrgId = await resolveEffectiveOrgId(rr, rr.orgId);
    const { newUser } = await approveRegistrationRequest(rr, effectiveOrgId);
    res.json({ message: "Approved", userId: String(newUser._id) });
  } catch (e) {
    console.error("[superadmin/approve-registration]", e);
    if (e.message && e.message.includes("password credentials")) {
      return res.status(400).json({ message: e.message });
    }
    res.status(500).json({ message: e.message || "Error approving registration" });
  }
};

/** POST /api/superadmin/pending-registrations/:requestId/reject */
exports.rejectPendingRegistration = async (req, res) => {
  try {
    const requestId = String(req.params.requestId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(requestId)) {
      return res.status(400).json({ message: "Invalid request id" });
    }

    const rr = await RegistrationRequest.findOne({ _id: requestId, status: "pending" }).lean();
    if (!rr) return res.status(404).json({ message: "Request not found" });

    await RegistrationRequest.deleteOne({ _id: rr._id });
    res.json({ message: "Rejected" });
  } catch (e) {
    console.error("[superadmin/reject-registration]", e);
    res.status(500).json({ message: e.message || "Error rejecting registration" });
  }
};

/** POST /api/superadmin/pending-staff/:userId/approve */
exports.approvePendingStaffUser = async (req, res) => {
  try {
    const userId = String(req.params.userId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: "Invalid user id" });
    }

    const updated = await UserModel.findOneAndUpdate(
      {
        _id: userId,
        status: "pending",
        role: { $in: [...STAFF_ROLES, ...ADMIN_ROLES] },
      },
      { $set: { status: "active" } },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: "Request not found" });

    res.json({ ok: true, userId: String(updated._id) });
  } catch (e) {
    console.error("[superadmin/approve-pending-staff]", e);
    res.status(500).json({ message: e.message || "Error approving staff request" });
  }
};

/** POST /api/superadmin/pending-staff/:userId/reject */
exports.rejectPendingStaffUser = async (req, res) => {
  try {
    const userId = String(req.params.userId || "").trim();
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: "Invalid user id" });
    }

    const updated = await UserModel.findOneAndUpdate(
      {
        _id: userId,
        status: "pending",
        role: { $in: [...STAFF_ROLES, ...ADMIN_ROLES] },
      },
      { $set: { status: "rejected" } },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: "Request not found" });

    try {
      await Doctor.deleteOne({ userId: updated._id });
    } catch (_) {}

    res.json({ ok: true });
  } catch (e) {
    console.error("[superadmin/reject-pending-staff]", e);
    res.status(500).json({ message: e.message || "Error rejecting staff request" });
  }
};

exports.listOrganizations = exports.getOrganizations;
exports.listPendingApplications = exports.getPendingApplications;
