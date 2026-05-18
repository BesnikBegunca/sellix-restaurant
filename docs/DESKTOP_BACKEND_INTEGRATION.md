# Desktop POS ↔ NestJS Backend Integration

**Task 10 — Implementation Report**
Date: 2026-05-18
Flutter analyzer: 78 issues (unchanged baseline)

---

## Overview

This document describes the integration layer connecting the Flutter Desktop POS
to a NestJS backend (`pos_api`). The integration covers:

1. Backend configuration constants
2. Device activation (first-run licensing)
3. Startup routing based on activation state
4. Real outbox-based sync upload to `/sync/push`

All features are additive — no existing screens, schemas, or auth flows were
modified.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  App Startup (main.dart)                                │
│                                                         │
│  ManagerData.load()                                     │
│       ↓                                                 │
│  ActivationService.loadPersistedActivation()            │
│       ├── activated? → verifyActivation() (GET)         │
│       │        ├── 200 OK  → BackgroundSyncService.start│
│       │        ├── 401     → revoke, show ActivationScreen│
│       │        └── network err → continue offline        │
│       └── not activated → show ActivationScreen         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  BackgroundSyncService.triggerSyncNow()                 │
│                                                         │
│  outbox (SQLite) → POST /sync/push → mark synced/failed │
└─────────────────────────────────────────────────────────┘
```

---

## Files Added

| File | Purpose |
|------|---------|
| `lib/config/api_config.dart` | API base URL + endpoint path constants |
| `lib/models/activation_response.dart` | DTO for POST /activation/desktop response |
| `lib/services/activation_service.dart` | Device activation, token management, local persistence |
| `lib/screens/activation_screen.dart` | First-run activation UI (Albanian locale) |

## Files Modified

| File | Change |
|------|--------|
| `lib/services/database_schema.dart` | Added `setActivatedTenant()` + mutable `_activatedBusinessId`/`_activatedBranchId` statics to replace placeholder tenant IDs at runtime |
| `lib/services/background_sync_service.dart` | Real POST /sync/push upload; 401 triggers one token refresh + retry; revokes activation on 4xx refresh failure |
| `lib/main.dart` | Added activation startup check; passes `activated` bool to `PosSystemApp`; starts `BackgroundSyncService` after confirmed activation |
| `test/widget_test.dart` | Passed required `activated: true` to `PosSystemApp` constructor |

---

## Backend Config (`lib/config/api_config.dart`)

```dart
const String kApiBaseUrl               = 'http://localhost:3000/api';
const String kEndpointActivateDesktop  = '/activation/desktop';
const String kEndpointVerifyActivation = '/activation/verify';
const String kEndpointRefreshToken     = '/activation/refresh';
const String kEndpointSyncPush         = '/sync/push';
```

Change `kApiBaseUrl` via `ApiClient.configureBaseUrl()` for staging/production.
The existing `kDefaultApiBaseUrl` in `api_client.dart` is preserved unchanged.

---

## ActivationService (`lib/services/activation_service.dart`)

### Local Persistence Keys (`app_meta` table)

| Key | Value |
|-----|-------|
| `activation_business_id` | businessId from activation response |
| `activation_branch_id` | branchId from activation response |
| `activation_device_id` | Server-assigned device record ID |
| `activation_access_token` | Bearer token for all API calls |
| `activation_refresh_token` | Optional refresh token |
| `activation_license_expires_at` | ISO-8601 expiry, or absent if no expiry |
| `activation_completed` | `'true'` when all required fields are present |

### Methods

```dart
// Restore activation from app_meta at startup
Future<void> loadPersistedActivation()

// First-run: POST /activation/desktop
Future<ActivationResponse> activateDesktop({
  required String activationKey,
  required String branchCode,
})

