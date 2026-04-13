# POS System — Përshkrimi i projektit

## Çfarë është ky projekt?

**POS System** është një aplikacion **Flutter** (Material 3) që simulon një **sistem pikësh shitjeje (POS)** për një ambient kafene / bar. Aplikacioni ofron hyrje me PIN për kamarierët, zgjedhje tavolinash, ndërtim porosish, pagesë, si dhe një **panel menaxheri** për menunë, tavolinat, shpenzimet, raportet dhe statistikat.

Të dhënat janë **në memorie** (pa bazë të dhënash të jashtme): pas mbylljes së aplikacionit gjendja humbet, përveç asaj që është e koduar si “mock” në `lib/models/mock_data.dart`.

---

## Qëllimi

- **Operacioni i ditës:** lejojë kamarierin të zgjedhë një tavolinë, të shtojë produkte sipas kategorive, të menaxhojë sasinë dhe totalin, dhe të finalizojë pagesën.
- **Menaxhimi:** lejojë menaxherin (PIN i veçantë) të konfigurojë menunë (kategori, produkte, lëvizje me drag-and-drop), tavolinat, kamarierët, turnin (shift), shpenzimet dhe të shohë përmbledhje fitimesh / “top puntor”.
- **UX për tablet / POS:** grid për tavolina dhe produkte, tema me ngjyra të markës (`AppColors`), header i përbashkët (`GgAppHeader`), ndërveprime hover ku ka kuptim.

---

## Teknologji dhe kërkesa

| Element | Vlera |
|--------|--------|
| Framework | Flutter |
| Gjuha | Dart (SDK `^3.10.4` në `pubspec.yaml`) |
| UI | Material 3, `cupertino_icons` |
| Platforma | Android, iOS, etj. (projekt standard Flutter) |

**Ekzekutimi lokal:**

```bash
cd pos_system
flutter pub get
flutter run
```

---

## Rrjedha kryesore e përdoruesit

1. **Hyrja (`LoginScreen`)**  
   - Tastierë numerike: PIN 4–6 shifra për kamarier, ose **PIN `9999`** për menaxherin.  
   - I njëjti ekran ofron edhe një **kalkulator ndrysi** (faturë / pagesë / ndryshi) kur zgjidhen fushat përkatëse — i dobishëm për POS në banak.

2. **Kamarieri**  
   - Pas PIN të saktë: **`TableSelectionScreen`** — rrjet tavolinash, përmbledhje tavolinash të zëna dhe totali i hapur.  
   - Zgjedhja e një tavoline hap **`PosOrderScreen`** me numër tavoline, numër porosie dhe emrin e kamarierit.

3. **Porosia (`PosOrderScreen`)**  
   - Kategori produktesh (menuja vjen nga `ManagerData`, e inicializuar nga mock).  
   - Shportë me sasi, total, veprime pagese; pas pagesës regjistrohet shitja për kamarierin (`recordSale`) sipas logjikës në kod.

4. **Menaxheri (`ManagerDashboardScreen`)**  
   - **`NavigationRail`** me seksione: Përmbledhje, Gjendja (shift), Kamarierët, Shpenzime, Fitime, Raporte, Top puntor, Menu, etj. (sipas implementimit në skedar).  
   - Nga dashboardi mund të dalë te hyrja (logout në sens navigimi).

---

## Struktura e kodit (përmbledhje)

| Rruga | Roli |
|-------|------|
| `lib/main.dart` | `PosSystemApp`, `MaterialApp`, tema, `home: LoginScreen` |
| `lib/screens/` | Ekranet: hyrje, tavolina, porosi POS, dashboard menaxheri |
| `lib/manager/manager_data.dart` | **Singleton** `ManagerData`: shift, kamarierë, shpenzime, shitje kamarierësh, menu dinamike, tavolina, notifikim UI (`ChangeNotifier`) |
| `lib/models/mock_data.dart` | Modelet `TableInfo`, `ProductItem`, `CategoryData` dhe lista fillestare mock (kafe, pije, kokteje, snack, etj.) |
| `lib/theme/` | `app_colors.dart`, `pos_grid.dart` — ngjyra dhe parametrat e grid-it |
| `lib/widgets/` | `gg_header.dart`, `hover_interaction.dart` — komponentë të përbashkët |
| `assets/images/` | Imazhe produktesh (të deklaruara në `pubspec.yaml`) |

---

## Funksionalitete të rëndësishme (menaxher / gjendje)

- **Turni (shift):** hapje / mbyllje, me data kohore.  
- **Kamarierët:** shtim me emër dhe PIN (PIN duhet të jetë unik; `9999` i rezervuar menaxherit).  
- **Shpenzime:** lista `ExpenseRow` me lloj, përshkrim, shumë, datë.  
- **Fitime:** vlera demo (`_baseDaily` / `_baseWeekly` / `_baseMonthly`) të kombinuara me shpenzimet — **jo** llogari kontabël reale, por vizualizim për UI.  
- **Top puntor / shitje:** `waiterSales` mblidhet kur finalizohet pagesa nga POS.  
- **Menu:** shtim / fshirje kategorish dhe produktesh, editim produkti, lëvizje produkti midis kategorive (`moveProduct`).  
- **Tavolina:** numër tavolinash, kolona, përditësim totali / zbrazje, shtim tavoline.

---

## Kufizime dhe shënime për zhvillim të ardhshëm

- **Nuk ka backend** ose ruajtje të përhershme: rihapja e aplikacionit rivendos pjesën që varet vetëm nga `ManagerData` (kamarierët e shtuar, shift-i, etj.), përveç inicializimit nga mock.  
- **Siguria:** PIN `9999` dhe PIN-et e kamarierëve janë për **demo**; në prod duhet autentikim i fortë dhe ruajtje e sigurt.  
- **Pagesa** është e integruar në UI si rrjedhë aplikacioni, jo si integrim me terminale bankare reale.

---

## Përmbledhje

**pos_system** është një prototip **POS System**: Flutter, UI e strukturuar për kamarier dhe menaxher, menu dhe tavolina të menaxhueshme në aplikacion, me të dhëna demo dhe gjendje në memorie — i përshtatshëm për demonstrim, dizajn UX dhe zgjerim të ardhshëm (API, DB, printim faturash, etj.).
