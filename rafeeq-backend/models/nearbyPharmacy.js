const mongoose = require("mongoose");

const nearbyPharmacySchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    address: { type: String, default: "" },
    distanceKm: { type: Number, default: 0 },
    phone: { type: String, default: "" },
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model("NearbyPharmacy", nearbyPharmacySchema);
