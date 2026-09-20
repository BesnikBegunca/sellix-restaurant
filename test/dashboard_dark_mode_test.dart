import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/features/dashboard/panels/company_settings_panel.dart';
import 'package:pos_system/features/dashboard/panels/staff_panel.dart';
import 'package:pos_system/manager/manager_data.dart';
import 'package:pos_system/services/app_language_service.dart';
import 'package:pos_system/theme/app_theme.dart';
import 'package:pos_system/theme/theme_mode_controller.dart';

/// Renders real dashboard panels in both appearances and asserts that what is
/// actually painted follows the theme — the thing that was broken when the
/// palette was a set of const light colours.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Widget host(Widget child, {required bool dark}) {
    ThemeModeController.instance.debugSetDark(dark);
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }

  /// Every Container background actually painted in the subtree.
  List<Color> paintedBackgrounds(WidgetTester tester) {
    final colors = <Color>[];
    for (final e in find.byType(Container).evaluate()) {
      final d = (e.widget as Container).decoration;
      if (d is BoxDecoration && d.color != null) colors.add(d.color!);
    }
    return colors;
  }

  List<Color> paintedTextColors(WidgetTester tester) {
    final colors = <Color>[];
    for (final e in find.byType(Text).evaluate()) {
      final c = (e.widget as Text).style?.color;
      if (c != null) colors.add(c);
    }
    return colors;
  }

  tearDown(() {
    ThemeModeController.instance.debugSetDark(false);
    AppLanguageService.instance.debugSetLanguage(AppLanguage.albanian);
  });

  testWidgets('staff panel paints dark surfaces in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(StaffPanel(m: ManagerData.instance), dark: true),
    );
    await tester.pump();

    final backgrounds = paintedBackgrounds(tester);
    expect(backgrounds, isNotEmpty);

    // No painted panel background may be near-white in dark mode. Before the
    // fix these were literal 0xFFFFFFFF from the const palette.
    for (final c in backgrounds) {
      if (c.a < 0.9) continue; // skip translucent tints
      expect(
        c.computeLuminance(),
        lessThan(0.5),
        reason: 'light surface $c painted in dark mode',
      );
    }

    // And the text must be light so it reads against them.
    final texts = paintedTextColors(tester);
    expect(texts, isNotEmpty);
    final dark = texts.where((c) => c.computeLuminance() < 0.25).toList();
    expect(dark, isEmpty, reason: 'dark text $dark painted on dark surfaces');
  });

  testWidgets('staff panel paints dark surfaces for the roster too', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(StaffPanel(m: ManagerData.instance), dark: true),
    );
    await tester.pump();

    for (final c in paintedBackgrounds(tester)) {
      if (c.a < 0.9) continue;
      expect(c.computeLuminance(), lessThan(0.5), reason: '$c');
    }
  });

  testWidgets('the same panel is light in light mode', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(StaffPanel(m: ManagerData.instance), dark: false),
    );
    await tester.pump();

    final opaque = paintedBackgrounds(tester).where((c) => c.a >= 0.9).toList();
    expect(opaque, isNotEmpty);
    expect(
      opaque.any((c) => c.computeLuminance() > 0.7),
      isTrue,
      reason: 'light mode should still paint light surfaces',
    );
  });

  testWidgets('settings panel renders all six languages', (tester) async {
    tester.view.physicalSize = const Size(1800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(CompanySettingsPanel(m: ManagerData.instance), dark: true),
    );
    await tester.pump();

    for (final l in AppLanguage.values) {
      expect(
        find.text(l.nativeName),
        findsOneWidget,
        reason: '${l.code} missing from the language card',
      );
    }
  });

  testWidgets('panels stack their form fields when the window is narrow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Wide: the name field and the button share a row.
    tester.view.physicalSize = const Size(1600, 1200);
    await tester.pumpWidget(
      host(StaffPanel(m: ManagerData.instance), dark: false),
    );
    await tester.pump();
    final wideButton = tester.getTopLeft(find.text('Shto anëtar').last);
    final wideField = tester.getTopLeft(find.byType(TextField).first);
    expect(
      wideButton.dy,
      closeTo(wideField.dy, 40),
      reason: 'wide layout should keep the button beside the fields',
    );

    // Narrow: everything stacks, so the button drops well below the field.
    tester.view.physicalSize = const Size(700, 1600);
    await tester.pumpWidget(
      host(StaffPanel(m: ManagerData.instance), dark: false),
    );
    await tester.pump();
    final narrowButton = tester.getTopLeft(find.text('Shto anëtar').last);
    final narrowField = tester.getTopLeft(find.byType(TextField).first);
    expect(
      narrowButton.dy,
      greaterThan(narrowField.dy + 60),
      reason: 'narrow layout should stack the button under the fields',
    );
  });
}
