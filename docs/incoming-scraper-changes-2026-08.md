# Incoming scraper changes — August 2026

From the `bulletin-v2` scraper repo. Two changes: one **shipping now**, one
**planned**. This document exists to answer one question — *does either break
the app, and can the scraper ship before the app updates?*

**Short answer: neither breaks the app, and both can ship independently.**
Change A needs no app work at all. Change B is purely additive and the app
keeps working unchanged; it just won't benefit until it adopts the new fields.

I checked this against the app's real code, not against assumptions — file and
line references are given so you can confirm rather than trust.

---

## Change A — v2.5.10, shipping now, **data only, no shape change**

Three classes of wrong data were removed from Notion, so the next `export.json`
rebuild (the Saturday Actions job) will carry different *values*. **No key was
added, removed, or retyped.**

### What changed

1. **Extraction commentary stripped from `notes`.** The `notes` field is
   published text that renders under a parish's name, but some entries carried
   internal commentary — `"Holy Day schedule lists 11:00 AM & 7:00 PM (day not
   specified); see extraction_notes."`, `"start time estimated"`, `"year not
   stated"`. 7 rows cleaned. Some notes became shorter; some became **null**.

2. **Undated Holy Day Masses dropped.** 12 parishes were publishing their Holy
   Day *policy* line ("Holy Days: 8:15, 11:15, 6:45 pm") as recurring weekly
   Masses on an arbitrarily chosen weekday. St. Thomas More advertised three
   Masses every Thursday, a day it has no weekday Mass at all. Those entries are
   gone; ~15 phantom Masses removed across 12 parishes.

3. **Seasonal / Triduum adoration cleared.** 24 parishes were publishing
   one-off liturgical adoration as their standing weekly schedule — 19 of them
   showing Holy Thursday 2026 adoration as "every Thursday, 8–10 pm", all year.
   Those parishes now have `schedules.adoration.times: []` and
   `is_perpetual: false`.

### Impact on the app: none — no code change required

| what the app sees | why it's fine |
|---|---|
| `notes` becomes `null` on some entries | `ScheduleEntry.fromJson` already null-guards it (`schedule_parser.dart:123`) |
| fewer entries in `schedules.mass` | just a shorter list; `listFromJson` is length-agnostic |
| `schedules.adoration.times` becomes `[]` for 24 parishes | `Parish.hasAdoration` is `adorationIsPerpetual \|\| adoration.isNotEmpty` (`parish.dart:59`), so the adoration section simply stops rendering for those parishes |

The one thing worth knowing, though it isn't a bug: **24 parishes will visibly
lose their adoration section, and 12 will show fewer Masses.** That is the
correction landing, not data loss — those entries were describing events that
do not happen. If the app has any "parishes with adoration" filter or count,
expect those numbers to drop.

**Nothing to do for Change A.** Listed so a shrinking schedule isn't mistaken
for a regression.

---

## Change B — monthly-ordinal recurrence, **planned, additive, spec frozen**

**Updated 2026-08-29: `occurrences` is withdrawn.** The export carries the
recurrence *rule* only; the app resolves it. Everything else below is
unchanged. The frozen spec is the `weeks_of_month` / `excluded_weeks` section of
`../bulletin-v2/EXPORT_SHAPE_CHANGES.md`, which is authoritative.

### The problem being fixed

60 schedule slots across ~40 parishes recur on an **ordinal weekday of the
month** — "First Friday", "Last Sunday", "2nd Tuesday" — but nothing in the
schema can express that, so every one is stored and exported as recurring
**every** week.

Split: 20 confessions, 13 adoration, 11 Masses, plus more found on a wider scan.

Right now the app renders a First Friday confession slot as happening every
Friday, and `nextOccurrence()` will happily return next Friday
(`schedule_parser.dart:210-233` — for a non-dated entry it rolls forward on
`dayOfWeek` alone). The published `notes` do say "First Friday of the month", so
a user reading the card is not misled; anything *computed* is wrong.

### The export shape

Two optional keys, on `schedules.mass[]`, `schedules.confession[]` and
`schedules.adoration.times[]` alike. Nothing is removed or retyped, and the keys
are emitted **only when non-null** — so every entry that exists today is
byte-identical.

```json
{
  "day": "Friday",
  "start": "17:30",
  "end": "18:15",
  "end_next_day": false,
  "mass_date": null,
  "language": null,
  "notes": "First Friday of the month",

  "weeks_of_month": [1]
}
```

- **`weeks_of_month`** — occurs **only** in these ordinal weeks. `[1]` = first
  weekday-of-month, `[-1]` = last, `[2,4]` = 2nd and 4th (real data). Absent /
  `null` / `[]` all mean **every week**, which is every entry today.
