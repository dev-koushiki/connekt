# CONNEKT / VIBELIVE – Cross-Platform Mobile & Web Ecosystem

**CONNEKT** is an integrated digital ecosystem combining social networking, live streaming, direct messaging, unified identity, and professional networking.

---

## 📱 Mobile Architecture (Flutter 3.x / Android)

The root project is a native Flutter cross-platform mobile application configured for building **Android App Bundles (`.aab`)** for Google Play distribution and **APKs (`.apk`)** for direct device installation.

### UI & Features (Matching Mockup Designs)
- **VIBELIVE Home Feed:**
  - Story circles with glowing gradient borders ("You", "Khalid", "Maya", "Leo", "Aiko", "Lena").
  - Category filter pills ("Popular", "Discover", "New", "Battle").
  - Live broadcast hero cards with viewer metrics (`100M`, `24.2K` diamonds), streamer details, and "Follow" button.
- **Interactive Live Stream Screen:**
  - Full-screen live video stream overlay.
  - Live incoming chat comments with animated bubbles.
  - Floating action buttons: Heart reaction counter (`12.5K`), comment counter (`8965`), and share.
  - Bottom comment input bar with gift icon.
- **Real-Time Direct & Group Messaging:**
  - Online presence indicators.
  - Blue pill message bubbles for sender, dark grey bubbles for recipient.
  - Read receipts with timestamps and double checkmarks (`10:00am ✔✔`).
  - Audio and video call headers.
- **Unified Identity & Experience Modes:**
  - Phone OTP registration with timer countdown.
  - Automatic Connekt Mail generation (`<username>@connekt.me`).
  - Seamless mode switching: **Personal (Common)**, **Professional**, and **Both Modes**.
  - Verified skills, education, work experience, and granular privacy controls.
- **Floating Glassy Bottom Navigation Bar:**
  - Centered glowing gradient camera / live stream broadcast button.

---

## 🏗️ Backend & Database Architecture

- **Backend:** Node.js, Express.js, Socket.IO, Helmet, CORS, Rate Limiting (`connekt/backend`).
- **Database:** PostgreSQL 18 with relational schema, UUID keys (`gen_random_uuid()`), and transactional migrations (`connekt/database`).
- **Web Frontend:** Standalone HTML5 / CSS3 / Vanilla JS single page application (`connekt/frontend`).

---

## 📦 How to Build the Android App Bundle (.aab)

To generate the production Android App Bundle for Google Play Store upload:

```bash
cd c:\Users\KOUSHIKI\Desktop\flutterProject\connekt

# 1. Ensure Flutter dependencies are installed
flutter pub get

# 2. Build the Android App Bundle (.aab)
flutter build appbundle
```

The output bundle will be generated at:
```
build/app/outputs/bundle/release/app-release.aab
```

### To Build a Direct Installable APK:
```bash
flutter build apk
```
The output APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### To Run the Mobile App in Development:
```bash
flutter run
```

---

## 🚀 Running the Backend & Database

1. **Initialize Database:**
   ```bash
   cd c:\Users\KOUSHIKI\Desktop\flutterProject\connekt\database
   node migrate.js
   ```

2. **Start Backend Server:**
   ```bash
   cd c:\Users\KOUSHIKI\Desktop\flutterProject\connekt\backend
   npm start
   ```
   The backend runs on `http://localhost:5000` (or `http://10.0.2.2:5000` when accessed from the Android emulator).

---

## 🧪 Verification & Status
- **Flutter Analyzer:** Ran `flutter analyze` with `No issues found! (0 errors, 0 warnings)`.
- **Backend Test Suite:** Ran `node backend/test_phase1.js` with 100% passing integration tests across authentication, OTP, mode switching, profile editing, and device session management.
