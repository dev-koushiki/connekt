# CONNEKT – AI-Powered Social Networking, Communication & Productivity Platform

**CONNEKT** is an integrated digital ecosystem combining social networking, communication, email, file sharing, meetings, productivity, professional networking, and AI-powered intelligence into one unified platform.

---

## 🏗️ Architecture & Technology Stack

- **Frontend:** HTML5, CSS3, Vanilla JavaScript (ES6+), Glassmorphic Responsive Design System. *(Zero external UI frameworks)*
- **Backend:** Node.js, Express.js, RESTful APIs, Socket.IO, Helmet, CORS, Rate Limiting.
- **Database:** PostgreSQL 15+/18+, `node-postgres` (`pg`), Parameterized SQL, UUID keys (`gen_random_uuid()`), Cascading Constraints & Foreign Keys.
- **Authentication & Security:** JWT Access Tokens, Bcrypt password hashing (10 salt rounds), Cryptographic 6-digit OTP engine, Device & Session Management.

---

## 🚀 Phase 1 Foundation Features Implemented

1. **Unified Identity & Account System:**
   - Phone-number registration with OTP challenge.
   - Unique username selection with real-time availability checking (`@username`).
   - Unique Connekt Mail generation (`<username>@connekt.me`).
   - Bcrypt-hashed secure passwords.
   - Prevention of duplicate phone numbers, usernames, and Connekt Mail addresses.

2. **Three Account Experience Modes:**
   - **Common Mode:** Personal social profile, bio, display name, personal links, location.
   - **Professional Mode:** Career headline, company, industry, summary, portfolio/GitHub/LinkedIn links, Open-to-work / Hiring flags.
   - **Both Mode (Universal Hybrid):** Seamless access to both experiences with an instant mode switcher widget in the top navigation bar.

3. **Profile Management:**
   - Personal profile updates (full name, bio, location, website, birthdate, gender).
   - Avatar upload via Multer with live previews.
   - Professional profile updates.
   - Verified Skills management (add, delete, proficiency rating).
   - Work Experience management (company, title, dates, descriptions).
   - Education management (institution, degree, field of study, years).

4. **Security, Privacy & Device Session Management:**
   - Multi-device active session tracking with User-Agent parsing and IP address recording.
   - Individual session termination and "Revoke All Other Devices" functionality.
   - Granular privacy controls: Profile visibility (Public / Contacts / Private), read receipts toggle, online presence toggle, group invitation approval enforcement, and message request filtering.
   - Password reset via verified phone OTP.

---

## 🛠️ Installation & Setup Guide

### 1. Prerequisites
- **Node.js** (v18+ or v22+)
- **PostgreSQL** (v15+ or v18+) running on port 5432

### 2. Database Initialization
Make sure your PostgreSQL instance is running. The migration script will automatically create the `connekt_db` database if it doesn't already exist and apply all tables, indexes, and triggers:

```bash
cd connekt/database
node migrate.js
```

### 3. Environment Variables
Create or edit `connekt/backend/.env`:

```env
PORT=5000
NODE_ENV=development

# Database (PostgreSQL)
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=root
DB_NAME=connekt_db

# Security & Tokens
JWT_SECRET=connekt_super_secret_jwt_key_phase1_2026_unbreakable_token_signature
JWT_EXPIRES_IN=7d
BCRYPT_SALT_ROUNDS=10

# Domain & OTP Settings
CONNEKT_DOMAIN=connekt.me
OTP_EXPIRY_MINUTES=5
MAX_OTP_ATTEMPTS=5

# SMTP Email Configuration (Optional for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=noreply@connekt.me
SMTP_PASS=app_password_placeholder
SMTP_FROM="CONNEKT Identity <noreply@connekt.me>"

# Client / CORS
CLIENT_URL=http://localhost:5000
```

### 4. Running the Application
To run the server:

```bash
cd connekt/backend
npm start
```

Open your browser and navigate to:
```
http://localhost:5000
```

---

## 🧪 Testing Phase 1 Functionality

### 1. Registration Flow
1. Open `http://localhost:5000`.
2. The **CONNEKT Identity** modal will appear. Select **Create Account**.
3. Enter your phone number (e.g. `+19876543210`) and click **Send OTP**.
4. The 6-digit OTP will appear in the system toast notification (in development mode) and console log.
5. Enter the OTP code.
6. Enter Full Name and Username (e.g. `alex`). Observe the live availability check (`✓ @alex is available`) and auto-generated Connekt Mail preview (`alex@connekt.me`).
7. Enter a password and choose your initial Mode (**Common**, **Professional**, or **Both**).
8. Click **Create My CONNEKT Account**. You will be authenticated immediately.

### 2. Mode Switching
- Use the **Personal | Professional | Both** pills in the top bar to instantly switch experience modes.
- Notice the dashboard hero banner, active mode badges, and views dynamically reflect the active mode.

### 3. Profile Management
- Navigate to **My Profile** in the sidebar.
- Edit your Personal Profile and click **Save**.
- Click **Professional Credentials**, fill in headline and company, and save.
- Go to **Skills & Endorsements**, add skills (e.g. `Node.js`, `PostgreSQL`), and remove skills.
- Go to **Work Experience** and **Education** to add credentials.
- Click **Change Photo** to upload a new profile picture.

### 4. Security & Device Management
- Navigate to **Security & Privacy**.
- Observe your active device session with IP and browser information.
- Toggle **Group Invitation Approval**, **Read Receipts**, and **Online Presence**.
- Save your privacy preferences.

---

## 🗺️ Six-Phase Development Roadmap

- [x] **Phase 1 – Foundation:** Unified Identity, OTP engine, PostgreSQL relational schema, Common & Professional modes, profile credentials, device management.
- [ ] **Phase 2 – Communication:** One-to-one & group messaging, Socket.IO real-time delivery, group invitation approval workflows, read receipts, online presence.
- [ ] **Phase 3 – Social and Community:** Feed, stories, likes & comments, public & private communities, live streaming with audience reactions.
- [ ] **Phase 4 – Connected Services:** Connekt Mail web client, secure file sharing, WebRTC audio/video meetings & screen sharing.
- [ ] **Phase 5 – Productivity and Intelligence:** Centralized Reminder Box, Gemini AI Assistant, Connekt Shield spam & phishing defense.
- [ ] **Phase 6 – Expansion and Optimization:** Professional networking jobs & internships, performance tuning, and audit security testing.
