# Desktop Online API Test

Validates that the Flutter Desktop POS can activate, push sync, and pull sync
against the deployed Railway production API.

---

## Production API

| Field | Value |
|-------|-------|
| Base URL | `https://posapi-production-a6e7.up.railway.app` |
| Health check | `GET /health` → `{"status":"ok"}` |
| Activation | `POST /activation/desktop` |
| Verify | `GET /activation/verify` |
| Refresh | `POST /activation/refresh` |
| Push sync | `POST /sync/push` |
| Pull sync | `GET /sync/pull` |

---

## Config Setup

### macOS development (VS Code — recommended)

Two launch configurations are defined in `.vscode/launch.json`:

| Config | API |
|--------|-----|
| **POS System – local backend** | `http://127.0.0.1:3000` (default fallback) |
| **POS System – Railway production API** | Railway via `POS_API_BASE_URL` env var |

Select **"POS System – Railway production API"** from the VS Code Run menu
(or the Flutter DevTools device selector) and press F5. No file changes needed.

The env var is set only for the Flutter process launched by VS Code — your
shell environment is unaffected.

### macOS development (terminal)

```bash
POS_API_BASE_URL=https://posapi-production-a6e7.up.railway.app flutter run -d macos
```

### Windows release (installer)

`release/app_config.json` is bundled beside the executable by the Inno Setup
installer script (`windows/installer/pos_system.iss`). No env var needed on
the deployed machine.

```json
{
  "apiBaseUrl": "https://posapi-production-a6e7.up.railway.app"
}
```

---

## Verifying Startup Logs

Open the debug console immediately after launch. You should see:

```
RuntimeConfigService: source = env var (POS_API_BASE_URL)
RuntimeConfigService: resolved API base URL = https://posapi-production-a6e7.up.railway.app
```

If you see `http://127.0.0.1:3000` instead, the env var was not passed — check
the launch config selection in VS Code.

Every outgoing request is also logged:

```
API REQUEST:
  baseUrl=https://posapi-production-a6e7.up.railway.app
  path=/activation/desktop
  full=https://posapi-production-a6e7.up.railway.app/activation/desktop
API ← 201 https://posapi-production-a6e7.up.railway.app/activation/desktop
```

---

## Activation Test

### Prerequisites

1. Obtain an `activationKey` and matching `branchCode` from the production
   database (Prisma Studio or direct Neon query).
2. If the device was previously activated against localhost, open the Sync
   Diagnostics dialog and tap **"Çaktivizo këtë pajisje"** → confirm.
   This clears all stored tokens before re-activating.

### Steps

1. Launch app with Railway config (see above).
2. Activation Screen appears.
3. Enter production `activationKey` and `branchCode`.
4. Tap **Aktivizo**.

### Expected

- App navigates to Login Screen.
- Debug log shows:
  ```
  API ← 201 .../activation/desktop
  ```
- Open Sync Diagnostics — verify:
  - **Status**: Active
  - **Business ID**: matches production record
  - **Branch ID**: matches production record
  - **Device ID**: the server-assigned device UUID

---

## Push Sync Test

### Steps

1. Log in as cashier → create a sale (add products, confirm payment).
2. Open Sync Diagnostics — **Pending events** count increases.
3. Wait for background push (≈ 30 s) or tap **Retry Sync Now**.

### Expected

- Pending count drops to 0.
- **Last push** timestamp updates (e.g. "Just now").
- Debug log:
  ```
  API ← 200 .../sync/push
  BackgroundSyncService: push complete — accepted=N duplicates=0 rejected=0
  ```
- Verify in Neon (Prisma Studio or psql):
  ```sql
  SELECT * FROM "Sale" ORDER BY "createdAt" DESC LIMIT 5;
  SELECT * FROM "SyncEvent" ORDER BY "receivedAt" DESC LIMIT 5;
  ```

---

## Pull Sync Test

### Steps

1. In Prisma Studio (or Neon SQL editor), update a product name or price
   directly in the `Product` table, bumping `updatedAt` to `NOW()`.
