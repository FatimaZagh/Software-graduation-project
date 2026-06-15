const mongoose = require("mongoose");
const AppointmentModel = require("../models/appointment");
const Doctor = require("../models/doctor");
const UserModel = require("../models/User");

function normalizeRole(input) {
  const r = String(input || "").trim();
  const map = {
    OrgAdmin: "Organization Admin",
    OrganizationAdmin: "Organization Admin",
    "Organization Admin": "Organization Admin",
  };
  return map[r] || r;
}

function ymdFromDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function rollingWeekRange() {
  const end = new Date();
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - 6);
  return { startYmd: ymdFromDate(start), endYmd: ymdFromDate(end) };
}

function isCancelledByDoctor(appt) {
  return (
    String(appt?.bookingStatus || "") === "cancelled_by_doctor" ||
    String(appt?.status || "") === "cancelled_by_doctor"
  );
}

function computeAlertLevel(rate) {
  if (rate > 30) return "critical_review";
  if (rate > 20) return "alert_admin";
  if (rate >= 15) return "warning_low";
  return "normal";
}

/** Human-readable English label for alertLevel (localization-friendly). */
function alertLevelLabel(level) {
  const labels = {
    normal: "Normal",
    warning_low: "Low warning",
    alert_admin: "Admin alert",
    critical_review: "Critical review",
  };
  return labels[level] || "Normal";
}

function buildAdminAlertMessage(doctorName, rate) {
  const name = String(doctorName || "Unknown").trim() || "Unknown";
  return `Admin Alert: Doctor ${name} has exceeded the permitted cancellation rate at ${rate}%`;
}

function topReasonFromCounts(reasonCounts) {
  let top = "";
  let max = 0;
  for (const [reason, count] of Object.entries(reasonCounts)) {
    if (count > max) {
      max = count;
      top = reason;
    }
  }
  return top || "N/A";
}

/**
 * GET /api/admin/doctor-analytics — Organization Admin only.
 * Rolling 7-day cancellation KPIs per doctor.
 */
async function getDoctorAnalytics(req, res, scoped) {
  if (normalizeRole(scoped.user.role) !== "Organization Admin") {
    return res.status(403).json({ message: "Organization Admin access required" });
  }

  const orgId = scoped.orgId;
  const { startYmd, endYmd } = rollingWeekRange();

  const [appts, doctorProfiles] = await Promise.all([
    AppointmentModel.find({
      orgId,
      doctorUserId: { $exists: true, $ne: null },
      date: { $gte: startYmd, $lte: endYmd },
    })
      .select("doctorUserId bookingStatus status cancellationReason date")
      .lean(),
    Doctor.find({ orgId }).select("userId displayName specialty").lean(),
  ]);

  const statsByDoctor = new Map();

  for (const a of appts) {
    const doctorId = String(a.doctorUserId);
    if (!mongoose.Types.ObjectId.isValid(doctorId)) continue;

    if (!statsByDoctor.has(doctorId)) {
      statsByDoctor.set(doctorId, {
        totalAppointmentsCount: 0,
        cancelledByDoctorCount: 0,
        reasonCounts: {},
      });
    }
    const row = statsByDoctor.get(doctorId);
    row.totalAppointmentsCount += 1;

    if (isCancelledByDoctor(a)) {
      row.cancelledByDoctorCount += 1;
      const reason = String(a.cancellationReason || "").trim() || "Other";
      row.reasonCounts[reason] = (row.reasonCounts[reason] || 0) + 1;
    }
  }

  const doctorUserIds = [
    ...new Set(doctorProfiles.map((d) => String(d.userId)).filter((id) => mongoose.Types.ObjectId.isValid(id))),
  ];
  const users = doctorUserIds.length
    ? await UserModel.find({ _id: { $in: doctorUserIds } }).select("name email").lean()
    : [];
  const userMap = Object.fromEntries(users.map((u) => [String(u._id), u]));

  const doctors = [];

  for (const doc of doctorProfiles) {
    const doctorId = String(doc.userId);
    const bucket = statsByDoctor.get(doctorId) || {
      totalAppointmentsCount: 0,
      cancelledByDoctorCount: 0,
      reasonCounts: {},
    };

    const total = bucket.totalAppointmentsCount;
    const cancelled = bucket.cancelledByDoctorCount;
    const rate = total > 0 ? Math.round((cancelled / total) * 1000) / 10 : 0;
    const alertLevel = computeAlertLevel(rate);
    const u = userMap[doctorId];

    const doctorName =
      doc.displayName || u?.name || appts.find((x) => String(x.doctorUserId) === doctorId)?.doctorName || "Unknown";

    doctors.push({
      doctorId,
      doctorName,
      specialty: doc.specialty || "",
      totalAppointmentsCount: total,
      cancelledByDoctorCount: cancelled,
      cancellationRate: rate,
      topCancellationReason: topReasonFromCounts(bucket.reasonCounts),
      cancellationReasonBreakdown: bucket.reasonCounts,
      alertLevel,
      alertLevelLabel: alertLevelLabel(alertLevel),
      ...(alertLevel === "alert_admin" || alertLevel === "critical_review"
        ? { alertMessage: buildAdminAlertMessage(doctorName, rate) }
        : {}),
    });
  }

  doctors.sort((a, b) => b.cancellationRate - a.cancellationRate || b.cancelledByDoctorCount - a.cancelledByDoctorCount);

  const alertDoctors = doctors.filter((d) => d.alertLevel === "alert_admin" || d.alertLevel === "critical_review");

  res.json({
    weekStart: startYmd,
    weekEnd: endYmd,
    doctors,
    alertDoctors,
    generatedAt: new Date().toISOString(),
  });
}

module.exports = {
  getDoctorAnalytics,
  computeAlertLevel,
  alertLevelLabel,
  buildAdminAlertMessage,
  rollingWeekRange,
};
