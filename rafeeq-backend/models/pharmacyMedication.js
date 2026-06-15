const mongoose = require("mongoose");

const pharmacyMedicationSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, index: true },
    genericName: { type: String, default: "" },
    strength: { type: String, default: "" },
    form: { type: String, default: "" },
    inStock: { type: Boolean, default: true },
    stockUnits: { type: Number, default: 0 },
    aisle: { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("PharmacyMedication", pharmacyMedicationSchema);
