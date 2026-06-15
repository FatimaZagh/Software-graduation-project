# Rafeeq — Multi-Tenant Healthcare Platform

Rafeeq is an academic graduation project: a **multi-tenant healthcare platform** that connects patients, clinicians, pharmacists, and facility administrators on a single system. It includes appointment booking, prescriptions, pharmacy inventory, billing, leave management, diagnostic workflows, and educational AI assistants.

The repository contains two applications:

| Folder | Stack | Role |
|--------|-------|------|
| [`rafeeq-backend/`](rafeeq-backend/) | Node.js, Express 5, MongoDB | REST API, auth, business logic |
| [`rafeeq_mobile/`](rafeeq_mobile/) | Flutter 3.x (Web, Android, iOS) | Cross-platform client UI |

---

## Features

### User roles

- **Patient** — Book appointments, view prescriptions, request medications, pharmacy search, medical records, payment history, medication reminders, AI medication assistant
- **Doctor** — Patient workspace, appointments, prescriptions, consultations, **order lab tests and imaging studies**, review completed results, chat
- **Nurse** — Triage, vitals, nursing notes, medications, labs, alerts (RBAC-limited; no billing/admin)
- **Laboratory Technician** (`Lab Technician`) — Diagnostic lab workflow: view incoming doctor orders, enter analysis text, attach result files, submit completed tests; access limited to **lab queue only** (no radiology orders)
- **Radiologist** (`Radiology Technologist`) — Diagnostic imaging workflow: view incoming imaging orders, enter findings/notes, attach images or reports, submit completed exams; access limited to **radiology queue only** (no lab orders)
- **Pharmacist** — Inventory, dispensing, medication requests, analytics, pharmacy settings
- **Organization Admin** — Staff, patients, appointments, billing, leave, doctor analytics (includes lab & radiology staff)
- **Super Admin** — Platform-wide organization approval, pending registrations, medical orders feed

#### Lab & Radiology workflow

Both roles share the **Technician Diagnostic Shell** (`TechnicianDiagnosticShell`) with role-specific queues enforced on the backend:

| Step | Actor | Action |
|------|--------|--------|
| 1 | **Doctor** | Creates a lab or radiology order for a patient |
| 2 | **Lab Technician** or **Radiologist** | Sees pending orders in their clinic/org queue |
| 3 | Technician | Enters results (analysis text + optional file attachment) |
| 4 | System | Locks the order (`isLocked`), notifies doctor and patient |
| 5 | **Doctor** | Reviews results in the diagnostic results screen |

**Registration:** Dedicated signup screens — `LabTechnicianSignupScreen` and radiology variant via `ClinicalTechnologistSignupScreen` (department: Laboratory / Radiology). Requires an active organization/clinic with the **Lab & Radiology** module enabled.

**API:** `GET/PUT /api/diagnostic/lab/*` and `/api/diagnostic/radiology/*` — protected by `requireTechnician` middleware (`x-user-id`, `x-org-id`). Lab technicians cannot submit radiology results and vice versa.

### Platform capabilities

- Multi-tenant organizations and clinics (`orgId` isolation)
- Internal vs external pharmacy registration and routing
- Waiting list and appointment reschedule/cancel
- Session billing and payment checkout
- GPS-based nearby pharmacy search (drug availability + distance)
- Medication local notifications (Android/iOS)
- Arabic / English localization (RTL support)
- Responsive UI for mobile, tablet, and desktop web

### AI (educational only — not a medical device)

| System | Provider | Endpoint | Used in app |
|--------|----------|----------|-------------|
| Rafeeq AI Medical Assistant | Google Gemini | `POST /api/ai/chat` | Prescription AI panel |
| Medication Chatbot | OpenRouter + OpenFDA | `POST /api/patient-portal/:id/chatbot/medications` | Backend ready; UI uses Gemini |
| Pseudo AI | Local rule-based (Flutter) | — | Full-screen assistant (offline demo) |

AI responses include safety guardrails: no definitive diagnosis, no prescription changes, healthcare scope filtering.

### Maps & location

- **flutter_map** + OpenStreetMap tiles
- **Geolocator** (mobile) / browser geolocation (web)
- **Nominatim** for address search and reverse geocoding
- **Haversine** distance on backend for pharmacy search within radius

