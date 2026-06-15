# Doctor Portal API — Postman reference

Base URL: `http://127.0.0.1:3000`  
All routes require `doctorUserId` = MongoDB `users._id` for a user with `role: "Doctor"`.

Replace `{{doctorId}}`, `{{appointmentId}}`, `{{patientUserId}}` with real ObjectId strings from your database.

---

## 1. Profile

**GET** `/api/doctor-portal/{{doctorId}}/profile`  
No body.

**PUT** `/api/doctor-portal/{{doctorId}}/profile`  
JSON example:

```json
{
  "displayName": "Dr. Ahmed Hassan",
  "specialization": "Internal medicine",
  "yearsExperience": 12,
  "certifications": ["Saudi Board", "ACLS"],
  "consultationFee": 250,
  "profileImageBase64": "data:image/jpeg;base64,/9j/4AAQ...",
  "workSchedule": [
    {
      "dayOfWeek": 1,
      "startTime": "09:00",
      "endTime": "17:00",
      "breaks": [{ "start": "12:00", "end": "13:00" }]
    }
  ]
}
```

---

## 2. Appointments

**GET** `/api/doctor-portal/{{doctorId}}/appointments`

**PATCH** `/api/doctor-portal/{{doctorId}}/appointments/{{appointmentId}}/booking`  
```json
{ "bookingStatus": "Accepted" }
```
Allowed: `Pending`, `Accepted`, `Rejected`.

**PATCH** `/api/doctor-portal/{{doctorId}}/appointments/{{appointmentId}}/reschedule`  
```json
{ "date": "2026-05-01", "time": "14:30" }
```

**PATCH** `/api/doctor-portal/{{doctorId}}/appointments/{{appointmentId}}/visit`  
```json
{ "status": "In Progress" }
```
Allowed visit `status`: `Waiting`, `In Progress`, `Completed`, `Cancelled`.

---

## 3. Waiting list

**GET** `/api/doctor-portal/{{doctorId}}/waiting-list`

---

## 4. Pre-consultation file

**GET** `/api/doctor-portal/{{doctorId}}/patient/{{patientUserId}}/preconsult`

---

## 5. Clinic session (vitals, diagnosis, attachments)

**GET** `/api/doctor-portal/{{doctorId}}/session/{{appointmentId}}`

**PUT** `/api/doctor-portal/{{doctorId}}/session/{{appointmentId}}`  
```json
{
  "diagnosis": "Acute bronchitis",
  "notes": "Advise fluids and rest.",
  "vitals": {
    "weightKg": 72,
    "bpSystolic": 120,
    "bpDiastolic": 78,
    "heartRate": 82,
    "temperatureC": 37.1
  },
  "attachments": [
    {
      "fileName": "cxr.png",
      "mimeType": "image/png",
      "dataBase64": "iVBORw0KGgoAAAANS..."
    }
  ]
}
```

---

## 6. E-prescription (patient app + pharmacy sync)

**POST** `/api/doctor-portal/{{doctorId}}/prescriptions`  
```json
{
  "patientUserId": "{{patientUserId}}",
  "appointmentId": "{{appointmentId}}",
  "signatureImageBase64": "data:image/png;base64,iVBORw0KGgo...",
  "items": [
    {
      "name": "Amoxicillin",
      "dosage": "500 mg",
      "duration": "7 days",
      "instructions": "Take after food",
      "frequency": "Three times daily"
    }
  ]
}
```

Creates: `Prescription`, `ElectronicPrescription` (patient-visible), and `PatientMedication` rows for the pharmacy/patient medication list.

---

## 7. Chat (polling in Flutter; no WebSocket in this build)

**GET** `/api/doctor-portal/{{doctorId}}/chat/patients`

**GET** `/api/doctor-portal/{{doctorId}}/chat/{{patientUserId}}/messages`

**POST** `/api/doctor-portal/{{doctorId}}/chat/{{patientUserId}}/messages`  
```json
{ "body": "Please bring your lab results to the visit." }
```

---

## 8. Reviews & analytics

**GET** `/api/doctor-portal/{{doctorId}}/reviews`  
Ratings linked by `doctorUserId` or by appointments assigned to this doctor.

**GET** `/api/doctor-portal/{{doctorId}}/analytics`  

**GET** `/api/doctor-portal/{{doctorId}}/statistics` — same handler as analytics.

**GET** `/api/doctor/statistics?doctorUserId={{doctorId}}` — legacy/query-style alias (same JSON).

Returns JSON including: `totalPatientsToday`, `appointmentsToday` (count for server **local** calendar date, with normalized `YYYY-MM-DD` stored dates), `totalAppointments` (all-time for this doctor), `earningsToday`, `newPatientsApprox`, `cancellationRate`, `consultationFee`, `statsDateLocal`.

---

## Patient booking note

`POST /api/appointments/book` sets `bookingStatus: "Pending"` and normalizes `date` to **`YYYY-MM-DD`**. Optional body field **`doctorUserId`** (Mongo id of a user with `role: "Doctor"`) ties the row to the doctor dashboard immediately (recommended when the patient app loads doctors from **`GET /api/doctors`** or **`GET /api/clinics/:id/doctors`**, both backed by the **`doctors`** collection).

Example booking body:

```json
{
  "patientUserId": "{{patientUserId}}",
  "patientName": "Sara Ali",
  "date": "2026-04-18",
  "time": "10:00",
  "doctorName": "Dr. Ahmed Hassan",
  "doctorUserId": "{{doctorMongoUserId}}",
  "branch": "Rafeeq Clinic — Main Branch",
  "clinicId": "{{clinicId}}"
}
```
