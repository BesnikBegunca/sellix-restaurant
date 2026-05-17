# 08 — Admin Session Timeout

## Problem

The manager dashboard stayed open indefinitely after login.  Once an admin
authenticated, anyone with physical access to the machine could walk up and use
the dashboard — export data, view sales, change prices, manage staff — with no
further authentication required.

## Risk

| Threat | Impact without fix |
|---|---|
| Admin steps away from terminal | Any person nearby gains full manager access |
| Shared workstation | Next user inherits the active admin session |
| POS left unlocked overnight | Unattended full access to all business data |
| Physical intrusion during shift | Attacker reads or mutates database through the UI |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/admin_session_service.dart` | NEW — idle timeout state machine |
| `lib/services/audit_log_service.dart` | Added `adminSessionTimeout` / `adminSessionUnlocked` actions + helpers |
| `lib/screens/manager_dashboard_screen.dart` | Activity detection, idle timer, lock overlay, re-auth flow |

## Exact Changes

### `lib/services/admin_session_service.dart` (new file)

Singleton state machine with a 10-minute idle timeout:

```
reset()           — called on fresh login; clears locked flag and resets clock
recordActivity()  — called on every pointer/keyboard event; updates last-activity timestamp
checkAndLock()    — called each timer tick; sets locked=true if idle >= 10 min; returns true if locked
unlock()          — called after correct PIN; clears locked flag and resets clock
isLocked          — read-only getter
```

### `lib/services/audit_log_service.dart`

- Added two constants to `AuditAction`:
  ```dart
  static const String adminSessionTimeout  = 'admin_session_timeout';
  static const String adminSessionUnlocked = 'admin_session_unlocked';
  ```
- Added display labels (`'Admin Session Timeout'`, `'Admin Session Unlocked'`) to
  the `label()` switch.
- Added two fire-and-forget helpers:
  ```dart
  void logAdminSessionTimeout()  — performedBy: 'system'
  void logAdminSessionUnlocked() — performedBy: 'manager'
  ```

### `lib/screens/manager_dashboard_screen.dart`

**Activity detection (two channels):**

1. `Listener` wraps the entire `Stack` — `onPointerDown`, `onPointerMove`,
   `onPointerSignal` (scroll wheel) all call `_onPointerActivity()`, which
   calls `AdminSessionService.instance.recordActivity()` when unlocked.

2. `HardwareKeyboard.instance.addHandler(_onKeyEvent)` — registered in
   `initState`, removed in `dispose` — observes every keystroke and calls
   `recordActivity()` when unlocked.  Returns `false` so no key event is
   consumed.

**Idle timer:**

`Timer.periodic(1 second, _checkIdleTimeout)` calls
`AdminSessionService.instance.checkAndLock()` every second.  On first true
result (idle >= 10 min):
- Logs `adminSessionTimeout`.
- Clears the PIN field.
- Sets `_sessionLocked = true` → `_buildLockOverlay()` renders.
- Schedules `_lockPinFocus.requestFocus()` for the next frame.

After the session is locked, the timer fires `setState(() {})` every second to
keep the PIN-rate-limiter countdown display current.

**Lock overlay (`_buildLockOverlay()`):**

Rendered as a `Positioned.fill` child inside the `Stack` — sits on top of the
full dashboard without navigating away.  Contains:
- Semi-transparent black backdrop (72 % opacity).
- Centred white card (max width 420 px) with lock icon, title, PIN text field,
  error banner, Unlock button, and Logout text button.

**Re-authentication (`_unlockSession()`):**

1. Guard: returns immediately if `PinRateLimiter.instance.isLocked` or pin < 4
   digits.
2. Calls `ManagerData.instance.verifyAdminPin(pin)`.
3. **Correct PIN:** resets `PinRateLimiter`, calls
   `AdminSessionService.instance.unlock()`, logs `adminSessionUnlocked`, sets
   `_sessionLocked = false`.
4. **Wrong PIN:** calls `PinRateLimiter.instance.recordFailure()`, logs
   `logPinLockout()` if that triggered a lockout, logs `logFailedPin()`, shows
   inline error message with remaining attempts or lockout countdown.

**Logout from lock overlay:**

`_exitToLogin()` calls `AdminSessionService.instance.reset()` before popping to
the login screen, ensuring a clean state for the next login.

## Behavior After Fix

| Scenario | Result |
|---|---|
| Admin actively using dashboard | Timer keeps resetting; session never locks |
| Admin idle for 10 minutes | Dashboard covered by lock overlay; audit entry written |
| Correct PIN entered on overlay | Session unlocked; dashboard immediately accessible |
| Wrong PIN entered | Error shown; session stays locked; rate limiter increments |
| 5 wrong PINs in a row | 60-second PIN lockout (existing rate limiter); countdown displayed |
| Admin clicks "Dil nga sistemi" | Navigates to login; session fully reset |
| Normal logout while session is active | Works as before; `AdminSessionService.reset()` called |

## What Was Not Changed

- Waiter authentication flow — unchanged.
- Waiter PIN hashing (`sha256` + salt) — unchanged.
- PIN rate limiter (`PinRateLimiter`) — reused as-is; no changes.
- Backend / cloud / Firebase — none added.
- Database schema — unchanged.
- Global UI design, colors, typography — unchanged.
- Any file other than the three listed above.

## Manual Test Checklist

- [ ] Log in as admin and verify the dashboard opens normally.
- [ ] Interact with the dashboard (click buttons, scroll, type) and confirm it
      does not lock while actively in use.
- [ ] Leave the dashboard completely idle for 10 minutes and confirm the lock
      overlay appears.
- [ ] With the overlay showing, enter a wrong PIN — confirm it stays locked and
      shows the remaining-attempts message.
- [ ] Enter a wrong PIN 5 times — confirm the 60-second lockout countdown is
      shown and the PIN field is disabled.
- [ ] After the lockout expires, enter the correct PIN — confirm the dashboard
      unlocks and resumes exactly where it was.
- [ ] Confirm the audit log contains `admin_session_timeout` and
      `admin_session_unlocked` entries for the test above.
- [ ] Click "Dil nga sistemi" on the lock overlay — confirm navigation returns
      to the login screen.
- [ ] Log in as a waiter — confirm the waiter flow is completely unaffected.
- [ ] Confirm normal logout (via the sidebar) still works when the session is
      not locked.
- [ ] Run `flutter analyze` — exactly 78 issues.

## Next Step

Next task: Add UUIDs to sync-critical tables.
