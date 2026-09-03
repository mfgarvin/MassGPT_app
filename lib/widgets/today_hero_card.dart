import 'package:flutter/material.dart';
import '../pages/filtered_parish_list_page.dart';
import '../theme/app_text.dart';
import '../utils/layout_scale.dart';
import '../main.dart' show goldTextAccentFor, kConfessionViolet;

/// What kind of schedule a hero suggestion is pointing the user toward.
enum HeroIntent { mass, confession, adoration }

/// A day-aware suggestion card that adapts its message and CTA to the
/// current weekday and time of day. Calls [onSelect] with the matching
/// intent so the host can route to the right filtered list.
class TodayHeroCard extends StatelessWidget {
  final void Function(HeroIntent intent) onSelect;
  final Color accentColor;
  final bool isDark;

  const TodayHeroCard({
    super.key,
    required this.onSelect,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final suggestion = _suggestionFor(now);
    final tint = _accentForIntent(suggestion.intent) ?? accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(suggestion.intent),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint,
                Color.lerp(tint, Colors.black, 0.28)!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            children: [
              // Decoration, like the map card's glass chip: at large text
              // sizes the badge and its gap cost the headline about a fifth
              // of the card, which is what pushed "Find Mass times today"
              // onto three lines. The headline is the card.
              if (!context.prefersStackedLayout) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(suggestion.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.kicker,
                      style: AppText.kicker(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.headline,
                      style: AppText.titleHero(color: Colors.white),
                    ),
                    if (suggestion.subline != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.subline!,
                        style: AppText.caption(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  _Suggestion _suggestionFor(DateTime now) {
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final hour = now.hour;
    final dayName = _dayName(weekday);

    // Sunday morning → main Mass
    if (weekday == DateTime.sunday && hour < 13) {
      return _Suggestion(
        kicker: 'SUNDAY',
        headline: 'Find a Mass today',
        subline: 'Sunday Mass times nearby',
        icon: Icons.church,
        intent: HeroIntent.mass,
      );
    }
    // Sunday afternoon/evening → adoration / quiet
    if (weekday == DateTime.sunday) {
      return _Suggestion(
        kicker: 'SUNDAY EVENING',
        headline: 'A quiet hour of adoration',
        subline: 'Find a chapel for evening prayer',
        icon: Icons.brightness_2_outlined,
        intent: HeroIntent.adoration,
      );
    }
    // Saturday afternoon/evening → vigil Mass
    if (weekday == DateTime.saturday && hour >= 14) {
      return _Suggestion(
        kicker: 'TONIGHT',
        headline: 'Vigil Mass tonight',
        subline: 'See Saturday vigil schedules',
        icon: Icons.nights_stay,
        intent: HeroIntent.mass,
      );
    }
    // Saturday morning → confession (penitential traditional time)
    if (weekday == DateTime.saturday) {
      return _Suggestion(
        kicker: 'SATURDAY',
        headline: 'Confessions this morning',
        subline: 'Many parishes hear confessions before vigil',
        icon: Icons.self_improvement,
        intent: HeroIntent.confession,
      );
    }
    // Friday → confession
    if (weekday == DateTime.friday) {
      return _Suggestion(
        kicker: 'FRIDAY',
        headline: 'Confession this week',
        subline: 'Find a parish offering reconciliation',
        icon: Icons.self_improvement,
        intent: HeroIntent.confession,
      );
    }
    // Weekday morning → daily Mass
    if (hour < 11) {
      return _Suggestion(
        kicker: dayName.toUpperCase(),
        headline: 'Daily Mass this morning',
        subline: 'Weekday Mass times nearby',
        icon: Icons.wb_sunny_outlined,
        intent: HeroIntent.mass,
      );
    }
    // Weekday late evening → adoration
    if (hour >= 19) {
      return _Suggestion(
        kicker: 'TONIGHT',
        headline: 'A quiet hour of adoration',
        subline: 'Find a chapel for evening prayer',
        icon: Icons.brightness_2_outlined,
        intent: HeroIntent.adoration,
      );
    }
    // Default daytime weekday → Mass times
    return _Suggestion(
      kicker: dayName.toUpperCase(),
      headline: 'Find Mass times today',
      subline: 'Browse parishes near you',
      icon: Icons.access_time,
      intent: HeroIntent.mass,
    );
  }

  /// Color hint per intent — gives each kind of suggestion a recognizable
  /// hue without overriding caller-provided accent. Adoration uses a deep
  /// bronze-gold so white text on the gradient stays ≥4.5:1 contrast.
  Color? _accentForIntent(HeroIntent intent) {
    switch (intent) {
      case HeroIntent.mass:
        return null; // use caller accent (oxblood / candlelight)
      case HeroIntent.confession:
        // Stays the deep violet in both themes: this tints a gradient that
        // white text sits on, so lightening it the way the Confession list's
        // ink does would cost the headline its contrast.
        return kConfessionViolet;
      case HeroIntent.adoration:
        return goldTextAccentFor(isDark: isDark); // bronze gold — Eucharistic
    }
  }

  String _dayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }
}

class _Suggestion {
  final String kicker;
  final String headline;
  final String? subline;
  final IconData icon;
  final HeroIntent intent;

  _Suggestion({
    required this.kicker,
    required this.headline,
    this.subline,
    required this.icon,
    required this.intent,
  });
}

/// Maps a hero intent to the matching [ParishFilter] for routing.
ParishFilter parishFilterForIntent(HeroIntent intent) {
  switch (intent) {
    case HeroIntent.mass:
      return ParishFilter.massTimes;
    case HeroIntent.confession:
      return ParishFilter.confession;
    case HeroIntent.adoration:
      return ParishFilter.adoration;
  }
}
