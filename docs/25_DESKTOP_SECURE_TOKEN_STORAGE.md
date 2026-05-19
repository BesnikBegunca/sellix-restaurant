# Desktop Secure Activation Token Storage

Activation Bearer and refresh tokens are no longer stored in plaintext SQLite
`app_meta`. Non-sensitive activation metadata remains in the database.

---

## Previous risk

| Issue | Impact |
|-------|--------|
| `activation_access_token` in `app_meta` | Copying `pos_system.db` exposes Bearer token |
| `activation_refresh_token` in `app_meta` | Long-lived refresh token reusable offline |

---

## Storage split

### Secure storage (`SecureActivationTokenStore`)

| Key (internal) | Content |
|----------------|---------|
| `pos_activation_access_token` | Bearer access token |
| `pos_activation_refresh_token` | Refresh token |

### SQLite `app_meta` (unchanged)

- `activation_completed`
- `activation_business_id` / `activation_branch_id` / `activation_device_id`
- `activation_license_expires_at`
- `activation_last_business_id` / `activation_last_business_name`
- `activation_business_name`
- `sync_pull_cursor`, `sync_last_*`, `audit_device_id`, etc.

---

## Platform notes

| OS | Backend |
|----|---------|
| Windows | DPAPI (`flutter_secure_storage` / `WindowsOptions`) |
| macOS | Keychain (`MacOsOptions`) |
| Linux | libsecret (`LinuxOptions`) — requires Secret Service (e.g. gnome-keyring) |

Package: `flutter_secure_storage` (see `pubspec.yaml`).

### Fallback policy

- **Release:** secure storage failure propagates; tokens are **not** written to SQLite.
- **Debug only:** in-memory fallback if OS secure storage throws (logged without token values).

---

## Migration (startup)

In `main.dart`, before `loadPersistedActivation()`:

1. `ActivationService.migrateTokensFromAppMetaIfNeeded()`
2. If secure store empty and legacy `app_meta` tokens exist → move to secure store.
3. Delete legacy `activation_access_token` / `activation_refresh_token` rows.
4. Debug log: `Activation tokens migrated to secure storage` (no token values).

---

## Code touchpoints

| File | Role |
|------|------|
| `lib/services/secure_activation_token_store.dart` | Read/write/clear tokens |
| `lib/services/activation_service.dart` | Persist, load, refresh, revoke |
| `lib/services/api_client.dart` | Bearer from secure store per request |
| `lib/screens/sync_diagnostics_screen.dart` | Presence yes/no, storage label |

---

## Revoke / reset

`revokeActivation()` / `resetLocalActivation()` / server revoke:

- `SecureActivationTokenStore.clearTokens()`
- Clear activation metadata in `app_meta` (not business data)
- `ApiClient.clearAccessToken()`
- UI → Activation / DeviceRevoked as before

---

## Sync Diagnostics

Shows:

- **Token storage:** Secure (or debug fallback label)
- **Access token present:** yes / no
- **Refresh token present:** yes / no

Never displays token strings. Export JSON does not include tokens.

---

## Manual test checklist

- [ ] Activate desktop → `app_meta` has no `activation_access_token` / `activation_refresh_token`
- [ ] Restart app → still activated, sync works
- [ ] Token refresh after 401 on sync still works
- [ ] Reset local activation → secure tokens cleared, diagnostics show `no`
- [ ] Server revoke (401) → secure tokens cleared
- [ ] Upgrade from old DB with plaintext tokens → migration on first launch, tokens in secure store only

---

## Unchanged

- pos_api contract
- Mobile apps
- Offline-first business SQLite data
- Activation flow UX
