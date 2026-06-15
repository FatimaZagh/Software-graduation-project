const mongoose = require("mongoose");

const drugSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    category: { type: String, required: true, trim: true, index: true },
    requiresPrescription: { type: Boolean, default: false, index: true },
  },
  { timestamps: true, collection: "drugs" }
);

drugSchema.index({ name: 1, category: 1 });

module.exports = mongoose.model("Drug", drugSchema);
