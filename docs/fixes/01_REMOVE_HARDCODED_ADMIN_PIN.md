# 01 — Remove Hardcoded Admin PIN

## Problem

Admin/manager access was granted to anyone who entered the PIN `9999`. This value was hardcoded directly in Flutter source code across three independent login paths:

1. The main PIN login screen (`login_screen.dart`)
2. The waiter selection screen admin button (`waiter_selection_screen.dart`)
3. The waiter add form, which blocked `9999` as a waiter PIN to "protect" the hardcoded admin slot (`waiters_panel.dart`, `manager_data.dart`)

Additionally, a comment in `manager_dashboard_screen.dart` documented this fact publicly in the source.

## Risk

A hardcoded credential in source code is a critical security vulnerability in any production system:

- Anyone with read access to the repository (or even the compiled binary via decompilation) can discover the PIN.
- The PIN cannot be changed without a new app deployment.
- There is no audit trail of who knows the PIN.
- It bypasses any future authentication improvements silently — the bypass remains active until explicitly removed.
- In a restaurant environment with staff turnover, a hardcoded admin PIN is unacceptable.

## Files Changed

| File | Nature of Change |
|------|-----------------|
| `lib/screens/login_screen.dart` | Replaced `pin == '9999'` with `ManagerData.instance.verifyAdminPin(pin)` |
| `lib/screens/waiter_selection_screen.dart` | Replaced `pin == '9999'` with `ManagerData.instance.verifyAdminPin(pin)` |
| `lib/manager/manager_data.dart` | Added `verifyAdminPin()` placeholder method; removed `|| p == '9999'` guard from `addWaiter()` |
| `lib/features/dashboard/panels/waiters_panel.dart` | Removed UI block that rejected `9999` as a waiter PIN |
| `lib/screens/manager_dashboard_screen.dart` | Removed `(PIN 9999)` from class doc comment |

## Exact Changes

### `login_screen.dart`
**Removed:**
```dart
if (pin == '9999') {
  _pinController.clear();
  AuditLogService.instance.logManagerLogin();
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ManagerDashboardScreen()),
  );
  return;
}
```
**Replaced with:**
```dart
// Admin PIN validation will be handled by SQLite-backed hashed PIN storage.
if (ManagerData.instance.verifyAdminPin(pin)) {
  _pinController.clear();
  AuditLogService.instance.logManagerLogin();
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ManagerDashboardScreen()),
  );
  return;
}
```

### `waiter_selection_screen.dart`
**Removed:**
```dart
if (pin == '9999') {
```
**Replaced with:**
```dart
// Admin PIN validation will be handled by SQLite-backed hashed PIN storage.
if (ManagerData.instance.verifyAdminPin(pin)) {
```

### `manager_data.dart`
**Added** a new `verifyAdminPin()` method in a new `// admin auth` section:
```dart
/// Placeholder for admin PIN verification.
/// TODO: Replace with SQLite-backed hashed PIN validation in the next phase.
bool verifyAdminPin(String pin) {
  // Admin PIN validation will be handled by SQLite-backed hashed PIN storage.
  return false;
}
```
**Removed** the `|| p == '9999'` guard from `addWaiter()`:
```dart
// Before:
if (_waiters.any((w) => w.pin == p) || p == '9999') return;

// After:
if (_waiters.any((w) => w.pin == p)) return;
```

### `waiters_panel.dart`
**Removed** the UI validation block that blocked 9999 from being a waiter PIN:
```dart
if (pin == '9999') {
  setState(() => _errorMsg = 'PIN 9999 është rezervuar për menaxherin.');
  return;
}
```

### `manager_dashboard_screen.dart`
**Removed** the reference from the class doc comment:
```dart
// Before:
/// Dashboard menaxheri (PIN 9999).

// After:
/// Dashboard menaxheri.
```

## Behavior After Fix

Admin login is **temporarily disabled**. `verifyAdminPin()` returns `false` for all inputs, so no PIN will grant manager/admin access until the next phase is complete (SQLite-backed admin PIN storage).

Waiter login via PIN (PINMODE) and waiter selection by name (NAMEMODE) are **not affected** and continue to work exactly as before.

## What Was Not Changed

- PIN hashing for waiters — not changed.
- SQLite admin PIN storage — not implemented yet (next phase).
- Admin PIN change UI — not implemented yet (future phase).
- UI layout, colors, dashboard panels, database schema, backup logic, sync logic.

## Manual Test Checklist

- [ ] Search project for `9999` — confirm zero results in `lib/`
- [ ] Confirm no condition in any file grants admin access via a hardcoded PIN
- [ ] Run `flutter analyze` — confirm no new errors introduced by these changes
- [ ] Run the app
- [ ] Test waiter login still works (PINMODE and NAMEMODE)
- [ ] Test that entering any PIN on the main login screen no longer opens the manager dashboard
- [ ] Test that the Admin PIN button on the waiter selection screen no longer grants access for any PIN

## Next Step

**Next task:** Store admin PIN in SQLite (hashed with bcrypt or SHA-256 + salt), implement admin PIN setup on first run, and replace `verifyAdminPin()` with real database-backed validation.
