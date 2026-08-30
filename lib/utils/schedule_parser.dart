import 'package:flutter/foundation.dart';

/// Pass as `countInProgress` wherever the schedule is Mass times.
///
/// Confession and adoration are come-and-go, so a window already open is the
/// soonest thing available. A Mass is not: you're meant to be there for the
/// start, so an in-progress one is skipped in favour of the next Mass. Mass
/// entries carry no end time in today's `export.json` (so nothing can be "in
/// progress" anyway), but the intent is stated rather than assumed.
const bool kCountMassInProgress = false;

/// A single structured schedule entry (one Mass, confession slot, or adoration
/// period). Built directly from the pre-parsed `schedules` objects in
/// `export.json` — see EXPORT_SHAPE_CHANGES.md in the scraper repo
/// (`../bulletin-v2`), which is authoritative. No string parsing happens
/// anymore; every field arrives structured.
class ScheduleEntry {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday (ISO standard)
  final int hour; // 0-23 — start time
  final int minute; // 0-59
  final int? endHour; // 0-23 — optional end time for ranges (e.g. confession windows)
  final int? endMinute;

  /// The exporter's `end_next_day`: this window's end falls on the following
  /// day. Read from the data rather than inferred — the two cases that look
  /// identical from the endpoints alone, a fully covered day (00:00–00:00 +1d)
  /// and a start with no stated end (16:00–16:00), differ only in this flag.
  final bool endNextDay;

  /// Non-null for one-off / holiday occurrences (Christmas, weddings, Holy
  /// Days). When set, the entry occurs on this specific date rather than
  /// recurring weekly. [dayOfWeek] still reflects the weekday the date falls on.
  final DateTime? date;

  /// Language note for Mass entries (null = English).
  final String? language;

  /// Free-text annotation ("Vigil Mass", "Christmas Eve", etc.).
  final String? note;

  /// The exporter's `weeks_of_month`: the entry occurs *only* in these ordinal
  /// weeks of the month ("First Friday", "2nd and 4th Saturday"). `1`..`5`, or
  /// `-1` for the last such weekday. Null means every week, which is what an
  /// export predating this field — and the great majority of entries — says.
  ///
  /// `5` and `-1` are not the same: a 5th Friday exists only in some months,
  /// while `-1` is whichever Friday is last, the 5th in a 5-Friday month.
  final List<int>? weeksOfMonth;

  /// The exporter's `excluded_weeks`: the inverse rule — every week *except*
  /// these ("Weekday Mass, except on First Fridays"). Same value domain.
  /// Never non-null alongside [weeksOfMonth]; null means never skipped.
  final List<int>? excludedWeeks;

  ScheduleEntry({
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
    this.endHour,
    this.endMinute,
    this.endNextDay = false,
    this.date,
    this.language,
    this.note,
    this.weeksOfMonth,
    this.excludedWeeks,
  });

  /// True when the entry carries a real window, not just a start time.
  ///
  /// A range needs two endpoints that actually differ — unless [endNextDay],
  /// which is how a fully covered day arrives (00:00–00:00 +1d) and how any
  /// 24-hour span is encoded. Identical endpoints without the flag mean the
  /// bulletin gave a start and no end ("Confessions after the 8:15 Mass"):
  /// the absence of a window, not a zero-length one. The scraper is moving to
  /// a null `end` for that case, which lands on this same branch, so the two
  /// repos can ship in either order and a cached export written under either
  /// convention renders correctly.
  bool get hasRange =>
      endHour != null &&
      endMinute != null &&
      (endNextDay || endHour! != hour || endMinute! != minute);

  /// True when the window runs past midnight into the next day. This is the
  /// exporter's own flag, not an inference from the endpoints — inferring it
  /// from `end <= start` was what made an open-ended slot look like a 24-hour
  /// window.
  bool get crossesMidnight => hasRange && endNextDay;

  /// A span covering a full 24 hours: identical endpoints, ending the next
  /// day. Independent of where it starts, so 22:00 → 22:00 +1d qualifies as
  /// well as the 00:00–00:00 middle days of a multi-day adoration.
  bool get isAllDay =>
      hasRange && endNextDay && endHour! == hour && endMinute! == minute;