Maps are **not** AI-powered — they use GPS and geometric distance calculations.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Client (rafeeq_mobile)                             │
│  Web · Android · iOS                                        │
│  go_router · Material 3 · Responsive layouts                │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP / REST (JSON)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Express API (rafeeq-backend) — port 3000                   │
│  JWT auth · bcrypt passwords · RBAC route guards            │
└──────────────────────────┬──────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
      MongoDB          Gemini API      OpenRouter / OpenFDA
   (rafeeq_db)      (AI assistant)   (medication chatbot)
```

**Design:** Online-first client–server. The mobile app requires a running backend and network connection for core workflows. Local storage (`SharedPreferences`) is used for locale and session hints only.

---

## Prerequisites

### Backend

- **Node.js** 18+ (LTS recommended)
- **MongoDB** 6+ running locally or remote
- npm

### Mobile / Web client

- **Flutter** 3.x (Dart SDK ≥ 3.11)
- For Android: Android SDK, JDK 17
- For iOS: Xcode (macOS only)
- For Windows desktop video backgrounds: MediaKit (initialized on Windows only)

---

## Quick start

### 1. Clone and enter the repo

```bash
git clone <repository-url>
cd Rafeeq
```

### 2. Backend setup

```bash
cd rafeeq-backend
cp .env.example .env
# Edit .env — set MONGODB_URI, JWT_SECRET, and optional API keys
npm install
npm start
```

The API listens on **http://localhost:3000**.

Verify MongoDB is running:

```bash
# Default URI from .env.example
mongodb://127.0.0.1:27017/rafeeq_db
```

Optional seed scripts:

```bash
npm run seed:appointments
npm run seed:pharmacy-drugs
```

### 3. Flutter client setup

```bash
cd ../rafeeq_mobile
flutter pub get
flutter run
```

Pick a device:

```bash
flutter run -d chrome          # Web
flutter run -d android         # Android emulator/device
flutter run -d ios             # iOS simulator (macOS)
```

---

## API base URL by platform

Configured in [`rafeeq_mobile/lib/api_config.dart`](rafeeq_mobile/lib/api_config.dart):

| Platform | Default API base |
|----------|------------------|
| Web | Same host as the page, port `3000` |
| Android emulator | `http://10.0.2.2:3000` |
| iOS simulator / desktop | `http://127.0.0.1:3000` |
| Physical device | Use your PC LAN IP |

Override for any device:

```bash
flutter run --dart-define=RAFEEQ_API_BASE=http://192.168.1.100:3000
```

---

## Environment variables

Copy [`rafeeq-backend/.env.example`](rafeeq-backend/.env.example) to `.env`:

| Variable | Required | Purpose |
|----------|----------|---------|
| `MONGODB_URI` | Yes | MongoDB connection string |
| `JWT_SECRET` | Yes | JWT signing for auth |
| `GEMINI_API_KEY` | For AI chat | Rafeeq AI Medical Assistant (`/api/ai/chat`) |
| `OPENROUTER_API_KEY` | For medication LLM | Medication chatbot fallback |
| `GOOGLE_MAPS_API_KEY` | Optional | Driving directions proxy (`/api/maps/directions`) |

Never commit `.env` or API keys to version control.

---

## Key API routes

| Prefix | Description |
|--------|-------------|
| `/api/auth` | Login, registration |
| `/api/patient-portal` | Patient dashboard data |
| `/api/doctor`, `/api/doctor-portal` | Doctor workspace |
| `/api/nurse` | Nurse portal |
| `/api/pharmacy`, `/api/pharmacies` | Pharmacy inventory & registration |
| `/api/appointments` | Booking, slots, cancel, reschedule |
| `/api/waiting-list` | Appointment waiting list |
| `/api/payments` | Checkout, saved cards, history |
| `/api/billing` | Org billing & session billing |
| `/api/leaves` | Leave requests |
| `/api/diagnostic` | Lab & radiology workflows |
| `/api/ai/chat` | Gemini medical assistant |
| `/api/superadmin` | Platform super admin |
| `/api/maps/directions` | Google Directions proxy |
| `/api/pharmacies/search-by-drug` | Nearby pharmacies by drug + GPS |

