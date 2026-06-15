# Registration + Admin + Booking — Postman Reference

Base URL: `http://127.0.0.1:3000`

---

## 1) Unified Sign-Up (with profile image)

### **POST** `/signup`

#### Patient example

```json
{
  "name": "Sara Ali",
  "email": "sara@example.com",
  "password": "1234",
  "role": "Patient",
  "profileImageUrl": "data:image/jpeg;base64,/9j/4AAQ...",
  "patientHealth": {
    "bloodType": "O+",
    "weightKg": 72,
    "heightCm": 165
  }
}
```

#### Doctor example

```json
{
  "name": "Dr. Ahmed Hassan",
  "email": "doctor.ahmed@example.com",
  "password": "1234",
  "role": "Doctor",
  "profileImageUrl": "data:image/jpeg;base64,/9j/4AAQ...",
  "doctorClinicId": "PUT_CLINIC_OBJECTID_HERE",
  "doctorSpecialization": "General Medicine",
  "doctorYearsExperience": 10,
  "doctorCertificatesBase64": [
    "data:image/jpeg;base64,/9j/4AAQ..."
  ],
  "doctorSignatureBase64": "data:image/png;base64,iVBORw0KGgo..."
}
```

#### Admin example

```json
{
  "name": "Admin User",
  "email": "admin@example.com",
  "password": "1234",
  "role": "Admin",
  "profileImageUrl": "data:image/jpeg;base64,/9j/4AAQ..."
}
```

---

## 2) Login (returns profile image URL)

### **POST** `/login`

```json
{ "email": "admin@example.com", "password": "1234" }
```

Response includes:
- `role`
- `id`
- `profileImageUrl`

---

## 3) Clinics list (for doctor signup + booking)

### **GET** `/api/clinics`

---

## 4) Enhanced booking — doctors + available slots by date

### **GET** `/api/clinics/:clinicId/doctors/availability?date=YYYY-MM-DD`

Example:
`/api/clinics/PUT_CLINIC_OBJECTID_HERE/doctors/availability?date=2026-04-18`

Returns doctors with:
- `name`, `specialty`, `profileImageUrl`
- `availableSlots` (e.g. `["09:00","09:30", ...]`)

---

## 5) Admin — Clinics CRUD

Admin auth: send header **`x-admin-user-id`** = Admin user's ObjectId  

### **POST** `/api/admin/clinics`

```json
{
  "name": "Rafeeq Clinic — New Branch",
  "address": "Some street",
  "city": "Riyadh",
  "phone": "+966..."
}
```

### **DELETE** `/api/admin/clinics/:clinicId`

---

## 6) Doctor leave requests + Admin approval

### Doctor submits
**POST** `/api/doctors/:doctorUserId/leave-requests`

```json
{
  "fromDate": "2026-05-01",
  "toDate": "2026-05-03",
  "reason": "Conference"
}
```

### Admin lists pending
**GET** `/api/admin/leave-requests` (header `x-admin-user-id`)

### Admin decides
**PATCH** `/api/admin/leave-requests/:id` (header `x-admin-user-id`)

```json
{ "status": "Approved" }
```

---

## 7) Private Messaging (Patient ↔ Doctor) — encrypted at rest

Messages are stored with `senderId` + `receiverId` and an encrypted payload (`AES-256-GCM`).
Only the two participant IDs can read their conversation via the endpoints below.

### Patient lists doctors to chat with (by clinic)
**GET** `/api/patient-portal/:patientUserId/chat/doctors?clinicId=PUT_CLINIC_OBJECTID_HERE`

### Patient reads messages with a specific doctor
**GET** `/api/patient-portal/:patientUserId/chat/:doctorUserId/messages`

### Patient sends message to a specific doctor
**POST** `/api/patient-portal/:patientUserId/chat/:doctorUserId/messages`

```json
{ "body": "Hello doctor, I have a question." }
```

### Doctor lists their chat patients (only those who chatted with THIS doctor)
**GET** `/api/doctor-portal/:doctorUserId/chat/patients`

### Doctor reads messages with a specific patient
**GET** `/api/doctor-portal/:doctorUserId/chat/:patientUserId/messages`

### Doctor sends message to a specific patient
**POST** `/api/doctor-portal/:doctorUserId/chat/:patientUserId/messages`

```json
{ "body": "Please describe your symptoms." }
```

---

## 8) Notifications (bell + unread badge)

Notifications are created automatically when:
- A private chat message is sent
- An appointment is booked / cancelled / rescheduled
- A lab result is uploaded

### Patient
**GET** `/api/patient-portal/:patientUserId/notifications`

**PATCH** `/api/patient-portal/:patientUserId/notifications/:notificationId/read`

### Doctor
**GET** `/api/doctor-portal/:doctorUserId/notifications`

**PATCH** `/api/doctor-portal/:doctorUserId/notifications/:notificationId/read`

