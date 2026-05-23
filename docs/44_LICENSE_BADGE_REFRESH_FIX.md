# Fix: Badge i skadimit të licencës pas rinovimit

**Data:** 2026-05-23  
**Projekti:** `pos_system`

---

## Problemi

Pas rinovimit nga SuperAdmin dhe **Riprovo** në desktop:

- POS çkyçet (overlay zhduket) ✅  
- `activation_license_expires_at` përditësohet në DB ✅  
- Badge lart djathtas: **"Licenca juaj skadon: X ditë"** mbetet me ditët e vjetra deri në restart ❌  

---

## Shkaku rrënjësor

| Fakt | Detaj |
|------|--------|
| Burimi UI | `LoginScreen` → `_LicenseExpiryChip` (`lib/screens/login_screen.dart`) |
| Leximi i datës | `ActivationService.licenseDaysRemaining()` → `app_meta` `activation_license_expires_at` |
| Kur ngarkohej | Vetëm një herë në `initState` → `_refreshLicenseDaysRemaining()` |
| Pas Riprovo | Refresh/verify shkruan meta të re, por **asnjë listener** nuk i thotë `LoginScreen` të rillogaritë ditët |

Gjendja e vjetër mbeti në `_licenseDaysRemaining` (state lokal i widget-it).

---

## Skedarët e ndryshuar

| Skedar | Ndryshim |
|--------|----------|
| `lib/services/activation_license_controller.dart` | **I ri** — cache në memorie + `ChangeNotifier` |
| `lib/services/activation_service.dart` | Sync expiry pas refresh/verify/activate; delegon `licenseDaysRemaining` |
| `lib/services/license_gate_service.dart` | `unblock()` → `reloadFromStorage()` |
| `lib/screens/login_screen.dart` | Dëgjon `ActivationLicenseController` |
| `lib/screens/license_suspended_screen.dart` | `await unblock()` |
| `test/activation_license_controller_test.dart` | **I ri** |

---

## Flow i vjetër vs i ri

### I vjetër

```text
initState → lexo app_meta → _licenseDaysRemaining
Riprovo → refresh/verify → përditëso app_meta
UI → _licenseDaysRemaining i pandryshuar
```

### I ri

```text
initState → dëgjo ActivationLicenseController + warm cache
refreshActivationToken → setExpiresAt / reload → notifyListeners
verifyActivation → _syncLicenseExpiresFromActivationBody → notifyListeners
unblock() → reloadFromStorage → notifyListeners
LoginScreen._onLicenseExpiryChanged → setState(daysRemaining nga controller)
```

---

## Si përhapet refresh në UI

1. **`ActivationLicenseController`** mban `_expiresAtIso` dhe llogarit `daysRemaining` (e njëjta formulë si më parë: ditë kalendarike).
2. **`setExpiresAt` / `reloadFromStorage`** → `notifyListeners()` (pa polling).
3. **`LoginScreen`** përditëson `_licenseDaysRemaining` në listener — dizajni i chip-it **i pandryshuar**.

---

## Verifikim manual

1. SuperAdmin rinovon licencën  
2. Desktop i bllokuar → **Riprovo**  
3. Overlay zhduket  
4. Badge tregon menjëherë ditët e reja (p.sh. ~365, jo 0–7)  

---

## Teste

```bash
flutter test test/activation_license_controller_test.dart
```

---

*Pa ndryshim layout; vetëm sinkronizim state pas refresh / verify / unblock.*
