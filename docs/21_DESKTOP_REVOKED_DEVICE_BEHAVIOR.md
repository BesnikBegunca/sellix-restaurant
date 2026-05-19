# Desktop Revoked Device Behavior

How the Flutter desktop POS handles device revocation vs local deactivation,
and how that maps to **pos_api** (including `PATCH /devices/:id/revoke`).

---

## Two different flows

### A. Local reset (desktop only)

**Trigger:** Operator chooses **“Rivendos aktivizimin lokal”** in Sync Diagnostics.

**What happens:**

1. `BackgroundSyncService.stop()` + `SyncStatusService.stop()`
2. `ActivationService.resetLocalActivation()` — clears tokens and sync metadata in `app_meta`
3. `ActivationStateController.setActivated(false)` — root UI → `ActivationScreen`
4. **No** call to `PATCH /devices/:id/revoke`
5. Local SQLite (sales, products, outbox rows) **unchanged**

**Server:** Device record may still show **active** in SuperAdmin until revoked there.

**UI copy:** Explains that server-side block requires SuperAdmin.

### B. SuperAdmin server revoke

**Trigger:** SuperAdmin (or API) calls:

```http
PATCH /devices/:deviceId/revoke
```

**What happens on desktop (next online API call):**

1. Protected endpoint returns **401** (not 403)
2. Sync may try `POST /activation/refresh` once; if refresh fails with 4xx → revoke path
3. `BackgroundSyncService.stop()` + `SyncStatusService.stop()`
4. `ActivationService.handleRevokedByServer()` — clears local tokens (same as revoke, **no** business data wipe)
5. `ActivationStateController.notifyServerRevoked()` — root UI → `DeviceRevokedScreen`
6. User taps **“Shko te aktivizimi”** → `ActivationScreen`

**No app restart required.**

---

## Why desktop does not call `PATCH /devices/:id/revoke`

pos_api documents this endpoint as **SuperAdmin only**. Desktop holds a **device activation token**, not a SuperAdmin JWT.

| Approach | Status |
|----------|--------|
| Call revoke with device token | ❌ Would get 403 — not implemented |
| Fake / bypass auth | ❌ Never |
| `ActivationService.revokeDeviceOnServer()` | Present but gated by `kServerRevokeAvailableToDesktop = false` |
| When API adds device self-revoke | Set flag to `true`; method calls `deviceRevokeEndpoint(deviceId)` |

Constant: `lib/config/api_config.dart` → `deviceRevokeEndpoint(String deviceId)`.

---

## 401 vs 403 (do not mix)

| HTTP | Meaning on desktop | Tokens | UI |
|------|-------------------|--------|-----|
| **401** | Invalid / revoked device or refresh token | **Cleared** | `DeviceRevokedScreen` → activation |
| **403** | Business or license suspended (or similar) | **Kept** | `LicenseSuspendedScreen` overlay |

**403 must not** call `revokeActivation()` or `handleRevokedByServer()`.

Detection:

- 403: `LicenseGateService.isLicenseSuspendedError()`
- 401: `ActivationService.shouldTreatAsDeviceRevocation()` (excludes validate-key and activate-desktop paths)

---

## Global handling (no restart)

| Component | Role |
|-----------|------|
| `ActivationStateController` | `ChangeNotifier` — `isActivated`, `serverRevoked` |
| `PosSystemApp` (`main.dart`) | Listens; `home` = Login / DeviceRevoked / Activation |
| `ApiClient.onUnauthorizedRevoke` | Wired in `main` — 401 → stop sync → `handleRevokedByServer` |
| `BackgroundSyncService` | Refresh 4xx → `handleRevokedByServer` |
| `ActivationService.verifyActivation` | 401 → `handleRevokedByServer` |

Default revoke message (`ActivationService.kDefaultServerRevokeMessage`):

> Kjo pajisje është çaktivizuar nga administratori. Aktivizojeni përsëri me një çelës të ri.

---

## What data is preserved

On both local reset and server revoke:

| Preserved | Cleared |
|-----------|---------|
| `sales`, `sale_lines`, products, categories, expenses, shifts | `activation_*` tokens in `app_meta` |
| `outbox` rows (may retry after re-activation) | `sync_pull_cursor`, sync timestamps |
| `company` (printer, admin PIN) | In-memory `ApiClient` Bearer |
| `audit_device_id` | `DatabaseSchema` activated tenant placeholders |

---

## Files

| File | Role |
|------|------|
| `lib/config/api_config.dart` | `deviceRevokeEndpoint` |
| `lib/services/activation_service.dart` | `handleRevokedByServer`, `revokeDeviceOnServer`, policy helpers |
| `lib/services/activation_state_controller.dart` | Root routing state |
| `lib/screens/device_revoked_screen.dart` | Post-revoke full screen |
| `lib/main.dart` | Listener + `ApiClient.onUnauthorizedRevoke` |
| `lib/services/background_sync_service.dart` | Refresh failure → revoke UX |
| `lib/screens/sync_diagnostics_screen.dart` | Local reset + SuperAdmin note |

---

## Manual test checklist

### Server revoke (SuperAdmin)

- [ ] Activate desktop; reach Login / POS.
- [ ] From SuperAdmin/API: `PATCH /devices/{activation_device_id}/revoke`
- [ ] On desktop: trigger sync or wait for connectivity sync.
- [ ] Expect **401** path (not 403 overlay).
- [ ] Sync stops; tokens cleared.
- [ ] **DeviceRevokedScreen** appears **without** app restart.
- [ ] Local sales/products still in SQLite.
- [ ] Tap **“Shko te aktivizimi”** → ActivationScreen.
- [ ] Re-activate with a new key → Login works; sync resumes.

### License / business suspended (403)

- [ ] Suspend license or business on server.
- [ ] Desktop API call returns **403**.
- [ ] **LicenseSuspendedScreen** overlay; tokens **remain**.
- [ ] **Kontrollo statusin** can recover after reactivate.
- [ ] **Not** DeviceRevokedScreen.

### Local reset only

- [ ] Sync Diagnostics → **Rivendos aktivizimin lokal**.
- [ ] ActivationScreen; server device may still be active in SuperAdmin.
- [ ] Local sales unchanged.

---

## Related docs

- `docs/16_DEACTIVATION_LOGOUT_CLEANUP.md` — token keys cleared on revoke
- `docs/20_DESKTOP_TENANT_DATA_ISOLATION.md` — tenant data not wiped on revoke
- `docs/99_POS_SYSTEM_REMAINING_WORK_AUDIT.md` — overall readiness
