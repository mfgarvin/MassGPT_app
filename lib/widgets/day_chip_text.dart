/// How the day label inside a schedule chip is sized.
///
/// Shared by the Mass card and the Confession/Adoration timeline card so that
/// a "Sat" reads the same on all three — they sit on the same page, and a day
/// set smaller in one card than another looks like a mistake rather than a
/// distinction.
///
/// Sizing by label length lets the common case (a single day) fill its chip,
/// while a run ("Mon–Fri") and a list ("Mon, Tue, Thu", which wraps) still
/// fit. Only the Mass card produces the longer forms; the timeline card's
/// rows are always one day.
double dayChipTextSize(String label) {
  if (label.length <= 3) return 17;
  if (label.length <= 8) return 13;
  return 11;
}

/// "Mon–Fri" and the like, as opposed to a comma-separated list. A run is one
/// idea and should shrink to one line rather than break across two.
bool isDayRun(String label) => label.contains('–');
