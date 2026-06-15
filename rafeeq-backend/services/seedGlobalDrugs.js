const Drug = require("../models/drug");
const Pharmacy = require("../models/pharmacy");
const globalDrugsDataset = require("../db/seeds/globalDrugsDataset");
const { inferRequiresPrescription } = require("../utils/drugPrescriptionClassification");

const INVENTORY_STATUS = "Available";

const MANUFACTURERS = ["PharmaPal", "MediCore", "HealthLine", "Rafeeq Pharma", "GlobalRx"];

function buildInventoryRows(drugs) {
  const now = new Date();
  const expiryBase = new Date();
  expiryBase.setFullYear(expiryBase.getFullYear() + 1);

  return drugs.map((drug, index) => {
    const expiry = new Date(expiryBase);
    expiry.setMonth((expiry.getMonth() + (index % 12)) % 12);
    return {
      drug_id: drug._id,
      quantity: 10,
      price: Number((8 + (index % 40) * 1.25).toFixed(2)),
      manufacturer: MANUFACTURERS[index % MANUFACTURERS.length],
      expiryDate: expiry,
      status: INVENTORY_STATUS,
      last_updated: now,
    };
  });
}

/**
 * Seed global Drug catalog when collection is empty.
 */
function enrichDrugRows(rows) {
  return rows.map((row) => ({
    ...row,
    requiresPrescription:
      row.requiresPrescription === true
        ? true
        : row.requiresPrescription === false
          ? false
          : inferRequiresPrescription(row.name, row.category),
  }));
}

/** Sync requiresPrescription flags on all catalog drugs (idempotent). */
async function syncDrugPrescriptionFlags() {
  const drugs = await Drug.find({}).select("name category requiresPrescription").lean();
  let updated = 0;
  for (const d of drugs) {
    const next = inferRequiresPrescription(d.name, d.category);
    if (d.requiresPrescription !== next) {
      await Drug.updateOne({ _id: d._id }, { $set: { requiresPrescription: next } });
      updated += 1;
    }
  }
  if (updated > 0) {
    console.log(`[MongoDB Seed] Updated requiresPrescription on ${updated} drug(s).`);
  }
  return updated;
}

async function seedGlobalDrugs() {
  try {
    const count = await Drug.countDocuments();
    if (count === 0) {
      console.log("[MongoDB Seed] Injecting 100+ global drugs into the catalog...");
      await Drug.insertMany(enrichDrugRows(globalDrugsDataset));
      console.log("[MongoDB Seed] Success: 100 medications initialized.");
    } else {
      console.log(`[MongoDB Seed] Drug catalog ready (${count} medications).`);
      await syncDrugPrescriptionFlags();
    }
    return await Drug.countDocuments();
  } catch (err) {
    console.error("[MongoDB Seed] Error seeding drugs:", err.message);
    throw err;
  }
}

/**
 * Backfill embedded inventory for pharmacies that have none (e.g. ph1 created before seed).
 */
async function backfillPharmacyInventories() {
  const drugs = await Drug.find({}).select("_id").lean();
  if (drugs.length === 0) {
    console.warn("[MongoDB Seed] Skipping pharmacy inventory backfill — no drugs in catalog.");
    return 0;
  }

  const pharmacies = await Pharmacy.find({
    $or: [{ inventory: { $exists: false } }, { inventory: { $size: 0 } }],
  });

  if (pharmacies.length === 0) return 0;

  const rows = buildInventoryRows(drugs);
  let updated = 0;

  for (const pharmacy of pharmacies) {
    pharmacy.inventory = rows;
    await pharmacy.save();
    updated += 1;
    console.log(
      `[MongoDB Seed] Inventory backfilled for pharmacy "${pharmacy.name}" (${rows.length} items, qty 10 each).`
    );
  }

  return updated;
}

/** Run drug seed then backfill any empty pharmacy inventories. */
async function runPharmacyStartupSeeds() {
  await seedGlobalDrugs();
  const backfilled = await backfillPharmacyInventories();
  if (backfilled > 0) {
    console.log(`[MongoDB Seed] Backfilled inventory on ${backfilled} pharmacy record(s).`);
  }
}

module.exports = {
  seedGlobalDrugs,
  syncDrugPrescriptionFlags,
  backfillPharmacyInventories,
  runPharmacyStartupSeeds,
  buildInventoryRows,
};
