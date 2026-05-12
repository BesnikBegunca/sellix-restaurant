# ESC/POS Thermal Printing — Implementation Report

## Overview

A production-grade ESC/POS thermal printing layer was added to the Flutter POS without changing the existing payment flow, UI design, or PDF printing system. The implementation is purely additive and offline-first.

---

## Architecture

```
PosOrderScreen
    │
    └── ReceiptPrinter (facade)
            │
            ├── [ESC/POS mode ON]
            │       └── EscPosPrinterService (singleton)
            │               ├── EscPosReceiptBuilder  → Uint8List (ESC/POS bytes)
            │               ├── _sendRawBytes()       → PowerShell + winspool.drv
            │               ├── Retry (×1 on failure)
            │               └── Text fallback         → WindowsPrintersService
            │
            └── [ESC/POS mode OFF]
                    └── WindowsPrintersService.printRawText() (unchanged legacy path)
```

---

## New Files

### `lib/services/escpos/escpos_bytes.dart`
Pure-Dart ESC/POS byte command builder. Chainable API:

| Method | ESC/POS Command | Description |
|---|---|---|
| `reset()` | `ESC @` | Initialize printer |
| `alignLeft/Center/Right()` | `ESC a 0/1/2` | Set text alignment |
| `boldOn/Off()` | `ESC E 1/0` | Bold text |
| `doubleSize(bool)` | `ESC ! 0x30/0x00` | Double height + width |
| `text(s)` | raw bytes | Encoded text |
| `textLine(s)` | + LF | Text + newline |
| `centeredLine(s)` | align + text + LF | Centered line |
| `boldCenteredLine(s)` | bold + center + LF | Bold centered |
| `separator()` | `---…` + LF | Dash separator |
| `rowLR(left, right)` | text | Two-column left/right row |
| `fullCut()` | `GS V 0` | Full paper cut |
| `partialCut()` | `GS V 1` | Partial paper cut |
| `drawerKick()` | `ESC p 0 0x19 0xFA` | Cash drawer kick |

**Encoding**: Albanian characters (ë, ç, â, etc.) are transliterated to ASCII equivalents so they print correctly on any CP437/CP850 code page without reprogramming the printer.

**Paper widths**: 80mm → 48 chars/line, 58mm → 32 chars/line.

---

### `lib/services/escpos/printer_profile.dart`
Printer capability profiles with auto-detection from Windows printer name.

| Profile | Paper | Chars | Cut | Drawer |
|---|---|---|---|---|
| `genericPos80` | 80mm | 48 | ✓ | ✓ |
| `epsonTm` | 80mm | 48 | ✓ | ✓ |
| `xprinter` | 80mm | 48 | ✓ | ✓ |
| `bixolon` | 80mm | 48 | ✓ | ✓ |
| `star` | 80mm | 48 | ✓ | ✓ |
| `sunmi` | 80mm | 48 | ✗ | ✗ |
| `narrowPos58` | 58mm | 32 | ✓ | ✗ |
| `unknown` | 80mm | 48 | ✗ | ✗ |

**Auto-detect** (`PrinterProfile.detectFromName(printerName)`): scans the Windows printer name string for keywords (case-insensitive): `epson`, `xprinter`, `xp-`, `sunmi`, `bixolon`, `srp-`, `star`, `tsp`, `58mm`, `pos58`, `pos`, `thermal`, `receipt`, `80mm`. Falls back to `genericPos80`.

---

### `lib/services/escpos/escpos_receipt_builder.dart`
Converts receipt data to a `Uint8List` of ESC/POS bytes.

| Method | Output |
|---|---|
| `buildKitchenReceipt(...)` | Kitchen order (sent on "Send Order") |
| `buildPaymentReceipt(...)` | Payment receipt (sent on "Pay") with footer, address, phone, shift ID |
| `buildShiftReceipt(...)` | Shift summary (all waiters + grand total) |
| `buildTestReceipt(...)` | Test page: alignment test, bold test, column test, profile info |

---

### `lib/services/escpos/escpos_printer_service.dart`
Singleton service. Central coordinator for all thermal printing.

#### Print Queue
- FIFO `Queue<_PrintJob>` processed sequentially
- Each job has a unique `jobId` — duplicate IDs are dropped (prevents double-print on rapid payment taps)
- `_processing` flag ensures only one job executes at a time
- `enqueue()` returns immediately (fire-and-forget)
- `printNow()` returns `Future<bool>` (awaitable, used in payment flow)

