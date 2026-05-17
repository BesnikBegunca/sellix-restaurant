# 05 — PIN Attempt Rate Limiting

## Problem

Both the admin and waiter PIN login flows allowed unlimited failed PIN attempts with no throttling. An attacker with physical access to the terminal could try every 4-to-6-digit numeric PIN combination (10,000–1,000,000 combinations) and brute-force their way into the system without any barrier.

---

## Risk

- **Admin PIN brute force** — An attacker could cycle through all 4-digit combinations (10,000 attempts) in under a minute using keyboard automation, bypassing admin authentication and gaining full manager access.
- **Waiter PIN brute force** — With enough attempts, any waiter's PIN can be discovered, allowing access to their table orders and revenue records.
- **No session lock** — Even without automation, a motivated person at an unattended terminal could manually guess a 4-digit PIN in seconds (only 10,000 combinations).
- **Audit log correlation** — Without rate limiting, the audit trail contains hundreds of `failed_pin` entries with no corresponding lockout event, making incident detection harder.

---

## Files Changed

| File | What changed |
|------|-------------|
| `lib/services/pin_rate_limiter.dart` | **New file** — `PinRateLimiter` singleton: tracks failed attempts, manages 60-second lockout, exposes `isLocked`, `remainingAttempts`, `lockoutSecondsRemaining`, `recordFailure()`, `reset()` |
| `lib/services/audit_log_service.dart` | Added `AuditAction.pinLockout` constant; added `pinLockout` display label in `label()`; added `logPinLockout()` typed helper |
| `lib/screens/login_screen.dart` | Import added; `_pinConfirmEnabled` checks `isLocked`; `_submitPin()` guards with `isLocked` at entry, calls `recordFailure()` + `logPinLockout()` on wrong PIN, calls `reset()` on success; lockout/warning banner added in `_pinCard` |
| `lib/screens/waiter_selection_screen.dart` | Import added; admin PIN `onSubmit` callback checks `isLocked` before proceeding, calls `recordFailure()` + `logPinLockout()` on wrong PIN, calls `reset()` on success |

---

## Exact Changes

### `PinRateLimiter` singleton (`lib/services/pin_rate_limiter.dart`)

- `maxAttempts = 5`, `lockoutDuration = Duration(seconds: 60)`.
- `recordFailure()` increments `_failedAttempts`. When the count reaches `maxAttempts`, it sets `_lockedUntil = now + 60s` and returns `true` (lockout triggered).
- `isLocked` getter: returns `true` while `DateTime.now()` is before `_lockedUntil`. When the lockout expires it auto-resets `_failedAttempts` and `_lockedUntil` and returns `false` — the lockout is invisible once expired.
- `remainingAttempts`: `(maxAttempts - _failedAttempts).clamp(0, maxAttempts)`.
- `lockoutSecondsRemaining`: whole seconds until `_lockedUntil`, 0 if not locked.
- `reset()`: zeroes both fields on successful authentication.
- The singleton is process-scoped — state is shared across all screens and persists until the app process is killed. Not written to SQLite.

### Failed-attempt tracking

Every wrong PIN entry in both login screens:
1. Calls `PinRateLimiter.instance.recordFailure()`.
2. If it returned `true`, calls `AuditLogService.instance.logPinLockout()` (logs `pin_lockout` action with `lockoutSeconds: 60`).
3. Calls `AuditLogService.instance.logFailedPin()` (existing call).
4. Shows a snackbar:
   - During lockout: `"Shumë tentativa të gabuara. Provo përsëri pas <N>s."`
   - Otherwise: `"PIN i gabuar. <N> tentativa të mbetur."`

### Lockout enforcement

- `login_screen.dart` — `_submitPin()` returns immediately if `isLocked`. `_pinConfirmEnabled` returns `false` when `isLocked`, which disables the confirm key on the numpad. The `_clockTimer` (1-second tick) rebuilds the widget tree every second, driving a live countdown in the lockout banner without a separate timer.
- `waiter_selection_screen.dart` — `onSubmit` callback checks `isLocked` before popping the dialog. If locked, it pops the dialog and shows the lockout snackbar, then returns.

### Reset on success

