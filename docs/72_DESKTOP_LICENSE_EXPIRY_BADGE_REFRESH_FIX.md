# Fix: Badge skadimi licence desktop pas rinovimit SuperAdmin

**Data:** 2026-05-23  
**Projekti:** `pos_system`

---

## Problemi

Pas rinovimit të licencës nga **mobile_dashboard** (SuperAdmin):

- Mobile tregon ditët e sakta të zgjatura ✅  
- Desktop **LoginScreen** mbetet me badge të vjetër, p.sh. *„Licenca juaj skadon: 365 ditë“* ❌  

Desktop lexonte `activation_license_expires_at` nga `app_meta` pa e përditësuar nga API pas rinovimit.

---

## Shkaktet rrënjësore

| # | Shkak | Efekti |
|---|--------|--------|
| 1 | `verifyActivation()` përdorte **GET** `/activation/verify` | pos_api pranon vetëm **POST** me `{ accessToken }` → verify në startup/Riprovo nuk përditësonte expiry |
| 2 | `_syncLicenseExpiresFromActivationBody` pranonte vetëm `String` | Nëse fusha nuk ishte string, thërriste `reloadFromStorage()` → **mbante cache të vjetër** |
| 3 | `refreshActivationToken()` pas `setExpiresAt` thërriste `reloadFromStorage()` | Rrezik ringarkimi stale nëse sync dështonte |
| 4 | `LoginScreen` ngarkonte vetëm nga SQLite në `initState` | Pa thirrje verify nga API kur përdoruesi qëndronte në login |

---

## Zgjidhja

### 1. `ActivationService`

- **POST** `/activation/verify` me `accessToken` nga secure storage (`_postVerifyActivation`).
- `parseLicenseExpiresAtValue()` — string, epoch, `DateTime`.
- `_syncLicenseExpiresFromActivationBody`:
  - shkruan `activation_license_expires_at` përmes `ActivationLicenseController.setExpiresAt`
  - `notifyListeners()` (në controller)
  - **nuk** ringarkon nga DB kur API nuk dërgon fushën
- Hequr `reloadFromStorage()` pas refresh token (mbështetet në sync).
- `syncLicenseExpiryFromApiIfActivated()` — verify për badge në login.
- Log debug `[LicenseExpiry]`: old, new, app_meta, ditë.

### 2. `ActivationLicenseController` (i pandryshuar në logjikë)

- Singleton i vetëm; `setExpiresAt` → persist + memorie + `notifyListeners()`.

### 3. `LoginScreen`

- Pas `reloadFromStorage()` në `_warmLicenseExpiryCache()` → `syncLicenseExpiryFromApiIfActivated()`.
- Listener ekzistues përditëson `_licenseDaysRemaining`.

### 4. `LicenseSuspendedScreen` — Riprovo

- `refreshActivationToken()` + `verifyActivation()` — tani verify POST + sync expiry.

---

## Flow i pritur

```text
SuperAdmin rinovon licencën (mobile)
    ↓
Desktop: Riprovo / startup verify / hapje LoginScreen
    ↓
POST /activation/verify ose POST /activation/refresh
    ↓
licenseExpiresAt i ri në përgjigje
    ↓
app_meta activation_license_expires_at
    ↓
ActivationLicenseController.setExpiresAt → notifyListeners
    ↓
LoginScreen badge përditësohet menjëherë
```

---

## Skedarët

| Skedar | Ndryshim |
|--------|----------|
| `lib/services/activation_service.dart` | POST verify, parse expiry, sync pa reload stale, logs |
| `lib/screens/login_screen.dart` | verify nga API në warm cache |
| `test/activation_license_expiry_sync_test.dart` | **I ri** — stale overwrite, parse, notify |
| `docs/72_DESKTOP_LICENSE_EXPIRY_BADGE_REFRESH_FIX.md` | Ky dokument |

**Pa ndryshuar:** API, mobile_dashboard, dizajn UI, reset aktivizimi, fshirje DB.

---

## Teste

```bash
flutter test test/activation_license_expiry_sync_test.dart
flutter test test/activation_license_controller_test.dart
```

Skenarët:

1. `2027-05-24` në meta → ditë të vjetra  
2. API body `2028-05-23` → ditë më të mëdha, meta e mbishkruar  
3. `notifyListeners` thirret  
4. Controller lexohet nga badge (përmes `daysRemaining`)

---

## QA manual

1. Rinovo licencën në mobile_dashboard.  
2. Hap desktop POS (LoginScreen).  
3. Kliko **Riprovo** (nëse pezulluar) ose prit verify në startup / hapje login.  
4. Badge duhet të tregojë ditët e reja (p.sh. 730 / 1092, jo 365 të vjetra).  
5. Restart desktop — badge mbetet i saktë (nga `app_meta` i përditësuar).

---

## Lidhje

- `docs/44_LICENSE_BADGE_REFRESH_FIX.md` — listener në LoginScreen (faza e mëparshme)  
- `docs/40_DESKTOP_LICENSE_LOCK_STATE_AUDIT.md` — audit licence gate