  /// True for dated (holiday / one-off) entries.
  bool get isDated => date != null;

  /// True when this entry recurs on an ordinal weekday of the month rather
  /// than every week. Route every recurrence decision through [occursOn]
  /// rather than testing this: it answers all three cases at once.
  bool get isMonthly => weeksOfMonth != null || excludedWeeks != null;

  /// Does this entry occur on the calendar day [day]? The single predicate
  /// for dated, weekly and monthly entries alike — anything that answers "is
  /// it on today" or "when is it next" from [dayOfWeek] alone is wrong for a
  /// monthly entry.
  bool occursOn(DateTime day) {
    if (date != null) {
      return day.year == date!.year &&
          day.month == date!.month &&
          day.day == date!.day;
    }
    if (day.weekday != dayOfWeek) return false;
    if (!isMonthly) return true;

    // Which ordinal weekday-of-month is this date, and is it the last one?
    final n = ((day.day - 1) ~/ 7) + 1;
    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
    final isLast = day.day + 7 > daysInMonth;
    bool listed(List<int> weeks) =>
        weeks.contains(n) || (weeks.contains(-1) && isLast);

    return weeksOfMonth != null ? listed(weeksOfMonth!) : !listed(excludedWeeks!);
  }

  /// Grouping discriminator for UI that merges entries sharing a time into one
  /// multi-day row. Empty for a weekly entry, so weekly rows group exactly as
  /// they did before this field existed; distinct for each ordinal rule, so a
  /// "First Friday" slot can never be collapsed into a weekly row and rendered
  /// as if it happened every week.
  String get recurrenceKey {
    if (weeksOfMonth != null) return 'w${weeksOfMonth!.join(',')}';
    if (excludedWeeks != null) return 'x${excludedWeeks!.join(',')}';
    return '';
  }

  static const Map<int, String> _ordinalNames = {
    1: '1st',
    2: '2nd',
    3: '3rd',
    4: '4th',
    5: '5th',
    -1: 'Last',
  };

  /// Compact ordinal for a chip — "1st", "2nd·4th", "Last", "Except 1st" — or
  /// null for a weekly entry. Deliberately short: the day columns it rides in
  /// are ~64px wide.
  ///
  /// "Except" rather than "Not": it echoes the note the field is derived from
  /// ("Weekday Mass (except on First Fridays)"), and under a "Fri" chip it
  /// reads as a sentence. It also keeps the excluded case visibly distinct
  /// from a plain "1st" sitting in the same list, which "No 1st" would not.
  String? get ordinalShortLabel {
    if (!isMonthly) return null;
    final weeks = weeksOfMonth ?? excludedWeeks!;
    final names = weeks.map((w) => _ordinalNames[w] ?? '$w').join('·');
    return weeksOfMonth != null ? names : 'Except $names';
  }

  /// Sentence form of the ordinal rule ("1st & 3rd Friday of the month"), or
  /// null for a weekly entry.
  ///
  /// The exporter guarantees [note] keeps stating the ordinal in prose, so
  /// this is normally redundant — it exists so a row still reads truthfully if
  /// an entry ever arrives carrying the rule and no note.
  String? get ordinalDescription {
    if (!isMonthly) return null;
    final weeks = weeksOfMonth ?? excludedWeeks!;
    final names = weeks.map((w) => _ordinalNames[w] ?? '$w').join(' & ');
    return weeksOfMonth != null
        ? '$names $dayName of the month'
        : 'Every $dayName except the $names';
  }

