# 16 — Add Connectivity Service

## Problem

The POS had a durable **outbox** queue and sync-ready entity rows, but no way to
know whether the device currently has a usable network link. A future sync worker
would either run blindly while offline (wasted retries, confusing failures) or
require ad-hoc checks scattered through the codebase.

## Risk

| Scenario | Problem without connectivity detection |
|---|---|
| Offline outbox drain | Worker hammers failed requests with no backoff signal |
| Online-only operations | No shared signal to defer uploads until link returns |
| Desktop Ethernet / Wi‑Fi | Platform-specific link changes invisible to Dart layer |
| Premature sync | Cannot gate “start sync” on `isOnline` |

## Files Changed

| File | Change type |
|---|---|
| `pubspec.yaml` | Added `connectivity_plus` dependency |
| `lib/services/connectivity_service.dart` | New singleton service |
| `lib/main.dart` | `ConnectivityService.instance.initialize()` at startup |

## Package Added

**`connectivity_plus: ^6.1.4`** — cross-platform link-type detection (Windows,
Linux, macOS, mobile). Uses `checkConnectivity()` for initial state and
`onConnectivityChanged` for updates. Returns `List<ConnectivityResult>` (v6 API).

## Service Behavior

`ConnectivityService` is a **singleton** (`ConnectivityService.instance`).

| API | Behavior |
|---|---|
| `initialize()` | Idempotent; reads current link, subscribes to changes |
| `dispose()` | Cancels subscription (does not close app-wide stream) |
| `status` | `ConnectivityStatus.online` or `.offline` |
| `isOnline` | `true` when status is online |
| `onStatusChanged` | Broadcast stream; emits only on **actual** status changes |

**Online:** any of `wifi`, `ethernet`, or `mobile` in the result list.

**Offline:** empty list, `none` only, or only non-data link types (e.g. bluetooth
without Wi‑Fi/Ethernet).

Errors from the platform plugin fall back to **offline**. In debug builds, a single
`debugPrint` line logs transitions (no production noise).

**Note:** This detects **network interface** presence, not guaranteed internet
or API reachability — sufficient for gating a future sync engine.

## What Was Not Changed

- **UI** — no banners, icons, or layout changes.
- **Backend / API** — no HTTP calls.
- **Outbox processing** — events are not drained automatically.
- **Dio** — not added.
- **Sync engine** — not implemented.
- **Offline POS flows** — unchanged; connectivity is observational only.

## Manual Test Checklist

- [ ] Run `flutter pub get`
- [ ] Launch app with network connected → `ConnectivityService.instance.isOnline` is `true`
- [ ] Disable Wi‑Fi / unplug Ethernet → status becomes offline (debug log in debug mode)
- [ ] Re-enable network → status becomes online again
- [ ] Confirm sales, menu, and shifts still work with network disabled
- [ ] Run `flutter analyze`

## Next Step

Next task: Add Dio API client foundation.
