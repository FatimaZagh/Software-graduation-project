/** Mon–Sun map ↔ Doctor.workSchedule array (dayOfWeek matches JS Date.getDay()). */

const DAY_KEYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const DAY_TO_JS = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
const JS_TO_DAY = { 0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat" };
const DAY_FULL = {
  Mon: "Monday",
  Tue: "Tuesday",
  Wed: "Wednesday",
  Thu: "Thursday",
  Fri: "Friday",
  Sat: "Saturday",
  Sun: "Sunday",
};

function defaultDynamicSchedule() {
  const map = {};
  for (const k of DAY_KEYS) {
    map[k] = { enabled: false, start: "09:00", end: "17:00" };
  }
  for (const k of ["Mon", "Tue", "Wed", "Thu", "Fri"]) {
    map[k] = { enabled: true, start: "09:00", end: "17:00" };
  }
  return map;
}

function isDynamicScheduleMap(obj) {
  if (!obj || typeof obj !== "object" || Array.isArray(obj)) return false;
  return DAY_KEYS.some((k) => Object.prototype.hasOwnProperty.call(obj, k));
}

function dynamicScheduleToWorkSchedule(map) {
  if (!isDynamicScheduleMap(map)) return [];
  const out = [];
  for (const key of DAY_KEYS) {
    const val = map[key];
    if (!val || !val.enabled) continue;
    const dow = DAY_TO_JS[key];
    if (dow === undefined) continue;
    out.push({
      dayOfWeek: dow,
      dayName: DAY_FULL[key] || key,
      startTime: String(val.start || val.startTime || "09:00"),
      endTime: String(val.end || val.endTime || "17:00"),
      breaks: Array.isArray(val.breaks) ? val.breaks : [],
    });
  }
  return out.sort((a, b) => a.dayOfWeek - b.dayOfWeek);
}

function workScheduleToDynamicSchedule(schedule) {
  const map = defaultDynamicSchedule();
  if (!Array.isArray(schedule)) return map;
  for (const d of schedule) {
    const dow = Number(d.dayOfWeek);
    const key = JS_TO_DAY[dow];
    if (!key) continue;
    map[key] = {
      enabled: true,
      start: String(d.startTime || d.start || "09:00"),
      end: String(d.endTime || d.end || "17:00"),
    };
  }
  return map;
}

/** Accept proposedSchedule object map, array, or { dynamicSchedule, workSchedule }. */
function resolveSchedulePayload(body) {
  const ps = body?.proposedSchedule;
  const rh = body?.requestedHours;

  if (isDynamicScheduleMap(ps)) {
    return { dynamicSchedule: ps, workSchedule: dynamicScheduleToWorkSchedule(ps) };
  }
  if (isDynamicScheduleMap(rh)) {
    return { dynamicSchedule: rh, workSchedule: dynamicScheduleToWorkSchedule(rh) };
  }
  if (ps && typeof ps === "object" && !Array.isArray(ps)) {
    if (isDynamicScheduleMap(ps.dynamicSchedule)) {
      return {
        dynamicSchedule: ps.dynamicSchedule,
        workSchedule: dynamicScheduleToWorkSchedule(ps.dynamicSchedule),
      };
    }
    if (Array.isArray(ps.workSchedule)) {
      const ws = normalizeWorkScheduleArray(ps.workSchedule);
      return { dynamicSchedule: workScheduleToDynamicSchedule(ws), workSchedule: ws };
    }
  }

  const raw = Array.isArray(ps) ? ps : Array.isArray(rh) ? rh : Array.isArray(body?.workSchedule) ? body.workSchedule : [];
  const workSchedule = normalizeWorkScheduleArray(raw);
  return { dynamicSchedule: workScheduleToDynamicSchedule(workSchedule), workSchedule };
}

function normalizeWorkScheduleArray(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((d) => ({
    dayOfWeek: Number(d.dayOfWeek ?? 0),
    dayName: d.dayName != null ? String(d.dayName) : "",
    startTime: String(d.startTime || d.start || "09:00"),
    endTime: String(d.endTime || d.end || "17:00"),
    breaks: Array.isArray(d.breaks) ? d.breaks : [],
  }));
}

function deriveWorkingHours(schedule) {
  if (!schedule.length) return { start: "09:00", end: "17:00" };
  const starts = schedule.map((d) => d.startTime).filter(Boolean);
  const ends = schedule.map((d) => d.endTime).filter(Boolean);
  starts.sort();
  ends.sort();
  return { start: starts[0] || "09:00", end: ends[ends.length - 1] || "17:00" };
}

/** "Friday", "fri", "Fri" → short key "Fri"; unknown → "". */
function normalizeDayNameToShortKey(name) {
  const raw = String(name || "").trim();
  if (!raw) return "";
  if (DAY_KEYS.includes(raw)) return raw;
  const cap3 =
    raw.length >= 3
      ? raw.charAt(0).toUpperCase() + raw.slice(1, 3).toLowerCase()
      : "";
  if (DAY_KEYS.includes(cap3)) return cap3;
  const low = raw.toLowerCase();
  for (const key of DAY_KEYS) {
    if (key.toLowerCase() === low) return key;
    if ((DAY_FULL[key] || "").toLowerCase() === low) return key;
    if (low.startsWith(key.toLowerCase()) || key.toLowerCase().startsWith(low.slice(0, 3))) {
      return key;
    }
  }
  const hit = DAY_KEYS.find((k) => low.startsWith(k.toLowerCase()) || (DAY_FULL[k] || "").toLowerCase().startsWith(low));
  return hit || "";
}

/** True when a schedule day label refers to the same weekday as jsDay (0=Sun … 6=Sat). */
function dayNameMatchesJsDay(name, jsDay) {
  const key = normalizeDayNameToShortKey(name);
  if (!key) return false;
  return DAY_TO_JS[key] === jsDay;
}

function isDateBlocked(blocklist, ymd) {
  if (!ymd || !Array.isArray(blocklist)) return false;
  return blocklist.some((b) => {
    const from = String(b.fromDate || "").trim();
    const to = String(b.toDate || "").trim();
    return from && to && ymd >= from && ymd <= to;
  });
}

/** Build dynamicSchedule + workSchedule from doctor registration payload. */
function buildScheduleFromRegistration(body = {}) {
  if (body.dynamicSchedule && isDynamicScheduleMap(body.dynamicSchedule)) {
    return resolveSchedulePayload(body);
  }
  if (body.proposedSchedule && isDynamicScheduleMap(body.proposedSchedule)) {
    return resolveSchedulePayload({ proposedSchedule: body.proposedSchedule });
  }
  if (Array.isArray(body.workSchedule) && body.workSchedule.length) {
    const workSchedule = normalizeWorkScheduleArray(body.workSchedule);
    return {
      dynamicSchedule: workScheduleToDynamicSchedule(workSchedule),
      workSchedule,
    };
  }

  const workingDays = Array.isArray(body.workingDays)
    ? body.workingDays
    : typeof body.workingDays === "string"
      ? body.workingDays.split(",").map((x) => x.trim()).filter(Boolean)
      : [];
  const hours =
    body.workingHours && typeof body.workingHours === "object"
      ? body.workingHours
      : { start: body.shiftStart || "09:00", end: body.shiftEnd || "17:00" };
  const start = String(hours.start || hours.startTime || "09:00");
  const end = String(hours.end || hours.endTime || "17:00");

  const map = defaultDynamicSchedule();
  for (const key of DAY_KEYS) {
    map[key] = { enabled: false, start, end };
  }
  for (const dayName of workingDays) {
    const key = normalizeDayNameToShortKey(dayName);
    if (key) map[key] = { enabled: true, start, end };
  }

  const workSchedule = dynamicScheduleToWorkSchedule(map);
  return { dynamicSchedule: map, workSchedule };
}

/** Ensure profile API returns schedule fields Flutter expects. */
function enrichDoctorProfileResponse(doc) {
  if (!doc || typeof doc !== "object") return doc;
  const row = { ...doc };
  let dynamicSchedule = row.dynamicSchedule;
  let workSchedule = Array.isArray(row.workSchedule) ? row.workSchedule : [];

  if (isDynamicScheduleMap(dynamicSchedule) && !workSchedule.length) {
    workSchedule = dynamicScheduleToWorkSchedule(dynamicSchedule);
  } else if (!isDynamicScheduleMap(dynamicSchedule) && workSchedule.length) {
    dynamicSchedule = workScheduleToDynamicSchedule(workSchedule);
  } else if (!isDynamicScheduleMap(dynamicSchedule)) {
    const built = buildScheduleFromRegistration({
      workingDays: row.workingDays,
      workingHours: row.workingHours,
    });
    dynamicSchedule = built.dynamicSchedule;
    workSchedule = built.workSchedule;
  }

  return {
    ...row,
    dynamicSchedule,
    workSchedule,
    workingHours: row.workingHours || deriveWorkingHours(workSchedule),
  };
}

function enrichScheduleRequestForAdmin(row) {
  let map = row?.dynamicSchedule;
  if (!isDynamicScheduleMap(map)) {
    const arr =
      Array.isArray(row?.proposedSchedule) && row.proposedSchedule.length
        ? row.proposedSchedule
        : Array.isArray(row?.requestedHours)
          ? row.requestedHours
          : [];
    map = workScheduleToDynamicSchedule(arr);
  }
  const scheduleBreakdown = [];
  for (const key of DAY_KEYS) {
    const v = map[key] || {};
    scheduleBreakdown.push({
      dayKey: key,
      dayLabel: DAY_FULL[key] || key,
      enabled: Boolean(v.enabled),
      start: String(v.start || v.startTime || "09:00"),
      end: String(v.end || v.endTime || "17:00"),
    });
  }
  const activeLines = scheduleBreakdown
    .filter((d) => d.enabled)
    .map((d) => `${d.dayKey}: ${d.start} - ${d.end}`);

  return {
    ...row,
    dynamicSchedule: map,
    proposedScheduleMap: map,
    proposedSchedule: row?.proposedSchedule ?? [],
    requestedHours: row?.requestedHours ?? [],
    scheduleBreakdown,
    scheduleSummary: activeLines.join(", "),
    activeDayCount: activeLines.length,
  };
}

module.exports = {
  DAY_KEYS,
  DAY_TO_JS,
  JS_TO_DAY,
  DAY_FULL,
  normalizeDayNameToShortKey,
  dayNameMatchesJsDay,
  defaultDynamicSchedule,
  isDynamicScheduleMap,
  dynamicScheduleToWorkSchedule,
  workScheduleToDynamicSchedule,
  resolveSchedulePayload,
  deriveWorkingHours,
  isDateBlocked,
  enrichScheduleRequestForAdmin,
  buildScheduleFromRegistration,
  enrichDoctorProfileResponse,
};
