/**
 * CDSS allergy cross-check for prescribing (drug name vs recorded allergies).
 * Uses substring / penicillin-family heuristics — not a substitute for clinical judgment.
 */

const PENICILLIN_FAMILY = [
  "penicillin",
  "amoxicillin",
  "ampicillin",
  "amoxiclav",
  "clavulan",
  "augmentin",
  "piperacillin",
  "ticarcillin",
  "cefalexin",
  "cephalexin",
  "cefuroxime",
  "ceftriaxone",
  "cefazolin",
];

function norm(s) {
  return String(s || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function collectAllergyStrings(medicalProfile, healthProfile) {
  const meds = [...(medicalProfile?.allergies?.medications || [])].map(String);
  const foods = [...(medicalProfile?.allergies?.foods || [])].map(String);
  const mats = [...(medicalProfile?.allergies?.materials || [])].map(String);
  const health = Array.isArray(healthProfile?.allergies) ? healthProfile.allergies.map(String) : [];
  return [...new Set([...meds, ...foods, ...mats, ...health].filter(Boolean))];
}

function penicillinFamilyHit(drugLower, allergyLower) {
  const drugHit = PENICILLIN_FAMILY.some((k) => drugLower.includes(k));
  const allergyHit = PENICILLIN_FAMILY.some((k) => allergyLower.includes(k));
  return drugHit && allergyHit;
}

function crossMatch(drugName, allergyEntry) {
  const d = norm(drugName);
  const a = norm(allergyEntry);
  if (!d || !a) return false;
  if (d.length >= 3 && a.length >= 3 && (d.includes(a) || a.includes(d))) return true;
  if (penicillinFamilyHit(d, a)) return true;
  return false;
}

/**
 * @returns {{ blocked: boolean, conflicts: Array<{ drug: string, allergy: string }>, message: string }}
 */
function evaluatePrescriptionAllergies(allergyList, medicationNames) {
  const conflicts = [];
  const names = (medicationNames || []).map((n) => String(n).trim()).filter(Boolean);
  const allergies = (allergyList || []).map(String).filter(Boolean);

  for (const drug of names) {
    for (const al of allergies) {
      if (crossMatch(drug, al)) {
        conflicts.push({ drug, allergy: al });
      }
    }
  }

  const blocked = conflicts.length > 0;
  let message = "";
  if (blocked) {
    const first = conflicts[0];
    message = `🚨 Warning: Patient has a recorded allergy to [${first.allergy}] that may conflict with [${first.drug}].`;
  }
  return { blocked, conflicts, message };
}

module.exports = {
  collectAllergyStrings,
  evaluatePrescriptionAllergies,
  crossMatch,
};
