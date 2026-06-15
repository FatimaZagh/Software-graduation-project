/**
 * Facility (Organization) lifecycle statuses.
 * - pending: awaiting Super Admin review
 * - active: live tenant (set by Super Admin approval)
 * - approved: legacy alias treated as active
 * - rejected: Super Admin declined registration
 * - suspended: temporarily disabled (legacy)
 */
const FACILITY_STATUS = Object.freeze({
  PENDING: "pending",
  APPROVED: "approved",
  REJECTED: "rejected",
  ACTIVE: "active",
  SUSPENDED: "suspended",
});

const APPROVED_STATUSES = [FACILITY_STATUS.ACTIVE, FACILITY_STATUS.APPROVED];

const LOGIN_BLOCKED_STATUSES = [
  FACILITY_STATUS.PENDING,
  FACILITY_STATUS.REJECTED,
  FACILITY_STATUS.SUSPENDED,
];

function normalizeFacilityStatus(status) {
  return String(status || "").trim().toLowerCase();
}

/** True when the facility may operate and appear on public discovery endpoints. */
function isOrganizationApproved(status) {
  return APPROVED_STATUSES.includes(normalizeFacilityStatus(status));
}

/** True when pharmacy / org-admin login must be blocked due to facility review state. */
function isOrganizationLoginBlocked(status) {
  return LOGIN_BLOCKED_STATUSES.includes(normalizeFacilityStatus(status));
}

function approvedOrganizationQuery() {
  return { status: { $in: APPROVED_STATUSES } };
}

/** Public discovery (Our Facilities): live tenants only. */
function activeOrganizationQuery() {
  return { status: FACILITY_STATUS.ACTIVE };
}

function pendingOrganizationQuery() {
  return { status: FACILITY_STATUS.PENDING };
}

function mapStatusFilterForQuery(raw) {
  const s = normalizeFacilityStatus(raw);
  if (!s || s === "all") return {};
  if (s === "approved" || s === "active") return approvedOrganizationQuery();
  if (s === "pending") return pendingOrganizationQuery();
  if (s === "rejected") return { status: FACILITY_STATUS.REJECTED };
  return { status: raw };
}

module.exports = {
  FACILITY_STATUS,
  APPROVED_STATUSES,
  LOGIN_BLOCKED_STATUSES,
  normalizeFacilityStatus,
  isOrganizationApproved,
  isOrganizationLoginBlocked,
  approvedOrganizationQuery,
  activeOrganizationQuery,
  pendingOrganizationQuery,
  mapStatusFilterForQuery,
};
