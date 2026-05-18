# Deactivation / Logout Cleanup

Makes revocation deterministic — all tokens cleared, sync stopped, metadata
reset — without touching any local business data.

---

## Problem

`revokeActivation()` previously only set `activation_completed = 'false'` and
cleared the in-memory `_activated` flag. Refresh tokens, access tokens, tenant
IDs, and sync timestamps remained on disk, and sync services kept running until
the next app restart. Silent failures could pile up on a revoked device.

---

## Files Changed

| File | Action |
|------|--------|
| `lib/services/activation_service.dart` | Expanded `revokeActivation()`; fixed `verifyActivation()` 401 path |
| `lib/services/background_sync_service.dart` | Stops self + `SyncStatusService` after refresh-token rejection |
| `lib/screens/sync_diagnostics_screen.dart` | Added "Çaktivizo këtë pajisje" button with confirm dialog |
| `docs/16_DEACTIVATION_LOGOUT_CLEANUP.md` | This file |

---

## Cleanup Behaviour

### `ActivationService.revokeActivation()`

Clears every activation `app_meta` key and resets in-memory state:

| Cleared | Type |
|---------|------|
| `activation_completed` | Set to `''` |
| `activation_access_token` | Set to `''` |
| `activation_refresh_token` | Set to `''` |
| `activation_business_id` | Set to `''` |
| `activation_branch_id` | Set to `''` |
| `activation_device_id` | Set to `''` |
| `activation_license_expires_at` | Set to `''` |
| `_businessId`, `_branchId`, `_serverDeviceId` | `null` (in-memory) |
| `ApiClient` Bearer token | Cleared |

### Sync Metadata Reset

Cleared by `revokeActivation()` so the next activation starts with a clean slate:

| Key | Action |
|-----|--------|
| `sync_last_error` | Set to `''` |
| `sync_last_push_at` | Set to `''` |
| `sync_last_pull_at` | Set to `''` |
| `sync_last_success_at` | Set to `''` |
| `sync_pull_cursor` | Set to `''` |

### What Is Intentionally Preserved

- All outbox events (pending / failed / synced)
- All local sales, sale lines, sale adjustments
- Products, categories, inventory items, stock movements
- Shifts, expenses
- Audit log
- Receipt / printer configuration

No SQLite tables are dropped or truncated.

---

## Services Stopped

### Manual deactivation (via UI)

Executed in sequence before navigating to `ActivationScreen`:

```dart
BackgroundSyncService.instance.stop();
SyncStatusService.instance.stop();
await ActivationService.instance.revokeActivation();
```

### Token invalidation (backend 401 on refresh)

`BackgroundSyncService._handleSyncUnauthorized()` on a 4xx response:

```dart
await ActivationService.instance.revokeActivation();
stop();                          // BackgroundSyncService self-stop
SyncStatusService.instance.stop();
rethrow;
```

The outer `triggerSyncNow()` / `pullSyncNow()` catch logs a backoff failure.
The `finally` block runs `setSyncingPush(false)` / `setSyncingPull(false)` +
`SyncStatusService.instance.refresh()` which will show "Jo aktivizuar" since
`isActivated` is now `false`.

---

## Deactivation UI

Located in `lib/screens/sync_diagnostics_screen.dart`, accessible by tapping
the sync chip in `ManagerTopBar`.

### "Çaktivizo këtë pajisje" button

- Shown at the bottom of the Sync Diagnostics dialog.
- Disabled when the device is already inactive (`!status.isActivated`).
- Shows a loading spinner while deactivation is in progress.

### Confirm dialog

> **Çaktivizo këtë pajisje?**
>
> Sinkronizimi me cloud do të ndalet.
> Të dhënat lokale të shitjeve dhe produkteve mbeten të paprekura.
> Do të keni nevojë të aktivizoni sërish pajisjen për të rifilluar sinkronizimin.
>
> [Anulo] [Çaktivizo]

On confirmation:

1. `BackgroundSyncService.instance.stop()`
2. `SyncStatusService.instance.stop()`
3. `await ActivationService.instance.revokeActivation()`
4. `Navigator.pushAndRemoveUntil(ActivationScreen)` — full stack replace

---

## Token Invalidation Flow

```
BackgroundSyncService.triggerSyncNow()
  → POST /sync/push → 401
  → _handleSyncUnauthorized()
    → POST /activation/refresh → 4xx
    → revokeActivation()         ← clears all tokens + sync metadata
    → stop()                     ← stops BackgroundSyncService loop
    → SyncStatusService.stop()   ← stops 10s poll timer
    → rethrow
  → outer catch logs backoff failure
  → finally: setSyncingPush(false), SyncStatusService.refresh()
            (shows "Jo aktivizuar")

Next app startup:
  loadPersistedActivation() → activation_completed = '' → returns early
  activated = false → home: ActivationScreen
```

---

## App Startup Consistency

`main.dart` startup path when `activation_completed` is empty/false:

```dart
await ActivationService.instance.loadPersistedActivation(); // no-op
bool activated = false;
// verifyActivation() not called
// BackgroundSyncService.start() not called
SyncStatusService.instance.start(); // runs, shows "Jo aktivizuar"
runApp(PosSystemApp(activated: false)); // home: ActivationScreen
```

`SyncStatusService` runs so the chip is ready when activation succeeds and the
app navigates to the manager screen without restart.

---

## Circular Import Avoidance

`ActivationService` does NOT import `BackgroundSyncService` or
`SyncStatusService`. Callers that manage those services do so explicitly:

```
BackgroundSyncService → ActivationService  (OK, already existed)
BackgroundSyncService → SyncStatusService  (OK, already existed)
Deactivation UI       → all three          (OK, UI layer owns orchestration)
```

---

## Manual Test Checklist

- [ ] Tap sync chip → open Sync Diagnostics → tap "Çaktivizo këtë pajisje"
- [ ] Confirm dialog appears with correct text
- [ ] Cancel → dialog stays open, no state change
- [ ] Confirm → app navigates to ActivationScreen
- [ ] After deactivation: `activation_completed` = `''` in DB (verify via SQLite viewer)
- [ ] After deactivation: `activation_access_token` = `''` in DB
- [ ] After deactivation: `sync_pull_cursor` = `''` in DB
- [ ] After deactivation: outbox events remain (verify row count unchanged)
- [ ] After deactivation: local sales remain (verify via SQLite viewer)
- [ ] Re-activate → app navigates to LoginScreen → sync resumes correctly
- [ ] Token invalidation: block refresh endpoint (return 401) → app stops syncing silently
- [ ] After token invalidation: next restart shows ActivationScreen
- [ ] Verify `isUsingFallback` does not reset on deactivation (runtime config unaffected)
- [ ] No analyzer regressions (flutter analyze: 78 issues)

---

## Next Step

Windows packaging / installer setup:
- Configure Windows installer to bundle `app_config.json` beside the executable
- Set the production `apiBaseUrl` during the install step
- Optionally add a post-install activation launcher that opens `ActivationScreen`
  directly on first run
