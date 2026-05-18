# Production API Config

Replaces the hardcoded `http://localhost:3000/api` with a runtime-resolved
base URL. No changes to activation, sync, or backend.

---

## Problem

The app had a hardcoded localhost URL as the only API base. Deploying to
production required a code change and rebuild.

---

## Files Changed

| File | Action |
|------|--------|
| `lib/services/runtime_config_service.dart` | Created — resolves API base URL from file, env var, or fallback |
| `lib/services/api_client.dart` | Fixed `configureBaseUrl()` trailing-slash bug; updated doc comment |
| `lib/config/api_config.dart` | Updated `kApiBaseUrl` doc comment to reference `RuntimeConfigService` |
| `lib/main.dart` | Loads config and applies to `ApiClient` at startup |

---

## Config Source Priority

1. **`app_config.json` beside the executable** — checked first
2. **`POS_API_BASE_URL` environment variable** — checked if file is absent
3. **Fallback** `http://localhost:3000/api` — used when neither is set; a
   warning is printed in debug mode

---

## `app_config.json` Format

Place this file in the same directory as the Windows executable:

```json
{
  "apiBaseUrl": "https://api.yourdomain.com/api"
}
```

The file is optional. If absent or malformed, the next source in the priority
list is tried.

---

## `RuntimeConfigService`

Located at `lib/services/runtime_config_service.dart`. Singleton.

### API

| Method / Getter | Returns |
|-----------------|---------|
| `load()` | `Future<void>` — reads file / env, sets `apiBaseUrl` |
| `reloadConfig()` | `Future<void>` — alias for `load()` |
| `apiBaseUrl` | `String` — resolved URL (no trailing slash) |
| `getApiBaseUrl()` | `String` — same as `apiBaseUrl` getter |
| `isUsingFallback` | `bool` — `true` when localhost fallback is active |

### Validation

A URL is accepted only when:
- Non-empty after trimming
- Starts with `http://` or `https://`

Trailing slashes are stripped. Invalid values are logged in debug mode and
silently skipped in favor of the next source.

---

## `ApiClient.configureBaseUrl()` Fix

**Bug (before):** The method added a trailing slash unconditionally:
```dart
_baseUrl = trimmed.endsWith('/') ? trimmed : '$trimmed/';
```
This created double-slash URLs like `http://localhost:3000/api//activation/desktop`.

**Fix (after):** Strips any trailing slashes:
```dart
_baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
```

---

## Startup Wiring (`main.dart`)

```dart
// Resolve API base URL — must run before any network call.
await RuntimeConfigService.instance.load();
ApiClient.instance.configureBaseUrl(RuntimeConfigService.instance.apiBaseUrl);
```

These two lines run before `ConnectivityService`, `BackgroundSyncService`,
and `ActivationService` initializations, so all subsequent network calls use
the resolved URL.

---

## Packaging for Windows

1. Build the release executable normally (`flutter build windows --release`).
2. Place `app_config.json` beside `pos_system.exe` in the output directory.
3. No rebuild required — the URL is read at runtime each launch.

Example directory layout:

```
Release/
  pos_system.exe
  app_config.json          ← add this file
  flutter_windows.dll
  ...
```

---

## What Was Not Changed

- Activation logic (`ActivationService`, `ActivationScreen`)
- Sync logic (`BackgroundSyncService`, `PullSyncApplyService`)
- Any backend endpoint
- Any POS sales, payment, or product flow

---

## Manual Test Checklist

- [ ] App starts without `app_config.json` — uses localhost fallback; debug log shows "WARNING — using fallback localhost URL"
- [ ] Place `app_config.json` with a valid URL beside executable — app uses that URL on next launch
- [ ] Place `app_config.json` with an invalid URL (no `http://` prefix) — falls through to env var / fallback
- [ ] Set `POS_API_BASE_URL=https://staging.example.com/api` env var — app uses it when no valid file exists
- [ ] Trailing slash in config file (`https://api.example.com/api/`) — stripped correctly
- [ ] `isUsingFallback` is `false` when file or env var was used
- [ ] Activation and sync endpoints are called with the resolved base URL (inspect debug logs)
- [ ] `reloadConfig()` picks up a new `app_config.json` placed after startup

---

## Next Step

- Add `SyncStatusService.instance.stop()` on logout / deactivation
- Configure Windows installer to bundle `app_config.json` with the correct
  production URL
