import 'package:agent_ui_mobile/core/theme/app_theme.dart';
import 'package:agent_ui_mobile/core/theme/tokens.dart';
import 'package:agent_ui_mobile/features/pairing/pairing_screen.dart';
import 'package:agent_ui_mobile/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// WCAG relative-luminance contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  test('both themes build with the palette and a blue primary', () {
    for (final brightness in Brightness.values) {
      final theme = buildTheme(brightness);
      final palette = theme.extension<AppPalette>()!;
      expect(theme.colorScheme.brightness, brightness);
      expect(theme.colorScheme.primary, palette.primary);
      expect(palette.primary.b, greaterThan(palette.primary.r), reason: 'primary stays blue');
    }
    expect(AppPalette.light.lerp(AppPalette.dark, 1).primary, AppPalette.dark.primary);
    expect(AppPalette.light.lerp(null, 0.5), AppPalette.light);
  });

  test('text colors reach 4.5:1 on the surfaces they sit on', () {
    for (final p in [AppPalette.light, AppPalette.dark]) {
      for (final surface in [p.background, p.surface, p.drawer, p.inputFill]) {
        expect(contrast(p.text, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.muted, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primary, surface), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(p.text, p.userBubble), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onTertiary, p.tertiary), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onSecondary, p.secondary), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onError, p.error), greaterThanOrEqualTo(4.5));
      expect(contrast(p.warning, p.warningBackground), greaterThanOrEqualTo(4.5));
      expect(contrast(p.codeText, p.codeBackground), greaterThanOrEqualTo(4.5));
    }
  });

  for (final brightness in Brightness.values) {
    for (final screen in ['pairing', 'settings']) {
      testWidgets('$screen fits a 320dp screen at 2x text in ${brightness.name} mode', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);

        final harness = await Harness.create(signedIn: screen == 'settings');
        await harness.pumpApp(tester);
        if (screen == 'settings') {
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(find.text('Connected'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('0.1.0 (1)'), 200);
          expect(find.text('0.1.0 (1)'), findsOneWidget);
        } else {
          expect(find.byType(PairingScreen), findsOneWidget);
        }
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final context = tester.element(find.byType(Scaffold).last);
        expect(Theme.of(context).brightness, brightness);
      });
    }
  }
}
