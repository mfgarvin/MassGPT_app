import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/pages/filtered_parish_list_page.dart';
import 'package:parishfinder/pages/find_parish_near_me_page.dart';
import 'package:parishfinder/pages/parish_detail_page.dart';
import 'package:parishfinder/utils/schedule_parser.dart';
import 'package:parishfinder/widgets/mass_schedule_card.dart';
import 'package:parishfinder/widgets/liturgical_day_tile.dart';
import 'package:parishfinder/widgets/next_mass_banner.dart';
import 'package:parishfinder/widgets/timeline_schedule_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

/// Android's accessibility font sizes top out around 2.0; 1.5 is the middle
/// setting and the point where side-by-side content starts stacking.
const _scales = [1.0, 1.3, 1.5, 2.0];

/// A phone, not the 800x600 default test surface — these are width bugs, and
/// the default surface is wide enough to hide them.
const _phone = Size(360, 800);

Widget _frame(Widget child, double scale) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    );

ScheduleEntry _entry(int day, int hour, int minute,
        {int? endHour, String? note}) =>
    ScheduleEntry(
      dayOfWeek: day,
      hour: hour,
      minute: minute,
      endHour: endHour,
      endMinute: endHour == null ? null : 0,
      note: note,
    );

/// The worst case in the real data: a long note on every row.
final _schedule = [
  _entry(6, 16, 30, note: 'Vigil Mass'),
  _entry(7, 8, 0),
  _entry(1, 7, 30, note: 'Weekday Mass (Marian Chapel)'),
  _entry(3, 8, 30, note: 'Weekday Mass (Marian Chapel)'),
];

