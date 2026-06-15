/**
 * OpenFDA drug label lookup — dynamic [MEDICATION_NAME] injection only.
 * No hardcoded section placeholder text; raw FDA fields or not found.
 * @see https://open.fda.gov/apis/drug/label/
 */

const OPENFDA_BASE = "https://api.fda.gov/drug/label.json";
const DEFAULT_TIMEOUT_MS = Number(process.env.OPENFDA_TIMEOUT_MS) || 10000;

function escapeFdaTerm(term) {
  return String(term || "")
    .trim()
    .replace(/"/g, '\\"');
}

/** Validates Flutter selectedMedicationName and builds dynamic search terms. */
function resolveMedicationQuery(selectedMedicationName) {
  const raw = String(selectedMedicationName ?? "").trim();
  if (!raw) {
    return {
      valid: false,
      raw: "",
      normalized: "",
      searchToken: "",
      error: "Medication name is required.",
    };
  }
  const normalized = normalizeDrugSearchTerm(raw);
  const searchToken = primarySearchToken(raw);
  if (!normalized && !searchToken) {
    return {
      valid: false,
      raw,
      normalized: "",
      searchToken: "",
      error: "Medication name is empty after normalization.",
    };
  }
  return {
    valid: true,
    raw,
    normalized: normalized || searchToken,
    searchToken: searchToken || normalized,
    error: null,
  };
}

/** Strip dose/strength suffixes so "Metformin 500mg" → "Metformin" */
function normalizeDrugSearchTerm(medicationName) {
  return String(medicationName || "")
    .trim()
    .replace(/\b\d+(\.\d+)?\s*(mg|mcg|g|ml|iu|%|units?)\b/gi, "")
    .replace(/\s+/g, " ")
    .trim();
}

function primarySearchToken(medicationName) {
  const cleaned = normalizeDrugSearchTerm(medicationName);
  const first = cleaned.split(/\s+/).filter(Boolean)[0] || cleaned;
  return first.trim();
}

function extractRawField(field) {
  if (!field) return null;
  if (Array.isArray(field)) {
    const parts = field
      .filter((x) => typeof x === "string" && x.trim())
      .map((x) => x.trim());
    return parts.length ? parts.join("\n\n") : null;
  }
  if (typeof field === "string" && field.trim()) return field.trim();
  return null;
}

function trimSection(text, maxLen = 2400) {
  if (!text) return null;
  const clean = text.replace(/\s+/g, " ").trim();
  if (clean.length <= maxLen) return clean;
  const cut = clean.slice(0, maxLen);
  const lastPeriod = cut.lastIndexOf(". ");
  if (lastPeriod > maxLen * 0.55) return `${cut.slice(0, lastPeriod + 1)}…`;
  return `${cut}…`;
}

/** Dynamic OpenFDA URL — [MEDICATION_NAME] injected per request */
function buildSearchUrl(field, medicationTerm, limit = 5) {
  const q = escapeFdaTerm(medicationTerm);
  const params = new URLSearchParams({
    search: `${field}:"${q}"`,
    limit: String(limit),
  });
  return `${OPENFDA_BASE}?${params.toString()}`;
}

function scoreLabelMatch(label, searchToken) {
  const token = searchToken.toLowerCase();
  const generic = (label.openfda?.generic_name || []).map((n) => String(n).toLowerCase());
  const brand = (label.openfda?.brand_name || []).map((n) => String(n).toLowerCase());
  const substance = (label.openfda?.substance_name || []).map((n) => String(n).toLowerCase());

  let score = 0;

  for (const name of generic) {
    if (name === token || name.startsWith(`${token} `) || name.startsWith(`${token}/`)) {
      score = Math.max(score, 100);
    } else if (name.includes(token)) {
      score = Math.max(score, 70);
    }
    if (/\band\b|\/|\+/.test(name) && name.includes(token)) {
      score -= 15;
    }
  }

  for (const name of [...brand, ...substance]) {
    if (name.includes(token)) score = Math.max(score, 55);
  }

  return score;
}

function pickBestLabel(results, searchToken) {
  if (!results?.length) return null;
  if (results.length === 1) return results[0];
  const ranked = results
    .map((label) => ({ label, score: scoreLabelMatch(label, searchToken) }))
    .sort((a, b) => b.score - a.score);
  return ranked[0]?.label || results[0];
}

function buildSearchStrategies(query) {
  const { raw, normalized, searchToken } = query;
  const strategies = [
    { field: "openfda.generic_name", term: searchToken },
    { field: "openfda.brand_name", term: searchToken },
    { field: "openfda.substance_name", term: searchToken },
    { field: "openfda.brand_name", term: normalized },
  ];
  if (raw.toLowerCase() !== searchToken.toLowerCase()) {
    strategies.push({ field: "openfda.brand_name", term: raw });
  }
  if (normalized.toLowerCase() !== searchToken.toLowerCase()) {
    strategies.push({ field: "openfda.generic_name", term: normalized });
  }
  return strategies.filter((s, i, arr) => {
    const key = `${s.field}:${s.term.toLowerCase()}`;
    return arr.findIndex((x) => `${x.field}:${x.term.toLowerCase()}` === key) === i;
  });
}

async function fetchLabelJson(url, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { Accept: "application/json" },
    });
    clearTimeout(timer);
    if (res.status === 404) return { status: 404, data: null };
    if (!res.ok) return { status: res.status, data: null };
    const data = await res.json();
    return { status: 200, data };
  } catch (err) {
    clearTimeout(timer);
    const isTimeout = err?.name === "AbortError";
    return { status: isTimeout ? 408 : 0, data: null, error: err?.message };
  }
}

