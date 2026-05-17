# POS System — Dashboard UI Design System

**Qëllimi:** Ky dokument përshkruan **saktësisht** pamjen vizuale të Manager Dashboard në `pos_system`, që një projekt tjetër (p.sh. `pos_stats_mobile`) ta **kopjojë 1:1** — ngjyra, font, ikona Material, spacing, komponente.

**Burimi i vërtetë në kod:**
- `lib/theme/app_colors.dart`
- `lib/theme/app_tokens.dart`
- `lib/theme/app_text_styles.dart`
- `lib/theme/app_spacing.dart`
- `lib/theme/app_radius.dart`
- `lib/theme/app_shadows.dart`
- `lib/main.dart` (ThemeData global)
- `lib/features/dashboard/widgets/manager_side_nav.dart`
- `lib/features/dashboard/widgets/manager_top_bar.dart`
- `lib/features/dashboard/widgets/stat_card.dart`
- `lib/widgets/dashboard/kpi_card.dart`
- `lib/widgets/dashboard/app_card.dart`
- `lib/widgets/dashboard/status_badge.dart`

**Font asset (kopjo në projektin mobil):**
```
assets/fonts/DMSans-VariableFont_opsz,wght.ttf
assets/fonts/DMSans-Italic-VariableFont_opsz,wght.ttf
```
Regjistro në `pubspec.yaml` si `family: DMSans`.

**Ikona:** vetëm **Material Icons** (`uses-material-design: true`) — **mos** përdor Cupertino ose ikona custom për dashboard.

---

## 1. Identiteti vizual

| Aspekt | Vlera |
|--------|--------|
| Stil | Premium, i pastër, hospitality / restorant |
| Ndjenja | Jeshile pyll, beige e butë, karta të bardha me border të lehtë |
| Hije | Të buta, jo të zeza — alpha ~4–8% |
| Kontrast | I lartë për titujt; tekst i zbutur për metadata |
| Material | Material 3 (`useMaterial3: true`) |

---

## 2. Paleta ngjyrash (HEX)

Kopjo këto vlera **fiks** — mos zëvendëso me ngjyra të ngjashme.

### Brand & sfond

| Token | HEX | Përdorim |
|-------|-----|----------|
| `primaryGreen` / `deepForestGreen` | `#234B36` | CTA, nav aktiv, vlera të theksuara, shiritë grafikë |
| `oliveGreen` | `#3E6B52` | Hover sekondar |
| `beige` / `warmOffWhite` | `#F7F8F6` | **Sfondi i faqes** (scaffold) |
| `lightGreenBg` / `softGreenTint` | `#EAF0EA` | Hover nav, chip, icon box background |
| `white` / `pureWhite` | `#FFFFFF` | Karta, header, sidebar |

### Border

| Token | HEX |
|-------|-----|
| `lightGreenBorder` | `#DCE5DC` |

### Tekst

| Token | HEX | Përdorim |
|-------|-----|----------|
| `darkGreenText` / `charcoalText` | `#222222` | Tituj, vlera KPI |
| `mediumGreenText` | `#555555` | Body |
| `lightGreenText` | `#888888` | Subtitle, metadata, hint |
| `mutedGray` | `#9E9E9E` | Label KPI (KpiCard) |

### Semantike

| Token | HEX | Përdorim |
|-------|-----|----------|
| `warmGold` | `#D4AF37` | Fitim, revenue, top employee |
| `successGreen` | `#28A745` | Trend pozitiv |
| `softRed` / `negativeText` / `accentRed` | `#DC3545` | Gabim, shpenzime |
| `mutedOrange` / `accentOrange` | `#FFA07A` | Warning, tavolina të zëna |
| `infoBlue` / `accentBlue` | `#5B9BD5` | Info |
| `negativeBg` | `#FFEBEE` | Sfond gabimi (i rrallë) |

### Border dinamik (opsional)

```dart
Color borderSubtle([double a = 0.1]) => Color(0xFF234B36).withValues(alpha: a);
```

---

## 3. Tipografia — fonti **DMSans**

**Font family globale:** `DMSans` (në çdo `TextStyle` dhe `ThemeData.fontFamily`).