#### Retry Logic
```
Attempt 1 → ESC/POS raw bytes
  FAIL →
Attempt 2 → ESC/POS raw bytes (retry)
  FAIL →
Attempt 3 → Text fallback (WindowsPrintersService.printRawText)
  Log audit event: escpos_fallback
```

#### Win32 Raw Printing (PowerShell P/Invoke)
The service sends ESC/POS bytes as a Windows RAW print job via a PowerShell script that compiles a C# helper class using `Add-Type` at runtime:

```
OpenPrinter(name)
StartDocPrinter(hPrinter, level=1, DOCINFO{pDataType="RAW"})
StartPagePrinter
WritePrinter(hPrinter, bytes, length)
EndPagePrinter
EndDocPrinter
ClosePrinter
```

This bypasses GDI entirely — the raw ESC/POS bytes are sent directly to the printer driver with no rendering, no font substitution, and no margin transforms.

---

## Modified Files

### `lib/services/windows_printers_service.dart`
New methods:
- `getDefaultPrinter()` — returns the Windows default printer name
- `isPrinterOnline(name)` — PowerShell `Get-Printer` status check, returns `true` only if status is "Normal"

### `lib/services/database_service.dart`
- DB version bumped **11 → 12**
- 7 backward-compatible `ALTER TABLE company ADD COLUMN` statements in `_onUpgrade` (try-catch)
- Fresh-install `CREATE TABLE company` DDL updated with all new columns
- New method: `updateEscPosSettings({useEscPos, cashDrawerEnabled, paperWidthMm, receiptFooter, businessAddress, businessPhone})`

New `company` columns:

| Column | Type | Default |
|---|---|---|
| `useEscPos` | INTEGER | 1 (true) |
| `cashDrawerEnabled` | INTEGER | 0 (false) |
| `paperWidthMm` | INTEGER | 80 |
| `receiptFooter` | TEXT | `'Ju Faleminderit!'` |
| `businessAddress` | TEXT | NULL |
| `businessPhone` | TEXT | NULL |

### `lib/manager/manager_data.dart`
6 new fields loaded from `company` row in `_init()`:
- `useEscPos` bool
- `cashDrawerEnabled` bool
- `paperWidthMm` int
- `receiptFooter` String
- `businessAddress` String?
- `businessPhone` String?

New method: `saveEscPosSettings({...})` — partial update, persists to DB and calls `notifyListeners()`.

### `lib/services/receipt_printer.dart`
Fully rewritten facade:
- `printKitchenOrder(...)` — routes through `EscPosPrinterService.printNow()` when `useEscPos == true`; falls back to legacy `WindowsPrintersService.printRawText()` when disabled
- `printShiftStatus(...)` — same routing pattern
- Both methods still return `Future<bool>` — **existing call sites in `pos_order_screen.dart` unchanged**

### `lib/screens/pos_order_screen.dart`
Added to `_payTable()` after successful payment receipt print:
```dart
if (data.cashDrawerEnabled) {
  final printer = await PrinterSettingsStore.loadSelectedPrinterName();
  if (printer.isNotEmpty) {
    EscPosPrinterService.instance.openCashDrawer(printer);
  }
}
```
Fire-and-forget — never blocks payment confirmation dialog.

### `lib/screens/admin_settings_screen.dart`

**Inside existing Printer card** (additions):
- Capability preview chip: detected profile name, paper width, cut/drawer support indicators
- **"Test Print"** button → `EscPosPrinterService.instance.printTestPage(...)` — prints all alignments, bold, columns, profile info
- **"Open Cash Drawer"** button → `EscPosPrinterService.instance.openCashDrawer(...)` — tests drawer without a sale

**New "Receipt Settings" card** (added after Printer card):
- ESC/POS toggle (SwitchListTile)
- Cash drawer toggle (SwitchListTile)
- Paper width selector: 80mm / 58mm (ChoiceChip)
- Receipt footer text field
- Business address field (optional — printed under company name on payment receipt)
- Business phone field (optional)
- "Save Receipt Settings" button

---

## Printer Detection Flow

```
1. Admin opens Admin Settings
2. Admin selects printer from Windows printer list (existing UI)
3. Below the dropdown: "Detected profile: Generic POS80 | Paper: 80mm · Cut: ✓ · Drawer: ✓"
4. Admin can override paper width in Receipt Settings (58mm / 80mm chip)
5. On "Test Print": profile is resolved → test receipt bytes generated → sent via winspool.drv
```

