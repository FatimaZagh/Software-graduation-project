const mongoose = require("mongoose");
const LabRequest = require("../models/labRequest");
const RadiologyRequest = require("../models/radiologyRequest");
const UserNotification = require("../models/userNotification");
const PatientNotification = require("../models/patientNotification");
const { enrichDiagnosticOrders, str } = require("../utils/diagnosticEnrichment");

function techScope(req) {
  return req.technicianScope || {};
}

function doctorScope(req) {
  return req.doctorScope || {};
}

function pendingFilter(orgId, _clinicId) {
  const filter = {
    status: { $in: ["Requested", "Pending", "Sample-Collected", "Scheduled"] },
    isLocked: { $ne: true },
  };
  if (orgId && mongoose.Types.ObjectId.isValid(String(orgId))) {
    filter.orgId = new mongoose.Types.ObjectId(String(orgId));
  }
  return filter;
}

/** GET /api/diagnostic/lab/pending */
async function listPendingLab(req, res) {
  const { orgId, role } = techScope(req);
  if (role === "Radiologist") {
    return res.json([]);
  }
  let list = await LabRequest.find(pendingFilter(orgId)).sort({ createdAt: -1 }).limit(100).lean();
  if (!list.length) {
    list = await LabRequest.find(pendingFilter(null)).sort({ createdAt: -1 }).limit(100).lean();
  }
  res.json(await enrichDiagnosticOrders(list));
}

/** GET /api/diagnostic/radiology/pending */
async function listPendingRadiology(req, res) {
  const { orgId, role } = techScope(req);
  if (role === "Lab Technician") {
    return res.json([]);
  }
  let list = await RadiologyRequest.find(pendingFilter(orgId)).sort({ createdAt: -1 }).limit(100).lean();
  if (!list.length) {
    list = await RadiologyRequest.find(pendingFilter(null)).sort({ createdAt: -1 }).limit(100).lean();
  }
  res.json(await enrichDiagnosticOrders(list));
}

function completedFilter(orgId) {
  const filter = { status: "Completed" };
  if (orgId && mongoose.Types.ObjectId.isValid(String(orgId))) {
    filter.orgId = new mongoose.Types.ObjectId(String(orgId));
  }
  return filter;
}

/** GET /api/diagnostic/lab/completed */
async function listCompletedLab(req, res) {
  const { orgId, role } = techScope(req);
  if (role === "Radiologist") {
    return res.json([]);
  }
  let list = await LabRequest.find(completedFilter(orgId)).sort({ completedAt: -1, updatedAt: -1 }).limit(100).lean();
  if (!list.length) {
    list = await LabRequest.find(completedFilter(null)).sort({ completedAt: -1, updatedAt: -1 }).limit(100).lean();
  }
  res.json(await enrichDiagnosticOrders(list));
}

/** GET /api/diagnostic/radiology/completed */
async function listCompletedRadiology(req, res) {
  const { orgId, role } = techScope(req);
  if (role === "Lab Technician") {
    return res.json([]);
  }
  let list = await RadiologyRequest.find(completedFilter(orgId)).sort({ completedAt: -1, updatedAt: -1 }).limit(100).lean();
  if (!list.length) {
    list = await RadiologyRequest.find(completedFilter(null)).sort({ completedAt: -1, updatedAt: -1 }).limit(100).lean();
  }
  res.json(await enrichDiagnosticOrders(list));
}

/** GET /api/diagnostic/lab/:id */
async function getLabOrder(req, res) {
  const { orgId } = techScope(req);
  const doc = await LabRequest.findOne({ _id: req.params.id, orgId }).lean();
  if (!doc) return res.status(404).json({ message: "Lab order not found" });
  const [enriched] = await enrichDiagnosticOrders([doc]);
  res.json(enriched);
}

/** GET /api/diagnostic/radiology/:id */
async function getRadiologyOrder(req, res) {
  const { orgId } = techScope(req);
  const doc = await RadiologyRequest.findOne({ _id: req.params.id, orgId }).lean();
  if (!doc) return res.status(404).json({ message: "Radiology order not found" });
  const [enriched] = await enrichDiagnosticOrders([doc]);
  res.json(enriched);
}

