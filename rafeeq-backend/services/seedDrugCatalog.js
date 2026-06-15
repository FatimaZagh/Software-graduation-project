/** @deprecated Use seedGlobalDrugs — kept for script compatibility. */
const { seedGlobalDrugs, runPharmacyStartupSeeds } = require("./seedGlobalDrugs");

async function seedDrugCatalogIfEmpty() {
  return seedGlobalDrugs();
}

module.exports = { seedDrugCatalogIfEmpty, seedGlobalDrugs, runPharmacyStartupSeeds };