`PinRateLimiter.instance.reset()` is called immediately before any successful navigation:
- Admin PIN verified → reset before `logManagerLogin()` + navigate.
- Waiter PIN verified → reset before `logWaiterLogin()` + navigate.

### UI feedback in `login_screen.dart`

A banner is inserted between the PIN text field and the numpad, visible only when there are failed attempts:

- **Lockout active** (red banner, `negativeBg` background): shows `"Shumë tentativa të gabuara. Provo përsëri pas <N>s."` The countdown updates every second via the existing `_clockTimer`.
- **Failures but not locked yet** (amber banner, `#FFF3CD` background): shows `"PIN i gabuar. <N> tentativa të mbetur."`
- **No failures** (or after reset): banner is hidden entirely.

---

## Login Behavior After Fix

### Wrong PIN (1–4 failures)

- Snackbar shows `"PIN i gabuar. X tentativa të mbetur."` (e.g. "4 tentativa të mbetur" after the first failure).
- Amber warning banner appears below the PIN field in `login_screen.dart`.
- Confirm button and `onSubmit` handler remain active.

### 5th wrong PIN (lockout triggered)

- `recordFailure()` returns `true`; `logPinLockout()` fires immediately.
- Snackbar shows `"Shumë tentativa të gabuara. Provo përsëri pas 60s."`.
- Red lockout banner appears in `login_screen.dart` with live countdown.
- Confirm button is disabled (`_pinConfirmEnabled` returns `false`).
- Any further press of the confirm key or Enter in the text field is a no-op.
- In `waiter_selection_screen.dart`, tapping Admin and pressing Confirm in the dialog pops the dialog and shows the lockout snackbar.

### During lockout

PIN submission is blocked at the top of `_submitPin()` and at the start of the admin PIN `onSubmit` callback. The lockout banner in `login_screen.dart` counts down live. After 60 seconds, `isLocked` auto-resets and the banner disappears on the next timer tick.

### Successful login

`PinRateLimiter.instance.reset()` is called, clearing `_failedAttempts` and `_lockedUntil`. The warning and lockout banners disappear on the next rebuild. The user gets a fresh 5 attempts in the next session.

---

## What Was Not Changed

- **PIN hashing** — SHA-256+salt hashing logic in `ManagerData` and `PinRateLimiter` are entirely separate.
- **Database schema** — no new SQLite tables or columns. Failed attempt count is in-memory only.
- **Backend / Firebase / cloud** — nothing added.
- **UI redesign** — no layout, font, color, or decorative changes beyond the inline lockout/warning banners (which appear only when needed and use existing `AppColors` tokens).
- **Waiter name selection (NAMEMODE)** — clicking a waiter name card does not involve a PIN and is not rate-limited.
- **Admin PIN setup dialog (first-run)** — no PIN is being verified in setup flow, so no rate limiting applies.
- **Sync and backup logic** — untouched.

---

## Manual Test Checklist

- [ ] Enter wrong PIN 1 time — snackbar shows "4 tentativa të mbetur"; amber banner appears in login screen
- [ ] Enter wrong PIN 4 times total — snackbar shows "1 tentativa të mbetur"; amber banner updates
- [ ] Enter wrong PIN 5th time — snackbar shows lockout message; red banner with countdown appears; confirm button grays out
- [ ] Try pressing confirm key during lockout — no action taken (button disabled)
- [ ] Try keyboard Enter in PIN field during lockout — no action taken
- [ ] Watch countdown in lockout banner — updates every second
- [ ] Wait 60 seconds — banner disappears; confirm button re-enables; new 5 attempts available
- [ ] Enter correct admin PIN — dashboard opens; subsequent wrong-PIN count resets
- [ ] Enter correct waiter PIN — table selection opens; subsequent wrong-PIN count resets
- [ ] Open waiter selection screen → tap Admin → enter wrong PIN in dialog — dialog closes, snackbar shows remaining attempts
- [ ] Enter wrong admin PIN 5 times via waiter selection screen Admin dialog — lockout triggered; next dialog attempt shows lockout snackbar immediately
- [ ] Confirm successful admin login resets the counter (enter correct PIN after earlier failures — no lock)
- [ ] Run `flutter analyze` — confirm exactly 78 issues (no new issues)

---

## Next Step

**Next task:** Add double-payment guard — detect and prevent submitting the same table order for payment twice within a short window.
