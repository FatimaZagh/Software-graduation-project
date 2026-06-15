/** 30-minute slot generation from doctor workSchedule + booked times. */

const { JS_TO_DAY, DAY_TO_JS, dayNameMatchesJsDay, normalizeDayNameToShortKey } = require("./dynamicSchedule");
const { activeSlotOccupancyQuery } = require("./appointmentStatus");

function hhmmToMinutes(hhmm) {
  const m = String(hhmm || "").trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  const hh = parseInt(m[1], 10);
  const mm = parseInt(m[2], 10);
  if (Number.isNaN(hh) || Number.isNaN(mm)) return null;
  return hh * 60 + mm;
}

function minutesToHhmm(mins) {
  const hh = Math.floor(mins / 60);
  const mm = mins % 60;
  return `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
}

function normalizeSlotTime(t) {
  const m = String(t || "").trim().match(/^(\d{1,2}):(\d{2})/);
  if (!m) return "";
  return `${String(parseInt(m[1], 10)).padStart(2, "0")}:${m[2]}`;
}

function slotRangesForDay(workDay) {
  const start =
    hhmmToMinutes(workDay?.startTime ?? workDay?.start) ?? 9 * 60;
  const end = hhmmToMinutes(workDay?.endTime ?? workDay?.end) ?? 17 * 60;
  const breaks = Array.isArray(workDay?.breaks) ? workDay.breaks : [];
  const breakRanges = breaks
    .map((b) => [hhmmToMinutes(b?.start), hhmmToMinutes(b?.end)])
    .filter(([a, b]) => a != null && b != null && b > a)
    .sort((x, y) => x[0] - y[0]);
  return { start, end, breakRanges };
}

function computeSlots(workDay, bookedTimes, stepMinutes = 30) {
  return computeSlotObjects(workDay, bookedTimes, stepMinutes)
    .filter((s) => !s.isBooked)
    .map((s) => s.value);
}

/** Full day grid: every 30-min interval with booking state for the UI. */
function computeSlotObjects(workDay, bookedTimes, stepMinutes = 30) {
  if (!workDay) return [];
  const { start, end, breakRanges } = slotRangesForDay(workDay);
  const booked = bookedTimes instanceof Set ? bookedTimes : new Set(bookedTimes || []);
  const out = [];
  for (let t = start; t + stepMinutes <= end; t += stepMinutes) {
    const inBreak = breakRanges.some(([a, b]) => t >= a && t < b);
    if (inBreak) continue;
    const hhmm = minutesToHhmm(t);
    const label = hhmmToDisplayLabel(hhmm);
    out.push({
      time: label,
      value: hhmm,
      isBooked: booked.has(hhmm),
    });
  }
  return out;
}

/** Calendar day for YYYY-MM-DD (noon UTC avoids TZ shifting the weekday). */
function resolveDayOfWeek(dateYmd) {
  const jsDay = new Date(`${dateYmd}T12:00:00`).getDay();
  return { jsDay, dayKey: JS_TO_DAY[jsDay] || "" };
}

/** Match workSchedule row by dayOfWeek index or day label (Fri, Friday, …). */
function findWorkDayForDate(schedule, dateYmd) {
  if (!Array.isArray(schedule) || !dateYmd) return null;
  const { jsDay, dayKey } = resolveDayOfWeek(dateYmd);

  const byIndex = schedule.find((w) => Number(w.dayOfWeek) === jsDay);
  if (byIndex) return byIndex;

  const byName = schedule.find((w) => {
    const label = String(w.dayName || w.day || "").trim();
    return label && dayNameMatchesJsDay(label, jsDay);
  });
  if (byName) return byName;

  const keyLower = String(dayKey).toLowerCase();
  return (
    schedule.find((w) => {
      const label = String(w.dayName || w.day || w.dayKey || "").trim();
      if (!label) return false;
      const shortKey = normalizeDayNameToShortKey(label);
      if (shortKey && DAY_TO_JS[shortKey] === jsDay) return true;
      const nLow = label.toLowerCase();
      return nLow === keyLower || nLow.startsWith(keyLower) || keyLower.startsWith(nLow.slice(0, 3));
    }) || null
  );
}

function hhmmToDisplayLabel(hhmm) {
  const mins = hhmmToMinutes(hhmm);
  if (mins == null) return String(hhmm || "").trim();
  const h24 = Math.floor(mins / 60);
  const mm = mins % 60;
  const period = h24 >= 12 ? "PM" : "AM";
  let h12 = h24 % 12;
  if (h12 === 0) h12 = 12;
  return `${h12}:${String(mm).padStart(2, "0")} ${period}`;
}

/** Steps A–E: schedule → 30-min slots → subtract booked → labels. */
async function generateAvailableSlotsForDoctor(
  AppointmentModel,
  { orgId, doctorUserId, dateYmd, workSchedule, bookingBlocklist, isDateBlockedFn }
) {
  const date = String(dateYmd || "").trim();
  if (!date) return { date: "", dayOfWeek: "", availableSlots: [], onLeave: false, hasSchedule: false };

  const { dayKey } = resolveDayOfWeek(date);
  if (typeof isDateBlockedFn === "function" && isDateBlockedFn(bookingBlocklist, date)) {
    return { date, dayOfWeek: dayKey, availableSlots: [], onLeave: true, hasSchedule: false };
  }

  const schedule = Array.isArray(workSchedule) ? workSchedule : [];
  const workDay = findWorkDayForDate(schedule, date);
  if (!workDay) {
    return { date, dayOfWeek: dayKey, availableSlots: [], onLeave: false, hasSchedule: false };
  }

  const booked = await loadBookedSlots(AppointmentModel, { orgId, doctorUserId, date });
  const slotObjects = computeSlotObjects(workDay, booked);
  return {
    date,
    dayOfWeek: dayKey,
    availableSlots: slotObjects,
    onLeave: false,
    hasSchedule: true,
  };
}

async function loadBookedSlots(AppointmentModel, { orgId, doctorUserId, date }) {
  const slotQuery = { doctorUserId, date: String(date || "").trim() };
  if (orgId) {
    slotQuery.$or = [{ orgId }, { orgId: null }, { orgId: { $exists: false } }];
  }
  const appts = await AppointmentModel.find(activeSlotOccupancyQuery(slotQuery))
    .select("time bookingStatus")
    .lean();
  const booked = new Set();
  for (const a of appts) {
    const slot = normalizeSlotTime(a.time);
    if (slot) booked.add(slot);
  }
  return booked;
}

module.exports = {
  hhmmToMinutes,
  minutesToHhmm,
  normalizeSlotTime,
  slotRangesForDay,
  computeSlots,
  computeSlotObjects,
  resolveDayOfWeek,
  findWorkDayForDate,
  hhmmToDisplayLabel,
  generateAvailableSlotsForDoctor,
  loadBookedSlots,
  normalizeDayNameToShortKey,
  dayNameMatchesJsDay,
};
