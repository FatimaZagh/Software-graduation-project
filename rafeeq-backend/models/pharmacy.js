const mongoose = require("mongoose");

const INVENTORY_STATUSES = ["Available", "Low Stock", "Out of Stock"];

const inventoryItemSchema = new mongoose.Schema(
  {
    drug_id: { type: mongoose.Schema.Types.ObjectId, ref: "Drug", required: true },
    quantity: { type: Number, default: 10, min: 0 },
    price: { type: Number, default: 15 },
    manufacturer: { type: String, default: "Rafeeq Pharma" },
    expiryDate: { type: Date },
    status: {
      type: String,
      enum: INVENTORY_STATUSES,
      default: "Available",
    },
    last_updated: { type: Date, default: Date.now },
  },
  { _id: true }
);

const inventoryLogSchema = new mongoose.Schema(
  {
    action: { type: String, enum: ["Dispense", "Restock", "Adjustment"], required: true },
    drug_id: { type: mongoose.Schema.Types.ObjectId, ref: "Drug" },
    drugName: { type: String, default: "" },
    quantityChange: { type: Number, default: 0 },
    previousQty: { type: Number, default: 0 },
    newQty: { type: Number, default: 0 },
    performedBy: { type: String, default: "" },
    note: { type: String, default: "" },
  },
  { timestamps: true }
);

const pharmacySchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    status: { type: String, default: "Active", trim: true },
    /** True while parent facility is pending/rejected Super Admin review — blocks pharmacist login. */
    facilityApprovalLocked: { type: Boolean, default: false, index: true },
    userId: { type: String, default: null, index: true },
    orgId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organization",
      default: null,
      index: true,
    },
    clinicId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Clinic",
      default: null,
      index: true,
    },
    pharmacyType: {
      type: String,
      enum: ["Internal", "External"],
      default: "External",
      index: true,
    },
    phone: { type: String, default: "" },
    address: { type: String, default: "" },
    operatingHours: { type: String, default: "Sat–Fri · 08:00 AM - 11:00 PM" },
    licenseNumber: { type: String, default: "" },
    wallet_balance: { type: Number, default: 0, min: 0 },
    inventory: { type: [inventoryItemSchema], default: [] },
    inventoryLogs: { type: [inventoryLogSchema], default: [] },
  },
  { timestamps: true, collection: "pharmacies" }
);

module.exports = mongoose.model("Pharmacy", pharmacySchema);
module.exports.INVENTORY_STATUSES = INVENTORY_STATUSES;
