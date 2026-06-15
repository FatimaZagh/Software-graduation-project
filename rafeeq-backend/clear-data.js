/**
 * Temporary utility — wipes all documents from every collection in the connected database.
 * Does NOT drop collections or indexes.
 *
 * Usage: node clear-data.js
 * Requires MONGO_URI in .env (falls back to MONGODB_URI for local dev).
 */
require("dotenv").config();
const mongoose = require("mongoose");

async function main() {
  const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!uri) {
    console.error("MONGO_URI is not set.");
    process.exit(1);
  }

  await mongoose.connect(uri);
  const db = mongoose.connection.db;
  const collections = await db.listCollections().toArray();

  if (collections.length === 0) {
    console.log("No collections found — nothing to clear.");
    await mongoose.disconnect();
    return;
  }

  console.log(`Clearing ${collections.length} collection(s) in "${db.databaseName}"…`);

  for (const { name } of collections) {
    const result = await db.collection(name).deleteMany({});
    console.log(`  ${name}: deleted ${result.deletedCount} document(s)`);
  }

  await mongoose.disconnect();
  console.log("All documents cleared. Connection closed.");
}

main().catch((err) => {
  console.error("clear-data failed:", err);
  mongoose.disconnect().finally(() => process.exit(1));
});
