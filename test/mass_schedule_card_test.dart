import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/utils/schedule_parser.dart';
import 'package:parishfinder/widgets/mass_schedule_card.dart';

import 'support/test_fonts.dart';

ScheduleEntry _entry(int day, int hour, int minute,
        {String? note, List<int>? weeksOfMonth}) =>
    ScheduleEntry(
        dayOfWeek: day,
        hour: hour,
        minute: minute,
        note: note,
        weeksOfMonth: weeksOfMonth);

Widget _wrap(List<ScheduleEntry> items,
        {double width = 360, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: MassScheduleCard(
                icon: const Icon(Icons.church),
                title: 'Mass Times',
                items: items,
                emptyMessage: 'No Mass times listed',
                color: Colors.red,
                cardColor: Colors.white,
                textColor: Colors.black,
                subtextColor: Colors.black54,
                isDark: false,
              ),
            ),
          ),
        ),
      ),
    );

/// True when [note] renders beside the time (chip) rather than on its own line
/// below it (block). The chip shares the row's baseline band with the time;
/// the block note sits strictly under it.
bool _isChip(WidgetTester tester, String note, String time) {
  final noteTop = tester.getTopLeft(find.text(note)).dy;
  final timeBottom = tester.getBottomLeft(find.text(time)).dy;
  return noteTop < timeBottom;
}

void main() {
  // Measured assertions need the real font metrics — see loadAppFonts.
  setUpAll(loadAppFonts);

  testWidgets('weekend section lists the Saturday vigil before Sunday Masses',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _entry(7, 9, 0), // Sun 9:00 AM
      _entry(7, 11, 0), // Sun 11:00 AM
      _entry(6, 16, 30), // Sat 4:30 PM vigil
    ]));

    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(rows.indexOf('Sat'), lessThan(rows.indexOf('Sun')));
    expect(rows.indexOf('4:30 PM'), lessThan(rows.indexOf('9:00 AM')));
  });

  testWidgets('weekday section stays ordered by clock time', (tester) async {
    await tester.pumpWidget(_wrap([
      _entry(2, 7, 0), // Tue 7:00 AM
      _entry(1, 8, 30), // Mon 8:30 AM
    ]));

    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(rows.indexOf('7:00 AM'), lessThan(rows.indexOf('8:30 AM')));
  });

  testWidgets('a long note renders in full instead of being ellipsized',
      (tester) async {
    const longNote =
        'Daily Mass; in Parish Center Chapel. When school is in session, '
        'Tuesday Mass is in the Main Church';
    await tester.pumpWidget(_wrap([_entry(2, 8, 0, note: longNote)]));

    final noteText = tester.widget<Text>(find.text(longNote));
    expect(noteText.overflow, isNot(TextOverflow.ellipsis));
    expect(noteText.maxLines, isNull);
  });

  testWidgets('a monthly Mass is not collapsed into a weekly row',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _entry(2, 8, 15), // Tue 8:15 AM, every week
      _entry(5, 8, 15, weeksOfMonth: [1]), // 1st Fri only, same time
    ]));

    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    // Collapsed onto one row these would read "Tue, Fri · 8:15 AM" — claiming
    // a Mass every Friday that only happens on the first.
    expect(rows, isNot(contains('Tue, Fri')));
    expect(rows, contains('Tue'));
    expect(rows, contains('Fri'));
    expect(rows, contains('1st')); // the ordinal marker under the day
  });

  // Regression: the day chip carries a minimum height so a monthly row's
  // two-line marker lines up with its neighbours — but it must stay a floor,
  // not a fixed height. Non-contiguous weekday sets collapse into labels that
  // wrap to several lines in the 64px column ("Mon, Tue, Wed, Fri, Sat" is
  // St. Sebastian's real weekday schedule), and a fixed height clipped them.
  // A widget test fails on overflow, so rendering these is the assertion.
  testWidgets('a wrapped multi-day label is not clipped', (tester) async {
    for (final days in const [
      [1, 2, 4], // Mon, Tue, Thu — St. Mark
      [1, 2, 3, 5], // Mon, Tue, Wed, Fri — nine parishes
      [1, 2, 3, 5, 6], // Mon, Tue, Wed, Fri, Sat — St. Sebastian
    ]) {
      await tester.pumpWidget(_wrap(
          [for (final d in days) _entry(d, 8, 30)]));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a monthly marker still lines the chips up', (tester) async {
    await tester.pumpWidget(_wrap([
      _entry(2, 8, 15),
      _entry(5, 8, 15, weeksOfMonth: [1]),
    ]));

    // Both chips share the floor height, so the day column doesn't step.
    final heights = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.constraints?.minHeight)
        .where((h) => h == 38)
        .toList();
    expect(heights.length, 2);
  });

  group('note placement is measured, not counted', () {
    // The tail left for a note after the 64px day chip, its 10px margin and
    // the 128px time column.
    const shortNote = 'Vigil Mass';
    const longNote = 'Weekday Mass (Marian Chapel)';

    testWidgets('a short note rides beside the time as a chip', (tester) async {
      await tester.pumpWidget(_wrap([_entry(6, 16, 30, note: shortNote)]));
      expect(_isChip(tester, shortNote, '4:30 PM'), isTrue);
    });

    testWidgets('a note too wide for the tail drops to its own line',
        (tester) async {
      await tester.pumpWidget(_wrap([_entry(2, 7, 30, note: longNote)]));
      expect(_isChip(tester, longNote, '7:30 AM'), isFalse,
          reason: '28 chars fit the old character budget but not the row');
    });

    testWidgets('no note is ever truncated', (tester) async {
      await tester.pumpWidget(_wrap([
        _entry(6, 16, 30, note: shortNote),
        _entry(2, 7, 30, note: longNote),
      ]));
      for (final note in [shortNote, longNote]) {
        final widget = tester.widget<Text>(find.text(note));
        final painter = TextPainter(
          text: TextSpan(text: note, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: widget.maxLines,
          textScaler: TextScaler.noScaling,
        )..layout(maxWidth: tester.getSize(find.text(note)).width);
        expect(painter.didExceedMaxLines, isFalse,
            reason: '"$note" is clipped in the space it was given');
      }
    });

    testWidgets('the same note becomes a block when the row is narrower',
        (tester) async {
      const note = 'Weekday Mass';
      await tester.pumpWidget(_wrap([_entry(2, 7, 30, note: note)]));
      expect(_isChip(tester, note, '7:30 AM'), isTrue);

      await tester.pumpWidget(_wrap([_entry(2, 7, 30, note: note)], width: 260));
      expect(_isChip(tester, note, '7:30 AM'), isFalse,
          reason: 'the boundary follows the available width');
    });

    testWidgets('large text pushes a borderline note to its own line',
        (tester) async {
      const note = 'Weekday Mass';
      await tester.pumpWidget(
          _wrap([_entry(2, 7, 30, note: note)], textScale: 2.0));
      expect(_isChip(tester, note, '7:30 AM'), isFalse,
          reason: 'the measurement must account for the text scaler');
    });
  });
}
