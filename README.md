# Attendance App (Multi-User, Multi-Employee)

Offline face-attendance app. Everything is stored locally on the phone — no API/server.

## Features
- Signup + Login (password protected), multiple owner profiles on one device
- Quick "Switch profile" between accounts
- Each owner's employees & records are completely separate
- Live in-app camera (no separate camera app opens)
- Real-time face detection: border turns GREEN and auto-captures when a face is found
- Front camera by default, switch to back if needed
- Register an employee with name + live face capture
- Punch In / Punch Out with live face verification
- Per-employee attendance history (grouped by date)
- Today's summary (first In / last Out per employee)

## How to run
1. Make sure **Android SDK Platform 36** is installed
   (Android Studio → SDK Manager → SDK Platforms → Android 16 / API 36).
2. In the project folder:
   ```
   flutter clean
   flutter pub get
   flutter run
   ```
First build downloads Gradle 8.11.1 — be patient.

## Versions used
- compileSdk / targetSdk: 36, minSdk: 21
- AGP 8.9.1, Gradle 8.11.1, Kotlin 2.1.0, Java 17

## Note on face matching
Uses live face **detection** (a real face present + eyes), robust to beard/look
changes. Auto biometric **recognition** (identifying WHICH person) needs a heavier
ML model, addable later with an API/server.

## Where data lives
SharedPreferences keys: `users`, `employees`, `records`, `session`.