/**
 * @param {ReturnType<typeof resolveMedicationQuery>} query
 * @returns {Promise<{ label: object|null, attemptedUrls: string[] }>}
 */
async function fetchBestLabelRecord(query) {
  const strategies = buildSearchStrategies(query);
  const attemptedUrls = [];
  const token = query.searchToken.toLowerCase();

  for (const { field, term } of strategies) {
    if (!term) continue;
    const url = buildSearchUrl(field, term);
    attemptedUrls.push(url);
    const { status, data } = await fetchLabelJson(url, DEFAULT_TIMEOUT_MS);
    if (status === 404 || status === 408 || status === 0) continue;
    if (status !== 200 || !data?.results?.length) continue;
    const best = pickBestLabel(data.results, token);
    if (best) return { label: best, attemptedUrls };
  }

  return { label: null, attemptedUrls };
}

function resolveDisplayName(query, label) {
  return (
    label.openfda?.brand_name?.[0] ||
    label.openfda?.generic_name?.[0] ||
    query.normalized ||
    query.raw
  );
}

function detectFollowUpIntent(userMessage) {
  const q = String(userMessage || "").toLowerCase();
  if (/side effect|adverse|reaction|risk/.test(q)) return "side_effects";
  if (/when should|when to take|timing|how to take|dose time|schedule/.test(q)) return "timing";
  if (/food interact|drug interact|interact|alcohol|grapefruit|with food/.test(q)) return "interactions";
  if (/dosage|dose|warning|administration/.test(q)) return "dosage";
  if (/use|indication|what is it for|purpose/.test(q)) return "uses";
  return "full";
}

const SECTION_FIELD_MAP = {
  uses: ["indications_and_usage", "purpose", "description"],
  side_effects: ["adverse_reactions", "warnings", "warnings_and_cautions", "boxed_warning"],
  interactions: ["drug_interactions", "ask_doctor_or_pharmacist"],
  timing: ["dosage_and_administration", "dosage_and_administration_table", "how_supplied"],
  dosage: ["dosage_and_administration", "dosage_and_administration_table", "warnings"],
};

function extractSectionFromLabel(label, intent) {
  const keys = SECTION_FIELD_MAP[intent] || [];
  for (const key of keys) {
    const raw = extractRawField(label[key]);
    if (raw) return trimSection(raw);
  }
  return null;
}