void setSurface(WidgetTester tester) {
  tester.view.physicalSize = _phone * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadAppFonts);

  // A RenderFlex overflow is an exception in a test, so pumping at each scale
  // is itself the assertion: these all threw "overflowed by N pixels" before
  // the columns, badges and card heights learned to follow the text scale.
  group('nothing overflows at accessibility text sizes', () {
    for (final scale in _scales) {
      testWidgets('mass schedule card at ${scale}x', (tester) async {
        setSurface(tester);
        await tester.pumpWidget(_frame(
            MassScheduleCard(
              icon: const Icon(Icons.access_time),
              // The longest title the card is given anywhere.
              title: 'Confession Times',
              items: _schedule,
              emptyMessage: '',
              color: Colors.red,
              cardColor: Colors.white,
              textColor: Colors.black,
              subtextColor: Colors.black54,
              isDark: false,
            ),
            scale));
        expect(tester.takeException(), isNull);
      });

      testWidgets('timeline card at ${scale}x', (tester) async {
        setSurface(tester);
        await tester.pumpWidget(_frame(
            TimelineScheduleCard(
              icon: const Icon(Icons.favorite_outline),
              title: 'Confession Times',
              items: [_entry(6, 15, 0, endHour: 16, note: 'In the Church')],
              emptyMessage: '',
              color: Colors.red,
              cardColor: Colors.white,
              textColor: Colors.black,
              subtextColor: Colors.black54,
              isDark: false,
            ),
            scale));
        expect(tester.takeException(), isNull);
      });

      testWidgets('next-Mass banner at ${scale}x', (tester) async {
        setSurface(tester);
        await tester.pumpWidget(_frame(
            NextMassBanner(
              schedule: _schedule,
              label: 'NEXT MASS',
              accentColor: Colors.red,
              cardColor: Colors.white,
              textColor: Colors.black,
              subtextColor: Colors.black54,
            ),
            scale));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('a parish name keeps room to read at large text', () {
    late final String json;
    setUpAll(() => json = File('export.demo.json').readAsStringSync());

    for (final scale in _scales) {
      testWidgets('list card at ${scale}x', (tester) async {
        SharedPreferences.setMockInitialValues({'cached_parishes_json': json});
        setSurface(tester);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const FilteredParishListPage(
              filter: ParishFilter.massTimes,
              title: 'Mass Times',
              accentColor: Colors.red,
              userLocation: LatLng(41.48, -81.78),
            ),
          ),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);

        // The bug this guards: the trailing badge took what it wanted and the
        // name, in an Expanded, got the remainder — one character per line at
        // 2x. Any name on screen must have room for several characters.
        final names = find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? '').startsWith('Saint ') &&
            (w.style?.fontWeight == FontWeight.bold));
        expect(names, findsWidgets);
        for (final name in names.evaluate()) {
          final width = tester.getSize(find.byWidget(name.widget)).width;
          expect(width, greaterThan(120),
              reason: '"${(name.widget as Text).data}" is squeezed to '
                  '${width.toStringAsFixed(0)}px at ${scale}x');
        }

        // Sort selector: three segments across a phone can't hold their own
        // labels at large text ("Soonest" wrapped to "Soone / st"), so past
        // 1.5x they stack. Either way nothing may overflow.
        await tester.tap(find.text('A–Z'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Filter sheet, including the "Clear" button that only appears once a
        // filter is active.
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Today'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Clear'), findsOneWidget);
      });
    }
  });

  group('the parish detail page fits the screen', () {
    late final List<Parish> parishes;
    setUpAll(() {
      final raw = jsonDecode(File('export.demo.json').readAsStringSync()) as List;
      parishes = [for (final j in raw) Parish.fromJson(j as Map<String, dynamic>)];
    });

    for (final scale in _scales) {
      testWidgets('detail page at ${scale}x', (tester) async {
        setSurface(tester);
        // A record with the lot: events summary, bulletin, phone, website —
        // so the section headers, the address card's "Get Directions" action
        // and the feedback prompt are all on screen.
        final parish = parishes.firstWhere((p) =>
            p.eventsSummary != null &&
            p.bulletinUrl != null &&
            p.website.isNotEmpty &&
            p.massTimes.isNotEmpty);

        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: ParishDetailPage(parish: parish),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Scroll the whole page: an overflow further down only throws once
        // that part is laid out.
        for (var i = 0; i < 12; i++) {
          await tester.drag(
              find.byType(CustomScrollView), const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'overflow after scrolling ${(i + 1) * 400}px at ${scale}x');
        }
      });
    }
  });

  group('the USCCB readings button keeps its gutter', () {
    for (final scale in _scales) {
      testWidgets('at ${scale}x', (tester) async {
        SharedPreferences.setMockInitialValues({});
        setSurface(tester);
        await tester.pumpWidget(_frame(
            const LiturgicalDayTile(
              cardColor: Colors.white,
              textColor: Colors.black87,
              subtextColor: Colors.black54,
            ),
            scale));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);

        // The button is full-width with a wrapping label, so once the label
        // wraps the row fills the width and the icon lands wherever the
        // padding leaves it — which was flat against the border, because the
        // horizontal padding was zero.
        final button = tester.getRect(find.byType(OutlinedButton));
        final icon = tester.getRect(find.byIcon(Icons.menu_book_outlined));
        expect(icon.left - button.left, greaterThanOrEqualTo(12.0),
            reason: 'the book icon is against the button border at ${scale}x');
        expect(button.right - icon.right, greaterThan(0));

        // And it grows with the text rather than staying an 18px speck.
        expect(icon.width, greaterThanOrEqualTo(18.0));
        if (scale >= 1.5) expect(icon.width, greaterThan(18.0));
      });
    }
  });

  group('the map keeps its proportions at large text', () {
    Future<void> pumpMap(WidgetTester tester, double scale) async {
      SharedPreferences.setMockInitialValues({
        'cached_parishes_json': File('export.demo.json').readAsStringSync(),
      });
      setSurface(tester);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const FindParishNearMePage(),
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    const attribution = '© OpenStreetMap contributors';

    testWidgets('the carousel never takes half the screen', (tester) async {
      await pumpMap(tester, 2.0);
      expect(tester.takeException(), isNull);
      expect(find.byType(PageView), findsOneWidget);

      // The strip is positioned, so measure the card inside it.
      final card = tester.getRect(find.text('Lakewood').first);
      expect(card.height, lessThan(_phone.height / 3),
          reason: 'the carousel is eating the map');
    });

    testWidgets('the OSM credit stays a credit', (tester) async {
      await pumpMap(tester, 1.0);
      final atNormal = tester.getSize(find.text(attribution));

      await pumpMap(tester, 2.0);
      final atLarge = tester.getSize(find.text(attribution));

      // Clamped: legible, but it does not double in size and start
      // competing with the map for the corner.
      expect(atLarge.width / atNormal.width, lessThan(1.3),
          reason: 'the attribution is scaling like body text');
      expect(atLarge.width, greaterThan(atNormal.width),
          reason: 'it should still grow a little');
    });
  });
}
