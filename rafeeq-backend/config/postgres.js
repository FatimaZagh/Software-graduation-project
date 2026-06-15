const { getPgConfigSummary } = require("../db/models/sequelizeFactory");

function formatPgConnectionError(err, summary) {
  const raw = err.original || err;
  const code = raw.code || err.parent?.code || "";
  const message = err.message || String(err);
  const hints = [];

  if (
    code === "28P01" ||
    message.includes("password authentication failed") ||
    message.includes("authentication failed")
  ) {
    hints.push(
      `Password rejected for user "${summary.user}". Set PG_PASSWORD in .env to your real pgAdmin / PostgreSQL password.`
    );
  }

  if (summary.passwordPlaceholder) {
    hints.push(
      'PG_PASSWORD still looks like a placeholder ("your_actual_pgadmin_password"). Replace it with your actual PostgreSQL password.'
    );
  }

  if (!summary.passwordSet && summary.mode === "PG_*") {
    hints.push("PG_PASSWORD is empty. Add your PostgreSQL password to .env.");
  }

  if (code === "3D000" || message.includes("does not exist")) {
    hints.push(
      `Database "${summary.database}" was not found. In pgAdmin run: CREATE DATABASE ${summary.database};`
    );
  }

  if (code === "ECONNREFUSED" || message.includes("ECONNREFUSED")) {
    hints.push("PostgreSQL is not accepting connections. Start the PostgreSQL service on port 5432.");
  }

  if (code === "ECONNRESET" || message.includes("ECONNRESET")) {
    hints.push(
      "Connection was reset — often caused by wrong credentials or PostgreSQL not running. Verify PG_PASSWORD and that the service is active."
    );
  }

  if (code === "ENOTFOUND" || message.includes("getaddrinfo")) {
    hints.push(`Host "${summary.host}" could not be resolved. Try PG_HOST=localhost or 127.0.0.1.`);
  }

  const wrapped = new Error(`PostgreSQL connection failed: ${message}`);
  wrapped.hints = hints;
  wrapped.code = code;
  wrapped.original = err;
  return wrapped;
}

async function initPostgres() {
  const summary = getPgConfigSummary();

  console.log(
    `[PostgreSQL] Connecting (${summary.mode}) → ${summary.user}@${summary.host}:${summary.port}/${summary.database}`
  );

  if (summary.passwordPlaceholder) {
    console.warn(
      "[PostgreSQL] Warning: PG_PASSWORD appears to be a placeholder. Update .env before connecting."
    );
  }

  const db = require("../db/models");

  try {
    await db.sequelize.authenticate();
    console.log("[PostgreSQL] Authentication successful — pharmacy inventory module ready.");
  } catch (err) {
    throw formatPgConnectionError(err, summary);
  }

  try {
    await db.sequelize.sync();
    await db.seedDrugsIfEmpty();
    console.log("[PostgreSQL] Schema synced and drug catalog verified.");
  } catch (err) {
    const wrapped = new Error(`PostgreSQL schema setup failed: ${err.message}`);
    wrapped.hints = [
      `Ensure database "${summary.database}" exists and user "${summary.user}" has CREATE privileges.`,
    ];
    wrapped.original = err;
    throw wrapped;
  }

  return db.sequelize;
}

function getDb() {
  return require("../db/models");
}

module.exports = { initPostgres, getDb, formatPgConnectionError };