- **`excluded_weeks`** — the inverse: every week **except** these. One known
  case so far (`"Weekday Mass (except on First Fridays)"`), which the earlier
  draft would have stored exactly backwards. Same value domain; never both keys
  on one entry.
- Value domain is `1`–`5` and `-1`. **`5` and `-1` differ**: a 5th Friday exists
  only in some months, and in a 5-Friday month `-1` is the 5th, not the 4th.
- Never combined with `mass_date` — a dated one-off is a date, not a rule.

### Why the pre-resolved `occurrences` array was dropped

It would have gone stale in the direction that matters: the app is
offline-first, and past the 90-day horizon the array empties, leaving a choice
between rendering weekly again (the bug) and hiding a real Mass. A rule has no
horizon. It also gave two representations of one fact with no stated winner, and
would have rewritten 60 entries' date arrays on every weekly rebuild, which
is noise in a file the scraper repo diffs as a freshness audit.

The arithmetic it saves is ten lines, with no timezone or locale dimension, and
is unit-testable with no data dependency.

### Does it break the app? No — verified

`ScheduleEntry.fromJson` (`schedule_parser.dart:94-127`) reads a fixed set of
keys by name off a `Map<String, dynamic>`. Unknown keys are never touched, and
Dart returns `null` for absent keys rather than throwing. So an app build that
predates this change parses the new export **exactly as it does today** and
ignores both new fields.

The scraper can ship whenever it's ready, with no coordination. Until the app
adopts the fields, a First Friday slot keeps rendering as weekly — current
behaviour, so **no regression, just an un-taken improvement.** Equally, the app
can adopt the fields *now*, before the scraper emits them: absent keys mean
weekly, so the code is inert until the data arrives and then just works.

### What the app does to adopt it

> **Adopted 2026-08-29** — steps 1–6 below are implemented, ahead of the
> scraper emitting the keys. `ScheduleEntry.weeksOfMonth` / `excludedWeeks`
> parse defensively; `occursOn()` is the single predicate; `currentWindowStart`
> and `nextOccurrence` route through it; `recurrenceKey` splits the
> `_collapse()` and `groupByDay` grouping keys; and `displayNote` falls back to
> a generated sentence if a rule ever arrives with no note. Covered by the
> `monthly-ordinal recurrence` group in `test/schedule_parser_test.dart`.
>
> **Presentation, answering the open question below.** The ordinal shows on the
> two surfaces that assert a *standing weekly schedule*: as a second line under
> the day on the Mass card (day chips are a fixed 38px so monthly and weekly
> rows stay level), and as a small marker on the time in the A–Z list's schedule
> chips (`_groupChip`), which carry no note at all and so were the worse of the
> two. It deliberately does **not** show on the confession/adoration card: that
> is a rolling Today/Tomorrow/This-week/Beyond list, so each row is one upcoming
> occurrence rather than a weekly claim, and bucketing already routes through
> `nextOccurrence`. Note the split — 20 confessions, 13 adoration, 11 Masses —
> means the A–Z chips, not the Mass card, are where most of this data is seen.

The whole rule collapses into one predicate. Add it to `ScheduleEntry` and route
every recurrence decision through it.

**1. Two fields, parsed defensively.**

```dart
/// Ordinal weeks this entry occurs in; null = every week.
final List<int>? weeksOfMonth;
/// Ordinal weeks this entry is skipped in; null = never skipped.
final List<int>? excludedWeeks;

/// 1..5 and -1 only. Anything else is malformed; empty => null (weekly).
static List<int>? _parseWeeks(dynamic v) {
  if (v is! List) return null;
  final out = v
      .whereType<int>()
      .where((n) => (n >= 1 && n <= 5) || n == -1)
      .toSet()
      .toList()
    ..sort();
  return out.isEmpty ? null : out;
}
```

In `fromJson`, with `weeks_of_month` winning if both somehow appear:

```dart
final weeks = _parseWeeks(json['weeks_of_month']);
final excluded = weeks == null ? _parseWeeks(json['excluded_weeks']) : null;
```

**2. The predicate.**

```dart
bool get isMonthly => weeksOfMonth != null || excludedWeeks != null;

/// Does this entry occur on [day]? Handles dated, weekly and monthly alike.
bool occursOn(DateTime day) {
  if (date != null) {
    return day.year == date!.year &&
        day.month == date!.month &&
        day.day == date!.day;
  }
  if (day.weekday != dayOfWeek) return false;
  if (!isMonthly) return true;

  final n = ((day.day - 1) ~/ 7) + 1;                  // 1st..5th
  final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
  final isLast = day.day + 7 > daysInMonth;
  bool listed(List<int> w) => w.contains(n) || (w.contains(-1) && isLast);

  return weeksOfMonth != null ? listed(weeksOfMonth!) : !listed(excludedWeeks!);
}
```

