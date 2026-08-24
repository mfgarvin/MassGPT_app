import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/main.dart' show themeNotifier, kCardColorDark;
import 'package:parishfinder/pages/find_parish_near_me_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The map tab is the one screen whose backdrop is an external image, so the
/// theme has to reach the tiles as well as the chrome over them.
Future<void> _pumpMap(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: FindParishNearMePage(inTab: true),
  ));
  await tester.pump(const Duration(seconds: 1));
}

ColorFilter _tileFilter(WidgetTester tester) {
  final filtered = tester.widget<ColorFiltered>(
    find.ancestor(
      of: find.byType(TileLayer),
      matching: find.byType(ColorFiltered),
    ).first,
  );
  return filtered.colorFilter;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cached_parishes_json': json.encode([
        {
          'name': 'St. Test Parish',
          'parish_id': '0001',
          'address': '1 Main St',
          'city': 'Lakewood',
          'zip_code': '44107',
          'latitude': 41.4805,
          'longitude': -81.7805,
          'schedules': {
            'mass': [],
            'confession': [],
            'adoration': {'is_perpetual': false, 'times': []},
          },
        },
      ]),
    });
  });

  tearDown(() => themeNotifier.setDarkMode(false));

  testWidgets('tiles use a different wash in each theme', (tester) async {
    themeNotifier.setDarkMode(false);
    await _pumpMap(tester);
    final light = _tileFilter(tester);

    themeNotifier.setDarkMode(true);
    await tester.pumpWidget(const MaterialApp(
      home: FindParishNearMePage(inTab: true),
    ));
    await tester.pump(const Duration(seconds: 1));
    final dark = _tileFilter(tester);

    expect(dark, isNot(equals(light)));
  });

  testWidgets('map chrome follows dark mode', (tester) async {
    themeNotifier.setDarkMode(true);
    await _pumpMap(tester);

    // The count pill / recenter button / carousel cards all share the card
    // colour; none of them may stay cream over a night map.
    final surfaces = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>();
    expect(surfaces, contains(kCardColorDark));
  });
}
