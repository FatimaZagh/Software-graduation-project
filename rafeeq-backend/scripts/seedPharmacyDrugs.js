/**
 * Seed global drug catalog + backfill empty pharmacy inventories.
 * Usage: node scripts/seedPharmacyDrugs.js
 */
require("../config/loadEnv");
const mongoose = require("mongoose");
const { runPharmacyStartupSeeds } = require("../services/seedGlobalDrugs");

const MONGO_URI = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/rafeeq_db";

(async () => {
  try {
    await mongoose.connect(MONGO_URI);
    console.log("Connected to MongoDB...");
    await runPharmacyStartupSeeds();
    process.exit(0);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
})();