// Startup check: GET /activation/verify
// Returns false on network error (app continues offline)
// Revokes local activation on 401
Future<bool> verifyActivation()
```

### Device UUID

The device UUID sent in the activation request is the same UUID used by
`AuditContextService` — stored under key `'audit_device_id'` in `app_meta`.
No new UUID mechanism was created.

---

## ActivationScreen (`lib/screens/activation_screen.dart`)

- Shown as `home:` when `activation_completed ≠ 'true'`
- Two fields: **Çelësi i Aktivizimit** (activation key) and **Kodi i Degës** (branch code)
- Loading spinner on submit
- Friendly Albanian error messages for 401, network failure, and generic errors
- On success: calls `BackgroundSyncService.instance.start()`, then pushes `LoginScreen` and removes itself from the navigation stack

---

## Refresh Token Rotation (`activation_service.dart`)

### `refreshActivationToken()`

Called by `BackgroundSyncService` when a sync request returns 401.

1. Reads `activation_refresh_token` from `app_meta`.
2. POSTs `{ refreshToken }` to `POST /activation/refresh` (no Bearer header needed).
3. On success: persists the new `accessToken` + `refreshToken` to `app_meta` and
   updates `ApiClient.setAccessToken(newToken)`.
4. Throws `DioException` on any failure — the caller decides whether to revoke.

### `revokeActivation()`

Sets `_activated = false`, writes `activation_completed = 'false'` to `app_meta`,
and clears the `ApiClient` bearer token. The next app startup routes to
`ActivationScreen`.

### 401 handling in `BackgroundSyncService._handleSyncUnauthorized()`

| Refresh outcome | Action |
|-----------------|--------|
| 200 (success) | New token stored; sync request retried once |
| 4xx server response | `revokeActivation()` called; failure recorded |
| Network error (no response) | No revocation; failure recorded — offline grace |

**Max one retry per sync trigger** — no loop possible because the refresh
attempt happens outside the `_isSyncing` guard.

---

## Tenant ID Replacement (`database_schema.dart`)

Previously, all outbox inserts stamped rows with the placeholder constants
`kLocalBusinessId = 'local-business'` and `kMainBranchId = 'main-branch'`.

After activation:

```dart
// Called by ActivationService._persistActivation() and loadPersistedActivation()
DatabaseSchema.setActivatedTenant(
  businessId: r.businessId,
  branchId:   r.branchId,
);
```

The internal `_activatedBusinessId` / `_activatedBranchId` statics are updated.
All subsequent `syncScopeStamp(deviceId)` calls (used by every sync-critical
`INSERT`) return the real tenant IDs. Existing historical rows with placeholder
values are not back-filled — they retain the values written at insert time.

---

## Sync Upload (`background_sync_service.dart`)

### Request

```
POST /sync/push
Authorization: Bearer <accessToken>
Content-Type: application/json

{
  "events": [
    {
      "uuid": "...",
      "entityType": "sales",
      "entityUuid": "...",
      "operation": "create",
      "payloadJson": { /* decoded — not a string */ },
      "businessId": "...",
      "branchId": "...",
      "deviceId": "...",
      "syncStatus": "pending",
      ...
    }
  ]
}
```

### Expected Response

```json
{
  "accepted":   ["uuid1", "uuid2"],
  "duplicates": ["uuid3"],
  "rejected":   [{"uuid": "uuid4", "reason": "validation_error"}],
  "serverTime": "2026-05-18T12:00:00.000Z"
}
```

### Per-event Handling

| Server bucket | Local action |
|---------------|-------------|
| `accepted` | `markOutboxEventSynced(uuid)` |
| `duplicates` | `markOutboxEventSynced(uuid)` — already on server, safe to clear |
| `rejected` | `markOutboxEventFailed(uuid, reason)` |

### Malformed Response Handling

The parser (`_parseSyncPushResponse`) validates the response strictly before
applying any state changes:

- `accepted`, `duplicates`, `rejected` must all be present and be arrays
- Every item in `accepted` / `duplicates` must be a `String`
- Every item in `rejected` must be a `Map` with a `String` `uuid` key

If any check fails → `_backoff.recordFailure()`, **zero events are marked** —
the batch remains fully pending for the next retry. This prevents partial state
corruption (some events marked synced while others are lost).

### Debug Logging

In debug builds, each sync attempt logs:

```
BackgroundSyncService: push complete — accepted=2 duplicates=1 rejected=0
BackgroundSyncService: malformed response — batch failed, no events marked
BackgroundSyncService: network error: DioException [...]
```

### Backoff

`SyncBackoffPolicy` tracks consecutive failures (network errors, malformed
responses, exceptions) up to 5 attempts. Resets on a successful batch or empty
queue. Retries are triggered naturally by connectivity-change events.

### Guards

| Guard | Effect |
|-------|--------|
| Offline | Skip |
| Already syncing | Skip (no concurrent uploads) |
| Not activated | Skip (no Bearer token) |
| Malformed response | Record failure, no partial marks |

---

## Startup Flow

```
main()
  │
  ├─ ManagerData.load()
  ├─ ConnectivityService.initialize()
  ├─ BackgroundSyncService.initialize()   ← wires connectivity listener
  ├─ ActivationService.loadPersistedActivation()
  │      └─ if completed: set token + tenant IDs in memory
  │
  ├─ if activated:
  │    ├─ verifyActivation()  [GET /activation/verify]
  │    │    ├─ 200  → activated = true
  │    │    ├─ 401  → activated = false (token revoked)
  │    │    └─ err  → activated = true  (offline grace)
  │    └─ if activated: BackgroundSyncService.start()
  │
  └─ runApp(PosSystemApp(activated: activated))
         └─ home: activated ? LoginScreen : ActivationScreen
