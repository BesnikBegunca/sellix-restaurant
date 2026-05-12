# POS System — Përshkrim i Plotë

## Çfarë është ky aplikacion?

**POS System** është një aplikacion **Flutter** për pikë shitjeje (Point of Sale) i destinuar për kafene, bare dhe restorante të vogla. Funksionon **100% offline** — nuk ka nevojë për internet, server, apo cloud. Të gjitha të dhënat ruhen në **SQLite** direkt në pajisjen ku ekzekutohet aplikacioni.

---

## Si funksionon

### Rrjedha e punës ditore

```
Hapja e aplikacionit
        │
        ▼
┌───────────────────┐
│   Login Screen    │  ← PIN numerik (4-6 shifra)
│  ose Name Mode    │     PIN 9999 = Menaxher
└───────────────────┘
        │
   ┌────┴────┐
   │         │
   ▼         ▼
Kamarier   Menaxher
   │         │
   ▼         ▼
Zgjidhja  Dashboard
tavolinës  Menaxheri
   │
   ▼
Porosia (POS Order Screen)
   │
   ▼
Pagesa → Regjistrohet shitja në SQLite
```

### Dy mënyra hyrjeje (konfigurohet nga menaxheri)

| Mënyra | Përshkrim |
|--------|-----------|
| **PINMODE** | Tastierë numerike — kamarieri shkruan PIN-in e tij |
| **NAMEMODE** | Lista e kamarierëve — klik mbi emrin, pa PIN |

---

## Teknologjitë e përdorura

| Teknologji | Versioni | Roli |
|-----------|---------|------|
| **Flutter** | SDK `^3.10.4` | Framework kryesor UI |
| **Dart** | `^3.10.4` | Gjuha e programimit |
| **Material 3** | built-in Flutter | Sistemi vizual UI |
| **sqflite** | `^2.3.3+1` | SQLite për Android / iOS |
| **sqflite_common_ffi** | `^2.3.4+1` | SQLite për Windows / macOS / Linux |
| **path_provider** | `^2.1.4` | Lokalizimi i skedarëve në disk |
| **path** | `^1.9.0` | Manipulim rrugësh skedarësh |
| **pdf** | `^3.11.1` | Gjenerimi i raporteve PDF |
| **printing** | `^5.13.4` | Printimi PDF (dialog sistem) |
| **file_picker** | `^6.1.1` | Zgjedhja e imazheve nga disku |

**Platformat e mbështetura:** Windows, macOS, Linux, Android, iOS, Web

---

## Struktura e bazës së të dhënave (SQLite)

Baza e të dhënave ruhet si skedar lokal `pos_system.db` dhe versionohet automatikisht (v7). Tabelat:

| Tabela | Çfarë ruan |
|--------|-----------|
| `company` | Emri i biznesit, logo (BLOB), mënyra hyrje, emri printerit |
| `waiters` | Kamarierët (emri + PIN unik) |
| `categories` | Kategoritë e menusë me ikonë Material |
| `products` | Produktet me çmim, emoji dhe imazh opsional |
| `tables` | Tavolinat (të zëna / bosh, totali aktual, kamarieri) |
| `current_orders` | Porositë aktive (meta: tavolina, kamarieri, numri porosis) |
| `current_order_lines` | Rreshtat e porosisë aktive (produkt, sasi) |
| `sales` | Historia e shitjeve të përfunduara |
| `expenses` | Shpenzimet (lloji, përshkrim, shumë, datë) |
| `shift` | Turni aktual (hapja / mbyllja) |
| `waiter_salaries` | Paga ditore për kamarier |
| `advances` | Avanset e dhëna kamarierëve |
| `waiter_worked_days` | Ditët e punuara (kalendar) |
| `app_meta` | Numëruesi global i porosive |

---

## Funksionalitetet e implementuara

### Kamarieri
- [x] Hyrja me PIN ose zgjedhje nga lista
- [x] Kalkulator ndrysi në ekranin e hyrjes (faturë / pagesë / ndryshi)
- [x] Zgjedhja e tavolinës (grid me gjendjen e tavolinave)
- [x] Krijimi dhe editimi i porosisë (shport me sasi)
- [x] Pagesa dhe regjistrimi i shitjes në SQLite
- [x] Porositë e hapura ruhen në SQLite — nëse mbyllet aplikacioni, porositë nuk humbasin

