# POS System

Flutter POS client that works fully offline. The desktop application does not
require PostgreSQL, Firebase, `posapi`, `app_config.json`, or an internet
connection.

## Local activation

Open **Developer access / Hyrje developer** from the activation or POS login
screen. Enter the owner/business name and the number of days, then generate a
license code. Give that code to the owner.

The owner enters the code in the activation screen, verifies it, enters a
branch code, and activates the terminal. License validation, expiry, and
activation metadata are stored locally in SQLite and secure desktop storage.

The local license code is signed inside the application, so changing the
expiry or payload invalidates it. The accepted duration is 1–3650 days.

## Run

```bash
flutter pub get
flutter run
```

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