| Rol | Size | Weight | Color | Line height | Letter spacing |
|-----|------|--------|-------|---------------|----------------|
| Page title (Overview) | 30 | w700 | `#222222` | 1.15 | -0.3 |
| Page title (token) | 32 | w600 | `#222222` | 1.2 | — |
| Section title (top bar) | 22 | w600 | `#222222` | 1.2 | — |
| Section title (card/AppCard) | 22–24 | w600–w700 | `#222222` | 1.2–1.25 | — |
| Card title | 18 | w600–w700 | `#222222` | — | — |
| KPI value (KpiCard) | **44** | w600 | `#222222` | 1.05 | — |
| KPI value (alt) | 40 | w600 | `#222222` | 1.1 | -0.5 |
| StatCard value | 20 | w700 | `#222222` | 1.1 | — |
| Body | 15–16 | w400 | `#222222` | 1.5 | — |
| Body small / table | 14 | w400–w500 | `#555555` | — | — |
| Muted / metadata | 12–13 | w400–w500 | `#888888` | 1.4 | 0.2–0.6 |
| Nav item | 14 | w500 (w600 aktiv) | primary ose medium | — | — |
| Button | 15 | w500 | white / primary | — | 0.1 |
| Badge | 11 | w600 | sipas variantit | — | 0.2–0.8 |
| Top bar chip label | 13 | w600 | `#222222` | 1.1 | — |
| Manager badge | 11 | w700 | `#FFFFFF` | — | **0.8** |

**Monedha:** format `XX.XX€` (euro pas numrit).

---

## 4. Spacing & layout

| Token | px |
|-------|-----|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `base` | 16 |
| `lg` / `cardGap` | 24 |
| `xl` / `pagePadding` | 32 |
| `xxl` | 48 |

| Layout | px |
|--------|-----|
| Sidebar gjerë | 256 |
| Sidebar i mbledhur | 80 |
| Header / top bar lartësi | 80 |
| Max content width | 1440 |
| Gap midis StatCard në row | 12 |
| Gap midis seksioneve | 20–24 |

**Padding faqe (dashboard body):** `32` all sides.

**Padding karte:** `24` (KpiCard, AppCard, SettingsCard); `20` (StatCard, TodaySummaryCard).

---

## 5. Radius & hije

| Element | Radius |
|---------|--------|
| Button / input / chip / badge | 12 |
| StatCard (variant) | 14 |
| Chart card | 16 |
| Card (standard) | **18** |
| Icon box (KpiCard) | 12 |
| Icon box (StatCard) | 10 |
| Dialog / modal | 20–24 |
| Pill badge | 20 |
| Logo box (login) | 16 |

**Hije karte (standard):**
```dart
BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))
// ose
BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))
```

**Karta:** `elevation: 0` — pamja vjen nga border + hije e lehtë, jo Material elevation të errët.

---

## 6. Struktura ekranit Dashboard

```
┌─────────────┬──────────────────────────────────────────┐
│  SIDEBAR    │  TOP BAR (80px, white, border bottom)    │
│  256px      ├──────────────────────────────────────────┤
│  white      │  CONTENT (beige #F7F8F6, padding 32)      │
│             │  max-width 1440, left-aligned            │
└─────────────┴──────────────────────────────────────────┘
```

### 6.1 Sidebar (`ManagerSideNav`)

- Sfond: `#FFFFFF`
- Border djathtas: `1px #DCE5DC`
- Header zone: lartësi `80px`
- Logo box: `32×32`, radius `8`, bg `#234B36`, ikonë `Icons.restaurant` white `18px`
- Titull: **"Menaxher POS"** — 15px w600 `#222222`
- Toggle: `Icons.keyboard_double_arrow_left` (hapur) / `Icons.menu` (mbledhur)
- Item lartësi: `44px`, radius `12`
- Item **aktiv**: bg `#EAF0EA`, shirit majtas `4×28px` `#234B36`, ikonë + tekst `#234B36` w600
- Item **inaktiv**: ikonë `#555555` w500
- Hover: bg `#EAF0EA`
- Footer: `OutlinedButton` "Dil" + `Icons.logout`

**Ikona navigimi (outline → filled kur aktiv):**

| Label (SQ) | Outline | Selected |
|------------|---------|----------|
| Përmbledhje | `Icons.dashboard_outlined` | `Icons.dashboard` |
| Gjendja | `Icons.schedule_outlined` | `Icons.schedule` |
| Kamarierët | `Icons.badge_outlined` | `Icons.badge` |
| Shpenzime | `Icons.table_rows_outlined` | `Icons.table_rows` |
| Fitime | `Icons.trending_up_outlined` | `Icons.trending_up` |
| Raporte | `Icons.description_outlined` | `Icons.description` |
| Top puntor | `Icons.emoji_events_outlined` | `Icons.emoji_events` |
| Menu | `Icons.menu_book_outlined` | `Icons.menu_book` |
| Tavolinat | `Icons.grid_view_outlined` | `Icons.grid_view` |
| Cilësimet | `Icons.settings_outlined` | `Icons.settings` |
| Pagat | `Icons.payments_outlined` | `Icons.payments` |
| Refund | `Icons.undo_outlined` | `Icons.undo` |
| Historiku | `Icons.history_outlined` | `Icons.history` |
| Audit | `Icons.security_outlined` | `Icons.security` |

