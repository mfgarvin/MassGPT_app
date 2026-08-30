import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/utils/schedule_parser.dart';

/// Build a structured mass/confession entry like the ones in export.json.
Map<String, dynamic> massJson(
  String day,
  String start, {
  String? massDate,
  String? language,
  String? notes,
}) =>
    {
      'day': day,
      'start': start,
      'mass_date': massDate,
      'language': language,
      'notes': notes,
    };

Map<String, dynamic> windowJson(String day, String start, String end,
        {String? notes, bool? endNextDay}) =>
    {
      'day': day,
      'start': start,
      'end': end,
      'notes': notes,
      if (endNextDay != null) 'end_next_day': endNextDay,
    };

ScheduleEntry windowEntry(String day, String start, String end) =>
    ScheduleEntry.fromJson(windowJson(day, start, end))!;

void main() {
  group('ScheduleEntry.fromJson', () {
    test('parses a weekly Mass entry', () {
      final e = ScheduleEntry.fromJson(massJson('Sunday', '09:00'))!;
      expect(e.dayOfWeek, 7); // Sunday = 7 ISO
      expect(e.hour, 9);
      expect(e.minute, 0);
      expect(e.isDated, false);
      expect(e.hasRange, false);
    });

    test('parses an afternoon 24-hour time', () {
      final e = ScheduleEntry.fromJson(massJson('Saturday', '16:30'))!;
      expect(e.dayOfWeek, 6);
      expect(e.hour, 16);
      expect(e.minute, 30);
    });

    test('parses a confession window with start and end', () {
      final e = ScheduleEntry.fromJson(windowJson('Saturday', '09:30', '10:00'))!;
      expect(e.hasRange, true);
      expect(e.hour, 9);
      expect(e.endHour, 10);
      expect(e.endMinute, 0);
    });

    test('captures language and notes annotations', () {
      final e = ScheduleEntry.fromJson(
          massJson('Sunday', '12:30', language: 'Spanish', notes: 'Vigil'))!;
      expect(e.language, 'Spanish');
      expect(e.note, 'Vigil');
      expect(e.noteLabel, 'Spanish · Vigil');
    });

    test('language badge + classification', () {
      ScheduleEntry lang(String? l) =>
          ScheduleEntry.fromJson(massJson('Sunday', '09:00', language: l))!;

      // English (explicit, null, or empty) carries no badge.
      expect(lang(null).languageBadge, isNull);
      expect(lang('English').languageBadge, isNull);
      expect(lang(null).isEnglish, true);

      // Known languages map to short codes.
      expect(lang('Spanish').languageBadge, 'ES');
      expect(lang('Polish').languageBadge, 'PL');
      expect(lang('Latin N.O.').languageBadge, 'LA');

      // Compound strings resolve to the non-English language they mention.
      expect(lang('English & Italian').languageBadge, 'IT');
      expect(lang('Bilingual (English-Polish)').languageBadge, 'PL');
      expect(lang('Bilingual').languageBadge, 'BIL');

      // Spanish vs. Other classification (used by the search filter).
      expect(lang('Spanish').isSpanish, true);
      expect(lang('Spanish').isOtherLanguage, false);
      expect(lang('Polish').isOtherLanguage, true);
      expect(lang('Polish').isSpanish, false);
      expect(lang('English').isOtherLanguage, false);
    });

    test('parses a dated holiday Mass', () {
      final e = ScheduleEntry.fromJson(
          massJson('Thursday', '00:00', massDate: '2025-12-25', notes: 'Midnight Mass'))!;
      expect(e.isDated, true);
      expect(e.date, DateTime(2025, 12, 25));
      expect(e.hour, 0);
    });

    test('returns null for an unparseable entry', () {
      expect(ScheduleEntry.fromJson({'day': 'Funday', 'start': '09:00'}), isNull);
      expect(ScheduleEntry.fromJson({'day': 'Sunday', 'start': 'noon'}), isNull);
    });

    test('listFromJson skips bad entries', () {
      final list = ScheduleEntry.listFromJson([
        massJson('Sunday', '09:00'),
        {'day': 'Funday', 'start': '09:00'},
        massJson('Monday', '08:00'),
      ]);
      expect(list.length, 2);
    });
  });

  group('display helpers', () {
    test('display gives compact day + time', () {
      final e = ScheduleEntry.fromJson(massJson('Sunday', '09:00'))!;
      expect(e.display, 'Sun · 9:00 AM');
    });

    test('range timeLabel drops shared meridiem', () {
      final e = ScheduleEntry.fromJson(windowJson('Saturday', '15:00', '15:30'))!;
      expect(e.timeLabel, '3:00 – 3:30 PM');
    });

    test('noon and midnight format correctly', () {
      expect(ScheduleEntry.fromJson(massJson('Sunday', '12:00'))!.timeLabel, '12:00 PM');
      expect(ScheduleEntry.fromJson(massJson('Monday', '00:00'))!.timeLabel, '12:00 AM');
    });

    test('a window crossing midnight keeps both meridiems', () {
      // Saint Bartholomew's confession: the bulletin gave no end time, so the
      // exporter wrote 00:00. Both endpoints are nominally "AM", but they are
      // ~15 hours apart — collapsing to "9:15 – 12:00 AM" read as a short
      // morning slot.
      final e =
          ScheduleEntry.fromJson(windowJson('Saturday', '09:15', '00:00'))!;
      expect(e.crossesMidnight, isTrue);
      expect(e.timeLabel, '9:15 AM – 12:00 AM');
    });

    test('an evening window into the small hours reads correctly', () {
      // Our Lady of Mount Carmel: First Friday 10pm until 8:15am Benediction.
      final e =
          ScheduleEntry.fromJson(windowJson('Friday', '22:00', '08:15'))!;
      expect(e.crossesMidnight, isTrue);
      expect(e.timeLabel, '10:00 PM – 8:15 AM');
    });

    // Identical endpoints mean two opposite things, told apart only by
    // `end_next_day`: a day covered end to end, or a start with no stated end.
    test('a covered day (00:00-00:00 +1d) renders as a full day', () {
      // Saint Albert the Great and Saint Edward: the middle days of a
      // multi-day adoration. Not flagged is_perpetual, so this is their only
      // signal, and it rendered as "12:00 – 12:00 AM" before the fix.
      final e = ScheduleEntry.fromJson(
          windowJson('Tuesday', '00:00', '00:00', endNextDay: true))!;
      expect(e.hasRange, isTrue);
      expect(e.isAllDay, isTrue);
      expect(e.timeLabel, 'All day');
      // A genuinely 24-hour window, so it is underway at any hour.
      expect(e.currentWindowStart(DateTime(2026, 8, 4, 13, 0)), isNotNull);
    });

    test('a 24-hour span away from midnight is still a full day', () {
      // The encoding v2.5.0 mandates for overnight adoration. Inferring
      // all-day-ness from midnight rather than the flag missed this.
      final e = ScheduleEntry.fromJson(
          windowJson('Tuesday', '22:00', '22:00', endNextDay: true))!;
      expect(e.isAllDay, isTrue);
      expect(e.timeLabel, 'All day');
    });

    test('matching endpoints without the flag mean no end was stated', () {
      // Saint Columbkille: "Confessions available after the 4:00 PM Vigil".
      final e = ScheduleEntry.fromJson(
          windowJson('Saturday', '16:00', '16:00', endNextDay: false))!;
      expect(e.hasRange, isFalse);
      expect(e.isAllDay, isFalse);
      expect(e.timeLabel, '4:00 PM');
    });

    test('an open-ended slot is never reported as in progress', () {
      // Before the fix this rolled to the next day and read as a window that
      // stayed open for a full 24 hours — confession "underway" at 3 AM.
      final e = ScheduleEntry.fromJson(
          windowJson('Saturday', '16:00', '16:00', endNextDay: false))!;
      expect(e.currentWindowStart(DateTime(2026, 8, 8, 18, 0)), isNull);
      expect(e.currentWindowStart(DateTime(2026, 8, 9, 3, 0)), isNull);
      expect(e.endOf(DateTime(2026, 8, 8, 16, 0)), isNull);
    });

    test('a missing flag falls back to end < start, and never to equal', () {
      // Pre-v2.5.0 cached exports carry no flag. Strict `<` matches the
      // exporter's own backfill, so equal endpoints read as an unstated end.
      final overnight =
          ScheduleEntry.fromJson(windowJson('Friday', '22:00', '08:15'))!;
      expect(overnight.crossesMidnight, isTrue);
      final open =
          ScheduleEntry.fromJson(windowJson('Saturday', '16:00', '16:00'))!;
      expect(open.hasRange, isFalse);
      expect(open.crossesMidnight, isFalse);
    });

    test('a null end reads the same as matching endpoints', () {
      // What the scraper will emit once end_time becomes nullable.
      final e = ScheduleEntry.fromJson(
          {'day': 'Saturday', 'start': '16:00', 'end': null})!;
      expect(e.hasRange, isFalse);
      expect(e.timeLabel, '4:00 PM');
    });

    test('a same-day window is unaffected', () {
      final e =
          ScheduleEntry.fromJson(windowJson('Tuesday', '08:30', '19:40'))!;
      expect(e.crossesMidnight, isFalse);
      expect(e.isAllDay, isFalse);
      expect(e.timeLabel, '8:30 AM – 7:40 PM');
    });
  });

  group('occurrence math', () {
    test('next occurrence for an upcoming weekday', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday
      final e = ScheduleEntry.fromJson(massJson('Wednesday', '14:00'))!;
      final next = e.nextOccurrence(now);
      expect(next.weekday, 3);
      expect(next.hour, 14);
    });

    test('minutes until later today', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final e = ScheduleEntry.fromJson(massJson('Monday', '17:00'))!;
      expect(e.minutesUntilNext(now), 420);
    });

    test('wraps to next week if already passed', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final e = ScheduleEntry.fromJson(massJson('Monday', '08:00'))!;
      final next = e.nextOccurrence(now);
      expect(next.weekday, 1);
      expect(next.day, 12);
    });

    test('dated entry occurs on its fixed date', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final e = ScheduleEntry.fromJson(massJson('Friday', '13:00', massDate: '2026-01-09'))!;
      final next = e.nextOccurrence(now);
      expect(next, DateTime(2026, 1, 9, 13, 0));
      expect(e.isPast(now), false);
    });

    test('past dated entry is flagged and excluded from soonest', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final past = ScheduleEntry.fromJson(massJson('Friday', '13:00', massDate: '2026-01-02'))!;
      expect(past.isPast(now), true);

      final weekly = ScheduleEntry.fromJson(massJson('Monday', '17:00'))!;
      final next = ScheduleParser.findNextOccurrence([past, weekly], now);
      expect(next, weekly); // past dated one is skipped
    });

    test('a window underway counts as in progress, not next week', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday 10am
      final e = windowEntry('Monday', '08:00', '17:00');
      expect(e.isInProgress(now), true);
      expect(e.nextOccurrence(now), DateTime(2026, 1, 5, 8, 0));
      expect(e.minutesUntilNext(now), -120);
    });

    test('a finished window still rolls to next week', () {
      final now = DateTime(2026, 1, 5, 18, 0); // Monday, after it closed
      final e = windowEntry('Monday', '08:00', '17:00');
      expect(e.isInProgress(now), false);
      expect(e.nextOccurrence(now), DateTime(2026, 1, 12, 8, 0));
    });

    test('a window crossing midnight stays in progress after 00:00', () {
      final e = windowEntry('Monday', '22:00', '01:00');
      expect(e.isInProgress(DateTime(2026, 1, 6, 0, 30)), true); // Tuesday 12:30am
      expect(e.isInProgress(DateTime(2026, 1, 6, 1, 30)), false);
    });

    test('a dated window underway is not flagged past', () {
      final now = DateTime(2026, 1, 9, 14, 0);
      final e = ScheduleEntry.fromJson({
        ...windowJson('Friday', '13:00', '16:00'),
        'mass_date': '2026-01-09',
      })!;
      expect(e.isPast(now), false);
      expect(e.isInProgress(now), true);
    });

    test('an in-progress window outranks a sooner-starting entry', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final adoration = windowEntry('Monday', '08:00', '17:00');
      final mass = ScheduleEntry.fromJson(massJson('Monday', '12:00'))!;
      expect(ScheduleParser.findNextOccurrence([mass, adoration], now), adoration);
    });

    test('Mass paths skip an in-progress entry and point at the next one', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday, 10 min into a 9:30 Mass
      final underway = windowEntry('Monday', '09:30', '10:30');
      expect(underway.nextOccurrence(now, kCountMassInProgress),
          DateTime(2026, 1, 12, 9, 30));
      expect(underway.minutesUntilNext(now, kCountMassInProgress), greaterThan(0));

      final later = ScheduleEntry.fromJson(massJson('Monday', '12:00'))!;
      expect(
        ScheduleParser.findNextOccurrence(
            [underway, later], now, kCountMassInProgress),
        later,
      );
    });

    test('a dated Mass under way is past for Mass paths, not for windows', () {
      final now = DateTime(2026, 1, 9, 13, 30);
      final e = ScheduleEntry.fromJson({
        ...windowJson('Friday', '13:00', '14:00'),
        'mass_date': '2026-01-09',
      })!;
      expect(e.isPast(now), false);
      expect(e.isPast(now, kCountMassInProgress), true);
    });
  });

  group('ScheduleParser', () {
    test('finds the soonest from multiple entries', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday
      final entries = ScheduleEntry.listFromJson([
        massJson('Wednesday', '14:00'),
        massJson('Monday', '17:00'),
        massJson('Saturday', '09:00'),
      ]);
      final next = ScheduleParser.findNextOccurrence(entries, now);
      expect(next?.dayOfWeek, 1);
      expect(next?.hour, 17);
    });

    test('minutesUntilNext returns null for empty list', () {
      expect(ScheduleParser.minutesUntilNext([]), isNull);
    });

    test('groupByBucket sorts entries into relative day buckets', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '17:00'),   // today
        massJson('Tuesday', '08:00'),  // tomorrow
        massJson('Saturday', '09:00'), // this week
      ]);
      final buckets = ScheduleParser.groupByBucket(entries, now);
      expect(buckets['today']!.length, 1);
      expect(buckets['tomorrow']!.length, 1);
      expect(buckets['thisWeek']!.length, 1);
      expect(buckets['beyond']!.isEmpty, true);
    });
  });

  group('groupByDay', () {
    test('merges consecutive identical days into a range, Sunday first', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '08:00'),
        massJson('Tuesday', '08:00'),
        massJson('Wednesday', '08:00'),
        massJson('Thursday', '08:00'),
        massJson('Friday', '08:00'),
        massJson('Saturday', '16:30'),
        massJson('Sunday', '09:00'),
        massJson('Sunday', '11:00'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Sun', 'Mon–Fri', 'Sat']);
      expect(groups.first.entries.map((e) => e.hour).toList(), [9, 11]);
      expect(groups[1].entries.single.hour, 8);
    });

    test('different times on adjacent days do not merge', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '08:00'),
        massJson('Tuesday', '12:10'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Mon', 'Tue']);
    });

    test('a language mark blocks merging', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '08:00'),
        massJson('Tuesday', '08:00', language: 'Spanish'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.length, 2);
    });

    test('entries within a day are sorted by start time', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Sunday', '11:00'),
        massJson('Sunday', '07:30'),
        massJson('Sunday', '09:00'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.single.entries.map((e) => e.hour).toList(), [7, 9, 11]);
    });

    test('dated entries trail as their own date-labeled group', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Sunday', '09:00'),
        massJson('Thursday', '10:00', massDate: '2026-12-25'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Sun', 'Dec 25']);
    });

    test('confession windows group like plain times', () {
      final entries = ScheduleEntry.listFromJson([
        windowJson('Saturday', '15:00', '15:45'),
        windowJson('Wednesday', '18:00', '18:30'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Wed', 'Sat']);
      expect(groups.last.entries.single.hasRange, true);
    });
  });

  // Ordinal-weekday recurrence: `weeks_of_month` / `excluded_weeks`, the
  // additive keys specified in ../bulletin-v2/EXPORT_SHAPE_CHANGES.md. The
  // scraper does not emit them yet, so these pin the app's side of the
  // contract in advance. Calendar facts used below: August 2026 has four
  // Fridays (7, 14, 21, 28); September's first is the 4th; October has five
  // (2, 9, 16, 23, 30).
  group('monthly-ordinal recurrence', () {
    Map<String, dynamic> monthly(String day, String start,
            {List<dynamic>? weeks, List<dynamic>? excluded, String? notes}) =>
        {
          'day': day,
          'start': start,
          'notes': notes,
          if (weeks != null) 'weeks_of_month': weeks,
          if (excluded != null) 'excluded_weeks': excluded,
        };

    test('absent keys mean weekly, exactly as before', () {
      final e = ScheduleEntry.fromJson(massJson('Friday', '08:15'))!;
      expect(e.isMonthly, false);
      expect(e.weeksOfMonth, isNull);
      expect(e.excludedWeeks, isNull);
      expect(e.occursOn(DateTime(2026, 8, 7)), true);
      expect(e.occursOn(DateTime(2026, 8, 28)), true);
      expect(e.recurrenceKey, '');
      expect(e.ordinalShortLabel, isNull);
    });

    test('null and empty are weekly too, and never distinguished', () {
      for (final v in [null, <dynamic>[], 'first', 0]) {
        final e = ScheduleEntry.fromJson({
          'day': 'Friday',
          'start': '08:15',
          'weeks_of_month': v,
          'excluded_weeks': v,
        })!;
        expect(e.isMonthly, false, reason: 'weeks_of_month: $v');
      }
    });

    test('out-of-domain values are discarded; a wholly bad list is weekly', () {
      final mixed =
          ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [1, 9, -2]))!;
      expect(mixed.weeksOfMonth, [1]);
      final junk = ScheduleEntry.fromJson(
          monthly('Friday', '17:30', weeks: [0, 6, 'first', null]))!;
      expect(junk.isMonthly, false);
    });

    test('values are de-duplicated and sorted, -1 first', () {
      final e = ScheduleEntry.fromJson(
          monthly('Saturday', '15:00', weeks: [4, 2, 4, -1]))!;
      expect(e.weeksOfMonth, [-1, 2, 4]);
    });

    test('weeks_of_month wins if both keys somehow arrive', () {
      final e = ScheduleEntry.fromJson(
          monthly('Friday', '17:30', weeks: [1], excluded: [2]))!;
      expect(e.weeksOfMonth, [1]);
      expect(e.excludedWeeks, isNull);
    });

    test('occursOn honours the ordinal, and only on the right weekday', () {
      final firstFriday =
          ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [1]))!;
      expect(firstFriday.occursOn(DateTime(2026, 8, 7)), true);
      expect(firstFriday.occursOn(DateTime(2026, 8, 14)), false);
      expect(firstFriday.occursOn(DateTime(2026, 8, 6)), false); // Thursday
    });

    test('-1 is the last of its weekday, 5 only exists in some months', () {
      final last =
          ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [-1]))!;
      final fifth =
          ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [5]))!;
      // August 2026 has four Fridays: the 28th is last, and there is no fifth.
      expect(last.occursOn(DateTime(2026, 8, 28)), true);
      expect(fifth.occursOn(DateTime(2026, 8, 28)), false);
      // October 2026 has five: the 30th is both the fifth and the last.
      expect(last.occursOn(DateTime(2026, 10, 30)), true);
      expect(fifth.occursOn(DateTime(2026, 10, 30)), true);
      expect(last.occursOn(DateTime(2026, 10, 23)), false);
    });

    test('excluded_weeks is the inverse', () {
      final e = ScheduleEntry.fromJson(monthly('Friday', '08:15',
          excluded: [1], notes: 'Weekday Mass (except on First Fridays)'))!;
      expect(e.occursOn(DateTime(2026, 8, 7)), false);
      expect(e.occursOn(DateTime(2026, 8, 14)), true);
      expect(e.occursOn(DateTime(2026, 8, 28)), true);
    });

    test('nextOccurrence skips to the right week, not the next weekday', () {
      final e = ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [1]))!;
      // Mon 10 Aug: the coming Friday is the 14th, but this Mass is the 4th
      // of September.
      expect(e.nextOccurrence(DateTime(2026, 8, 10, 12, 0)),
          DateTime(2026, 9, 4, 17, 30));
    });

    test('nextOccurrence rolls past today once the slot has started', () {
      final e = ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [1]))!;
      expect(e.nextOccurrence(DateTime(2026, 8, 7, 18, 0)),
          DateTime(2026, 9, 4, 17, 30));
      expect(e.nextOccurrence(DateTime(2026, 8, 7, 9, 0)),
          DateTime(2026, 8, 7, 17, 30));
    });

    test('a fifth-week slot can be months out and is still found', () {
      final e = ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [5]))!;
      expect(e.nextOccurrence(DateTime(2026, 8, 1, 12, 0)),
          DateTime(2026, 10, 30, 17, 30));
    });

    test('an excluded week is skipped by nextOccurrence', () {
      final e =
          ScheduleEntry.fromJson(monthly('Friday', '08:15', excluded: [1]))!;
      expect(e.nextOccurrence(DateTime(2026, 9, 1, 12, 0)),
          DateTime(2026, 9, 11, 8, 15));
    });

    test('an off-week window is not reported as in progress', () {
      final e = ScheduleEntry.fromJson({
        'day': 'Friday',
        'start': '17:30',
        'end': '18:15',
        'end_next_day': false,
        'weeks_of_month': [1],
      })!;
      // 14 Aug is the second Friday: nothing is open, and "next" is September.
      expect(e.isInProgress(DateTime(2026, 8, 14, 17, 45)), false);
      expect(e.nextOccurrence(DateTime(2026, 8, 14, 17, 45)),
          DateTime(2026, 9, 4, 17, 30));
      // 7 Aug is the first: the window is genuinely open.
      expect(e.isInProgress(DateTime(2026, 8, 7, 17, 45)), true);
    });

    test('soonest ranking prefers a weekly entry over a distant monthly one',
        () {
      final entries = ScheduleEntry.listFromJson([
        monthly('Friday', '17:30', weeks: [1]),
        massJson('Friday', '19:00'),
      ]);
      final next = ScheduleParser.findNextOccurrence(
          entries, DateTime(2026, 8, 10, 12, 0))!;
      expect(next.hour, 19);
    });

    test('labels describe the rule', () {
      final first =
          ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [1]))!;
      expect(first.ordinalShortLabel, '1st');
      expect(first.ordinalDescription, '1st Friday of the month');

      final twoAndFour =
          ScheduleEntry.fromJson(monthly('Saturday', '15:00', weeks: [2, 4]))!;
      expect(twoAndFour.ordinalShortLabel, '2nd·4th');
      expect(twoAndFour.ordinalDescription, '2nd & 4th Saturday of the month');

      final last =
          ScheduleEntry.fromJson(monthly('Sunday', '14:00', weeks: [-1]))!;
      expect(last.ordinalShortLabel, 'Last');

      final except =
          ScheduleEntry.fromJson(monthly('Friday', '08:15', excluded: [1]))!;
      expect(except.ordinalShortLabel, 'Except 1st');
      expect(except.ordinalDescription, 'Every Friday except the 1st');
    });

    test('the exporter note wins over the generated description', () {
      final e = ScheduleEntry.fromJson(monthly('Friday', '17:30',
          weeks: [1], notes: 'First Friday of the month'))!;
      expect(e.displayNote, 'First Friday of the month');
      expect(e.noteLabel, 'First Friday of the month');
    });

    test('a monthly entry without a note still says so', () {
      final e = ScheduleEntry.fromJson(monthly('Friday', '17:30', weeks: [1]))!;
      expect(e.displayNote, '1st Friday of the month');
    });

    test('groupByDay never merges a monthly day-run with a weekly one', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Wednesday', '08:15'),
        monthly('Thursday', '08:15', weeks: [1]),
        massJson('Friday', '08:15'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Wed', 'Thu', 'Fri']);
    });
  });
}
