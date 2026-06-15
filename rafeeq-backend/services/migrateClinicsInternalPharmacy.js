const mongoose = require("mongoose");
const Clinic = require("../models/clinic");
const Pharmacy = require("../models/pharmacy");
const Organization = require("../models/Organization");
const { provisionInternalPharmacy } = require("./internalPharmacyProvisioning");

/**
 * Backfill internal pharmacy + InternalPharmacist for clinics missing them.
 */
async function migrateAllClinicsInternalPharmacy() {
  const clinics = await Clinic.find({}).sort({ createdAt: 1 }).lean();
  const summary = {
    total: clinics.length,
    provisioned: 0,
    skipped: 0,
    failed: 0,
    clinics: [],
  };

  for (const clinic of clinics) {
    const clinicId = String(clinic._id);
    const clinicName = String(clinic.name || "").trim() || "Clinic";
    const entry = {
      clinicId,
      clinicName,
      orgId: clinic.orgId ? String(clinic.orgId) : null,
      status: "pending",
    };

    let orgId = clinic.orgId;
    if (!orgId || !mongoose.Types.ObjectId.isValid(String(orgId))) {
      entry.status = "skipped";
      entry.reason = "missing or invalid orgId";
      summary.skipped += 1;
      summary.clinics.push(entry);
      continue;
    }

    try {
      let org = await Organization.findById(orgId).select("name address phone activeModules").lean();
      if (!org) {
        const fallbackOrg = await Organization.findOne({}).sort({ createdAt: 1 }).lean();
        if (fallbackOrg) {
          orgId = fallbackOrg._id;
          await Clinic.updateOne({ _id: clinic._id }, { $set: { orgId } });
          entry.repairedOrgId = String(orgId);
          entry.previousOrgId = String(clinic.orgId);
          entry.orgId = String(orgId);
          org = fallbackOrg;
        } else {
          entry.status = "skipped";
          entry.reason = "organization not found and no fallback org in database";
          summary.skipped += 1;
          summary.clinics.push(entry);
          continue;
        }
      }

      if (clinic.internalPharmacyId && mongoose.Types.ObjectId.isValid(String(clinic.internalPharmacyId))) {
        const existing = await Pharmacy.findById(clinic.internalPharmacyId).lean();
        if (existing && (existing.pharmacyType === "Internal" || !existing.pharmacyType)) {
          entry.pharmacyId = String(existing._id);
          const refreshed = await provisionInternalPharmacy({
            orgId,
            clinicId: clinic._id,
            pharmacyName: `${clinicName} — In-House Pharmacy`,
            address: clinic.address || "",
            phone: clinic.phone || "",
          });
          entry.internalPharmacist = refreshed?.internalPharmacist || null;
          entry.status = "skipped";
          entry.reason = "internal pharmacy already linked";
          summary.skipped += 1;
          summary.clinics.push(entry);
          continue;
        }
      }

      const bundle = await provisionInternalPharmacy({
        orgId,
        clinicId: clinic._id,
        pharmacyName: `${clinicName} — In-House Pharmacy`,
        address: clinic.address || org.address || org.location?.address || "",
        phone: clinic.phone || org.phone || "",
      });

      await Clinic.updateOne(
        { _id: clinic._id },
        {
          $set: {
            hasInternalPharmacy: true,
            internalPharmacyId: bundle?.pharmacy?._id || bundle?.pharmacy?.id,
          },
        }
      );

      if (bundle?.pharmacy?._id) {
        entry.pharmacyId = String(bundle.pharmacy._id);
      }
      if (bundle?.internalPharmacist) {
        entry.internalPharmacist = {
          email: bundle.internalPharmacist.email,
          password: bundle.internalPharmacist.password,
          role: bundle.internalPharmacist.role,
          userId: bundle.internalPharmacist.userId,
        };
      }

      entry.status = bundle?.reused ? "linked_existing" : "provisioned";
      summary.provisioned += 1;
      summary.clinics.push(entry);
    } catch (err) {
      entry.status = "failed";
      entry.reason = err.message || String(err);
      summary.failed += 1;
      summary.clinics.push(entry);
    }
  }

  return summary;
}

module.exports = { migrateAllClinicsInternalPharmacy };
