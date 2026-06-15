/**
 * Context-lock enforcement for Rafeeq medication follow-up chat.
 */

/** Tokens used to detect mentions of a different medication */
const KNOWN_DRUG_TOKENS = [
  "metformin", "glucophage", "amoxicillin", "amoxil", "paracetamol", "acetaminophen",
  "panadol", "tylenol", "ibuprofen", "advil", "brufen", "nurofen", "omeprazole",
  "prilosec", "atorvastatin", "lipitor", "lisinopril", "zestril", "amlodipine",
  "norvasc", "metoprolol", "lopressor", "betaloc", "azithromycin", "zithromax",
];

function normalize(s) {
  return String(s || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

const VIOLATION_PATTERNS = [
  /\b(diagnos(e|is|ing)|do i have|could i have|might i have|what disease|what condition|symptoms of(?! this))\b/i,
  /\b(switch to|change to|replace with|instead of|take instead|rather than|stop taking and)\b/i,
  /\b(prescribe me|start taking|new medication|different drug|another medicine|recommend a drug)\b/i,
  /\b(should i take|can i take)\s+(a |the )?(new|different|another|other)\b/i,
  /\b(covid|diabetes|hypertension|cancer|flu|pneumonia|asthma|depression)\b/i,
];

const ALLOWED_FOLLOWUP_TOPICS = [
  "side effect",
  "adverse",
  "storage",
  "store",
  "fridge",
  "interact",
  "interaction",
  "alcohol",
  "food",
  "timing",
  "when to take",
  "when should i take",
  "how to take",
  "food interaction",
  "food interactions",
  "with meal",
  "empty stomach",
  "missed dose",
  "forgot dose",
  "warning",
  "caution",
  "expire",
  "pregnancy",
  "breastfeed",
  "ingredient",
  "generic",
  "brand",
  "overdose",
  "allergy",
  "rash",
  "nausea",
  "drowsy",
  "sleepy",
];

function medicationTokens(name) {
  const n = normalize(name);
  const parts = n.split(/\s+/).filter((w) => w.length > 2);
  return [n, ...parts];
}

function mentionsCurrentMedication(message, currentMedication) {
  const q = normalize(message);
  const tokens = medicationTokens(currentMedication);
  return tokens.some((t) => t.length > 2 && q.includes(t));
}

function mentionsOtherDrug(message, currentMedication) {
  const q = normalize(message);
  const currentTokens = medicationTokens(currentMedication);
  for (const token of KNOWN_DRUG_TOKENS) {
    const nt = normalize(token);
    if (nt.length < 4) continue;
    if (!q.includes(nt)) continue;
    const matchesCurrent = currentTokens.some(
      (ct) => ct.includes(nt) || nt.includes(ct)
    );
    if (!matchesCurrent) return true;
  }
  return false;
}

function matchesViolationPattern(message) {
  return VIOLATION_PATTERNS.some((re) => re.test(message));
}

function isAllowedFollowUpTopic(message) {
  const q = normalize(message);
  return ALLOWED_FOLLOWUP_TOPICS.some((topic) => q.includes(topic));
}

/**
 * @param {string} userMessage
 * @param {string} currentMedication
 * @returns {boolean}
 */
function isContextViolation(userMessage, currentMedication) {
  const msg = String(userMessage || "").trim();
  const med = String(currentMedication || "").trim();
  if (!msg || !med) return false;

  if (matchesViolationPattern(msg)) return true;
  if (mentionsOtherDrug(msg, med)) return true;

  return false;
}

/**
 * Follow-up must relate to the locked medication (name mention or on-topic keyword).
 * @param {string} userMessage
 * @param {string} currentMedication
 * @returns {boolean}
 */
function isRelevantToLockedMedication(userMessage, currentMedication) {
  const msg = String(userMessage || "").trim();
  const med = String(currentMedication || "").trim();
  if (!msg || !med) return false;

  if (mentionsCurrentMedication(msg, med)) return true;
  if (isAllowedFollowUpTopic(msg)) return true;

  const q = normalize(msg);
  const shortFollowUps = [
    "is it safe",
    "any risks",
    "what are the risks",
    "tell me more",
    "explain",
    "more info",
    "more information",
    "how does it work",
    "what does it do",
    "can i drink",
    "with water",
  ];
  if (shortFollowUps.some((p) => q.includes(p))) return true;

  return false;
}

function contextBreakRejection(currentMedication) {
  const med = String(currentMedication || "").trim() || "your selected medication";
  return `I am only able to discuss information regarding ${med}. For diagnostics or other medical questions, please consult your doctor.`;
}

function buildContextLockedSystemPrompt(currentMedication) {
  const med = String(currentMedication || "").trim();
  const { buildPharmacistSystemPrompt } = require("./medicationLlm");
  return buildPharmacistSystemPrompt(med, { contextLocked: true, followUp: true });
}

module.exports = {
  isContextViolation,
  isRelevantToLockedMedication,
  contextBreakRejection,
  buildContextLockedSystemPrompt,
  mentionsCurrentMedication,
};
