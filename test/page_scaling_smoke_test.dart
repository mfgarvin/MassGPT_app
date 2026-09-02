import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/main.dart';
import 'package:parishfinder/pages/filtered_parish_list_page.dart';
import 'package:parishfinder/pages/find_parish_near_me_page.dart';
import 'package:parishfinder/pages/research_parish_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

/// Every top-level screen, pumped and scrolled at normal and maximum text
/// size. An overflow (or any other layout assertion) is an exception in a
/// test, so this is a broad net rather than a precise one: it says *some*
/// screen broke, and the failure names the widget and file.
///
/// It caught the Home wordmark colliding with the menu button, the square
/// next-Mass tile spilling its third line, and the map's fixed-height carousel
/// — none of which the per-widget tests were looking at.
///
/// Screens needing more than a pump (the filter sheet, the parish detail page)
/// have their own tests in text_scaling_test.dart.
const _phone = Size(360, 800);
const _scales = [1.0, 2.0];

Widget _wrap(Widget child, double scale) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );

void main() {
  setUpAll(loadAppFonts);

  final screens = <String, Widget Function()>{
    'HomePage': () => const HomePage(),
    'RootShell': () => const RootShell(),
    'FavoritesPage': () => const FavoritesPage(),
    'SettingsPage': () => const SettingsPage(),
    'AboutPage': () => const AboutPage(),
    'FeedbackPage': () => const FeedbackPage(),
    'ResearchParishPage': () => const ResearchParishPage(),
    'FirstRunDisclaimerDialog': () => const FirstRunDisclaimerDialog(),
    'FindParishNearMePage': () => const FindParishNearMePage(),
    'Confession list': () => const FilteredParishListPage(
          filter: ParishFilter.confession,
          title: 'Confession Times',
          accentColor: Colors.purple,
        ),
    'Adoration list': () => const FilteredParishListPage(
          filter: ParishFilter.adoration,
          title: 'Adoration',
          accentColor: Colors.orange,
        ),
  };

  for (final screen in screens.entries) {
    for (final scale in _scales) {
      testWidgets('${screen.key} lays out at ${scale}x', (tester) async {
        SharedPreferences.setMockInitialValues({
          'cached_parishes_json': File('export.demo.json').readAsStringSync(),
          // A saved parish, so the home-parishes strip is populated.
          'favorite_parishes': ['id:0689'],
        });
        await favoritesManager.init();
        tester.view.physicalSize = _phone * tester.view.devicePixelRatio;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(screen.value(), scale));
        // Two frames: parish data arrives from the mocked cache asynchronously.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull,
            reason: '${screen.key} threw on first layout at ${scale}x');

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isEmpty) return;
        for (var i = 0; i < 8; i++) {
          await tester.drag(scrollable.first, const Offset(0, -350));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${screen.key} threw after scrolling '
                  '${(i + 1) * 350}px at ${scale}x');
        }
      });
    }
  }
}
