const mongoose = require("mongoose");

const clinicSchema = new mongoose.Schema(
  {
    orgId: { type: mongoose.Schema.Types.ObjectId, ref: "Organization", index: true, required: false },
    name: { type: String, required: true },
    address: { type: String, default: "" },
    city: { type: String, default: "" },
    phone: { type: String, default: "" },
    hasInternalPharmacy: { type: Boolean, default: false, index: true },
    /** Capability tags e.g. Laboratory, Radiology */
    features: { type: [String], default: [] },
    /** Clinical services offered at this branch */
    services: { type: [String], default: [] },
    /** Default consultation fee for this branch (ILS) */
    defaultConsultationFee: { type: Number, default: 100, min: 0 },
    /** Priced specialized services at clinic level */
    servicePricing: [
      {
        key: { type: String, default: "" },
        name: { type: String, default: "" },
        price: { type: Number, default: 0, min: 0 },
        enabled: { type: Boolean, default: true },
      },
    ],
    hasLab: { type: Boolean, default: false, index: true },
    hasRadio: { type: Boolean, default: false, index: true },
    internalPharmacyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Pharmacy",
      default: null,
    },
    totalRevenue: { type: Number, default: 0, min: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Clinic", clinicSchema);
