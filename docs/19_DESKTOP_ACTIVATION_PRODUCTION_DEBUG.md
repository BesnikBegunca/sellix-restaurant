# Desktop Activation — Production Debug Guide

Reliable first-run activation against the Railway production API, with a clear
local reset path and debug logging.

---

## Production API

| Item | Value |
|------|-------|
| Base URL | `https://posapi-production-a6e7.up.railway.app` |
| Health | `GET /health` |
| Validate key | `POST /activation/validate-key` |
| Activate desktop | `POST /activation/desktop` |

No `/api` prefix — paths are rooted at the host above.

---

## Run against Railway

### VS Code (recommended)

Launch config **"POS System – Railway production API"** in `.vscode/launch.json`
sets `POS_API_BASE_URL` for the Flutter process only.

### Terminal (macOS)

```bash
POS_API_BASE_URL=https://posapi-production-a6e7.up.railway.app flutter run -d macos
```

### Release bundle

Place `app_config.json` beside the executable:

```json
{
  "apiBaseUrl": "https://posapi-production-a6e7.up.railway.app"
}
```

See `release/app_config.example.json`.

---

## Startup verification

In the debug console you should see:

```
POS API: baseUrl=https://posapi-production-a6e7.up.railway.app | source=app_config.json or POS_API_BASE_URL
```

If you see `fallback (localhost — production keys will NOT work)`, the app is
still on `http://127.0.0.1:3000`. Fix the launch config or env var before testing
production keys.

The Activation screen shows the same URL and an orange warning when localhost
is active.

---

## Reset local activation

Clears **only** activation/sync metadata in `app_meta` — **not** sales or SQLite
business data.

### From Sync Diagnostics

1. Open **Sync Diagnostics** (manager settings).
2. Tap **Rivendos aktivizimin lokal**.
3. Confirm → app navigates to **ActivationScreen**.

### From Activation screen (debug builds only)

Tap **Rivendos aktivizimin lokal** at the bottom of the card.

### Keys cleared

| Key | Purpose |
|-----|---------|
| `activation_completed` | Routing flag |
| `activation_access_token` | Bearer token |
| `activation_refresh_token` | Refresh token |
| `activation_business_id` | Tenant |
| `activation_branch_id` | Branch |
| `activation_device_id` | Server device id |
| `activation_license_expires_at` | License expiry |
| `sync_pull_cursor` | Pull cursor |
| `sync_last_error` | Last sync error |
| `ApiClient` bearer | In-memory HTTP auth |

`audit_device_id` (local device UUID) is **kept** so the same physical machine
re-activates with a stable fingerprint.

---

## Activation flow (desktop)

1. **Verifiko çelësin** → `POST /activation/validate-key`
   - Body: `{ "activationKey": "POS-..." }`
   - UI shows `businessName`, `branchName`, `licenseStatus`
2. Enter **Kodi i Degës** (must match the branch `code` in production DB —
   not the display name "Kaçanik")
3. **Aktivizo terminalin** → `POST /activation/desktop`

---

## Expected request bodies

### Validate key

```json
{
  "activationKey": "POS-D8CK-W9K4-TRR3"
}
```

Example response:

```json
{
  "valid": true,
  "businessName": "Punto Lavazza",
  "branchName": "Kaçanik",
  "licenseStatus": "active",
  "licenseExpiresAt": "2027-05-19T01:10:55.207Z"
}
```

### Activate desktop

Production API expects **exactly**:

```json
{
  "activationKey": "POS-D8CK-W9K4-TRR3",
  "branchCode": "<code from admin panel>",
  "deviceUuid": "<stable local UUID from audit_device_id>",
  "deviceName": "MacBook-Pro.local",
  "platform": "macos"
}
```

> **Note:** The field is `deviceUuid`, not `deviceFingerprint`. `platform` is
> required (e.g. `macos`, `windows`, `linux`).

Example success response (tokens redacted in app logs):

```json
{
  "businessId": "...",
  "branchId": "...",
  "deviceId": "...",
  "accessToken": "...",
  "refreshToken": "...",
  "licenseExpiresAt": "..."
}
```

---

## Debug logging (activation only)

On **Verifiko** / **Aktivizo**, debug builds log:

- `baseUrl`
- `endpoint`
- request `bodyKeys` (never token values)
- response `status` + sanitized `body` (`accessToken` / `refreshToken` → `<redacted>`)

---

## Common errors

| Symptom | Cause | Fix |
|---------|-------|-----|
| Production key fails; log shows `127.0.0.1:3000` | Localhost fallback | Set `POS_API_BASE_URL` or `app_config.json` |
| Validate OK, activate 404 "Branch with code … not found" | Wrong `branchCode` | Use branch **code** from admin/DB, not display name |
| `deviceUuid must be a string` | Missing/wrong body fields | Use desktop build with correct DTO (see above) |
| 403 on verify/sync | License suspended | Contact admin; check `licenseStatus` on validate |
| Connection error | Offline / firewall | `curl` `/health`; check macOS network entitlement |
| Stale activation after failed test | Old tokens in `app_meta` | **Rivendos aktivizimin lokal** |

---

## Manual test checklist

- [ ] **Reset** — Sync Diagnostics → Rivendos aktivizimin lokal → ActivationScreen
- [ ] **Run** — `POS_API_BASE_URL=https://posapi-production-a6e7.up.railway.app flutter run -d macos`
- [ ] **Log** — startup shows Railway URL (not localhost)
- [ ] **Key** — enter `POS-D8CK-W9K4-TRR3` → Verifiko → shows **Punto Lavazza** / **Kaçanik**
- [ ] **Branch code** — enter correct production `branchCode` → Aktivizo
- [ ] **Login** — app reaches PIN / Login screen
- [ ] **Restart** — quit and relaunch → still activated (Login, not Activation)
- [ ] **Reset again** — Rivendos → ActivationScreen; local sales still present

---

## curl smoke tests

```bash
# Health
curl -sS https://posapi-production-a6e7.up.railway.app/health

# Validate
curl -sS -X POST https://posapi-production-a6e7.up.railway.app/activation/validate-key \
  -H 'Content-Type: application/json' \
  -d '{"activationKey":"POS-D8CK-W9K4-TRR3"}'
```

---

## Files

| File | Role |
|------|------|
| `lib/services/runtime_config_service.dart` | Resolves base URL |
| `lib/services/activation_service.dart` | validate + activate + reset |
| `lib/screens/activation_screen.dart` | Two-step UI + localhost warning |
| `lib/screens/sync_diagnostics_screen.dart` | API info + reset button |
| `lib/services/activation_api_log.dart` | Debug logging (no tokens) |
| `lib/services/activation_error_message.dart` | User-facing errors |
| `.vscode/launch.json` | Railway vs local launch configs |
