const mongoose = require("mongoose");

const organizationSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    logoUrl: { type: String, default: "" },
    phone: { type: String, default: "" },
    mapUrl: { type: String, default: "" },
    latitude: { type: Number, default: null },
    longitude: { type: Number, default: null },
    description: { type: String, default: "" },
    /** Selected capability keys from facility registration (e.g. pharmacy, labRadiology). */
    moduleKeys: { type: [String], default: [] },
    // Facility details (root `city` mirrors `location.city` for simpler API payloads)
    address: { type: String, default: "" },
    city: { type: String, default: "" },
    specialty: { type: String, default: "" },
    location: {
      city: { type: String, default: "" },
      address: { type: String, default: "" },
    },
    // Branding colors (used by frontend theming)
    theme: {
      primaryColor: { type: String, default: "#004D40" },
      accentColor: { type: String, default: "#D4AF37" },
    },
    subscriptionType: { type: String, default: "Free" },
    hasInternalPharmacy: { type: Boolean, default: false },
    internalPharmacyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Pharmacy",
      default: null,
    },
    activeModules: {
      pharmacy: { type: Boolean, default: false },
      labRadiology: { type: Boolean, default: false },
      internsTrainees: { type: Boolean, default: false },
      emergency: { type: Boolean, default: false },
    },
    /** Super Admin review: pending → approved | rejected (active = legacy approved). */
    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "active", "suspended"],
      default: "pending",
      index: true,
    },
    rejectionReason: { type: String, default: "" },
    adminSettings: {
      defaultCurrency: { type: String, default: "ILS" },
      cancellationPenaltyPolicy: { type: String, default: "" },
      locale: { type: String, default: "en" },
    },
    billingSettings: {
      clinicCommissionRate: { type: Number, default: 0.2, min: 0, max: 1 },
      totalRevenue: { type: Number, default: 0, min: 0 },
    },
    rolePermissionMatrix: {
      type: Map,
      of: [String],
      default: {},
    },
    inventorySnapshot: {
      pharmacyItems: { type: Number, default: 0 },
      labAssaysInProgress: { type: Number, default: 0 },
      lowStockAlerts: { type: Number, default: 0 },
    },
  },
  { timestamps: true }
);

organizationSchema.index({ name: 1 }, { unique: true });

module.exports = mongoose.model("Organization", organizationSchema);