async function submitLab(req, res) {
  const { orgId, userId, role } = techScope(req);
  if (role === "Radiologist") {
    return res.status(403).json({ message: "Lab submission is not available for radiology technicians" });
  }
  const lab = await LabRequest.findOne({ _id: req.params.id, orgId });
  if (!lab) return res.status(404).json({ message: "Lab order not found" });
  if (lab.isLocked || lab.status === "Completed") {
    return res.status(409).json({ message: "Results are locked and cannot be modified" });
  }

  const analysis = str(req.body.resultAnalysis);
  if (!analysis) return res.status(400).json({ message: "resultAnalysis is required" });

  const fileUrl = str(req.body.attachmentUrl || req.body.fileUrl);
  const fileName = str(req.body.attachmentName || req.body.fileName);
  const mimeType = str(req.body.mimeType) || "application/pdf";

  lab.resultAnalysis = analysis;
  if (fileUrl) {
    lab.attachment = {
      fileUrl: fileUrl.slice(0, 14 * 1024 * 1024),
      fileName,
      mimeType,
      uploadedAt: new Date(),
      uploadedBy: userId,
    };
    lab.resultImages.push({ fileUrl: lab.attachment.fileUrl, uploadedBy: userId });
  }
  lab.status = "Completed";
  lab.isLocked = true;
  lab.completedAt = new Date();
  lab.submittedBy = userId;
  lab.isReadByDoctor = false;
  await lab.save();

  if (lab.doctorUserId) {
    await UserNotification.create({
      orgId,
      userId: lab.doctorUserId,
      role: "Doctor",
      type: "lab_result_completed",
      title: "Lab results ready",
      body: `${lab.testName} completed for review`,
      read: false,
      meta: { labRequestId: String(lab._id), patientUserId: String(lab.patientUserId) },
    });
  }
  await PatientNotification.create({
    patientUserId: lab.patientUserId,
    type: "lab_result",
    title: "New lab result available",
    body: `${lab.testName} results are ready`,
    read: false,
    meta: { labRequestId: String(lab._id) },
  });

  const [enriched] = await enrichDiagnosticOrders([lab.toObject()]);
  res.json(enriched);
}

async function submitRadiology(req, res) {
  const { orgId, userId, role } = techScope(req);
  if (role === "Lab Technician") {
    return res.status(403).json({ message: "Imaging submission is not available for laboratory technicians" });
  }
  let order = await RadiologyRequest.findOne({ _id: req.params.id, orgId });
  if (!order) order = await RadiologyRequest.findOne({ _id: req.params.id });
  if (!order) return res.status(404).json({ message: "Radiology order not found" });
  if (order.isLocked || order.status === "Completed") {
    return res.status(409).json({ message: "Results are locked and cannot be modified" });
  }

  const analysis = str(req.body.resultAnalysis);
  const technicianNotes = str(req.body.technicianNotes);
  const fileUrl = str(req.body.attachmentUrl || req.body.fileUrl);
  if (!analysis && !technicianNotes && !fileUrl) {
    return res.status(400).json({
      message: "Provide imaging report data, technician notes, or an attachment",
    });
  }

  const fileName = str(req.body.attachmentName || req.body.fileName);
  const mimeType = str(req.body.mimeType) || "application/pdf";

  order.resultAnalysis = analysis || technicianNotes;
  if (fileUrl) {
    order.attachment = {
      fileUrl: fileUrl.slice(0, 14 * 1024 * 1024),
      fileName,
      mimeType,
      uploadedAt: new Date(),
      uploadedBy: userId,
    };
    order.resultImages = [{ fileUrl: order.attachment.fileUrl, uploadedBy: userId }];
    if (fileUrl.startsWith("http")) order.resultUrls.push(fileUrl);
  }
  order.status = "Completed";
  order.isLocked = true;
  order.completedAt = new Date();
  order.submittedBy = userId;
  order.isReadByDoctor = false;
  await order.save();

  const notifyOrgId = order.orgId || orgId;
  if (order.doctorUserId) {
    await UserNotification.create({
      orgId: notifyOrgId,
      userId: order.doctorUserId,
      role: "Doctor",
      type: "radiology_result_completed",
      title: "Radiology results ready",
      body: `${order.studyName} completed for review`,
      read: false,
      meta: { radiologyRequestId: String(order._id), patientUserId: String(order.patientUserId) },
    });
  }
  await PatientNotification.create({
    patientUserId: order.patientUserId,
    type: "radiology_result",
    title: "New imaging result available",
    body: `${order.studyName} results are ready`,
    read: false,
    meta: { radiologyRequestId: String(order._id) },
  });

  const [enriched] = await enrichDiagnosticOrders([order.toObject()]);
  res.json(enriched);
}

