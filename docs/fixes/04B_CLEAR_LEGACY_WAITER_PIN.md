# 04B — Clear Legacy Waiter PIN Plaintext

## Problem

Task 04 added SHA-256+salt hashed columns (`pinHash`, `pinSalt`, `pinUpdatedAt`) to the `waiters` table and migrated existing plaintext PINs at startup. However, the original `pin TEXT` column continued to hold plaintext values for any waiter that had not yet been processed by the in-app migration — and the login/duplicate-check code still contained plaintext comparison fallbacks (`enteredPin == waiter.pin`).

This meant that:
- Old plaintext PINs remained on disk in SQLite until the first post-Task-04 app launch.
- Login code still had a code path that compared PINs without hashing.
- The in-memory `WaiterInfo` object held `pin` = original plaintext even after migration wrote the hash to disk.

---

## Risk

- **Residual plaintext exposure** — Any database file opened before the migration ran still contained readable PINs in `waiters.pin`.
- **Plaintext comparison fallback** — The legacy `enteredPin == waiter.pin` branch in `findWaiterByPin()` and `waiterPinExists()` could be triggered by any waiter whose `isHashed` flag was false, bypassing hash security entirely.
- **In-memory plaintext** — After Task 04 migration, `_waiters[i].pin` held the original plaintext string in RAM for the lifetime of the session.

---

## Files Changed

| File | What changed |
|------|-------------|
| `lib/services/database_schema.dart` | Added v16 `UPDATE` migration: sets `pin = pinHash` for all rows where hash is present and `pin` still differs |
| `lib/services/database_service.dart` | Bumped DB version 15 → 16; `updateWaiterPin()` now also writes `'pin': hash` to replace plaintext in the legacy column |
| `lib/manager/manager_data.dart` | `_migrateWaiterPins()` now passes `pin: hash` (not `pin: w.pin`) when constructing the migrated `WaiterInfo`; removed both legacy plaintext fallbacks from `_waiterPinExists()` and `findWaiterByPin()` |

---

## Database Migration

### v16 upgrade block (`database_schema.dart`)

```sql
UPDATE waiters
SET pin = pinHash
WHERE pinHash IS NOT NULL
  AND pinSalt IS NOT NULL
  AND pin != pinHash
```

This runs inside `upgrade()` during SQLite `onUpgrade` before any in-memory loading occurs. It is wrapped in `try/catch` so a schema mismatch on a very old DB cannot crash startup.

**Why `pin = pinHash` and not `pin = ''`?**

The original `waiters.pin` column has a `UNIQUE` constraint. Setting every row to `''` would violate it. Since each waiter has a distinct random salt, their SHA-256 hashes are guaranteed to differ — assigning `pin = pinHash` satisfies the constraint while removing all plaintext.

### Fresh installs

The `ensureTables()` `CREATE TABLE waiters` statement already uses:
```sql
pin TEXT NOT NULL DEFAULT ''
```
(no UNIQUE, no plaintext ever written). The v16 UPDATE is a no-op on fresh installs.

---

## Code Changes

### `database_service.dart` — `updateWaiterPin()`

```dart
await db.update('waiters', {
  'pin': hash,          // replaces plaintext with hash (maintains UNIQUE)
  'pinHash': hash,
  'pinSalt': salt,
  'pinUpdatedAt': DateTime.now().toIso8601String(),
}, where: 'id = ?', whereArgs: [id]);
```

### `manager_data.dart` — `_migrateWaiterPins()`

In-memory object now built with `pin: hash` instead of `pin: w.pin`:

```dart
_waiters[i] = WaiterInfo(
  dbId: w.dbId, name: w.name,
  pin: hash,           // task 4B: hash replaces plaintext in memory too
  pinHash: hash, pinSalt: salt,
  pinUpdatedAt: DateTime.now().toIso8601String(),
);
```

### `manager_data.dart` — `_waiterPinExists()` (legacy fallback removed)

Before:
```dart
if (w.isHashed && _hashPin(pin, w.pinSalt!) == w.pinHash) return true;
else if (w.pin == pin) return true;   // ← REMOVED
```

After:
```dart
if (w.isHashed && _hashPin(pin, w.pinSalt!) == w.pinHash) return true;
```

### `manager_data.dart` — `findWaiterByPin()` (legacy fallback removed)

Before:
```dart
if (w.isHashed && _hashPin(pin, w.pinSalt!) == w.pinHash) return w;
else if (w.pin == pin) return w;      // ← REMOVED
```

After:
```dart
if (w.isHashed && _hashPin(pin, w.pinSalt!) == w.pinHash) return w;
```

---

## Login Behavior After Fix

`findWaiterByPin(String pin)` now has a single code path:

```
for each waiter in _waiters:
  if isHashed AND SHA-256(enteredPin + waiter.pinSalt) == waiter.pinHash → return waiter
return null
```

A waiter with `isHashed == false` can no longer log in at all. This state cannot occur on normal operation: the v16 DB migration and `_migrateWaiterPins()` together ensure every waiter row has a valid `pinHash`/`pinSalt` before the UI is displayed.

---

## What Was Not Changed

- Admin PIN logic — unchanged.
- UI layout, colors, or fonts — no design changes.
- Waiter name-based login (NAMEMODE) — unaffected.
- Backend, Firebase, or cloud sync — nothing added.
- Rate limiting or brute-force protection — not added (scheduled separately).
- The `waiters.pin` column is **kept** (not dropped) to preserve schema backward compatibility. It now holds the same value as `pinHash`.

---

## Manual Test Checklist

- [ ] Launch app with a pre-Task-04 database (waiters with plaintext PINs in `pin` column)
- [ ] Confirm v16 migration ran: open SQLite file — `waiters.pin` equals `waiters.pinHash` for every row; no short numeric strings visible
- [ ] Existing waiter can log in with their PIN after migration — same PIN, same behavior
- [ ] Add a new waiter with a valid PIN → waiter appears in list; `pin` column equals `pinHash` in SQLite immediately
- [ ] New waiter can log in with their assigned PIN
- [ ] Entering a wrong PIN fails with "PIN i gabuar" error
- [ ] Try adding a waiter with a duplicate PIN → error "Ky PIN ekziston tashmë"
- [ ] Admin PIN login still works (opening manager dashboard)
- [ ] Admin PIN change in Company Settings still works
- [ ] Search codebase for `== w.pin`, `== waiter.pin`, `enteredPin == pin` — confirm no plaintext comparison remains
- [ ] Search codebase for `debugPrint` / `print` containing `pin` — confirm no PIN is logged
- [ ] Run `flutter analyze` — confirm still 78 pre-existing issues, no new errors

---

## Next Step

**Next task:** Add PIN attempt rate limiting — track failed PIN attempts per session and temporarily lock the login screen after N consecutive failures, to prevent brute-force attacks on both waiter and admin PINs.
