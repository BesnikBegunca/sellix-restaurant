# Desktop Support Bundle Export

Structured, non-sensitive diagnostics export for remote troubleshooting when
a client reports sync or activation issues without giving support direct machine access.

---

## Why this exists

Sync Diagnostics already shows runtime state and can copy failed-outbox JSON.
A **support bundle** collects app, API, activation, sync, outbox, database health,
and printer settings in one file — with secrets redacted.

---

## How to export

1. Open **Sync Diagnostics** (manager).
2. Click **Eksporto support bundle**.
3. Choose save location (file picker) or accept default under app Documents.
4. Send `pos_support_bundle_YYYYMMDD_HHMMSS.json` to support (email, ticket).

---

## File name and location

| Pattern | Example |
|---------|---------|
| `pos_support_bundle_YYYYMMDD_HHMMSS.json` | `pos_support_bundle_20260519_143022.json` |

- **Preferred:** user-selected path via `file_picker` save dialog.
- **Fallback:** `{ApplicationDocumentsDirectory}/pos_support_bundle_*.json`

---

## What is included

| Section | Contents |
|---------|----------|
| **app** | Version, build, OS, platform, release/debug |
| **apiConfig** | baseUrl, source, fallback/localhost/blocked flags |
| **activation** | completed, IDs, business name, license expiry, token **presence only** |
| **sync** | outbox counts, last push/pull/success/error, cursor, backoff, connectivity |
| **failedOutboxEvents** | Full failed list with redacted payloads |
| **recentOutboxEvents** | Last 20 outbox rows (any status) |
| **recentAuditLogs** | Last 20 audit rows (redacted details) |
| **rejectedReasons** | Unique `lastError` strings from failed events |
| **database** | `PRAGMA integrity_check`, schema version, file size |
| **printer** | configured yes/no, name, ESC/POS, cash drawer |

**Not included:** full sales history, access/refresh tokens, PIN/password hashes.

---

## What is redacted

Keys containing (case-insensitive):

- `token`, `password`, `pin`, `hash`, `secret`, `activationKey`, `activation_key`

Replaced with `"<redacted>"` in nested JSON payloads and maps.

Activation section uses booleans only: `accessTokenPresent`, `refreshTokenPresent`.

---

## How support should use it

1. Confirm **apiConfig** — correct Railway URL, not localhost fallback in release.
2. Check **activation** — `activationCompleted`, IDs, token presence.
3. Read **sync.lastError** and **failedOutboxEvents** / **rejectedReasons**.
4. Verify **database.integrityOk** and reasonable **databaseSizeBytes**.
5. Compare **sync.pullCursor** and timestamps with server logs (same tenant/device).

Do not ask customers to paste token values — they are not in the bundle.

---

## Manual test checklist

- [ ] Open Sync Diagnostics → **Eksporto support bundle**
- [ ] File created; path shown in snackbar
- [ ] JSON is valid (parse in editor)
- [ ] No `accessToken`, `refreshToken`, passwords, or PIN hashes in file
- [ ] Failed outbox events present when failures exist
- [ ] API URL and config source present
- [ ] `database.integrityCheck` present
- [ ] Works offline
- [ ] Works when device not activated

---

## Files

| File | Role |
|------|------|
| `lib/services/support_bundle_service.dart` | Collect + save |
| `lib/services/support_bundle_redaction.dart` | Redaction helpers |
| `lib/screens/sync_diagnostics_screen.dart` | Export button |
| `lib/config/app_version_info.dart` | Version labels (sync with pubspec) |

---

## Unchanged

- Sync push/pull behavior
- API contracts
- Mobile apps
