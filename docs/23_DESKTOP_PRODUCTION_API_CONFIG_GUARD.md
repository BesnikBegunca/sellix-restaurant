# Desktop Production API Config Guard

Release builds must never activate or sync against the localhost fallback API.
Debug builds keep localhost for local development.

---

## Why localhost is blocked in release

| Risk | Effect |
|------|--------|
| Missing `app_config.json` on install | App silently uses `http://127.0.0.1:3000` |
| Production activation keys | Fail against localhost |
| Sync | Pushes/pulls to wrong host; looks “broken” |
| Support | Hard to diagnose misconfiguration |

`RuntimeConfigService` still resolves fallback in release (for diagnostics display),
but **`isBlockedInRelease`** stops activation, sync, and shows `ConfigErrorScreen`.

---

## Resolution order

| Priority | Source | When |
|----------|--------|------|
| 1 | `app_config.json` beside executable (+ macOS bundle parent) | Always |
| 2 | `POS_API_BASE_URL` | Always |
| 3 | `release/app_config.json` in project tree | **Debug / profile only** (`!kReleaseMode`) |
| 4 | `http://127.0.0.1:3000` fallback | Debug operations only; **blocked in release** |

Expected debug logs after startup:

```
[RuntimeConfig] checking: …/app_config.json
[RuntimeConfig] source=env          ← or file / release_file
[RuntimeConfig] url=https://posapi-production-a6e7.up.railway.app
[RuntimeConfig] localhost=false
[RuntimeConfig] blockedInRelease=false
```

---

## Local testing against Railway (macOS / Windows dev)

### Option A — environment variable (recommended for one-off runs)

```bash
POS_API_BASE_URL=https://posapi-production-a6e7.up.railway.app flutter run -d macos
```

Or use the helper script:

```bash
./scripts/run_macos_prod_api.sh
```

VS Code: launch configuration **「POS System – Railway production API」** (sets `POS_API_BASE_URL`).

### Option B — project `release/app_config.json` (debug only)

1. `cp release/app_config.example.json release/app_config.json`
2. Set production `apiBaseUrl` (already in example)
3. `flutter run -d macos` — no env var needed; loads `release/app_config.json` automatically

Verify before packaging:

```bash
./scripts/verify_api_config.sh
```

### Option C — localhost (local NestJS only)

Default launch **「POS System – local backend」** or no config → `source=fallback`, `localhost=true`.

### Valid `app_config.json`

```json
{
  "apiBaseUrl": "https://posapi-production-a6e7.up.railway.app"
}
```

Place beside `pos_system.exe` (same folder as the executable).  
**Do not rely on `release/app_config.json` in production** — that path is for debug/profile builds only.

---

## Windows EXE / installer builds

1. Run `./scripts/verify_api_config.sh` (or copy example → `release/app_config.json` manually).
2. Build release: `flutter build windows --release`
3. Copy `release/app_config.json` next to `pos_system.exe` in the output folder (Inno Setup does this from `release\app_config.json`).
4. On first launch, logs should show `source=file`, `localhost=false`.

Without `app_config.json` beside the EXE, release builds show **ConfigErrorScreen** (no activation/sync on localhost).

### `POS_API_BASE_URL` example

```bash
export POS_API_BASE_URL=https://posapi-production-a6e7.up.railway.app
```

Windows (session):

```cmd
set POS_API_BASE_URL=https://posapi-production-a6e7.up.railway.app
```

URL must start with `http://` or `https://`. Trailing slashes are stripped.

---

## Release guard behavior

| Check | Release |
|-------|---------|
| `isUsingFallback` | Blocked |
| `isLocalhost` (file/env pointing at localhost) | Blocked |
| Debug + fallback | Allowed (orange warning) |

### UI

- **`ConfigErrorScreen`** — full-screen at startup when blocked
  - Shows source + URL (no secrets)
  - **Riprovo konfigurimin** → `reloadConfig()` + re-route home
  - **Shiko udhëzimet** → setup steps dialog
- **`ActivationScreen`** — form disabled if blocked (defense in depth)
- **`BackgroundSyncService`** — `start` / push / pull no-op; `sync_last_error` = `API nuk është konfiguruar`; no backoff retry loop

---

## Installer / bundling

Inno Setup (`windows/installer/pos_system.iss`) copies:

```
Source: release\app_config.json → {app}\
```

Build steps (see `docs/17_WINDOWS_PACKAGING_INSTALLER.md`):

1. Copy `release/app_config.example.json` → `release/app_config.json`
2. Set production `apiBaseUrl`
3. Build installer — `app_config.json` lands beside `pos_system.exe`

`release/app_config.json` is gitignored; use the example template in repo.

---

## Files

| File | Role |
|------|------|
| `lib/services/runtime_config_service.dart` | URL resolution, `isBlockedInRelease`, `isLocalhost` |
| `lib/screens/config_error_screen.dart` | Release blocker UI |
| `lib/main.dart` | Startup gate, retry reload |
| `lib/screens/activation_screen.dart` | Disabled form + warning |
| `lib/services/background_sync_service.dart` | Sync blocked |
| `lib/services/activation_service.dart` | validate/activate blocked |

---

## Manual test checklist

### Debug

- [ ] Run without env/config → localhost fallback; orange warning on activation
- [ ] Validate-key / activate against local API works

### Release (no config)

- [ ] Build/run release without `app_config.json`
- [ ] `ConfigErrorScreen` appears (not Login/Activation)
- [ ] Activation API calls blocked
- [ ] Sync not started; diagnostics show config error

### Release (valid config)

- [ ] `app_config.json` with Railway URL beside exe
- [ ] App → Login or Activation normally
- [ ] Sync starts when activated

### Release (localhost in config)

- [ ] `app_config.json` with `"apiBaseUrl": "http://127.0.0.1:3000"`
- [ ] `ConfigErrorScreen` appears

### Retry

- [ ] Fix `app_config.json` while app open
- [ ] **Riprovo konfigurimin** → app proceeds if URL valid

---

## Unchanged

- No hardcoded Railway URL in source
- Debug localhost fallback preserved
- API request payload shapes unchanged
