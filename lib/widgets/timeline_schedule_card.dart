import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/layout_scale.dart';
import '../utils/schedule_parser.dart';
import 'day_chip_text.dart';

/// Schedule card that groups entries into Today / Tomorrow / This week / Beyond
/// buckets with relative time hints. Designed for Mass times where parishes
/// commonly have 5-15 entries spread across the week.
class TimelineScheduleCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final List<ScheduleEntry> items;
  final String emptyMessage;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final bool isDark;

  const TimelineScheduleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = ScheduleParser.groupByBucket(items);
    final hasUpcoming = buckets.values.any((l) => l.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 16),
          if (items.isEmpty || !hasUpcoming)
            _emptyRow()
          else ...[
            _section('Today', buckets['today']!, isFirst: true),
            _section('Tomorrow', buckets['tomorrow']!),
            _section('This week', buckets['thisWeek']!),
            _section('Beyond', buckets['beyond']!),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon,
        ),
        const SizedBox(width: 16),
        // Wraps rather than overflows: at large text scales a two-word title
        // ("Confession Times") is wider than the row, and an unconstrained
        // Text there clips with a debug stripe instead of taking a second line.
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: subtextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              emptyMessage,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: subtextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, List<UpcomingEntry> entries,
      {bool isFirst = false}) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: color.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...entries.map((e) => _entryRow(e, label)),
        ],
      ),
    );
  }

  /// A row's lead at normal text size: the day chip plus its margin (only on
  /// this-week / beyond rows) and the time column. Both grow with the text
  /// scale — see [TextScaleLayout.scaled] and the same rule in
  /// MassScheduleCard.
  /// Wider than it was (38): the day label is set to match the Mass card's
  /// chip, and 38px could not hold it.
  static const _dayColumnWidth = 46.0;
  static const _dayColumnMargin = 10.0;
  static const _timeColumnWidth = 128.0;

  /// Horizontal padding a note chip adds around its text.
  static const _noteChipPadding = 16.0;

  Widget _entryRow(UpcomingEntry e, String bucketLabel) {
    final showDay = bucketLabel == 'This week' || bucketLabel == 'Beyond';
    final note = e.noteLabel;
    // Prose note: its own full-width line under the row.
    final blockStyle = GoogleFonts.inter(
      fontSize: 13,
      color: subtextColor,
      fontStyle: FontStyle.italic,
    );
    // Tag note: a chip beside the time.
    final chipStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: subtextColor,
    );

    // Measured, not counted — see the same rule in MassScheduleCard. A
    // character budget can't see how wide the row is, so notes that "fit" it
    // still rendered as "Mar ia…" in the narrow tail.
    return LayoutBuilder(builder: (context, constraints) {
      final dayWidth = showDay
          ? context.scaled(_dayColumnWidth, max: constraints.maxWidth * 0.25)
          : 0.0;
      final dayLead = showDay ? dayWidth + _dayColumnMargin : 0.0;
      final timeWidth = context.scaled(_timeColumnWidth,
          max: constraints.maxWidth - dayLead - 24);

      String? chipNote;
      String? blockNote;
      if (note != null) {
        final tail = constraints.maxWidth - dayLead - timeWidth;
        final painter = TextPainter(
          text: TextSpan(text: note, style: chipStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (tail > 0 && painter.width + _noteChipPadding <= tail) {
          chipNote = note;
        } else {
          blockNote = note;
        }
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Day chip (only shown for this-week / beyond)
                if (showDay)
                  Container(
                    width: dayWidth,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    // Sized to fill the chip rather than sit in it as a
                    // footnote — these are always a single day, so there is
                    // room. FittedBox keeps a wide text scale honest.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        e.dayLabel,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: dayChipTextSize(e.dayLabel),
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                // Time (or time range)
                SizedBox(
                  width: timeWidth,
                  child: Text(
                    e.timeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                // Short note as a chip beside the time (e.g. "Vigil Mass").
                if (chipNote != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: _noteChipPadding / 2, vertical: 3),
                        decoration: BoxDecoration(
                          color: subtextColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          chipNote,
                          style: chipStyle,
                          maxLines: 1,
                          // Measured to fit, so this never fires.
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Long note: full width under the row, indented past the day chip.
            if (blockNote != null)
              Padding(
                padding: EdgeInsets.only(left: dayLead, top: 2),
                child: Text(blockNote, style: blockStyle),
              ),
          ],
        ),
      );
    });
  }
}
