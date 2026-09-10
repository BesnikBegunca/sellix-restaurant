# POS System

Flutter POS client with an external licensing/synchronisation API.

## External API

The desktop app does not connect directly to PostgreSQL or Firebase. The API
configured in `app_config.json` is the security boundary; it can use PostgreSQL,
Firebase, or another database on the server side without shipping database
credentials in the app.

Copy `release/app_config.example.json` to `app_config.json` beside the
executable (or set `POS_API_BASE_URL`) and use HTTPS in production.

## Developer license access

The activation and POS login screens expose **Developer access / Hyrje
developer**. The developer signs in with an API developer account, enters the
owner's license key, and submits the number of days to add.

The API must provide:

- `POST /developer/auth/login` with `{ "email": "...", "password": "..." }`
  returning `{ "accessToken": "...", "developerName": "..." }`.
- `POST /developer/licenses/extend` with a developer bearer token and
  `{ "licenseKey": "...", "days": 30 }`, returning
  `{ "licenseKey": "...", "licenseExpiresAt": "..." }`.

The server must enforce developer role/permissions, validate the day range
(the client accepts 1–3650), audit the change, and calculate the new expiry on
the server. Developer tokens are held in memory only by the client.

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
