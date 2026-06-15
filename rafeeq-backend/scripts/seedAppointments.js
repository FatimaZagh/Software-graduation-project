/**
 * One-time / manual seed: inserts 3 sample appointments if the collection is empty.
 * Run from project root: node scripts/seedAppointments.js
 */
const mongoose = require("mongoose");
const AppointmentModel = require("../models/appointment");

const MONGODB_URI = "mongodb://127.0.0.1:27017/rafeeq_db";

async function main() {
  await mongoose.connect(MONGODB_URI);
  const count = await AppointmentModel.countDocuments();
  if (count > 0) {
    console.log(`Skipping seed: ${count} appointment(s) already exist.`);
    await mongoose.disconnect();
    return;
  }
  await AppointmentModel.insertMany([
    {
      patientName: "Ahmad Ali",
      time: "09:00 AM",
      date: "2026-04-02",
      status: "Waiting",
      doctorName: "Dr. Ahmed Hassan",
      branch: "Rafeeq Clinic — Main Branch",
    },
    {
      patientName: "Sara Khaled",
      time: "10:30 AM",
      date: "2026-04-02",
      status: "Waiting",
      doctorName: "Dr. Sara Mahmoud",
      branch: "Rafeeq Clinic — Main Branch",
    },
    {
      patientName: "Omar Hassan",
      time: "11:15 AM",
      date: "2026-04-03",
      status: "Waiting",
      doctorName: "Dr. Layla Farid",
      branch: "Rafeeq Clinic — North Branch",
    },
  ]);
  console.log("Inserted 3 sample appointments.");
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