---

## Print Queue Behaviour

| Scenario | Behaviour |
|---|---|
| Normal print | Runs immediately via `printNow()` |
| Rapid double-tap on "Pay" | `_isPaying` flag in `PosOrderScreen` prevents second payment; print deduplication drops same `jobId` |
| Background enqueue | `enqueue()` returns instantly; job runs in background |
| Concurrent prints | `_processing` flag serialises jobs; second job waits |
| Print during payment dialog | Payment dialog appears immediately; print runs in background |

---

## Fallback Behaviour

| Failure point | Fallback |
|---|---|
| ESC/POS raw bytes fail (attempt 1) | Retry once (attempt 2) |
| ESC/POS raw bytes fail (attempt 2) | Fall back to `printRawText` GDI text mode |
| Text fallback also fails | Return false; payment flow continues unblocked |
| No printer configured | Return false immediately; no dialog shown |
| PowerShell timeout (>15s) | `ProcessResult` with exit code 1; triggers fallback |
| `drawerKick()` fails | Silently discarded; never blocks payment |

---

## How to Test on Real Hardware

### Prerequisites
- Windows 10/11
- POS80 thermal printer (USB or networked) installed as a Windows printer
- Printer driver installed and printer set to "Generic / Text Only" or native ESC/POS driver

### Steps
1. Open Admin Settings → select the printer from the dropdown
2. Tap **Test Print** — the test page should emerge from the printer showing:
   - Left / Center / Right alignment test
   - Bold text test
   - 3-column item grid
   - Printer profile info (name, paper width, cut, drawer)
3. Tap **Open Cash Drawer** — the drawer should open if connected to the printer's RJ-11 port
4. Go to POS → create an order → tap "Send Order" → kitchen receipt should print
5. Tap "Pay" → payment receipt with footer text should print; drawer opens if enabled

### Verification
- If the test page prints with correct alignment and bold, ESC/POS mode is working
- If only text with no formatting prints, the driver is intercepting bytes (disable GDI rendering in driver settings or use "Generic / Text Only" data type)
- Run `flutter run -d windows` and check the debug console — `Process.run` failures will surface as `exitCode != 0`

---

## Edge Cases Handled

| Edge case | Handling |
|---|---|
| Printer disconnected mid-print | PowerShell exits non-zero → retry → text fallback → return false |
| Duplicate payment taps | `_isPaying` flag in `PosOrderScreen` + job dedup in queue |
| Spooler timeout | `Process.run(...).timeout(15s)` → `ProcessResult(-1, 1, ...)` |
| Unsupported ESC/POS commands | `PrinterProfile.supportsCut/supportsDrawer` gates the command |
| Non-ASCII characters | `EscPosBytes._encode()` transliterates to ASCII |
| Long product names | `col(s, width)` truncates to column width |
| Large receipts | ESC/POS `MultiPage` is handled by the printer's internal buffer |
| Paper width mismatch | Admin can override via paper width chip in Receipt Settings |
| Printer offline | `isPrinterOnline()` used by capability preview; print continues anyway (spooler queues it) |
| Partial print failure | `WritePrinter` writes all bytes atomically; partial writes are not possible at this level |
| Failed drawer command | Silent `catch (_)` in `openCashDrawer()` — never blocks payment |
| ESC/POS disabled | Setting toggle routes all calls through legacy text path |
| Fresh install (no prior DB) | New columns present in `CREATE TABLE company` DDL |
| Restored older backup | `ALTER TABLE … ADD COLUMN` try-catch in `_onUpgrade` adds missing columns |

---

## Future Extension Points

The architecture is designed for extension without rewriting:

| Future target | Extension point |
|---|---|
| Android USB OTG | Replace `_sendRawBytes()` backend in `EscPosPrinterService` |
| Bluetooth ESC/POS | Replace `_sendRawBytes()` backend |
| Network/LAN printer | Replace `_sendRawBytes()` backend with socket |
| Sunmi internal printer | Add `SunmiPrinterService` + platform channel; `ReceiptPrinter` routes to it |
| Multiple printer zones (kitchen + receipt) | Add `kitchenPrinterName` to `company` table; split routing in `ReceiptPrinter` |

---

## `flutter analyze`

```
0 errors · 0 new warnings
```
(Pre-existing warnings unchanged)