### 6.2 Top bar (`ManagerTopBar`)

- Sfond `#FFFFFF`, border bottom `#DCE5DC`
- Titull seksioni: 22px w600
- Subtitle: `Manager Dashboard · POS System` — 12px `#888888`
- **Shift chip:** dot 7px (jeshile nëse hapur), tekst "Gjendja e hapur" / "Gjendja e mbyllur"
- **Koha:** `Icons.schedule_outlined` + HH:mm + datë dd.MM.yyyy në chip `#EAF0EA`
- **Badge menaxher:** bg `#234B36`, `Icons.manage_accounts` + "MENAXHER" white 11px w700

---

## 7. Komponente kryesore

### 7.1 `KpiCard` (premium KPI)

```
┌─────────────────────────────────┐
│ [icon 48×48]          [+12%?]   │  ← icon box: bg #EAF0EA, icon #234B36 24px
│ Label (13px #9E9E9E w500)       │
│ VALUE (44px w600 #222222)       │
│ subtitle? (14px #9E9E9E)         │
└─────────────────────────────────┘
```
- Karta: white, border `#DCE5DC`, radius **18**, padding **24**
- Trend pozitiv: `#28A745` | negativ: `#DC3545`

### 7.2 `StatCard` (grid overview)

```
┌────────────────────────┐
│ [40×40 icon]  [badge?] │
│ TITLE (12px #888)      │
│ Value (20px w700)      │
│ subtitle? (12px #555)  │
└────────────────────────┘
```
- Padding `20`, radius `14`, hije `0x08… blur 12 offset (0,4)`
- Icon box: `40×40`, radius `10`, bg = `accentColor @ 10% alpha`
- Badge pill: bg primary `@ 8%`, tekst primary 11px w600

**StatCard icons & accent (Overview):**

| Titull | Icon | Accent |
|--------|------|--------|
| Gjendja e Turnit | `Icons.schedule_outlined` | primary / muted |
| Kamarierë Aktivë | `Icons.people_outline` | default primary |
| Shpenzime Sot | `Icons.payments_outlined` | `#DC3545` |
| Fitim Ditor | `Icons.trending_up` | `#D4AF37` |
| Fitim Javor | `Icons.trending_up_outlined` | `#D4AF37` |
| Punonjësi Më i Mirë | `Icons.emoji_events_outlined` | `#D4AF37` |
| Tavolina të Lira | `Icons.table_restaurant_outlined` | primary |
| Tavolina të Zëna | `Icons.event_seat_outlined` | `#FFA07A` |
| Bilanci i Hapur | `Icons.account_balance_wallet_outlined` | default |
| Kategoritë e Menusë | `Icons.restaurant_menu_outlined` | default |
| Produktet | `Icons.inventory_2_outlined` | default |
| Shitjet e Stafit | `Icons.point_of_sale_outlined` | `#D4AF37` |

### 7.3 `AppCard` (seksion i madh)

- Titull: 22px w600
- Subtitle: 13px `#9E9E9E`
- Radius 18, padding 24, hije alpha 0.04 blur 24

### 7.4 `SettingsCard`

- Ikona në kuti `40×40`, bg `#EAF0EA`, icon `#234B36` 20px
- Titull 18px w700
- I njëjti border/hije si kartat e tjera

### 7.5 `StatusBadge`

| Variant | Background | Text | Border |
|---------|------------|------|--------|
| success | `#EAF0EA` | `#234B36` | `#DCE5DC` |
| warning | orange 22% | charcoal | orange 45% |
| info | blue 14% | charcoal | blue 35% |
| error | red 12% | `#DC3545` | red 35% |
| neutral | green tint 65% | `#9E9E9E` | `#DCE5DC` |

Padding: `12×6` (normal), `8×4` (compact). Radius `12`. Font 12–14px w600.

### 7.6 Butonat (ThemeData)

| Lloji | BG | Text | Border | Min height |
|-------|-----|------|--------|------------|
| Elevated / Filled | `#234B36` | white | — | 48 |
| Outlined | transparent | `#234B36` | `#DCE5DC` | 48 |

