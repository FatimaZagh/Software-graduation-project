/**
 * Rafeeq Medication Assistant
 * Pipeline: OpenFDA label → LLM (OpenAI/Gemini) → rule-based structured fallback.
 */

const {
  fetchOpenFdaDrugLabel,
  fetchOpenFdaFollowUp,
  resolveMedicationQuery,
} = require("./openFdaDrug");
const { generateMedicationLlmAnswer } = require("./medicationLlm");
const {
  isContextViolation,
  isRelevantToLockedMedication,
  contextBreakRejection,
} = require("./medicationContextLock");

const RULES = [
  {
    id: "missed_dose",
    keywords: ["missed dose", "forgot dose", "نسيت الجرعة", "فاتتني"],
    response:
      "If you missed a dose: take it as soon as you remember unless it is almost time for the next dose. Do not double doses. Confirm with your prescriber for insulin, blood thinners, or antibiotics.",
  },
  {
    id: "storage",
    keywords: ["store", "fridge", "temperature", "تخزين", "ثلاجة"],
    response:
      "Most tablets/capsules should be stored cool and dry away from sunlight. Some liquids must be refrigerated — always read the pharmacy label on your box.",
  },
  {
    id: "side_effects",
    keywords: ["side effect", "adverse", "آثار جانبية", "أعراض"],
    response:
      "Side effects vary by drug class. Mild nausea or drowsiness can occur early. Stop and seek urgent care for rash with fever, swelling of lips/tongue, or trouble breathing (possible allergy).",
  },
  {
    id: "interaction",
    keywords: ["interaction", "alcohol", "grapefruit", "تداخل", "كحول"],
    response:
      "Drug interactions depend on your full medication list and conditions. Avoid alcohol with sedatives and many pain medicines. Grapefruit affects some statins and blood pressure drugs — ask your pharmacist.",
  },
  {
    id: "paracetamol",
    keywords: ["paracetamol", "acetaminophen", "panadol", "باراسيتامول", "بنادول"],
    response:
      "Paracetamol (acetaminophen) is used for pain/fever. Typical adult max is 4 g/day from ALL sources — do not exceed. Avoid if severe liver disease unless prescribed.",
  },
  {
    id: "ibuprofen",
    keywords: ["ibuprofen", "advil", "brufen", "ايبوبروفين"],
    response:
      "Ibuprofen is an NSAID for pain/inflammation. Take with food. Avoid if you have kidney disease, stomach ulcers, or late pregnancy unless your doctor approves.",
  },
  {
    id: "antibiotic_course",
    keywords: ["antibiotic", "مضاد حيوي", "course"],
    response:
      "Finish the antibiotic course as prescribed even if you feel better, unless your doctor tells you to stop. Never share antibiotics or use leftovers for a new illness.",
  },
];