  static const Map<String, int> _dayMap = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  /// Build an entry from a structured schedule object:
  /// `{day, start, end?, mass_date?, language?, notes?}`.
  /// Returns null if the day or start time can't be read.
  static ScheduleEntry? fromJson(Map<String, dynamic> json) {
    final dayOfWeek = _dayMap[(json['day'] as String?)?.trim().toLowerCase()];
    final start = _parseHm(json['start']);
    if (dayOfWeek == null || start == null) {
      debugPrint('Skipping unparseable schedule entry: $json');
      return null;
    }
    final end = _parseHm(json['end']);
    // The exporter has emitted this on every range entry since v2.5.0 and
    // backfills it as `end < start` for older rows (utils/notion_to_app.py,
    // _structured_ranges), so the fallback matches that rule for a pre-v2.5.0
    // cached export. Strict `<`, so equal endpoints fall back to false — an
    // unstated end, which is the safe reading.
    // The two keys are mutually exclusive by contract; if both ever arrive,
    // `weeks_of_month` wins (EXPORT_SHAPE_CHANGES.md, "Semantics").
    final weeks = _parseWeeks(json['weeks_of_month']);
    final excluded = weeks == null ? _parseWeeks(json['excluded_weeks']) : null;
    final endNextDay = (json['end_next_day'] as bool?) ??
        (end != null &&
            (end.hour * 60 + end.minute) < (start.hour * 60 + start.minute));
    return ScheduleEntry(
      dayOfWeek: dayOfWeek,
      hour: start.hour,
      minute: start.minute,
      endHour: end?.hour,
      endMinute: end?.minute,
      endNextDay: endNextDay,
      date: _parseDate(json['mass_date']),
      language: (json['language'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['language'] as String).trim(),
      note: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notes'] as String).trim(),
      weeksOfMonth: weeks,
      excludedWeeks: excluded,
    );
  }

  /// Parse an ordinal-week list. The domain is `1`..`5` and `-1`; anything
  /// else is malformed and discarded. Absent, null, not-a-list and empty all
  /// collapse to null — the spec is explicit that a consumer must not
  /// distinguish them, and null is "every week", which is how every entry
  /// written before this field behaves.
  static List<int>? _parseWeeks(dynamic value) {
    if (value is! List) return null;
    final out = value
        .whereType<int>()
        .where((n) => (n >= 1 && n <= 5) || n == -1)
        .toSet()
        .toList()
      ..sort();
    return out.isEmpty ? null : out;
  }

  /// Parse a list of structured schedule objects into entries.
  static List<ScheduleEntry> listFromJson(dynamic jsonList) {
    if (jsonList is! List) return [];
    final out = <ScheduleEntry>[];
    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        final e = ScheduleEntry.fromJson(item);
        if (e != null) out.add(e);
      }
    }
    return out;
  }

  /// Parse "HH:MM" (24-hour, zero-padded) into hour/minute.
  static ({int hour, int minute})? _parseHm(dynamic value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return (hour: h, minute: m);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// End datetime of the occurrence beginning at [start], or null when the
  /// entry has no range. A window whose end is not after its start (e.g.
  /// 22:00–00:30) is treated as running into the next day.
  DateTime? endOf(DateTime start) {
    if (!hasRange) return null;
    final end =
        DateTime(start.year, start.month, start.day, endHour!, endMinute!);
    // Trust the flag. The `!isAfter` arm only catches data that contradicts
    // itself (an end at or before the start without the flag), where rolling
    // forward still beats returning a window of negative length.
    return endNextDay || !end.isAfter(start)
        ? end.add(const Duration(days: 1))
        : end;
  }

  /// Start of the window currently underway (adoration open now, confession
  /// line already going), or null when nothing is in progress. Only ranged
  /// entries can be in progress. Checks today and yesterday, since a window
  /// that crosses midnight began the day before.
  DateTime? currentWindowStart([DateTime? fromTime]) {
    if (!hasRange) return null;
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final offset in const [0, -1]) {
      final day = today.add(Duration(days: offset));
      if (!occursOn(day)) continue;
      final start = DateTime(day.year, day.month, day.day, hour, minute);
      if (!now.isBefore(start) && now.isBefore(endOf(start)!)) return start;
    }
    return null;
  }

  /// True when a ranged entry's window contains [fromTime].
  bool isInProgress([DateTime? fromTime]) => currentWindowStart(fromTime) != null;

  /// Calculate the next occurrence of this entry from now.
  ///
  /// A ranged entry that is currently underway returns the start of the window
  /// in progress (in the past), so "soonest" ranks it ahead of anything still
  /// upcoming — you can walk into adoration or a confession line at any point.
  /// Mass paths pass [countInProgress] `false`: you're expected to be there for
  /// the start, so a Mass already under way should point at the next one.
  /// Dated entries return their fixed date/time (which may be in the past —
  /// callers filter those out). Weekly entries roll forward to the next match.
  DateTime nextOccurrence([DateTime? fromTime, bool countInProgress = true]) {
    final now = fromTime ?? DateTime.now();

    final inProgress = countInProgress ? currentWindowStart(now) : null;
    if (inProgress != null) return inProgress;

    if (date != null) {
      return DateTime(date!.year, date!.month, date!.day, hour, minute);
    }

    if (isMonthly) {
      // A monthly rule can't be reached by adding 7, so scan candidate days.
      // The bound is generous — a `[5]`-only slot can be ~3 months out — and
      // falling through to the weekly arithmetic keeps an unforeseen rule
      // showing a Mass too often rather than hiding it entirely.
      final today = DateTime(now.year, now.month, now.day);
      for (var i = 0; i <= 400; i++) {
        final day = today.add(Duration(days: i));
        if (!occursOn(day)) continue;
        final start = DateTime(day.year, day.month, day.day, hour, minute);
        if (!start.isBefore(now)) return start;
      }
    }

    final currentDayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    int daysUntil = dayOfWeek - currentDayOfWeek;

    if (daysUntil == 0) {
      final eventTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (eventTime.isBefore(now)) {
        daysUntil = 7;
      }
    } else if (daysUntil < 0) {
      daysUntil += 7;
    }

    final nextDate = now.add(Duration(days: daysUntil));
    return DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);
  }

  /// Get minutes until the next occurrence (negative for past dated entries
  /// and for a ranged entry whose window is already underway).
  int minutesUntilNext([DateTime? fromTime, bool countInProgress = true]) {
    final now = fromTime ?? DateTime.now();
    return nextOccurrence(now, countInProgress).difference(now).inMinutes;
  }

  /// True if this is a dated entry whose occurrence is already in the past.
  /// A dated window still running counts as upcoming, not past — unless the
  /// caller isn't counting in-progress entries (see [nextOccurrence]).
  bool isPast([DateTime? fromTime, bool countInProgress = true]) {
    if (date == null) return false;
    final now = fromTime ?? DateTime.now();
    if (countInProgress && isInProgress(now)) return false;
    return nextOccurrence(now, countInProgress).isBefore(now);
  }

  /// Abbreviated weekday, e.g. "Sun".
  String get dayLabel {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[dayOfWeek - 1];
  }

  /// Full weekday, e.g. "Sunday".
  String get dayName {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return names[dayOfWeek - 1];
  }

  /// Human time, e.g. "10:30 AM", or "3:00 – 3:30 PM" for ranges.
  /// When both endpoints share a meridiem, the first one is dropped.
  String get timeLabel {
    final start = _format12(hour, minute);
    if (!hasRange) return start;
    // A round-the-clock day would otherwise render as "12:00 – 12:00 AM",
    // which reads as zero minutes rather than twenty-four hours.
    if (isAllDay) return 'All day';
    final end = _format12(endHour!, endMinute!);
    // Only collapse the meridiem within a single day. Across midnight the two
    // endpoints can share one ("9:15 AM – 12:00 AM") while being ~15 hours
    // apart, and dropping it would read as a short morning slot.
    final sameMeridiem = (hour >= 12) == (endHour! >= 12) && !crossesMidnight;
    if (sameMeridiem) {
      final startNoMer = start.replaceFirst(RegExp(r'\s?(AM|PM)$'), '');
      return '$startNoMer – $end';
    }
    return '$start – $end';
  }

  /// Compact label for chips and previews, e.g. "Sun · 9:00 AM".
  String get display => '$dayLabel · $timeLabel';

  /// The note to show on a row: the exporter's prose, or the ordinal rule
  /// spelled out when a monthly entry arrives without one. Never both — the
  /// note already states the ordinal whenever it exists, and repeating it
  /// would read as two different rules.
  String? get displayNote => note ?? ordinalDescription;

  /// Combined language + note annotation for muted display, or null.
  /// Mass views prefer [languageBadge] + [displayNote] separately; this stays
  /// for confession/adoration cards (which never carry a language).
  String? get noteLabel {
    final parts = <String>[];
    if (language != null) parts.add(language!);
    final n = displayNote;
    if (n != null) parts.add(n);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Keyword → short badge map, checked in order so that compound strings like
  /// "English & Italian" or "Bilingual (English-Polish)" resolve to the
  /// non-English language they mention.
  static const List<({String keyword, String badge})> _languageBadges = [
    (keyword: 'spanish', badge: 'ES'),
    (keyword: 'polish', badge: 'PL'),
    (keyword: 'croatian', badge: 'HR'),
    (keyword: 'slovenian', badge: 'SL'),
    (keyword: 'italian', badge: 'IT'),
    (keyword: 'german', badge: 'DE'),
    (keyword: 'korean', badge: 'KO'),
    (keyword: 'swahili', badge: 'SW'),
    (keyword: 'latin', badge: 'LA'),
  ];

  /// True when this entry is plain English (or unspecified, which means English).
  bool get isEnglish {
    final lang = language?.toLowerCase().trim();
    return lang == null || lang.isEmpty || lang == 'english';
  }

  /// Short uppercase badge for a non-English Mass (e.g. "ES", "PL"), or null
  /// when the Mass is in English. Falls back to "BIL" for generic bilingual
  /// notes and a 2-letter slice for anything unrecognized.
  String? get languageBadge {
    if (isEnglish) return null;
    final lang = language!.toLowerCase();
    for (final entry in _languageBadges) {
      if (lang.contains(entry.keyword)) return entry.badge;
    }
    if (lang.contains('bilingual')) return 'BIL';
    return language!.replaceAll(RegExp(r'[^A-Za-z]'), '').substring(0, 2).toUpperCase();
  }

  /// True when this Mass is (at least partly) in Spanish.
  bool get isSpanish =>
      !isEnglish && language!.toLowerCase().contains('spanish');

  /// True for a non-English Mass that isn't Spanish (Polish, Croatian, Latin…).
  bool get isOtherLanguage => !isEnglish && !isSpanish;

  static String _format12(int hour, int minute) {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mer = hour >= 12 ? 'PM' : 'AM';
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $mer';
  }
}