Radius buton: **12**.

### 7.7 Input fields

- Filled white
- Border `#DCE5DC`, radius 12
- Focus: border `#234B36` **width 2**
- Hint: 14px `#888888`
- Padding: `16×14`

### 7.8 SnackBar

- Floating
- BG `#234B36`
- Tekst white

### 7.9 Dialog

- BG `#EAF0EA`
- Elevation 0
- Radius 20
- Title 18px w700 `#222222`

---

## 8. Grafikët (fl_chart)

**Bar chart (Weekly Sales):**
- Bar: `#234B36`, width 28, top radius 6
- Background rod: `#EAF0EA` @ 60% alpha
- Karta: white, radius 16, padding 24
- Titull chart: 15px w600

**Pie / occupancy:** përdor të njëjtën paletë (primary, orange, lightGreenBg).

---

## 9. Overview — header pattern

```dart
// Titull faqe
Text('Pasqyra', style: TextStyle(
  fontSize: 30, fontWeight: FontWeight.w700,
  color: Color(0xFF222222), height: 1.15, letterSpacing: -0.3,
));
Text('Real-time operational insights', style: TextStyle(
  fontSize: 14, color: Color(0xFF888888), height: 1.4,
));
```

---

## 10. Përshtatje për MOBIL (`pos_stats_mobile`)

Mbaj **të njëjtat** token-e; ndrysho vetëm layout:

| Desktop | Mobile |
|---------|--------|
| Sidebar 256px | Bottom nav **ose** drawer i hapur |
| Row 4–6 StatCard | `GridView` 2 kolona |
| Padding 32 | Padding 16–20 |
| Top bar 80px | `AppBar` kompakt + titull 20px |
| maxWidth 1440 | full width |

**Mos ndrysho:** ngjyrat HEX, DMSans, ikonat Material, stilin e KpiCard/StatCard, border `#DCE5DC`, sfond beige.

### Ekran i rekomanduar mobil (stats only)

1. **AppBar** — titull "Pasqyra Live", chip sync (Live/Offline)
2. **Row 2×2 KpiCard:**
   - `Icons.euro` / `Icons.today` → Totali sot
   - `Icons.schedule` → Total shift
   - `Icons.receipt_long` → Porosi sot
   - `Icons.hourglass_top` → Hapur tani
3. **AppCard** "Kamarierët" — listë si tabelë: emër | paguar | hapur | total
4. **AppCard** "Porositë sot" — rreshta: ora, kamarier, tavolinë, total€

Ikona për mobile stats (shtesë, nëse duhen):
- `Icons.point_of_sale`
- `Icons.people_outline`
- `Icons.wifi` / `Icons.cloud_off` (sync status)

---

## 11. ThemeData Flutter (kopjo në projektin mobil)

```dart
ThemeData(
  useMaterial3: true,
  fontFamily: 'DMSans',
  scaffoldBackgroundColor: const Color(0xFFF7F8F6),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF234B36),
    brightness: Brightness.light,
    primary: const Color(0xFF234B36),
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: const Color(0xFF222222),
  ),
  // ... kopjo inputDecorationTheme, elevatedButtonTheme, cardTheme,
  // snackBarTheme, dialogTheme nga lib/main.dart
);
```

---

## 12. Checklist për Codex / AI

Kur ndërtosh UI mobil, verifiko:

- [ ] Fonti është **DMSans** (jo Roboto/Inter)
- [ ] Sfondi faqes `#F7F8F6`, kartat `#FFFFFF`
- [ ] Border kartash `#DCE5DC`, radius 18 (ose 14 për StatCard)
- [ ] Primary CTA `#234B36`
- [ ] Ikona nga **Material Icons** me emra të saktë si në tabelën e sidebar
- [ ] KPI values ~40–44px w600
- [ ] Icon box: `#EAF0EA` + ikonë `#234B36`
- [ ] Hije të buta, jo Material elevation 8+
- [ ] Tekst shqip në UI (labels)
- [ ] Formati parash `123.45€`

---

## 13. Referencë vizuale e shpejtë (ASCII)

```
Palette:
  █ #234B36  primary
  █ #F7F8F6  page bg
  █ #EAF0EA  tint
  █ #DCE5DC  border
  █ #222222  text
  █ #888888  muted
  █ #D4AF37  gold KPI
  █ #DC3545  red
```

---

*Dokument i gjeneruar nga `pos_system` — përditëso nëse ndryshon `lib/theme/`.*