const DRUG_PROFILES = [
  {
    tokens: ["metformin", "glucophage", "ميتفورمين"],
    uses: "Type 2 diabetes: lowers blood sugar by reducing liver glucose production and improving insulin sensitivity. Sometimes used for PCOS per clinician guidance.",
    sideEffects: "Nausea, diarrhea, stomach upset (often improve over weeks). Rare: lactic acidosis — seek urgent care for severe weakness, rapid breathing, unusual muscle pain.",
    interactions: "Avoid excessive alcohol (increases lactic acidosis risk). Contrast dye for scans may require temporary hold — follow hospital instructions. Some diuretics and heart drugs need monitoring.",
    dosageWarning: "Take exactly as prescribed with meals unless told otherwise. Do not double doses. Kidney function affects safety — your doctor sets the dose.",
  },
  {
    tokens: ["amoxicillin", "amoxil", "أموكسيسيلين"],
    uses: "Antibiotic for bacterial infections such as ear/sinus/throat infections, some skin and urinary infections, and H. pylori combinations when prescribed.",
    sideEffects: "Diarrhea, nausea, rash. Stop and seek care for hives, facial swelling, or trouble breathing (allergic reaction).",
    interactions: "May reduce effectiveness of oral contraceptives in some patients — use backup if advised. Probenecid can raise amoxicillin levels. Tell your doctor about all antibiotics/allergy history.",
    dosageWarning: "Complete the full course even if you feel better. Dosing depends on infection type and kidney function — never share leftover antibiotics.",
  },
  {
    tokens: ["paracetamol", "acetaminophen", "panadol", "tylenol"],
    uses: "Pain and fever relief for headaches, mild pain, and colds.",
    sideEffects: "Generally well tolerated; overdose can cause serious liver injury.",
    interactions: "Check all cold/flu products — many contain paracetamol. Avoid alcohol in high doses. Warfarin users: report heavy regular use to your clinician.",
    dosageWarning: "Typical adult maximum 4 g per day from all sources. Lower limits apply for liver disease, alcohol use, or pediatric patients.",
  },
  {
    tokens: ["ibuprofen", "advil", "brufen", "nurofen"],
    uses: "Pain, inflammation, and fever (NSAID).",
    sideEffects: "Stomach upset, heartburn, dizziness. Rare: bleeding ulcers, kidney problems, allergic reactions.",
    interactions: "Avoid with other NSAIDs, aspirin (unless prescribed), blood thinners without medical advice. Caution with ACE inhibitors/diuretics (kidney).",
    dosageWarning: "Take with food. Use lowest effective dose for shortest time. Avoid in late pregnancy unless directed.",
  },
  {
    tokens: ["omeprazole", "prilosec", "أوميبرازول"],
    uses: "Reduces stomach acid for GERD, ulcers, and related conditions.",
    sideEffects: "Headache, nausea, abdominal pain. Long-term use may affect magnesium/B12 absorption — follow up with your doctor.",
    interactions: "Can affect absorption of some drugs (e.g., clopidogrel, certain antifungals). Tell your clinician about all medicines.",
    dosageWarning: "Usually taken before breakfast. Do not stop long-term therapy abruptly without medical advice.",
  },
  {
    tokens: ["atorvastatin", "lipitor", "أتورفاستاتين"],
    uses: "Lowers LDL cholesterol and cardiovascular risk when prescribed.",
    sideEffects: "Muscle aches, digestive upset. Report unexplained severe muscle pain or dark urine.",
    interactions: "Grapefruit juice can raise levels. Caution with some antibiotics and antifungals. Alcohol and liver disease increase monitoring needs.",
    dosageWarning: "Often taken in the evening. Dose is individualized — do not adjust without your prescriber.",
  },
  {
    tokens: ["lisinopril", "zestril", "ليسينوبريل"],
    uses: "ACE inhibitor for high blood pressure, heart failure, and kidney protection in diabetes when indicated.",
    sideEffects: "Dry cough, dizziness, high potassium. Angioedema is rare but urgent — facial/lip swelling.",
    interactions: "Avoid potassium supplements/salt substitutes unless approved. NSAIDs may reduce blood pressure effect. Pregnancy: not safe.",
    dosageWarning: "First doses may cause lightheadedness — rise slowly. Stay hydrated unless restricted for heart/kidney reasons.",
  },
  {
    tokens: ["amlodipine", "norvasc"],
    uses: "Calcium channel blocker for hypertension and angina.",
    sideEffects: "Ankle swelling, flushing, headache, dizziness.",
    interactions: "Grapefruit may increase levels. Caution with other blood pressure medicines.",
    dosageWarning: "Take at the same time daily. Do not stop suddenly without medical guidance.",
  },
  {
    tokens: ["metoprolol", "lopressor", "betaloc"],
    uses: "Beta-blocker for high blood pressure, angina, and heart rhythm issues when prescribed.",
    sideEffects: "Fatigue, cold hands/feet, slow heart rate, dizziness.",
    interactions: "May interact with other heart medicines and some depression drugs. Avoid abrupt stop — rebound heart issues.",
    dosageWarning: "Dose tailored to heart rate and blood pressure — follow prescriber instructions exactly.",
  },
  {
    tokens: ["azithromycin", "zithromax", "زيثروماكس"],
    uses: "Macrolide antibiotic for respiratory and some skin infections.",
    sideEffects: "Diarrhea, nausea, abdominal pain. Seek care for severe allergic reactions or irregular heartbeat symptoms.",
    interactions: "QT-prolonging drugs and some antacids need timing separation — ask pharmacist.",
    dosageWarning: "Often a short course (e.g., Z-pack). Complete as directed even if symptoms improve early.",
  },
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

function formatStructuredProfile(drugLabel, profile) {
  return [
    `**${drugLabel}** — patient-friendly overview`,
    "",
    "**Uses & Indications**",
    profile.uses,
    "",
    "**Common Side Effects**",
    profile.sideEffects,
    "",
    "**Food / Drug Interactions**",
    profile.interactions,
    "",
    "**Standard Dosage Warning**",
    profile.dosageWarning,
    "",
    "_Educational summary only. Follow your prescription label and clinician._",
  ].join("\n");
}

function findDrugProfile(medicationName) {
  const q = normalize(medicationName);
  if (!q) return null;
  for (const p of DRUG_PROFILES) {
    for (const t of p.tokens) {
      const nt = normalize(t);
      if (q.includes(nt) || nt.includes(q)) return p;
    }
  }
  return null;
}

function replyForMedication(medicationName) {
  const name = String(medicationName || "").trim();
  const profile = findDrugProfile(name);
  if (profile) {
    const display =
      profile.tokens.find((t) => normalize(name).includes(normalize(t))) || name;
    return {
      answer: formatStructuredProfile(display.charAt(0).toUpperCase() + display.slice(1), profile),
      matchedRuleId: "drug_profile",
      confidence: "structured_profile",
      source: "drug_profile",
      medicationName: name,
    };
  }
  return null;
}

function buildMedicationPrompt(medicationName) {
  const name = String(medicationName || "").trim();
  return `Provide structured educational information for: ${name}. Sections: Uses & Indications, Common Side Effects, Food/Drug Interactions, Standard Dosage Warning.`;
}

function reply(question) {
  const q = normalize(question);
  if (!q) {
    return {
      answer: "Ask me about storage, missed doses, side effects, or tap a medication name for structured drug info.",
      matchedRuleId: null,
      confidence: "none",
      source: "rules",
    };
  }

  for (const rule of RULES) {
    for (const kw of rule.keywords) {
      if (q.includes(normalize(kw))) {
        return {
          answer: rule.response,
          matchedRuleId: rule.id,
          confidence: "rule_keyword",
          source: "rules",
        };
      }
    }
  }

  for (const p of DRUG_PROFILES) {
    for (const t of p.tokens) {
      if (q.includes(normalize(t))) {
        const out = replyForMedication(t);
        return { ...out, matchedRuleId: "drug_profile", confidence: "rule_drug_in_question" };
      }
    }
  }

  return {
    answer:
      "I could not match that to a safe rule-based answer. For personal dosing, interactions, or new symptoms, please contact your Rafeeq pharmacist or doctor with your full medication list.",
    matchedRuleId: null,
    confidence: "fallback",
    source: "rules",
  };
}

/**
 * Context-locked follow-up — FDA section → LLM (drug-specific) → curated profile only.
 * Never uses generic keyword RULES (those caused identical boilerplate for all drugs).
 */
async function replyContextLockedFollowUp(userMessage, currentMedication) {
  const med = String(currentMedication || "").trim();
  const msg = String(userMessage || "").trim();

  if (isContextViolation(msg, med) || !isRelevantToLockedMedication(msg, med)) {
    return {
      answer: contextBreakRejection(med),
      matchedRuleId: "context_lock",
      confidence: "context_blocked",
      source: "context_lock",
      currentMedication: med,
      contextLocked: true,
      blocked: true,
    };
  }

  const structuredQuestion = `Regarding ${med} only: ${msg}`;

  const fdaFollowUp = await fetchOpenFdaFollowUp(med, msg);
  if (fdaFollowUp.found && fdaFollowUp.answer) {
    return {
      answer: fdaFollowUp.answer,
      matchedRuleId: fdaFollowUp.matchedRuleId,
      confidence: fdaFollowUp.confidence,
      source: "openfda",
      currentMedication: med,
      contextLocked: true,
      blocked: false,
    };
  }

  const query = resolveMedicationQuery(med);

  const llm = await generateMedicationLlmAnswer({
    currentMedication: query.valid ? query.raw : med,
    medicationName: query.valid ? query.normalized : med,
    question: structuredQuestion,
    contextLocked: true,
    followUp: true,
  });
  if (llm) {
    return {
      ...llm,
      currentMedication: med,
      contextLocked: true,
      blocked: false,
      fdaNotFound: Boolean(fdaFollowUp.notFound),
    };
  }

  const profile = replyForMedication(query.valid ? query.normalized : med);
  if (profile) {
    return {
      ...profile,
      currentMedication: med,
      contextLocked: true,
      blocked: false,
      fdaNotFound: Boolean(fdaFollowUp.notFound),
    };
  }

  return {
    answer: `OpenFDA has no U.S. label for **${med}**. The AI assistant did not return a response for: "${msg}". Please consult your pharmacist.`,
    matchedRuleId: "no_source",
    confidence: "no_source",
    source: "none",
    currentMedication: med,
    contextLocked: true,
    blocked: false,
    error: true,
    fdaNotFound: Boolean(fdaFollowUp.notFound),
  };
}

/**
 * Medication tap lookup: OpenFDA → LLM → rules.
 * Follow-up chat: context-locked Q&A when message + currentMedication.
 * @param {{ question?: string, message?: string, medicationName?: string, currentMedication?: string }} input
 */
async function replyAsync(input = {}) {
  const userMessage = String(input.message || input.question || "").trim();
  const medContext = String(
    input.currentMedication || input.medicationName || ""
  ).trim();

  if (userMessage && medContext) {
    return replyContextLockedFollowUp(userMessage, medContext);
  }

  if (medContext) {
    const query = resolveMedicationQuery(medContext);
    if (!query.valid) {
      return {
        answer: query.error,
        source: "validation",
        error: true,
        contextLocked: true,
      };
    }

    const fda = await fetchOpenFdaDrugLabel(medContext);
    if (fda.found && fda.answer) {
      return {
        answer: fda.answer,
        matchedRuleId: fda.matchedRuleId || "openfda",
        confidence: fda.confidence || "fda_label",
        source: "openfda",
        medicationName: query.normalized,
        currentMedication: query.raw,
        contextLocked: true,
      };
    }

    const llm = await generateMedicationLlmAnswer({
      medicationName: query.normalized,
      currentMedication: query.raw,
      question:
        userMessage ||
        `Provide uses, side effects, food interactions, and warnings for ${query.raw}. This drug may be a local/regional brand not listed in U.S. FDA OpenFDA.`,
      contextLocked: true,
    });
    if (llm) {
      return {
        ...llm,
        currentMedication: query.raw,
        contextLocked: true,
        fdaNotFound: true,
      };
    }

    const profile = replyForMedication(query.normalized);
    if (profile) {
      return { ...profile, currentMedication: query.raw, contextLocked: true, fdaNotFound: true };
    }

    return {
      answer: `No OpenFDA U.S. label was found for **${query.raw}** (searched: ${(fda.searchedTerms || []).join(", ") || query.searchToken}). AI assistant unavailable. Please consult your pharmacist.`,
      matchedRuleId: null,
      confidence: "no_source",
      source: "none",
      medicationName: query.normalized,
      currentMedication: query.raw,
      contextLocked: true,
      error: true,
      fdaNotFound: true,
    };
  }

  if (userMessage) {
    return {
      answer: contextBreakRejection("your selected medication"),
      matchedRuleId: "context_lock",
      confidence: "context_blocked",
      source: "context_lock",
      contextLocked: true,
      blocked: true,
    };
  }

  return reply("");
}

module.exports = {
  reply,
  replyForMedication,
  replyAsync,
  buildMedicationPrompt,
  RULES,
  DRUG_PROFILES,
};