/// Helpers over lists of [ScheduleEntry]. (Formerly a string parser — now that
/// `export.json` ships structured schedules, this only does occurrence math.)
class ScheduleParser {
  /// Entries that are upcoming: weekly entries always qualify; dated entries
  /// only while still in the future.
  static List<ScheduleEntry> _upcomingOnly(
    List<ScheduleEntry> entries,
    DateTime now,
    bool countInProgress,
  ) {
    return entries.where((e) => !e.isPast(now, countInProgress)).toList();
  }

  /// Find the soonest upcoming entry, or null. Pass [countInProgress] `false`
  /// for Mass schedules — see [ScheduleEntry.nextOccurrence].
  static ScheduleEntry? findNextOccurrence(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
    bool countInProgress = true,
  ]) {
    final now = fromTime ?? DateTime.now();
    final upcoming = _upcomingOnly(entries, now, countInProgress);
    if (upcoming.isEmpty) return null;
    upcoming.sort(
      (a, b) => a
          .minutesUntilNext(now, countInProgress)
          .compareTo(b.minutesUntilNext(now, countInProgress)),
    );
    return upcoming.first;
  }

  /// Minutes until the soonest upcoming entry, or null.
  static int? minutesUntilNext(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
    bool countInProgress = true,
  ]) {
    final now = fromTime ?? DateTime.now();
    return findNextOccurrence(entries, now, countInProgress)
        ?.minutesUntilNext(now, countInProgress);
  }

  /// Group entries by relative day buckets, sorted by occurrence.
  /// Buckets: 'today', 'tomorrow', 'thisWeek', 'beyond' (8+ days out).
  static Map<String, List<UpcomingEntry>> groupByBucket(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
    bool countInProgress = true,
  ]) {
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = _upcomingOnly(entries, now, countInProgress).map((e) {
      final next = e.nextOccurrence(now, countInProgress);
      final eventDay = DateTime(next.year, next.month, next.day);
      return UpcomingEntry(
        entry: e,
        occurrence: next,
        daysFromToday: eventDay.difference(today).inDays,
      );
    }).toList()
      ..sort((a, b) => a.occurrence.compareTo(b.occurrence));

    final buckets = <String, List<UpcomingEntry>>{
      'today': [],
      'tomorrow': [],
      'thisWeek': [],
      'beyond': [],
    };

    for (final u in upcoming) {
      if (u.daysFromToday == 0) {
        buckets['today']!.add(u);
      } else if (u.daysFromToday == 1) {
        buckets['tomorrow']!.add(u);
      } else if (u.daysFromToday <= 7) {
        buckets['thisWeek']!.add(u);
      } else {
        buckets['beyond']!.add(u);
      }
    }
    return buckets;
  }

  /// Group entries into day-runs for at-a-glance display: bucket by weekday,
  /// merge consecutive days whose schedules are identical ("Mon–Fri"), order
  /// Sunday first. Dated (holiday) entries trail as their own date groups.
  static List<ScheduleDayGroup> groupByDay(List<ScheduleEntry> entries) {
    final weekly = <int, List<ScheduleEntry>>{};
    final dated = <DateTime, List<ScheduleEntry>>{};
    for (final e in entries) {
      if (e.isDated) {
        final d = e.date!;
        (dated[DateTime(d.year, d.month, d.day)] ??= []).add(e);
      } else {
        (weekly[e.dayOfWeek] ??= []).add(e);
      }
    }

    int startMinutes(ScheduleEntry e) => e.hour * 60 + e.minute;
    for (final list in [...weekly.values, ...dated.values]) {
      list.sort((a, b) => startMinutes(a).compareTo(startMinutes(b)));
    }

    // Two days merge only when their schedules are indistinguishable on a
    // card: same times, ranges, and language marks.
    // Read the end through hasRange so an open-ended slot signs the same
    // whether the exporter wrote a null end or an end equal to the start.
    String signature(List<ScheduleEntry> list) => list
        .map((e) =>
            '${e.hour}:${e.minute}-${e.hasRange ? '${e.endHour}:${e.endMinute}' : ''}-${e.languageBadge}-${e.recurrenceKey}')
        .join('|');

    final runs = <({int firstDay, int lastDay, List<ScheduleEntry> entries})>[];
    for (var day = 1; day <= 7; day++) {
      final todays = weekly[day];
      if (todays == null) continue;
      final prev = runs.isEmpty ? null : runs.last;
      if (prev != null &&
          prev.lastDay == day - 1 &&
          signature(prev.entries) == signature(todays)) {
        runs[runs.length - 1] =
            (firstDay: prev.firstDay, lastDay: day, entries: prev.entries);
      } else {
        runs.add((firstDay: day, lastDay: day, entries: todays));
      }
    }
    // Sunday-first: the run containing Sunday leads, then Mon..Sat order.
    runs.sort((a, b) => (a.lastDay == 7 ? 0 : a.firstDay)
        .compareTo(b.lastDay == 7 ? 0 : b.firstDay));

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return [
      for (final r in runs)
        ScheduleDayGroup(
          r.firstDay == r.lastDay
              ? days[r.firstDay - 1]
              : '${days[r.firstDay - 1]}–${days[r.lastDay - 1]}',
          r.entries,
        ),
      for (final d in dated.keys.toList()..sort())
        ScheduleDayGroup('${months[d.month - 1]} ${d.day}', dated[d]!),
    ];
  }
}

/// A run of days sharing an identical schedule, for compact card display
/// ("Mon–Fri" → 8:00 AM). Entries are sorted by start time.
class ScheduleDayGroup {
  final String label;
  final List<ScheduleEntry> entries;

  ScheduleDayGroup(this.label, this.entries);
}

/// A schedule entry paired with its next occurrence datetime.
class UpcomingEntry {
  final ScheduleEntry entry;
  final DateTime occurrence;
  final int daysFromToday;

  UpcomingEntry({
    required this.entry,
    required this.occurrence,
    required this.daysFromToday,
  });

  int get hour => entry.hour;
  int get minute => entry.minute;

  String get timeLabel => entry.timeLabel;
  String get dayLabel => entry.dayLabel;
  String? get noteLabel => entry.noteLabel;
}
