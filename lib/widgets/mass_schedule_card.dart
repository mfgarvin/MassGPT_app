import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show cardBorderFor;
import '../utils/layout_scale.dart';
import '../utils/schedule_parser.dart';
import 'day_chip_text.dart';
import 'language_badge.dart';

/// Mass schedule card that presents the *standing weekly schedule* split into
/// a Weekend section (Saturday Vigil + Sunday) and a Weekday section, rather
/// than a rolling "next few days" view. One-off / holiday Masses (entries with
/// a `mass_date`) that are still upcoming are surfaced in a separate
/// "Upcoming / Special" section; past dated Masses are dropped.
class MassScheduleCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final List<ScheduleEntry> items;
  final String emptyMessage;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final bool isDark;

  const MassScheduleCard({
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

  /// A weekend Mass = any Sunday Mass, or a Saturday Mass at/after noon (Vigil).
  /// Saturday morning daily Mass stays in the weekday group.
  static bool _isWeekend(ScheduleEntry e) =>
      e.dayOfWeek == 7 || (e.dayOfWeek == 6 && e.hour >= 12);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final regular = items.where((e) => !e.isDated).toList();
    final weekend = regular.where(_isWeekend).toList();
    final weekday = regular.where((e) => !_isWeekend(e)).toList();

    // Upcoming dated/holiday Masses (next ~21 days), soonest first.
    final special = items
        .where((e) => e.isDated && !e.isPast(now, kCountMassInProgress))
        .where((e) =>
            e.minutesUntilNext(now, kCountMassInProgress) <= 21 * 24 * 60)
        .toList()
      ..sort((a, b) => a
          .nextOccurrence(now, kCountMassInProgress)
          .compareTo(b.nextOccurrence(now, kCountMassInProgress)));

    final hasAny =
        weekend.isNotEmpty || weekday.isNotEmpty || special.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: cardBorderFor(isDark: isDark),
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
          if (!hasAny)
            _emptyRow()
          else ...[
            // Weekend reads chronologically as the weekend is kept — Saturday
            // vigil first, then Sunday morning — so it orders by day, not by
            // clock time (which would bury a 4:30 PM vigil under 9:00 AM).
            _weeklySection('Weekend', weekend,
                isFirst: true, dayFirstOrder: true),
            _weeklySection('Weekday', weekday, isFirst: weekend.isEmpty),
            _specialSection(special, now),
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

  Widget _sectionLabel(String label) {
    return Row(
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
          child: Container(height: 1, color: color.withValues(alpha: 0.18)),
        ),
      ],
    );
  }

  /// Weekend / weekday section. Rows with identical time + note are collapsed
  /// across days, e.g. five Mon–Fri 8:00 AM entries render as one "Mon–Fri" row.
  Widget _weeklySection(
    String label,
    List<ScheduleEntry> entries, {
    bool isFirst = false,
    bool dayFirstOrder = false,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final rows = _collapse(entries, dayFirstOrder: dayFirstOrder);
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(label),
          const SizedBox(height: 10),
          ...rows.map((r) => _row(r.daysLabel, r.entry.timeLabel,
              r.entry.displayNote, r.entry.languageBadge,
              r.entry.ordinalShortLabel)),
        ],
      ),
    );
  }

  Widget _specialSection(List<ScheduleEntry> entries, DateTime now) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Upcoming / Special'),
          const SizedBox(height: 10),
          ...entries.map((e) {
            final d = e.nextOccurrence(now, kCountMassInProgress);
            final dateLabel = '${e.dayLabel} ${d.month}/${d.day}';
            return _row(dateLabel, e.timeLabel, e.displayNote, e.languageBadge);
          }),
        ],
      ),
    );
  }

  /// A schedule row's lead at normal text size: the day chip, its margin and
  /// the time column. Both columns grow with the text scale (see
  /// [TextScaleLayout.scaled]) — at 2× the old fixed widths left the times
  /// wrapping mid-label and the note tail too narrow to hold anything.
  static const _dayColumnWidth = 64.0;
  static const _dayColumnMargin = 10.0;
  static const _timeColumnWidth = 128.0;

  /// Horizontal padding a note chip adds around its text.
  static const _noteChipPadding = 16.0;

  /// One schedule row. [ordinalLabel] is the monthly-recurrence marker
  /// ("1st", "Last", "Not 1st") shown under the day, or null for a weekly row.
  Widget _row(String dayLabel, String timeLabel, String? note,
      [String? languageBadge, String? ordinalLabel]) {
    // Prose note: its own full-width line under the row.
    final blockStyle = GoogleFonts.inter(
      fontSize: 13,
      color: subtextColor,
      fontStyle: FontStyle.italic,
    );
    // Tag note: a chip beside the time, like the language badge.
    final chipStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: subtextColor,
    );

    // Which of the two a note gets is decided by measuring it, not by counting
    // its characters. A character budget can't know how wide the row actually
    // is, and the tail left over after the day chip and the time column is
    // narrow (~84dp on a 360dp phone) — a 28-character note fits the old limit
    // and still renders as "Weekday Mass (Mari…". Measuring puts the boundary
    // exactly where the text stops fitting, at any width and any text scale.
    return LayoutBuilder(builder: (context, constraints) {
      // Cap each column so the two of them can never crowd the row: the day
      // chip may take a quarter of it, the time whatever is left over with a
      // little room kept back for a note.
      final dayWidth = context.scaled(_dayColumnWidth,
          max: constraints.maxWidth * 0.25);
      final timeWidth = context.scaled(_timeColumnWidth,
          max: constraints.maxWidth - dayWidth - _dayColumnMargin - 24);

      String? chipNote;
      String? blockNote;
      if (note != null) {
        final tail =
            constraints.maxWidth - dayWidth - _dayColumnMargin - timeWidth;
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
                Container(
                  width: dayWidth,
                  // Floor, not a fixed height, so a monthly row's two-line chip
                  // matches the one-line chips around it without clipping a day
                  // label that needs to wrap ("Mon, Tue, Thu" is three lines at
                  // 64px). 38 is the two-line content height (11px day + 9px
                  // ordinal) plus the 3px vertical padding; at 36 the ordinal
                  // clips. A longer label still grows the row, as it always did.
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The ordinal rides above the day, not beside it — "1st
                      // Fri" doesn't fit the 64px column — and above rather
                      // than below because it qualifies what follows: the chip
                      // reads "1st / Fri" the way you'd say it.
                      if (ordinalLabel != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            ordinalLabel,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      // A run ("Mon–Fri") is one idea and shouldn't break
                      // across lines, so it shrinks to fit instead. A list
                      // ("Mon, Tue, Thu") is several, and still wraps.
                      if (isDayRun(dayLabel))
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            dayLabel,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: dayChipTextSize(dayLabel),
                              fontWeight: FontWeight.w700,
                              color: color,
                              height: 1.1,
                            ),
                          ),
                        )
                      else
                        Text(
                          dayLabel,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: dayChipTextSize(dayLabel),
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: timeWidth,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          timeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (languageBadge != null) ...[
                        const SizedBox(width: 6),
                        LanguageBadge(label: languageBadge, color: color),
                      ],
                    ],
                  ),
                ),
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
                          // Measured to fit, so this never fires — it's a floor
                          // under a rounding disagreement, not the layout plan.
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Long note: full width under the row, aligned with the time column
            // so it reads as an annotation on that Mass rather than a new entry.
            if (blockNote != null)
              Padding(
                padding: EdgeInsets.only(
                  left: dayWidth + _dayColumnMargin, top: 2),
                child: Text(blockNote, style: blockStyle),
              ),
          ],
        ),
      );
    });
  }

  /// Collapse entries that share an identical time + note into a single row
  /// spanning multiple days. Preserves day order (Mon..Sun) within a row.
  /// Rows sort by start time, or by day-then-time when [dayFirstOrder] is set.
  List<_CollapsedRow> _collapse(
    List<ScheduleEntry> entries, {
    bool dayFirstOrder = false,
  }) {
    final groups = <String, List<ScheduleEntry>>{};
    for (final e in entries) {
      // The ordinal is part of the key: without it a "First Friday" Mass
      // merges with a weekly one at the same time and the row claims both
      // happen every week.
      final key = '${e.hour}:${e.minute}:${e.endHour}:${e.endMinute}:'
          '${e.language ?? ''}:${e.note ?? ''}:${e.recurrenceKey}';
      groups.putIfAbsent(key, () => []).add(e);
    }

    final rows = groups.values.map((g) {
      final days = g.map((e) => e.dayOfWeek).toSet().toList()..sort();
      return _CollapsedRow(
        entry: g.first,
        daysLabel: _daysLabel(days),
        firstDay: days.first,
      );
    }).toList()
      ..sort((a, b) {
        if (dayFirstOrder && a.firstDay != b.firstDay) {
          return a.firstDay.compareTo(b.firstDay);
        }
        final at = a.entry.hour * 60 + a.entry.minute;
        final bt = b.entry.hour * 60 + b.entry.minute;
        return at.compareTo(bt);
      });
    return rows;
  }

  static const _abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _daysLabel(List<int> days) {
    if (days.length == 1) return _abbr[days.first - 1];
    // Contiguous run of 3+ → "Mon–Fri"
    final contiguous =
        days.length >= 3 && days.last - days.first == days.length - 1;
    if (contiguous) return '${_abbr[days.first - 1]}–${_abbr[days.last - 1]}';
    return days.map((d) => _abbr[d - 1]).join(', ');
  }
}

class _CollapsedRow {
  final ScheduleEntry entry;
  final String daysLabel;

  /// Earliest ISO weekday in the row — the sort key for day-ordered sections.
  final int firstDay;

  _CollapsedRow({
    required this.entry,
    required this.daysLabel,
    required this.firstDay,
  });
}
