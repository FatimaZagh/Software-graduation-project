const { Sequelize, DataTypes } = require("sequelize");
const { buildSequelizeFromEnv } = require("./sequelizeFactory");
const drugsSeed = require("../seeds/drugsSeed");

const sequelize = buildSequelizeFromEnv();

const Drug = sequelize.define(
  "Drug",
  {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    name: { type: DataTypes.STRING(255), allowNull: false },
    category: { type: DataTypes.STRING(128), allowNull: false },
  },
  { tableName: "drugs", timestamps: false }
);

const Pharmacy = sequelize.define(
  "Pharmacy",
  {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    name: { type: DataTypes.STRING(255), allowNull: false },
    latitude: { type: DataTypes.DOUBLE, allowNull: false },
    longitude: { type: DataTypes.DOUBLE, allowNull: false },
    status: { type: DataTypes.STRING(32), allowNull: false, defaultValue: "Active" },
    user_id: { type: DataTypes.STRING(64), allowNull: true },
    wallet_balance: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0 },
  },
  { tableName: "pharmacies", timestamps: true, createdAt: "created_at", updatedAt: "updated_at" }
);

const MedicationRequest = sequelize.define(
  "MedicationRequest",
  {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    patient_user_id: { type: DataTypes.STRING(64), allowNull: false },
    pharmacy_id: { type: DataTypes.INTEGER, allowNull: false },
    medication_name: { type: DataTypes.STRING(255), allowNull: false },
    drug_id: { type: DataTypes.INTEGER, allowNull: true },
    quantity: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1 },
    status: {
      type: DataTypes.ENUM("Pending", "Paid", "Failed", "Rejected", "Approved", "Dispensed"),
      allowNull: false,
      defaultValue: "Pending",
    },
    amount: { type: DataTypes.DECIMAL(12, 2), allowNull: true },
    card_last_four: { type: DataTypes.STRING(4), allowNull: true },
    paid_at: { type: DataTypes.DATE, allowNull: true },
  },
  { tableName: "medication_requests", timestamps: true, createdAt: "created_at", updatedAt: "updated_at" }
);

const PharmacyOrderTransaction = sequelize.define(
  "PharmacyOrderTransaction",
  {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    order_id: { type: DataTypes.INTEGER, allowNull: false },
    pharmacy_id: { type: DataTypes.INTEGER, allowNull: false },
    amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
    status: {
      type: DataTypes.ENUM("Pending", "Mock Processing", "Paid", "Failed"),
      allowNull: false,
      defaultValue: "Pending",
    },
    card_last_four: { type: DataTypes.STRING(4), allowNull: true },
  },
  { tableName: "pharmacy_order_transactions", timestamps: true, createdAt: "created_at", updatedAt: false }
);

const PharmacyInventory = sequelize.define(
  "PharmacyInventory",
  {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    pharmacy_id: { type: DataTypes.INTEGER, allowNull: false },
    drug_id: { type: DataTypes.INTEGER, allowNull: false },
    quantity: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
    status: {
      type: DataTypes.ENUM("Available", "Low Stock", "Out of Stock"),
      allowNull: false,
      defaultValue: "Available",
    },
    last_updated: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  },
  { tableName: "pharmacy_inventory", timestamps: false, indexes: [{ unique: true, fields: ["pharmacy_id", "drug_id"] }] }
);

Pharmacy.hasMany(PharmacyInventory, { foreignKey: "pharmacy_id", as: "inventory" });
Drug.hasMany(PharmacyInventory, { foreignKey: "drug_id", as: "inventory" });
PharmacyInventory.belongsTo(Pharmacy, { foreignKey: "pharmacy_id", as: "pharmacy" });
PharmacyInventory.belongsTo(Drug, { foreignKey: "drug_id", as: "drug" });
Pharmacy.hasMany(MedicationRequest, { foreignKey: "pharmacy_id", as: "medicationRequests" });
Pharmacy.hasMany(PharmacyOrderTransaction, { foreignKey: "pharmacy_id", as: "transactions" });
MedicationRequest.hasMany(PharmacyOrderTransaction, { foreignKey: "order_id", as: "transactions" });

async function seedDrugsIfEmpty() {
  const count = await Drug.count();
  if (count >= 100) return;
  if (count > 0) await Drug.destroy({ where: {} });
  await Drug.bulkCreate(drugsSeed);
  console.log(`Seeded ${drugsSeed.length} drugs into global catalog.`);
}

module.exports = {
  sequelize,
  Sequelize,
  Drug,
  Pharmacy,
  PharmacyInventory,
  MedicationRequest,
  PharmacyOrderTransaction,
  seedDrugsIfEmpty,
};