### Menaxheri
- [x] Dashboard me `NavigationRail`
- [x] Menaxhimi i menusë (kategori + produkte, drag-and-drop, editim, imazhe)
- [x] Menaxhimi i tavolinave (numri, kolonat)
- [x] Menaxhimi i kamarierëve (shtim, fshirje, PIN unik)
- [x] Shpenzimet (shtim, fshirje, lista)
- [x] Pagat dhe avanset (tarifë ditore, ditët e punuara, kalkulim mujor)
- [x] Fitimi real (revenue - expenses) ditor / javor / mujor nga SQLite
- [x] Top punëtori (sipas shitjeve)
- [x] Raportet dhe eksporti PDF (shpenzime, përmbledhja e menaxherit)
- [x] Gjendja e turnit (mbyllje / hapje, reset shitjesh)
- [x] Ndryshimi i mënyrës së hyrjes (PINMODE / NAMEMODE)
- [x] Ngarkimi i logos së kompanisë (BLOB në SQLite)

### Printimi
- [x] Gjenerimi i tekstit të kuponit (POS80, 32 karaktere gjerësi)
- [x] Formatimi i kuponit: emri biznesit, kamarieri, tavolina, produktet, totali, data
- [x] Printimi i gjendjes së turnit (si kupon termik)
- [x] **Windows:** listimi i printerëve të instaluar (PowerShell) dhe printimi direkt (System.Drawing)
- [x] Panel "Printers" në Admin Settings (dropdown + save)

---

## Sa larg është nga publikimi

### Gjendja aktuale: **~75% e gatshme**

#### Gjendje e mirë (funksionon plotësisht)
| Funksion | Gjendja |
|---------|---------|
| Hyrja dhe autentikimi | Plotë |
| Porositë dhe shitoret | Plotë |
| Baza e të dhënave SQLite | Plotë |
| Menuja dinamike | Plotë |
| Tavolinat | Plotë |
| Shpenzimet dhe pagat | Plotë |
| Raportet PDF | Plotë |
| Printimi Windows (tekst raw) | Plotë |
| Printimi PDF (dialog sistem) | Plotë |
| Rikuperimi i porosive pas rindezjes | Plotë |

#### Mungon për publikim real

| Çfarë mungon | Prioriteti | Vështirësia |
|-------------|-----------|-------------|
| **Siguria e PIN-eve** — aktualisht ruhen si tekst i thjeshtë në SQLite | E lartë | E mesme |
| **Backup / eksport i bazës** — nëse pajisja dëmtohet, të dhënat humbasin | E lartë | E ulët |
| **Testimi në pajisje reale** (Windows POS terminal + printer POS80) | E lartë | — |
| **Shumë valuta / formati** — aktualisht çmimet nuk kanë simbolin e monedhës | E mesme | E ulët |
| **Historiku i porosive** — shitjet fshihen me mbyllje turni; nuk ka arkivë afatgjatë | E mesme | E mesme |
| **Ricënim produkti** — nëse çmimi ndryshon, porositë historike tregojnë çmimin e ri | E mesme | E mesme |
| **Kodi PIN menaxher `9999` i fiksuar** — duhet të bëhet i konfigurushëm | E lartë | E ulët |
| **Nuk ka role** — çdo kamarier mund t'i shohë tavolinat e të tjerëve | E ulët | E mesme |
| **Printimi iOS / Android** — `printing` paketi funksionon por nuk është testuar me printer POS | E mesme | — |
| **Instaluesi / setup wizard** — hera e parë e hapjes nuk ka "wizard" konfigurimi | E ulët | E mesme |

---

## Çfarë duhet bërë për ta bërë perfekt për offline

Aplikacioni tashmë është i dizajnuar dhe arkitektuar si **offline-first**. SQLite me `sqflite_common_ffi` funksionon plotësisht pa lidhje interneti. Por për t'u konsideruar "i gatshëm për prodhim" offline, duhen:

### 1. Backup i automatizuar i bazës së të dhënave
```
Zbatimi:
- Buton "Eksporto DB" në Admin Settings → kopjon pos_system.db në USB / rrjet lokal
- Opsionalisht: backup automatik ditore në dosje të konfiguruar nga menaxheri
```

