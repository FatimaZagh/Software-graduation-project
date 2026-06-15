/**
 * One-time backfill: internal pharmacy + InternalPharmacist for all clinics missing them.
 * Run from backend root: node scripts/migrateClinicsInternalPharmacy.js
 */
require("../config/loadEnv");

const mongoose = require("mongoose");
const { migrateAllClinicsInternalPharmacy } = require("../services/migrateClinicsInternalPharmacy");

const MONGODB_URI = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/rafeeq_db";

async function main() {
  await mongoose.connect(MONGODB_URI);
  console.log("[migrate-clinics] Connected to", MONGODB_URI);

  const summary = await migrateAllClinicsInternalPharmacy();

  console.log("[migrate-clinics] Done.");
  console.log(JSON.stringify(summary, null, 2));

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error("[migrate-clinics] Fatal:", err);
  process.exit(1);
});