2. In the POS desktop app, open Sync Diagnostics → tap **Retry Sync Now**
   (or wait for the next auto-pull cycle).

### Expected

- **Last pull** timestamp updates.
- Debug log:
  ```
  BackgroundSyncService: pull complete — entities=N upserted=N skipped=0
  ```
- The changed product name/price is visible in the POS product grid.

---

## Diagnostics Test

Open Sync Diagnostics after a successful push + pull cycle:

| Field | Expected |
|-------|----------|
| Status | Active (green) |
| Network | Online (green) |
| Business ID | Matches production record |
| Branch ID | Matches production record |
| Device ID | Matches production record |
| Pending events | 0 |
| Failed events | 0 |
| Last push | < 5 min ago |
| Last pull | < 5 min ago |
| Last success | < 5 min ago |
| Pull cursor | ISO-8601 timestamp (not "—") |

---

## Common Errors

### `DioExceptionType.connectionError`

- Confirm env var is set: check startup log for `resolved API base URL`.
- Confirm Railway service is running: `curl https://posapi-production-a6e7.up.railway.app/health`.
- macOS: ensure `com.apple.security.network.client` entitlement is present
  (already added in task 16, confirmed in `macos/Runner/DebugProfile.entitlements`).

### `401 Unauthorized` on activation

- The `activationKey` has already been used on another device, or the key is
  expired. Generate a new key from the production database.

### `401` on push/pull after successful activation

- Access token expired and refresh was rejected (key revoked server-side).
- The app will call `revokeActivation()` automatically and stop syncing.
- Re-activate using a fresh key.

### Push rejected events (`rejected` > 0)

- Check the **Recent Failed Events** section in Sync Diagnostics.
- The event's `lastError` field shows the server rejection reason.
- Tap **Clear Resolved** to remove successfully synced rows from the outbox view.

### Pull cursor not advancing

- The server returned a malformed response — check Railway logs.
- The cursor is only persisted after a successful SQLite transaction; a failed
  pull leaves the cursor unchanged so the same batch will be retried.

---

## Manual Test Checklist

### Config

- [ ] Launch with "POS System – Railway production API" config in VS Code
- [ ] Startup log shows `resolved API base URL = https://posapi-production-a6e7.up.railway.app`
- [ ] Every API request log shows Railway URL as `baseUrl`

### Activation

- [ ] Deactivate existing local activation via Sync Diagnostics (if needed)
- [ ] Enter production activation key + branch code
- [ ] App navigates to Login Screen
- [ ] Sync Diagnostics shows correct Business ID / Branch ID / Device ID
- [ ] Status chip shows "Sinkronizuar" (green)

### Push sync

- [ ] Create a sale in POS
- [ ] Sync Diagnostics shows pending count > 0
- [ ] Pending count drops to 0 after sync
- [ ] Sale appears in Neon `Sale` table
- [ ] `SyncEvent` row recorded in Neon

### Pull sync

- [ ] Modify a product in Prisma Studio / Neon
- [ ] Trigger pull via Retry Sync Now
- [ ] Change is visible in POS product list
- [ ] Pull cursor advances (new value in Sync Diagnostics)

### Diagnostics

- [ ] All fields populated (no "—" in IDs or timestamps after first sync)
- [ ] "Retry Sync Now" triggers both push and pull without error
- [ ] "Clear Resolved" removes synced rows from outbox view

---

## Files Added / Changed

| File | Change |
|------|--------|
| `release/app_config.json` | Production Railway URL (gitignored) |
| `.vscode/launch.json` | Two launch configs: local and Railway |
| `.gitignore` | `release/app_config.json` excluded |
| `docs/18_DESKTOP_ONLINE_API_TEST.md` | This file |

---

## Next Step

Code signing + auto-update:
- Sign `pos_system.exe` and the Inno Setup installer with an EV/OV certificate
- Evaluate Squirrel.Windows or a custom update endpoint for in-app update checks
