const { Sequelize } = require("sequelize");

function getPgConfig() {
  const databaseUrl = String(process.env.DATABASE_URL || "").trim();

  if (databaseUrl) {
    return {
      mode: "DATABASE_URL",
      databaseUrl,
      host: "(from DATABASE_URL)",
      port: "(from DATABASE_URL)",
      database: "(from DATABASE_URL)",
      user: "(from DATABASE_URL)",
      password: "(from DATABASE_URL)",
    };
  }

  return {
    mode: "PG_*",
    databaseUrl: null,
    host: process.env.PG_HOST || "localhost",
    port: Number(process.env.PG_PORT || 5432),
    database: process.env.PG_DATABASE || "rafeeq_db",
    user: process.env.PG_USER || "postgres",
    password: process.env.PG_PASSWORD || "",
  };
}

/** Safe summary for logs — never prints the real password. */
function getPgConfigSummary() {
  const cfg = getPgConfig();
  const passwordSet =
    cfg.mode === "DATABASE_URL" ? cfg.databaseUrl.includes("@") : Boolean(String(cfg.password).length);

  return {
    mode: cfg.mode,
    host: cfg.host,
    port: cfg.port,
    database: cfg.database,
    user: cfg.user,
    passwordSet,
    passwordPlaceholder:
      cfg.mode === "PG_*" &&
      (cfg.password === "your_actual_pgadmin_password" ||
        cfg.password === "postgres" ||
        cfg.password === "REPLACE_WITH_YOUR_PGADMIN_PASSWORD"),
  };
}

function buildSequelizeFromEnv() {
  const cfg = getPgConfig();

  const commonOptions = {
    dialect: "postgres",
    logging: false,
    define: { underscored: true },
    dialectOptions: {
      connectTimeout: 10000,
    },
    pool: {
      max: 5,
      min: 0,
      acquire: 15000,
      idle: 10000,
    },
  };

  if (cfg.databaseUrl) {
    return new Sequelize(cfg.databaseUrl, commonOptions);
  }

  return new Sequelize(cfg.database, cfg.user, cfg.password, {
    host: cfg.host,
    port: cfg.port,
    ...commonOptions,
  });
}

module.exports = { buildSequelizeFromEnv, getPgConfig, getPgConfigSummary };
