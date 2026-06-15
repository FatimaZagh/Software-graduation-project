/**
 * Determines whether a catalog drug requires an active physician prescription before purchase.
 */

const RX_REQUIRED_CATEGORIES = new Set([
  "Antibiotic",
  "Anticoagulant",
]);

const RX_NAME_PATTERNS = [
  /amoxicillin/i,
  /warfarin/i,
  /alprazolam/i,
  /diazepam/i,
  /clonazepam/i,
  /lorazepam/i,
  /tramadol/i,
  /codeine/i,
  /oxycodone/i,
  /morphine/i,
  /methotrexate/i,
  /rivaroxaban/i,
  /enoxaparin/i,
  /ciprofloxacin/i,
  /azithromycin/i,
  /cephalexin/i,
  /doxycycline/i,
  /clarithromycin/i,
  /metformin/i,
  /insulin/i,
];

const OTC_NAME_PATTERNS = [
  /^paracetamol/i,
  /^ibuprofen/i,
  /^aspirin\s+100/i,
  /^vitamin\s+d/i,
  /^calcium\s+carbonate/i,
  /^folic\s+acid/i,
  /^cetirizine/i,
  /^loratadine/i,
  /^oral\s+rehydration/i,
  /^activated\s+charcoal/i,
  /^loperamide/i,
];

function inferRequiresPrescription(name, category) {
  const n = String(name || "").trim();
  const c = String(category || "").trim();

  if (!n) return false;

  for (const rx of OTC_NAME_PATTERNS) {
    if (rx.test(n)) return false;
  }

  for (const rx of RX_NAME_PATTERNS) {
    if (rx.test(n)) return true;
  }

  if (RX_REQUIRED_CATEGORIES.has(c)) return true;

  if (c === "Psychiatric" && /(alprazolam|diazepam|clonazepam|lorazepam|midazolam)/i.test(n)) {
    return true;
  }

  if (c === "Diabetes" || c === "Corticosteroid" || c === "Neurology") {
    return true;
  }

  return false;
}

function applyRequiresPrescriptionToDrugDoc(doc) {
  const flag =
    doc.requiresPrescription === true
      ? true
      : doc.requiresPrescription === false
        ? false
        : inferRequiresPrescription(doc.name, doc.category);
  return { ...doc, requiresPrescription: flag };
}

module.exports = {
  inferRequiresPrescription,
  applyRequiresPrescriptionToDrugDoc,
  RX_REQUIRED_MESSAGE:
    "This medication requires a valid prescription from a licensed physician.",
};
