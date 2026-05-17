# 04 — Hash Waiter PINs

## Problem

Waiter PINs were stored as plaintext strings in the `waiters` SQLite table (`pin TEXT NOT NULL UNIQUE`). Any person with file-system access to the database file — or read access to a backup — could see every staff member's PIN without any cracking effort.

---

## Risk

Plaintext staff PINs are dangerous for several reasons:

- **Database file exposure** — SQLite databases are plain files on disk. A backup, a misplaced copy, or a compromised device gives immediate access to all PINs.
- **Shared secrets** — waiters often share PINs informally. Seeing a colleague's PIN in the database confirms or widens that exposure.
- **Audit log correlation** — if PINs ever appear in logs (debug output, crash reports), they directly identify the user.
- **Credential re-use** — many people reuse short numeric PINs across services. Exposure here leaks credentials elsewhere.

---

## Files Changed

| File | What changed |
|------|-------------|
| `lib/models/pos_models.dart` | `WaiterInfo` extended with `pinHash`, `pinSalt`, `pinUpdatedAt`, `isHashed` getter; `fromMap` reads new fields; `pin` kept as legacy field with default `''` |
| `lib/services/database_schema.dart` | Added 3 columns to `waiters` `CREATE TABLE`; added 3 `ALTER TABLE` migration statements in `upgrade()` (v15 block) |
| `lib/services/database_service.dart` | Bumped DB version 14 → 15; updated `insertWaiter(name, pinHash, pinSalt)`; added `updateWaiterPin(id, hash, salt)` |
| `lib/manager/manager_data.dart` | Added `_migrateWaiterPins()` called in `_init()`; updated `addWaiter()` to hash before insert; added `_waiterPinExists()` and public `waiterPinExists()`; made `findWaiterByPin()` async with hash comparison |
| `lib/screens/login_screen.dart` | Added `await` to `findWaiterByPin(pin)` call |
| `lib/features/dashboard/panels/waiters_panel.dart` | Made `_add()` async; replaced sync `w.pin == pin` check with `await widget.m.waiterPinExists(pin)`; added `await` to `addWaiter` call; fixed button callbacks to explicit lambdas |
| `lib/features/dashboard/widgets/waiters/waiter_list.dart` | Replaced `w.pin` with `const pin = '••••'` — hash is never passed to the UI |

---

## Database Changes

Three columns added to the `waiters` table:

```sql
pinHash      TEXT    -- SHA-256(pin + salt), hex string
pinSalt      TEXT    -- 32 cryptographically-random bytes, base64url-encoded
pinUpdatedAt TEXT    -- ISO-8601 timestamp of last hash write
```

The existing `pin TEXT NOT NULL` column is **kept** for backward compatibility. After migration it holds the original plaintext (for existing records) or the pinHash as a unique placeholder (for new records). It is no longer used for login verification.

---

## Migration Strategy

Migration runs automatically during `ManagerData._init()` on every app launch, before the UI is ready:

1. All waiters are loaded from SQLite into `_waiters`.
2. `_migrateWaiterPins()` iterates the list.
3. For each waiter where `isHashed == false` and `pin` is non-empty:
   - Generates a fresh 32-byte random salt (`_generateSalt()` — same helper used for admin PIN).
   - Computes `SHA-256(pin + salt)` using `package:crypto`.
   - Calls `DatabaseService.updateWaiterPin(id, hash, salt)` — writes `pinHash`, `pinSalt`, `pinUpdatedAt` to SQLite.
   - Replaces the in-memory `WaiterInfo` with a new instance that has `isHashed == true`.
4. If any waiter was migrated, `notifyListeners()` is called.

Migration is **idempotent** — re-running on an already-migrated database is a no-op (all waiters have `isHashed == true`). No existing waiter record is deleted or invalidated.

---

## Login Behavior After Fix

`findWaiterByPin(String pin)` is now `async` and uses hash comparison:

```
for each waiter:
  if isHashed:
    if SHA-256(enteredPin + waiter.pinSalt) == waiter.pinHash → return waiter
  else:
    if enteredPin == waiter.pin → return waiter  (legacy fallback only)
```

The legacy fallback can only trigger for a waiter with no hash — which cannot occur on normal operation after migration. It is kept as a safety net only.

New waiters added after this update:
- `addWaiter()` generates salt + hash before the DB insert.
- `insertWaiter()` stores the hash in both `pin` (legacy placeholder) and `pinHash`.
- No plaintext PIN is ever written to disk for new records.

Duplicate PIN detection in `addWaiter()` and the waiter add form (`waiters_panel.dart`) now calls `waiterPinExists(pin)`, which hashes the candidate PIN with each existing waiter's individual salt and compares — correctly detecting duplicates without storing or logging the plaintext.

The PIN display in the manager dashboard (`WaiterGridCard`) now always shows `PIN: ••••`. The hash is never passed to any UI widget.

---

## What Was Not Changed

- Admin PIN logic — unchanged; it already used hashed storage from task 02.
- Backend, Firebase, or cloud sync — nothing added.
- UI layout or visual design — no design changes.
- Rate limiting or brute-force protection — not added (scheduled separately).
- Sync logic or backup/restore logic — untouched.
- Waiter login flow from the waiter selection screen (NAMEMODE) — login there is by name selection, no PIN involved.

---

## Manual Test Checklist

- [ ] Launch app with existing plaintext-PIN waiters in the database
- [ ] Confirm `_migrateWaiterPins()` ran: open SQLite file and verify `pinHash`/`pinSalt` are populated for every waiter row
- [ ] Existing waiter can log in with their PIN — same PIN, same behavior
- [ ] Manager dashboard → Staff panel: PIN shows as `••••`, not plaintext or hash
- [ ] Add a new waiter with a valid PIN → waiter appears in list
- [ ] New waiter can log in with their assigned PIN
- [ ] Entering a wrong PIN fails with "PIN i gabuar" error
- [ ] Try adding a duplicate PIN → error "Ky PIN ekziston tashmë"
- [ ] Admin PIN login still works (entering admin PIN opens manager dashboard)
- [ ] Admin PIN change in Company Settings still works
- [ ] Search codebase for `debugPrint` / `print` containing `pin` — confirm no PIN is logged
- [ ] Run `flutter analyze` — confirm still 78 pre-existing issues, no new errors

---

## Next Step

**Next task:** Add PIN attempt rate limiting — track failed PIN attempts per session and temporarily lock the login screen after N consecutive failures, to prevent brute-force attacks on both waiter and admin PINs.
