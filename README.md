#  Offline Password Manager

A simple **offline password manager** built with **Flutter**.  
Designed to be lightweight, fully local, and focused on privacy — no cloud, no tracking, no ads.

This is a personal project to explore Flutter development and local data encryption.  
It stores your passwords securely using AES encryption and lets you manage them easily on your Android device.

---

## Features

- Offline storage (no internet permission)
- AES encryption for passwords  
- Biometric unlock (fingerprint or PIN)
- Copy username or password to clipboard
- Add, edit, and delete accounts
- Local SQLite database
- Simple and minimal Material UI

---

## Tech Stack

| Layer | Technology |
|:------|:------------|
| UI | Flutter (Material Design) |
| Local DB | Sqflite |
| Encryption | AES via `encrypt` + `flutter_secure_storage` |
| Auth | `local_auth` (biometrics) |
| Platform | Android |

---

## Screenshots

*(Coming soon)*

---

## Project Structure
lib/
├─ main.dart
├─ models/
│ └─ account.dart
├─ data/
│ └─ db_helper.dart
├─ services/
│ ├─ encryption_service.dart
│ └─ auth_service.dart
├─ screens/
│ ├─ home_screen.dart
│ ├─ add_edit_screen.dart
│ └─ lock_screen.dart
└─ widgets/
└─ account_tile.dart

---

## Getting Started

### 1. Clone the repo
```bash
git clone https://github.com/<your-username>/offline-password-manager.git
cd offline-password-manager

### 2. Install Dependencies
```bash
flutter pub get

#### 3. Run the app
```bash
flutter run