---

## Project structure

```
Rafeeq/
├── README.md                 # This file
├── rafeeq-backend/
│   ├── server.js             # Express entry point
│   ├── config/               # Environment loading
│   ├── controllers/          # Route handlers
│   ├── models/               # Mongoose schemas
│   ├── routes/               # API routers
│   ├── services/             # Business logic (AI, pharmacy, billing…)
│   ├── utils/                # Helpers (password, RBAC, logging)
│   └── scripts/              # Seed scripts
│
└── rafeeq_mobile/
    ├── lib/
    │   ├── main.dart         # App entry, GoRouter, theme
    │   ├── api_config.dart   # Backend URL resolution
    │   ├── landing_screen.dart
    │   ├── login_screen.dart
    │   ├── features/         # Role dashboards & flows
    │   │   ├── patient_dashboard/
    │   │   ├── doctor_dashboard/
    │   │   ├── nurse_dashboard/
    │   │   ├── pharmacist_dashboard/
    │   │   ├── admin_dashboard/
    │   │   ├── auth/
    │   │   ├── billing/
    │   │   ├── diagnostic/
    │   │   └── leave/
    │   ├── super_admin/
    │   ├── widgets/          # responsive_layout, shared UI
    │   └── l10n/             # Arabic / English strings
    ├── android/              # Android native project
    ├── ios/                  # iOS native project
    └── assets/               # Images, videos
```

---

## Responsive design

A single Flutter codebase adapts to phone, tablet, and desktop web:

- **Breakpoints** in `lib/widgets/responsive_layout.dart` (600 / 800 / 1200 px)
- **`RafeeqResponsive`** — padding, grid columns, dialog widths
- **Dashboards** — sidebar on wide screens (≥900px), drawer + bottom navigation on mobile
- **`LayoutBuilder`**, **`MediaQuery`**, **`Flexible`/`Expanded`**, **`Wrap`** for overflow-safe layouts

---

## Building for production

### Android APK

```bash
cd rafeeq_mobile
flutter build apk --release
```

Debug APK (development):

```bash
flutter build apk --debug
```

Android cleartext HTTP is enabled for local development only (`network_security_config.xml`). Use HTTPS in production.

### Web

```bash
flutter build web
```

Serve the `build/web` folder behind a web server with the API on the same origin or configure CORS.

---

## Offline behavior

The app is **online-first**. Without internet and a running backend:

- Login, dashboards, booking, pharmacy, and real AI **do not work**
- **Pseudo AI** (local rule-based assistant) works without network
- **Scheduled medication notifications** may still fire if previously synced on device
- Bundled assets (e.g. landing video) work offline

---

## Security notes

- Passwords hashed with **bcrypt**
- Auth via **JWT** bearer tokens
- API keys (Gemini, OpenRouter, Google Maps) stay **server-side** in `.env`
- CVV is verified transiently at checkout — **not stored**
- Multi-tenant queries filter by `orgId` / user role

This is an **academic prototype**, not a certified medical device or HIPAA-compliant production system.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| White screen on Android startup | MediaKit is Windows-only; ensure latest `main.dart` (no `MediaKit.ensureInitialized()` on mobile) |
| Cannot reach API from phone | Use `--dart-define=RAFEEQ_API_BASE=http://<PC_LAN_IP>:3000` |
| Android emulator localhost | Use `10.0.2.2:3000`, not `127.0.0.1` |
| Gradle / desugaring errors | `coreLibraryDesugaring` enabled in `android/app/build.gradle.kts` |
| AI returns error | Set `GEMINI_API_KEY` in backend `.env` and restart server |
| MongoDB connection failed | Start MongoDB; check `MONGODB_URI` |

---

## Development commands

```bash
# Backend
cd rafeeq-backend && npm start

# Flutter analyze
cd rafeeq_mobile && flutter analyze

# Flutter clean rebuild
flutter clean && flutter pub get && flutter run
```

---

## License

Academic / graduation project. Specify license terms before public or commercial distribution.

---

## Authors

Rafeeq — Healthcare Platform (Graduation Project)

For questions about setup, architecture, or demo flows, refer to the inline code documentation in `rafeeq-backend/services/` and `rafeeq_mobile/lib/features/`.