**3. `currentWindowStart()`** (`schedule_parser.dart:181-200`) — the existing
`if (date != null) {...} else if (day.weekday != dayOfWeek) continue;` block
becomes `if (!occursOn(day)) continue;`. Without this, a First Friday adoration
window reads as "in progress" on every Friday.

**4. `nextOccurrence()`** (`schedule_parser.dart:210-233`) — the weekly
`daysUntil` arithmetic is correct only for `!isMonthly`. For a monthly entry,
scan forward day by day for the first `occursOn` at/after now:

```dart
final today = DateTime(now.year, now.month, now.day);
for (var i = 0; i <= 400; i++) {
  final d = today.add(Duration(days: i));
  if (!occursOn(d)) continue;
  final t = DateTime(d.year, d.month, d.day, hour, minute);
  if (!t.isBefore(now)) return t;
}
// Scan exhausted (shouldn't happen): fall back to the weekly roll-forward.
```

400 days is a generous bound — a `[5]`-only slot can be ~3 months out — and
failing *back to weekly* keeps the failure generous rather than hiding a Mass.

**5. `_collapse()` in `mass_schedule_card.dart:298-309`** — the grouping key is
`hour:minute:endHour:endMinute:language:note`. Two entries sharing a time and
note merge into one multi-day row, so a First Friday slot can currently be
collapsed with a weekly one and rendered as if both were weekly. **Append the
ordinal to the key.** (This call site wasn't in the earlier draft of this doc.)

**6. Presentation.** Render the ordinal ("1st Fri", "Last Sun") on the row.
`notes` already carries the text, so this is polish, not correctness.

**No change needed** at `filtered_parish_list_page.dart:334` — the weekday
filter tests `dayOfWeek`, and a First Friday entry genuinely does occur on
Fridays. The `DayFilter` today/tomorrow/thisWeek branch below it goes through
`nextOccurrence`, so step 4 fixes it for free. **If you only do two things, do
3 and 4** — that's where the wrongness is user-visible.

### One honest caveat

**Coverage is ~50 of 60 slots.** The ordinal is derived deterministically by
the scraper from the `notes` text (rather than asked of the LLM, which would
re-roll its mistakes weekly), and it refuses rather than guesses. 8 slots read
*"the Thursday before the First Friday"*, which is genuinely not an ordinal of
the month — when the first Friday is the 1st or 2nd, that Thursday falls in the
*previous* month. Those keep no keys and stay weekly. **No entry will carry a
wrong ordinal; not every monthly entry will carry one.** Don't try to
special-case the residue in the app.

The scraper also guarantees `notes` keeps stating the ordinal — the fields are
derived from that text, so the human-readable and machine-readable forms cannot
silently diverge.

## Open questions

The three questions in the earlier draft are now closed:

1. *Anywhere else recurrence is derived from `day` alone?* — Yes, two, both
   found and covered above: the `_collapse()` grouping key
   (`mass_schedule_card.dart:309`) and the weekday filter
   (`filtered_parish_list_page.dart:334`, which needs no change). Every other
   call site — `next_mass_banner.dart`, `next_mass_tile.dart`,
   `mass_schedule_card.dart`, and the filtered list's sorting and
   `_minutesUntilNext` map — routes through `nextOccurrence` /
   `minutesUntilNext` / `currentWindowStart`, so steps 3 and 4 cover them all.
2. *Does "soonest" ranking use `nextOccurrence` directly?* — Yes.
   `filtered_parish_list_page.dart:412`, `:1190-1200` and
   `mass_schedule_card.dart:55` all sort on `nextOccurrence` directly. No
   separate comparator to fix.
3. *ISO date strings or timestamps for `occurrences`?* — Moot; `occurrences` is
   withdrawn.

Still genuinely open, and an app-side call:

- **How to render an ordinal on a collapsed multi-day row.** "1st Fri" is easy;
  a row collapsing several days where only some are monthly is not — which is
  the argument for splitting them (step 5) rather than labelling them.

The scraper-side spec is `EXPORT_SHAPE_CHANGES.md` in `../bulletin-v2`, which
stays authoritative; the design rationale is
`../bulletin-v2/docs/design/monthly-recurrence.md` (note: its `occurrences`
proposal is superseded by the spec).