function formatFdaAnswer(query, label, intent = "full") {
  const brand = resolveDisplayName(query, label);
  const med = query.normalized;

  if (intent !== "full") {
    const sectionTitle = {
      uses: "Uses & Indications",
      side_effects: "Common Side Effects",
      interactions: "Food / Drug Interactions",
      timing: "When to Take / Administration",
      dosage: "Dosage & Warnings",
    }[intent];

    const body = extractSectionFromLabel(label, intent);
    if (!body) {
      return { answer: null, brandName: brand };
    }

    return {
      answer: [
        `**${brand}** (${med}) — FDA label excerpt`,
        "",
        `**${sectionTitle}**`,
        body,
        "",
        `_Source: U.S. FDA OpenFDA drug label for ${brand}. Educational only — follow your prescriber's instructions._`,
      ].join("\n"),
      brandName: brand,
    };
  }

  const sectionBlocks = [
    { title: "Uses & Indications", body: extractSectionFromLabel(label, "uses") },
    { title: "Common Side Effects", body: extractSectionFromLabel(label, "side_effects") },
    { title: "Food / Drug Interactions", body: extractSectionFromLabel(label, "interactions") },
    { title: "Standard Dosage Warning", body: extractSectionFromLabel(label, "dosage") },
  ].filter((s) => s.body);

  if (!sectionBlocks.length) {
    return { answer: null, brandName: brand };
  }

  const answer = [
    `**${brand}** (${med}) — U.S. FDA drug label data`,
    "",
    ...sectionBlocks.flatMap((s, i) =>
      i === 0 ? [`**${s.title}**`, s.body] : ["", `**${s.title}**`, s.body]
    ),
    "",
    `_Source: OpenFDA public label for ${brand}. Not personalized medical advice._`,
  ].join("\n");

  return { answer, brandName: brand };
}

function notFoundResult(query, attemptedUrls = []) {
  return {
    found: false,
    notFound: true,
    medicationName: query.normalized,
    rawName: query.raw,
    searchedTerms: buildSearchStrategies(query).map((s) => `${s.field}:"${s.term}"`),
    attemptedUrls,
  };
}

/**
 * @param {string} selectedMedicationName — exact value from Flutter currentMedication / medicationName
 */
async function fetchOpenFdaDrugLabel(selectedMedicationName) {
  const query = resolveMedicationQuery(selectedMedicationName);
  if (!query.valid) {
    return { ...notFoundResult(query), error: query.error };
  }

  const { label, attemptedUrls } = await fetchBestLabelRecord(query);
  if (!label) {
    return notFoundResult(query, attemptedUrls);
  }

  const formatted = formatFdaAnswer(query, label, "full");
  if (!formatted.answer) {
    return notFoundResult(query, attemptedUrls);
  }

  return {
    found: true,
    answer: formatted.answer,
    brandName: formatted.brandName,
    source: "openfda",
    confidence: "fda_label",
    matchedRuleId: "openfda",
    medicationName: query.normalized,
    rawName: query.raw,
  };
}

/**
 * @param {string} selectedMedicationName
 * @param {string} userMessage
 */
async function fetchOpenFdaFollowUp(selectedMedicationName, userMessage) {
  const query = resolveMedicationQuery(selectedMedicationName);
  if (!query.valid) {
    return { found: false, error: query.error, intent: detectFollowUpIntent(userMessage) };
  }

  const intent = detectFollowUpIntent(userMessage);
  const { label, attemptedUrls } = await fetchBestLabelRecord(query);
  if (!label) {
    return { ...notFoundResult(query, attemptedUrls), intent };
  }

  const formatted = formatFdaAnswer(query, label, intent);
  if (!formatted.answer) {
    return { ...notFoundResult(query, attemptedUrls), intent };
  }

  return {
    found: true,
    answer: formatted.answer,
    brandName: formatted.brandName,
    source: "openfda",
    confidence: "fda_label_section",
    matchedRuleId: `openfda_${intent}`,
    intent,
    medicationName: query.normalized,
    rawName: query.raw,
  };
}

module.exports = {
  fetchOpenFdaDrugLabel,
  fetchOpenFdaFollowUp,
  fetchBestLabelRecord,
  formatFdaAnswer,
  buildSearchUrl,
  normalizeDrugSearchTerm,
  resolveMedicationQuery,
  detectFollowUpIntent,
};
