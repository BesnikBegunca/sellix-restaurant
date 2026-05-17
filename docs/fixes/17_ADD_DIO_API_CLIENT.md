# 17 — Add Dio API Client Foundation

## Problem

The app could detect **link-level** connectivity (`ConnectivityService`) and queue
local mutations in the **outbox**, but had no shared HTTP layer for a future NestJS
backend. Without a central client, sync and auth would sprawl into ad-hoc `http`
calls, duplicated timeouts, and inconsistent headers.

## Risk

| Scenario | Problem without ApiClient |
|---|---|
| Future sync service | Every feature invents its own HTTP stack |
| Auth token handling | Bearer header logic copied in multiple places |
| Timeouts / JSON | Inconsistent error handling and parsing |
| Environment URLs | Production hosts hardcoded in UI or managers |

## Files Changed

| File | Change type |
|---|---|
| `pubspec.yaml` | Added `dio` dependency |
| `lib/services/api_client.dart` | New singleton HTTP foundation |

## Package Added

**`dio: ^5.8.0+1`** — configurable HTTP client with interceptors.

## ApiClient Behavior

**Singleton:** `ApiClient.instance`

| Concern | Implementation |
|---|---|
| **baseUrl** | Default `kDefaultApiBaseUrl` = `http://localhost:3000/api`; override via `configureBaseUrl()` |
| **Timeouts** | connect 15s, receive 30s, send 30s |
| **Headers** | `Accept` and `Content-Type`: `application/json` |
| **Response** | `ResponseType.json` |
| **Token** | `setAccessToken` / `clearAccessToken`; request interceptor adds `Authorization: Bearer …` when set |
| **Interceptors** | Request (auth + debug log), response (debug log), error (debug log) — logs only in `kDebugMode` |
| **HTTP verbs** | `get`, `post`, `put`, `delete` — thin wrappers over `dio` |

`Dio` is created **lazily** on first access to `.dio` or any verb method. No
request runs at app startup.

## What Was Not Changed

- **UI** — unchanged.
- **Backend** — no real endpoints called.
- **Auth / login flow** — token API exists but is unused.
- **Outbox processing** — not wired to HTTP.
- **Sync engine** — not implemented.
- **`main.dart`** — no automatic API initialization or calls.
- **Offline POS** — unchanged.

## Manual Test Checklist

- [ ] Run `flutter pub get`
- [ ] `ApiClient.instance.dio` builds without throwing (lazy init)
- [ ] No API calls on app launch (no requests in debug log)
- [ ] `setAccessToken('test')` then `clearAccessToken()` — no crash
- [ ] App works fully offline (POS unchanged)
- [ ] Run `flutter analyze`

## Next Step

Next task: Add BackgroundSyncService skeleton.
