import '../models/parish.dart';
import 'search_normalize.dart';

/// Free-text parish search: every whitespace-separated word in the query has to
/// match *somewhere* in the parish, but they don't all have to match the same
/// field and they don't have to appear in the query's order.
///
/// This is what makes "joseph strongsville" work. Matching the whole query as
/// one substring — the old behaviour — meant a name word and a city word could
/// never be typed together, because no single field contains both. Splitting
/// into words and requiring each to land somewhere fixes that, and it also
/// covers "strongsville joseph", "st joseph 44136" and "44136 joseph".
///
/// Results are ranked (see [parishSearchScore]) so a caller that shows only a
/// handful — Home's autocomplete takes 5 — shows the most likely ones.
List<Parish> searchParishes(Iterable<Parish> parishes, String query) {
  final tokens = searchTokens(query);
  if (tokens.isEmpty) return const [];

  final scored = <(int, Parish)>[];
  for (final parish in parishes) {
    final score = parishSearchScore(parish, tokens);
    if (score != null) scored.add((score, parish));
  }

  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    if (byScore != 0) return byScore;
    return normalizeForSearch(a.$2.name).compareTo(normalizeForSearch(b.$2.name));
  });

  return [for (final entry in scored) entry.$2];
}

/// Score [parish] against already-normalized [tokens], or null when any token
/// fails to match — which is what makes the query an AND of its words.
///
/// Higher is better. Within a field a match at the start of the field beats one
/// at the start of a later word, which beats one in the middle of a word, so
/// "jos" ranks "St. Joseph" above "San Jose de..." only by field weight but
/// keeps mid-word noise ("Vojtech") below real word hits. Name outweighs city
/// so that typing a saint's name doesn't bury it under a city that happens to
/// contain the letters.
int? parishSearchScore(Parish parish, List<String> tokens) {
  if (tokens.isEmpty) return null;
  final name = normalizeForSearch(parish.name);
  final city = normalizeForSearch(parish.city);
  final zip = parish.zipCode.trim();

  var total = 0;
  for (final token in tokens) {
    final best = [
      _positionScore(name, token) * 3,
      _positionScore(city, token) * 2,
      zip.startsWith(token) ? 4 : 0,
    ].reduce((a, b) => a > b ? a : b);
    if (best == 0) return null;
    total += best;
  }

  // A parish whose name contains the query verbatim ("saint joseph") is a
  // better hit than one that merely collects the same words apart, so the
  // contiguous phrase keeps the edge that word-splitting would otherwise cost
  // it.
  final phrase = tokens.join(' ');
  total += _positionScore(name, phrase) * 4;
  total += _positionScore(city, phrase) * 2;
  return total;
}

/// 3 at the front of [haystack], 2 at the start of any later word, 1 mid-word,
/// 0 when absent.
int _positionScore(String haystack, String token) {
  final i = haystack.indexOf(token);
  if (i < 0) return 0;
  if (i == 0) return 3;
  return haystack[i - 1] == ' ' ? 2 : 1;
}

/// The query split into normalized words. Normalizing first means each word is
/// already Saint-folded and diacritic-folded, so "sts." arrives as "saint".
List<String> searchTokens(String query) => normalizeForSearch(query)
    .split(' ')
    .where((t) => t.isNotEmpty)
    .toList();
