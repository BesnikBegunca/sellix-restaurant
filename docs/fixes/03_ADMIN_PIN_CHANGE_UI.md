# 03 — Admin PIN Change UI

## Problem

After task 02, the admin PIN was stored in SQLite as a salted SHA-256 hash and login
validation worked correctly. However, there was no way to change the admin PIN from inside
the app. Once set (on first run), the PIN was permanent until the database was deleted or
manually edited. This made the system unusable in production where periodic PIN rotation
is required.

---

## Risk

A PIN that cannot be changed forces staff to share a permanently known credential. If the
PIN is compromised — by an ex-employee, a shoulder-surf, or a data exposure — there is no
recovery path short of reinstalling the app. For a restaurant POS system, regular PIN
rotation is a minimum operational security requirement.

---

## Files Changed

| File | What changed |
|------|-------------|
| `lib/features/dashboard/panels/company_settings_panel.dart` | Added `flutter/services.dart` import; added 3 PIN controllers + error/loading state; added `_changeAdminPin()` method; added a new `SettingsCard` with the PIN change form in the `build()` method |

---

## Exact Changes

### New state fields (in `_CompanySettingsPanelState`)

```dart
final _currentPinCtrl  = TextEditingController();
final _newPinCtrl      = TextEditingController();
final _confirmPinCtrl  = TextEditingController();
String? _pinErrorMsg;
bool _pinChanging = false;
```

All three controllers are disposed in `dispose()` alongside the existing `_nameCtrl`.

### `_changeAdminPin()` method

Async method that:
1. Reads and trims all three fields.
2. Runs client-side validation (see below).
3. Calls `await widget.m.verifyAdminPin(currentPin)` — the same SHA-256 check used by the login screen.
4. If invalid current PIN → sets `_pinErrorMsg` and returns.
5. On success → calls `await widget.m.setAdminPin(newPin)`, clears all fields, shows a green `SnackBar`.

### New `SettingsCard` in `build()`

Inserted between the Printer Settings card and the "Ruaj Ndryshimet" company-save button row. Uses:
- `SettingsCard` widget (icon: `Icons.lock_outline`, title: `'Ndrysho PIN-in e Administratorit'`)
- Three `TextField` widgets: each with `obscureText: true`, `FilteringTextInputFormatter.digitsOnly`, `maxLength: 6`, and the existing `inputDeco()` style from `dashboard_helpers.dart`
- Error container: same red-tinted `Container` + `Icon(Icons.error_outline)` pattern used by the business info card
- "Ndrysho PIN-in" `FilledButton` (green, disabled + spinner while `_pinChanging`)
- "Anulo" `OutlinedButton` that clears all three fields and resets the error

---

## Validation Rules

| Field | Rule |
|-------|------|
| Current admin PIN | Must not be empty; must pass `ManagerData.instance.verifyAdminPin()` |
| New admin PIN | Must not be empty; must match `^\d{4,6}$` (4–6 digits only) |
| Confirm new admin PIN | Must exactly equal the new admin PIN field |

Client-side rules are checked first (instant feedback). The async `verifyAdminPin()` call
is only made once all client-side checks pass — to avoid unnecessary DB reads on obvious
input errors.

---

## Behavior After Fix

1. Admin logs in with the current PIN.
2. In the manager dashboard, navigates to **Cilësimet e Kompanisë** (Company Settings).
3. Scrolls down to the new **Ndrysho PIN-in e Administratorit** card.
4. Enters current PIN → new PIN → confirm new PIN.
5. Presses **Ndrysho PIN-in**.
6. On success: all fields clear, green snackbar confirms the change. The new PIN is
   immediately active — no restart required.
7. Next login attempt with the old PIN fails; the new PIN succeeds.

The company-name/logo save flow ("Ruaj Ndryshimet" button) is completely independent —
the PIN change has its own buttons and does not interact with that form.

---

## What Was Not Changed

- Waiter PIN hashing — waiter PINs are still stored as plaintext. Scheduled separately.
- Rate limiting or brute-force protection on the PIN change form — not added.
- Backend, Firebase, or cloud sync — nothing added.
- Global dashboard layout, colors, or navigation — no structural UI change.
- Database schema — no new columns or tables (uses the `adminPinHash`/`adminPinSalt`
  columns added in task 02).
- Admin PIN change UI from the login screen — login screen is untouched.

---

## Manual Test Checklist

- [ ] Log in as admin with the current PIN
- [ ] Open the manager dashboard → navigate to **Cilësimet e Kompanisë**
- [ ] Scroll to **Ndrysho PIN-in e Administratorit**
- [ ] Leave all fields empty → press **Ndrysho PIN-in** → error "Të gjitha fushat janë të detyrueshme"
- [ ] Enter a new PIN with fewer than 4 digits → error "4–6 shifra"
- [ ] Enter a correct current PIN but mismatched new/confirm PINs → error "nuk përputhen"
- [ ] Enter wrong current PIN (correct format) → error "PIN-i aktual është i gabuar"
- [ ] Enter correct current PIN + valid matching new PIN → green snackbar, fields clear
- [ ] Close app and reopen
- [ ] Try logging in with the old PIN → fails
- [ ] Log in with the new PIN → succeeds, manager dashboard opens
- [ ] Run `flutter analyze` → confirm still 78 pre-existing issues, no new errors

---

## Next Step

**Next task:** Hash waiter PINs in SQLite — migrate existing plaintext waiter PINs to
SHA-256 + salt storage, update `findWaiterByPin()` to use async hash comparison, and
prevent new waiters from being added with plaintext PINs.
