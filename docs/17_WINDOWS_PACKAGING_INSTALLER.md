# Windows Packaging / Installer Setup

Covers the full path from `flutter build` to a distributable Windows installer
that ships `app_config.json` beside the executable so production API config
requires no recompile.

---

## Files Added

| File | Purpose |
|------|---------|
| `release/app_config.example.json` | Template for production API config |
| `windows/installer/pos_system.iss` | Inno Setup installer script |
| `docs/17_WINDOWS_PACKAGING_INSTALLER.md` | This file |

---

## Step 1 — Build the Flutter Release

Run on a Windows machine (or Windows CI runner):

```powershell
flutter clean
flutter pub get
flutter build windows --release
```

Output lands at:

```
build\windows\x64\runner\Release\
  pos_system.exe
  flutter_windows.dll
  data\
  ...
```

---

## Step 2 — Prepare `app_config.json`

Copy the example template and fill in the production URL:

```powershell
copy release\app_config.example.json release\app_config.json
```

Edit `release\app_config.json`:

```json
{
  "apiBaseUrl": "https://api.yourdomain.com/api"
}
```

Rules enforced by `RuntimeConfigService`:
- Must start with `http://` or `https://`
- Trailing slashes are stripped automatically
- If missing or invalid, the app falls back to `http://localhost:3000/api` with
  a debug-mode warning

---

## Step 3 — Verify API Config (optional, before building installer)

Run the release executable directly:

```powershell
cd build\windows\x64\runner\Release
copy ..\..\..\release\app_config.json .
.\pos_system.exe
```

In debug build: watch the console for:

```
RuntimeConfigService: URL from file: https://api.yourdomain.com/api
```

In release build: verify via the Sync Diagnostics dialog that the activation
endpoint resolves correctly.

---

## Step 4 — Build the Installer (Inno Setup)

### Install Inno Setup

Download from [jrsoftware.org/isinfo.php](https://jrsoftware.org/isinfo.php)
(free, version 6.x required).

### Compile

```
windows\installer\pos_system.iss  →  Open in Inno Setup Compiler  →  Build → Compile
```

Or via command line:

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer\pos_system.iss
```

Output: `release\installer_output\POSSystemSetup_1.0.0.exe`

---

## Installer Script Overview

`windows/installer/pos_system.iss` — Inno Setup 6

| Setting | Value |
|---------|-------|
| App name | POS System |
| Version | 1.0.0 (update `AppVersion` per release) |
| Publisher | Your Company Name (update `AppPublisher`) |
| Install dir | `%ProgramFiles%\POS System` |
| Min Windows | Windows 10 1809 (build 17763) |
| Architecture | x64 only |

### What the installer bundles

| Source | Destination |
|--------|-------------|
| `build\windows\x64\runner\Release\*` | `{app}\` (recursive) |
| `release\app_config.json` | `{app}\` (beside the exe) |

### Shortcuts created

- Start Menu: `POS System` + `Uninstall POS System`
- Desktop: `POS System`

### On uninstall

`app_config.json` is explicitly removed (added to `[UninstallDelete]` since
it's not registered by the default uninstaller rules).

---

## Updating for a New Release

1. Bump `AppVersion` in `pos_system.iss`
2. Bump `version` in `pubspec.yaml`
3. Run `flutter build windows --release`
4. Update `release\app_config.json` if the API URL changed
5. Recompile the installer

---

## Directory Layout After Install

```
C:\Program Files\POS System\
  pos_system.exe
  app_config.json          ← bundled by installer
  flutter_windows.dll
  data\
    flutter_assets\
    icudtl.dat
    ...
```

---

## Installer Tooling Comparison

| Tool | Pros | Cons |
|------|------|------|
| **Inno Setup** ✓ (chosen) | Free, simple script, wide POS use | No MSIX signing, no Store |
| MSIX | Native Windows 10/11, supports auto-update | Requires code signing cert (~$300/yr) |
| Advanced Installer | GUI-based, MSIX + MSI | Paid for advanced features |

Inno Setup is the right choice for an on-premise POS: it produces a single
`.exe` installer, needs no certificate for basic deployment, and is trivial to
automate in CI.

---

## Manual Test Checklist

### Direct run (no installer)

- [ ] `flutter build windows --release` completes without errors
- [ ] Copy `release\app_config.json` beside `pos_system.exe` in the Release folder
- [ ] Launch `pos_system.exe` — Activation Screen appears (device not yet activated)
- [ ] Open Sync Diagnostics — verify "Jo aktivizuar" status chip is shown
- [ ] Activate with a valid key — app navigates to Login Screen
- [ ] Verify sync diagnostics shows the correct Business ID / Branch ID

### Runtime config verification

- [ ] With valid `app_config.json`: Sync Diagnostics shows correct URL in debug log
- [ ] With missing `app_config.json`: app falls back to localhost (debug warning printed)
- [ ] With `app_config.json` containing an invalid URL (no `https://`): falls back to localhost
- [ ] With env var `POS_API_BASE_URL` set: env var URL is used when file is absent

### Installer build and install

- [ ] `pos_system.iss` compiles in Inno Setup 6 without errors
- [ ] `release\installer_output\POSSystemSetup_1.0.0.exe` is produced
- [ ] Install on a clean Windows 10/11 machine — completes without errors
- [ ] Desktop shortcut and Start Menu entry are created
- [ ] Launch from desktop shortcut — Activation Screen appears
- [ ] `app_config.json` is present beside `pos_system.exe` in the install dir
- [ ] Activation works end-to-end after install
- [ ] Sync diagnostics dialog opens and shows correct metadata
- [ ] Uninstall removes all files including `app_config.json`

---

## Next Step

Code signing + auto-update:
- Obtain an EV or OV code-signing certificate (Sectigo / DigiCert)
- Sign `pos_system.exe` and the installer with `signtool.exe`
- Evaluate Inno Setup's `[CustomMessages]` + download URL for a lightweight
  auto-update check, or adopt a dedicated update server (Squirrel.Windows /
  custom endpoint)
