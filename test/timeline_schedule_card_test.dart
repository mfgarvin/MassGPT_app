import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/utils/schedule_parser.dart';
import 'package:parishfinder/widgets/timeline_schedule_card.dart';

import 'support/test_fonts.dart';

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

Widget _wrap(List<ScheduleEntry> items,
        {double width = 360, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: TimelineScheduleCard(
                icon: const Icon(Icons.favorite_outline),
                title: 'Confession Times',
                items: items,
                emptyMessage: 'No times listed',
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

/// True when the note renders beside the time (chip) rather than on its own
/// line below it (block).
///
/// Told apart horizontally, not vertically: a chip starts after the 128px time
/// column, a block note is indented only past the day chip. Comparing tops
/// instead would misread a wrapped two-line time, whose bottom sits below the
/// block note that follows it.
bool _isChip(WidgetTester tester, String note) =>
    tester.getTopLeft(find.text(note)).dx >
    tester.getTopLeft(find.textContaining('3:00').first).dx + 100;

void main() {
  // Measured assertions need the real font metrics — see loadAppFonts.
  setUpAll(loadAppFonts);

  group('note placement is measured, not counted', () {
    testWidgets('a short note rides beside the time as a chip', (tester) async {
      const note = 'Chapel';
      await tester.pumpWidget(_wrap([_entry(6, 15, 0, endHour: 16, note: note)]));
      expect(find.text(note), findsOneWidget);
      expect(_isChip(tester, note), isTrue);
    });

    testWidgets('a note too wide for the tail drops to its own line',
        (tester) async {
      // The case seen on Church of the Gesu's Adoration card: rendered as
      // "Mar ia…" under the old 28-character budget.
      const note = 'In the Church (or by appointment)';
      await tester.pumpWidget(_wrap([_entry(6, 15, 0, endHour: 16, note: note)]));
      expect(_isChip(tester, note), isFalse);
    });

    testWidgets('no note is ever truncated', (tester) async {
      for (final note in ['Chapel', 'In the Church (or by appointment)']) {
        await tester
            .pumpWidget(_wrap([_entry(6, 15, 0, endHour: 16, note: note)]));
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

    testWidgets('large text pushes a borderline note to its own line',
        (tester) async {
      // Fits the tail at 1x, not at 2x — the case a character budget can't see.
      const note = 'In the Church';
      await tester.pumpWidget(_wrap([_entry(6, 15, 0, endHour: 16, note: note)]));
      expect(_isChip(tester, note), isTrue);

      await tester.pumpWidget(
          _wrap([_entry(6, 15, 0, endHour: 16, note: note)], textScale: 2.0));
      expect(_isChip(tester, note), isFalse);
    });
  });
}
