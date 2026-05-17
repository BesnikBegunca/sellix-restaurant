# 02 — SQLite-Backed Hashed Admin PIN

## What Was Added

Replaced the `verifyAdminPin()` placeholder (which always returned `false`) with a full
SHA-256 + salt implementation backed by SQLite. The admin PIN is now stored as a salted
hash in the `company` table. Login is validated by hashing the entered PIN with the stored
salt and comparing to the stored hash.

A first-run setup flow was also added: when no admin PIN is stored, entering any valid PIN
presents a one-time confirmation dialog to set it as the admin PIN.

---

## Files Changed

| File | What changed |
|------|-------------|
| `lib/services/database_schema.dart` | Added 4 columns to `company` table; added `ALTER TABLE` migration statements in `upgrade()` |
| `lib/services/database_service.dart` | Bumped DB version 13 → 14; added `updateAdminPin(hash, salt)` method |
| `lib/manager/manager_data.dart` | Added `crypto` import; added `_adminPinHash`/`_adminPinSalt` fields; loaded from DB in `_init()`; replaced placeholder with real `verifyAdminPin()`, plus `hasAdminPin`, `setAdminPin()`, and private hash/salt helpers |
| `lib/screens/login_screen.dart` | Made `_submitPin()` async; added admin PIN verification flow; added first-run `_showAdminPinSetupDialog()` |
| `lib/screens/waiter_selection_screen.dart` | Updated admin button callback: `await verifyAdminPin()`, first-run setup dialog, captured navigator before async gap |

---

## How the PIN Is Stored

Four new columns were added to the existing `company` table (row `id = 1`):

```sql
adminPinHash       TEXT    -- SHA-256(pin + salt), hex string
adminPinSalt       TEXT    -- 32 random bytes encoded as base64url
adminPinCreatedAt  TEXT    -- ISO-8601 timestamp of first PIN creation
adminPinUpdatedAt  TEXT    -- ISO-8601 timestamp of last PIN change
```

The PIN itself is **never stored**. Only the salted hash is persisted.

---

## How Validation Works

```
entered_pin  →  SHA-256(entered_pin + stored_salt)  →  compare with stored_hash
```

1. On app start, `ManagerData._init()` loads `adminPinHash` and `adminPinSalt` from the `company` row into memory (`_adminPinHash`, `_adminPinSalt`).
2. When a PIN is submitted, `verifyAdminPin(pin)` is called:
   - If either field is `null`, returns `false` immediately.
   - Otherwise: `sha256(pin + salt)` is computed and compared to the stored hash.
   - Returns `true` only on an exact match.
3. `hashPin` and `generateSalt` are private static methods in `ManagerData`:
   - Salt: 32 cryptographically random bytes, encoded as base64url.
   - Hash: `dart:convert utf8.encode(pin + salt)` passed to `package:crypto sha256`.

---

## How the First Admin PIN Is Created

On first launch (no admin PIN in DB):

- **Login screen (PINMODE):** entering any PIN that does not match a waiter opens the setup dialog.
- **Login screen (NAMEMODE):** any PIN entry opens the setup dialog.
- **Waiter selection screen admin button:** if no PIN is stored, the dialog is shown immediately after entering any PIN.

The dialog reads:

> **Konfiguro PIN e Administratorit**
> Nuk është konfiguruar asnjë PIN i administratorit. Dëshironi ta vendosni këtë PIN si PIN-in e administratorit?
>
> [ Anulo ]  [ Konfirmo ]

On **Konfirmo**: `ManagerData.instance.setAdminPin(pin)` is called, which:
1. Generates a fresh 32-byte random salt.
2. Computes SHA-256(pin + salt).
3. Persists both to SQLite via `DatabaseService.updateAdminPin()`.
4. Updates the in-memory cache.
5. Navigates directly to `ManagerDashboardScreen`.

---

## Login Flow After Fix

### PINMODE (waiters use PINs)

1. If admin PIN is stored **and** matches → go to manager dashboard.
2. If entered PIN matches a waiter → go to table selection (waiter login unaffected).
3. If neither matches and no admin PIN is stored → show first-run setup dialog.
4. If neither matches and admin PIN is stored → show "PIN i gabuar" error.

### NAMEMODE (waiters select by name; PIN field is admin-only)

1. If no admin PIN is stored → show first-run setup dialog.
2. If admin PIN is stored and matches → go to manager dashboard.
3. If admin PIN is stored and does not match → show "PIN i gabuar" error.

---

## What Was Not Changed

- Waiter PIN hashing — waiter PINs are still stored as plaintext. Scheduled for a separate task.
- Admin PIN change UI — no UI to change an existing admin PIN yet. Next phase.
- Database schema of any table other than `company`.
- UI layout, colors, fonts, or dashboard panels.
- Backup/restore logic or sync logic.
- Any Firebase/cloud/backend logic (none added).

---

## Manual Test Checklist

- [ ] Delete or reset the app's SQLite database to simulate first run
- [ ] Launch app in PINMODE: enter a 4-digit PIN → confirm setup dialog appears → press Konfirmo → manager dashboard opens
- [ ] Close app, reopen: enter the same PIN → manager dashboard opens without the setup dialog
- [ ] Enter a different PIN → "PIN i gabuar" error is shown
- [ ] Add a waiter with a PIN and verify waiter login still works in PINMODE
- [ ] Switch to NAMEMODE and confirm admin PIN dialog appears on the first entry
- [ ] Test admin button on waiter selection screen: first run shows setup dialog; subsequent attempts validate against stored hash
- [ ] Run `flutter analyze` and confirm no new errors in changed files
- [ ] Search project for `9999` — confirm still zero results in `lib/`

---

## Next Step

**Next task:** Admin PIN change UI — add a section inside the manager dashboard (e.g., Company Settings panel) where the admin can verify the current PIN and set a new one, using `ManagerData.instance.setAdminPin(newPin)`.