/** GET /api/doctor/lab-results/completed */
async function doctorCompletedLab(req, res) {
  const { orgId, doctorUserId } = doctorScope(req);
  const list = await LabRequest.find({ orgId, doctorUserId, status: "Completed" })
    .sort({ completedAt: -1, updatedAt: -1 })
    .limit(200)
    .lean();
  res.json(await enrichDiagnosticOrders(list));
}

/** GET /api/doctor/radiology-results/completed */
async function doctorCompletedRadiology(req, res) {
  const { orgId, doctorUserId } = doctorScope(req);
  const list = await RadiologyRequest.find({ orgId, doctorUserId, status: "Completed" })
    .sort({ completedAt: -1, updatedAt: -1 })
    .limit(200)
    .lean();
  res.json(await enrichDiagnosticOrders(list));
}

/** GET /api/doctor/diagnostic-unread-counts */
async function doctorUnreadCounts(req, res) {
  const { orgId, doctorUserId } = doctorScope(req);
  const [labUnread, radiologyUnread] = await Promise.all([
    LabRequest.countDocuments({ orgId, doctorUserId, status: "Completed", isReadByDoctor: false }),
    RadiologyRequest.countDocuments({ orgId, doctorUserId, status: "Completed", isReadByDoctor: false }),
  ]);
  res.json({ labUnread, radiologyUnread, total: labUnread + radiologyUnread });
}

/** PATCH /api/doctor/lab-results/:id/read */
async function markLabRead(req, res) {
  const { orgId, doctorUserId } = doctorScope(req);
  const doc = await LabRequest.findOneAndUpdate(
    { _id: req.params.id, orgId, doctorUserId, status: "Completed" },
    { $set: { isReadByDoctor: true, readByDoctorAt: new Date() } },
    { new: true }
  ).lean();
  if (!doc) return res.status(404).json({ message: "Lab result not found" });
  res.json(doc);
}

/** PATCH /api/doctor/radiology-results/:id/read */
async function markRadiologyRead(req, res) {
  const { orgId, doctorUserId } = doctorScope(req);
  const doc = await RadiologyRequest.findOneAndUpdate(
    { _id: req.params.id, orgId, doctorUserId, status: "Completed" },
    { $set: { isReadByDoctor: true, readByDoctorAt: new Date() } },
    { new: true }
  ).lean();
  if (!doc) return res.status(404).json({ message: "Radiology result not found" });
  res.json(doc);
}

/** GET patient completed diagnostic results — full multi-clinic history by patient id only */
async function patientDiagnosticResults(req, res) {
  const patientUserId = req.patientUserId;
  if (!patientUserId || !mongoose.Types.ObjectId.isValid(String(patientUserId))) {
    return res.status(400).json({ message: "Valid patientUserId is required" });
  }

  const [labs, radiology] = await Promise.all([
    LabRequest.find({ patientUserId, status: "Completed" }).sort({ completedAt: -1 }).limit(200).lean(),
    RadiologyRequest.find({ patientUserId, status: "Completed" }).sort({ completedAt: -1 }).limit(200).lean(),
  ]);

  const enrichedLabs = await enrichDiagnosticOrders(labs);
  const enrichedRad = await enrichDiagnosticOrders(radiology);

  const mapOrder = (o, kind) => ({
    kind,
    id: String(o._id),
    date: o.completedAt || o.updatedAt,
    clinicName: o.clinicName || "",
    doctorName: o.doctorName || "",
    patient: o.patient || {},
    testOrModality: kind === "lab" ? o.testName : o.studyName,
    testType: kind === "lab" ? o.testType || "" : o.modality || "",
    resultAnalysis: o.resultAnalysis || "",
    attachmentUrl: o.attachment?.fileUrl || "",
    attachmentName: o.attachment?.fileName || "",
    mimeType: o.attachment?.mimeType || "",
    isLocked: o.isLocked === true,
  });

  const combined = [
    ...enrichedLabs.map((l) => mapOrder(l, "lab")),
    ...enrichedRad.map((r) => mapOrder(r, "radiology")),
  ].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  res.json(combined);
}

module.exports = {
  listPendingLab,
  listPendingRadiology,
  listCompletedLab,
  listCompletedRadiology,
  getLabOrder,
  getRadiologyOrder,
  submitLab,
  submitRadiology,
  doctorCompletedLab,
  doctorCompletedRadiology,
  doctorUnreadCounts,
  markLabRead,
  markRadiologyRead,
  patientDiagnosticResults,
};
