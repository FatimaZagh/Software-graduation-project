/** Shared appointment lifecycle helpers for booking & slot occupancy. */

const TERMINAL_STATUSES = [
  "Completed",
  "Cancelled",
  "Terminated",
  "cancelled_by_doctor",
  "cancelled_by_patient",
];

const DOCTOR_CANCEL_REASONS = [
  "Emergency",
  "Sick Leave",
  "Surgery",
  "Equipment Issue",
  "Other",
];

/** Mongo filter: appointments that still hold a calendar slot. */
function activeSlotOccupancyQuery(extra = {}) {
  return {
    ...extra,
    bookingStatus: {
      $nin: [
        "Rejected",
        "reschedule_requested",
        "cancelled_by_doctor",
        "cancelled_by_patient",
      ],
    },
    status: { $nin: TERMINAL_STATUSES },
  };
}

/** Primary (non force-accepted) holder — max one per slot for patient self-booking. */
function primarySlotOccupancyQuery(extra = {}) {
  return {
    ...activeSlotOccupancyQuery(extra),
    isForceAccepted: { $ne: true },
  };
}

function isPatientBookedActive(appt) {
  const s = String(appt?.status || "");
  if (TERMINAL_STATUSES.includes(s)) return false;
  if (s === "cancelled_by_doctor") return false;
  return s === "booked" || s === "Waiting" || s === "In Progress";
}

function isCancelledByDoctor(appt) {
  return String(appt?.status || "") === "cancelled_by_doctor";
}

function isAppointmentCancelled(appt) {
  const s = String(appt?.status || "");
  const b = String(appt?.bookingStatus || "");
  return (
    s === "cancelled_by_doctor" ||
    s === "cancelled_by_patient" ||
    b === "cancelled_by_doctor" ||
    b === "cancelled_by_patient" ||
    s === "Cancelled"
  );
}

/** Active patient bookings (status booked / in-progress pipeline). */
function patientActiveBookingQuery(extra = {}) {
  return activeSlotOccupancyQuery({
    ...extra,
    status: { $in: ["booked", "Waiting", "In Progress"] },
  });
}

module.exports = {
  TERMINAL_STATUSES,
  DOCTOR_CANCEL_REASONS,
  activeSlotOccupancyQuery,
  primarySlotOccupancyQuery,
  patientActiveBookingQuery,
  isPatientBookedActive,
  isCancelledByDoctor,
  isAppointmentCancelled,
};
