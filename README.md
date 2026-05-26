# CVAI — CCTV AI Attendance System

A Flutter mobile app for the **CVAI** AI attendance system. It pairs with a
Raspberry Pi 5 device over Bluetooth, then manages cameras, students,
attendance records, and alert rules.

> **This is a UI-only prototype.** All data is mock / in-memory. There are no
> real network calls, BLE, auth, or backend SDKs.

## Design system

Notion-style: light blue + white, soft shadows, rounded corners, Inter font.
Tokens live in `lib/theme/` (`app_colors.dart`, `app_text_styles.dart`,
`app_theme.dart`).

## App flow

```
Login → BLE Scan → BLE Pair → WiFi Setup → Provisioning Success
      ↘ Skip to App (Dev) ↘
                            Home (bottom-nav shell)
                            ├─ Dashboard
                            ├─ Attendance
                            ├─ Cameras
                            ├─ Users
                            └─ Settings
```

## Structure

- `lib/theme/` — colors, text styles, `ThemeData`
- `lib/widgets/` — reusable components (buttons, cards, pills, avatars, nav)
- `lib/models/` — plain Dart models
- `lib/data/mock_data.dart` — all hardcoded demo data
- `lib/screens/` — 25 screens grouped by feature area

## Run

```bash
flutter pub get
flutter run
```

Use **"Skip to App (Dev)"** on the login screen to jump straight to the
dashboard.