```

---

## What Was Not Implemented

| Requirement | Status |
|-------------|--------|
| Real-time WebSocket sync | Out of scope |
| Pull sync (server → device) | Out of scope |
| Mobile dashboard | Out of scope |
| Re-activation UI (change credentials after activation) | Not requested |
| Server-side refresh token revocation | Stateless JWT limitation — document in `11_DEVICE_REFRESH_TOKEN_ROTATION.md` |

---

## Manual Test Checklist

### First-run (unactivated device)

- [ ] Launch app — ActivationScreen is shown, not LoginScreen
- [ ] Submit empty fields — shows Albanian validation message
- [ ] Submit invalid key — shows "Çelësi i aktivizimit ose kodi i degës është i pasaktë."
- [ ] Submit with server offline — shows network error message
- [ ] Submit valid key + branch code — navigates to LoginScreen

### Returning activated device

- [ ] Launch with backend online — verify succeeds, LoginScreen shown
- [ ] Launch with backend offline — LoginScreen shown (offline grace)
- [ ] Launch with expired/revoked token (backend returns 401) — ActivationScreen shown

### Token refresh

- [ ] Activate device — `activation_refresh_token` stored in `app_meta`
- [ ] Force access token expired (shorten `DEVICE_JWT_EXPIRES_IN` to `1s` in backend env)
- [ ] Trigger sync — 401 received from `/sync/push`
- [ ] `_handleSyncUnauthorized()` calls `POST /activation/refresh`
- [ ] New tokens persisted to `app_meta`; sync retried once; outbox event synced
- [ ] Verify only ONE retry attempt is made (no infinite loop)
- [ ] Force refresh token invalid (tamper stored token in DB viewer)
- [ ] Sync returns 401 → refresh returns 401 → `revokeActivation()` called → next startup shows `ActivationScreen`
- [ ] Simulate server offline during refresh → network error → activation NOT revoked → events stay `pending`

### Sync upload

- [ ] Create a sale while activated + online — outbox event synced on next trigger
- [ ] Verify `accepted` UUIDs marked `syncStatus = 'synced'` in SQLite
- [ ] Re-send same UUID → server returns in `duplicates[]` → still marked synced locally
- [ ] Send event with unknown entityType → server returns in `rejected[]` → marked failed locally
- [ ] Debug log shows `accepted=N duplicates=N rejected=N` for each batch
- [ ] Simulate server 5xx — `_backoff.failureCount` increments, no events marked
- [ ] Simulate malformed response (`{"results": [...]}`) — `_backoff.failureCount` increments, no events marked
- [ ] Simulate network timeout — `_backoff.failureCount` increments, events remain `pending`
- [ ] After 5 failures — `_backoff.exhausted = true`; successful batch resets it

---

## Next Step

Add fiscal/receipt compliance layer or implement refresh token rotation.