### 2. Kriptimi i PIN-eve
```dart
// Aktualisht:
await db.insert('waiters', {'name': name, 'pin': pin}); // tekst i thjeshtë!

// Duhet:
import 'package:crypto/crypto.dart';
final hashed = sha256.convert(utf8.encode(pin)).toString();
await db.insert('waiters', {'name': name, 'pin': hashed});
```

### 3. PIN menaxheri i konfigurushëm
```dart
// Aktualisht: if (pin == '9999') → menaxher
// Duhet: ruhet e enkriptuar në tabelën company
await db.update('company', {'managerPin': hashedPin}, where: 'id = 1');
```

### 4. Arkivimi i shitjeve sipas turnit
```sql
-- Tabela e re: shift_snapshots
CREATE TABLE shift_snapshots (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  closedAt   TEXT NOT NULL,
  salesJson  TEXT NOT NULL,  -- JSON e shitjeve
  totalRevenue REAL NOT NULL
);
```

### 5. Snapshot i çmimit në porosi
```sql
-- Aktualisht current_order_lines ruan productPrice ✓ (tashmë e mirë)
-- Por sales nuk ruan rreshtat — duhet tabela sale_lines
CREATE TABLE sale_lines (
  saleId       INTEGER NOT NULL REFERENCES sales(id),
  productName  TEXT NOT NULL,
  productPrice REAL NOT NULL,
  qty          INTEGER NOT NULL
);
```

### 6. Testimi i plotë mbi hardware reale
- Windows 10/11 + printer termik POS80 (port USB/COM)
- Tablet Android me ekran 10"+ (orientim landscape)
- Skenar i plotë: hapje aplikacion → porosi → pagim → kupon → mbyllje turni

---

## Struktura e kodit

```
lib/
├── main.dart                          # Entry point, SQLite init, MaterialApp
├── manager/
│   └── manager_data.dart              # Singleton ChangeNotifier — gjendja globale
├── models/
│   └── mock_data.dart                 # TableInfo, ProductItem, CategoryData
├── screens/
│   ├── login_screen.dart              # PIN / NAMEMODE + kalkulator ndrysi
│   ├── waiter_selection_screen.dart   # Lista kamarierësh (NAMEMODE)
│   ├── table_selection_screen.dart    # Grid tavolinash
│   ├── pos_order_screen.dart          # Shporta dhe porosia
│   ├── manager_dashboard_screen.dart  # Dashboard menaxheri
│   └── admin_settings_screen.dart     # Cilësimet: printerë, login mode
├── services/
│   ├── database_service.dart          # DAL SQLite (të gjitha queries)
│   ├── database_helper.dart           # Alias backward-compatible
│   ├── receipt_text.dart              # Gjenerimi tekst kupon POS80
│   ├── receipt_printer.dart           # Abstraksia printimit
│   ├── windows_printers_service.dart  # PowerShell: listim + printim Windows
│   ├── printer_settings_store.dart    # Ruajtja zgjedhjes printerit
│   ├── expenses_pdf_export.dart       # PDF shpenzimesh
│   └── manager_summary_pdf.dart       # PDF përmbledhja menaxheri
├── theme/
│   ├── app_colors.dart                # Ngjyrat e brendit (jeshile + beige)
│   └── pos_grid.dart                  # Parametrat grid
├── utils/
│   └── image_utils.dart               # Ndihma imazhesh
└── widgets/
    ├── gg_header.dart                 # Header i përbashkët
    └── hover_interaction.dart         # Efektet hover desktop
```

---

## Ekzekutimi lokal

```bash
cd pos_system
flutter pub get

# Windows (rekomandohet për POS)
flutter run -d windows

# macOS
flutter run -d macos

# Android
flutter run -d android

# Web (pa printim termik)
flutter run -d chrome
```

---

## Përmbledhje e shpejtë

| Aspekt | Gjendja |
|--------|---------|
| Offline-first | **Po — plotësisht** (SQLite lokal) |
| Backend / internet | **Jo — nuk kërkohet** |
| Platforma kryesore | Windows POS terminal |
| Platforma sekondare | Android tablet, macOS |
| Printimi | Windows (termik raw) + të gjitha platformat (PDF) |
| Gatishmëria për prodhim | **~75%** |
| Gjëja kryesore që mungon | Backup DB + kriptim PIN + arkivë shitjesh |
