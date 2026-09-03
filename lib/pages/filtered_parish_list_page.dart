import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../services/parish_service.dart';
import '../utils/layout_scale.dart';
import '../utils/schedule_parser.dart';
import '../main.dart'
    show
        FavoritesManager,
        kBackgroundColor,
        kBackgroundColorDark,
        kCardColor,
        kCardColorDark,
        cardBorderFor,
        onAccentFor,
        themeNotifier;
import 'parish_detail_page.dart';
import '../widgets/stained_glass_header.dart';
import '../widgets/language_badge.dart';

enum ParishFilter {
  massTimes,
  confession,
  adoration,
  all,
}

enum SortOrder {
  distance,
  alphabetical,
  nearestAndSoonest,
}

enum DayFilter {
  any,
  today,
  tomorrow,
  thisWeek,
}

enum TimeOfDayFilter {
  any,
  morning,    // 5am-12pm
  afternoon,  // 12pm-5pm
  evening,    // 5pm-9pm
  night,      // 9pm-5am
}

enum LanguageFilter {
  any,
  spanish,
  other, // any non-English Mass that isn't Spanish
}

class FilteredParishListPage extends StatefulWidget {
  final ParishFilter filter;
  final String title;
  final Color accentColor;
  final LatLng? userLocation;

  const FilteredParishListPage({
    super.key,
    required this.filter,
    required this.title,
    required this.accentColor,
    this.userLocation,
  });

  @override
  State<FilteredParishListPage> createState() => _FilteredParishListPageState();
}

class _FilteredParishListPageState extends State<FilteredParishListPage> {
  List<Parish> _parishes = [];
  List<Parish> _filteredParishes = [];
  /// Keyed by [FavoritesManager.keyFor], not by name — six parish names repeat
  /// across cities, and name keys made those records overwrite each other.
  final Map<String, double> _distances = {};
  final Map<String, int> _minutesUntilNext = {};
  bool _isLoading = true;
  SortOrder _sortOrder = SortOrder.nearestAndSoonest;
  bool _showAllParishes = false;
  DayFilter _dayFilter = DayFilter.any;
  TimeOfDayFilter _timeOfDayFilter = TimeOfDayFilter.any;
  LanguageFilter _languageFilter = LanguageFilter.any;
  Set<int> _selectedWeekdays = {}; // 1=Monday, 7=Sunday

  /// Language filtering only applies to Mass schedules (which carry a language).
  bool get _languageFilterApplies =>
      widget.filter == ParishFilter.massTimes || widget.filter == ParishFilter.all;

  /// 2 days in minutes
  static const int _twoDaysInMinutes = 2880;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
    _loadParishData();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _loadParishData() async {
    try {
      final parishes = await parishService.getParishes();

      setState(() {
        _parishes = parishes;
        _calculateDistances();
        _calculateNextOccurrences();
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading parish data: $e');
    }
  }

  void _calculateDistances() {
    if (widget.userLocation == null) return;

    for (final parish in _parishes) {
      if (parish.latitude != null && parish.longitude != null) {
        _distances[FavoritesManager.keyFor(parish)] = _calculateDistance(
          widget.userLocation!.latitude,
          widget.userLocation!.longitude,
          parish.latitude!,
          parish.longitude!,
        );
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMiles = 3958.8;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Whether a window already open counts as "soonest" for this list. True for
  /// confession/adoration (come and go); false for Mass — see
  /// [kCountMassInProgress]. The "all" list falls back to confession only when
  /// a parish has no Mass times, so it follows the schedule actually used.
  bool _countInProgressFor(Parish parish) {
    switch (widget.filter) {
      case ParishFilter.massTimes:
        return kCountMassInProgress;
      case ParishFilter.confession:
      case ParishFilter.adoration:
        return true;
      case ParishFilter.all:
        return parish.massTimes.isEmpty;
    }
  }

  void _calculateNextOccurrences() {
    for (final parish in _parishes) {
      // A perpetual chapel is open right now, so nothing is sooner. It carries
      // no ScheduleEntry, though, so the generic path below left it with no
      // countdown at all — which sorted it behind every scheduled parish and
      // then hid it entirely, because the two-day cap drops anything without
      // one. Rank it as open and move on.
      if (widget.filter == ParishFilter.adoration &&
          parish.adorationIsPerpetual) {
        _minutesUntilNext[FavoritesManager.keyFor(parish)] = 0;
        continue;
      }

      List<ScheduleEntry> scheduleToCheck = [];

      // Get the appropriate schedule based on filter
      switch (widget.filter) {
        case ParishFilter.massTimes:
          scheduleToCheck = parish.massTimes;
          break;
        case ParishFilter.confession:
          scheduleToCheck = parish.confTimes;
          break;
        case ParishFilter.adoration:
          scheduleToCheck = parish.adoration;
          break;
        case ParishFilter.all:
          scheduleToCheck = parish.massTimes.isNotEmpty
              ? parish.massTimes
              : parish.confTimes;
          break;
      }

      // Calculate minutes until next occurrence
      final minutes = ScheduleParser.minutesUntilNext(
          scheduleToCheck, null, _countInProgressFor(parish));
      if (minutes != null) {
        _minutesUntilNext[FavoritesManager.keyFor(parish)] = minutes;
      }
    }
  }

  void _applyFilter() {
    switch (widget.filter) {
      case ParishFilter.massTimes:
        _filteredParishes = _parishes
            .where((p) => p.massTimes.isNotEmpty)
            .toList();
        break;
      case ParishFilter.confession:
        _filteredParishes = _parishes
            .where((p) => p.confTimes.isNotEmpty)
            .toList();
        break;
      case ParishFilter.adoration:
        _filteredParishes = _parishes
            .where((p) => p.hasAdoration)
            .toList();
        break;
      case ParishFilter.all:
        _filteredParishes = List.from(_parishes);
        break;
    }
    _applySorting();
  }

  void _applySorting() {
    if (_sortOrder == SortOrder.distance && widget.userLocation != null) {
      _filteredParishes.sort((a, b) {
        final distA =
            _distances[FavoritesManager.keyFor(a)] ?? double.infinity;
        final distB =
            _distances[FavoritesManager.keyFor(b)] ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else if (_sortOrder == SortOrder.nearestAndSoonest && widget.userLocation != null) {
      // Composite score: combine distance and time
      _filteredParishes.sort((a, b) {
        final scoreA = _calculateCompositeScore(a);
        final scoreB = _calculateCompositeScore(b);
        if (scoreA != scoreB) return scoreA.compareTo(scoreB);
        // Everything underway right now scores the same, so the nearer one
        // wins — otherwise a perpetual chapel across the street loses to an
        // all-day chapel on the far side of town.
        final distA = _distances[FavoritesManager.keyFor(a)] ?? double.infinity;
        final distB = _distances[FavoritesManager.keyFor(b)] ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else {
      _filteredParishes.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  /// Distance cap in miles - parishes within this range are sorted by time
  static const double _distanceCapMiles = 10.0;

  /// Calculate composite score using distance cap approach
  /// - Within cap: sort by time (soonest first)
  /// - Beyond cap: pushed to bottom, sorted by distance
  double _calculateCompositeScore(Parish parish) {
    final key = FavoritesManager.keyFor(parish);
    final distance = _distances[key];
    final minutes = _minutesUntilNext[key];

    // If either is missing, return infinity
    if (distance == null || minutes == null) {
      return double.infinity;
    }

    // Distance cap scoring:
    // - Within 10 miles: score = minutes (0-9999 range, sorted by time)
    // - Beyond 10 miles: score = 10000 + distance (always after nearby parishes)
    if (distance <= _distanceCapMiles) {
      // In-progress entries come back negative (minutes since it started), and
      // a perpetual chapel is pinned at 0. Ranking by how long ago something
      // opened is meaningless, so everything happening now ties at 0 and the
      // caller's distance tiebreak decides.
      return minutes < 0 ? 0.0 : minutes.toDouble();
    } else {
      return 10000.0 + distance;
    }
  }

  bool _hasActiveFilters() {
    return _dayFilter != DayFilter.any ||
        _timeOfDayFilter != TimeOfDayFilter.any ||
        _selectedWeekdays.isNotEmpty ||
        (_languageFilterApplies && _languageFilter != LanguageFilter.any);
  }

  /// The schedule entries the time filters scan, based on filter type.
  List<ScheduleEntry> _filterableEntries(Parish parish) {
    switch (widget.filter) {
      case ParishFilter.massTimes:
        return parish.massTimes;
      case ParishFilter.confession:
        return parish.confTimes;
      case ParishFilter.adoration:
        return parish.adoration;
      case ParishFilter.all:
        return [...parish.massTimes, ...parish.confTimes];
    }
  }

  /// Whether a single entry satisfies every active filter.
  bool _entryMatchesFilters(
      Parish parish, ScheduleEntry entry, DateTime now, DateTime today) {
    // Check language filter (Mass-only; confession/adoration carry no language
    // so they never satisfy a Spanish/Other request).
    if (_languageFilterApplies && _languageFilter != LanguageFilter.any) {
      final matchesLanguage = _languageFilter == LanguageFilter.spanish
          ? entry.isSpanish
          : entry.isOtherLanguage;
      if (!matchesLanguage) return false;
    }

    // Check weekday filter
    if (_selectedWeekdays.isNotEmpty && !_selectedWeekdays.contains(entry.dayOfWeek)) {
      return false;
    }

    // Check time of day filter
    if (_timeOfDayFilter != TimeOfDayFilter.any) {
      final hour = entry.hour;
      bool matchesTime = false;
      switch (_timeOfDayFilter) {
        case TimeOfDayFilter.morning:
          matchesTime = hour >= 5 && hour < 12;
          break;
        case TimeOfDayFilter.afternoon:
          matchesTime = hour >= 12 && hour < 17;
          break;
        case TimeOfDayFilter.evening:
          matchesTime = hour >= 17 && hour < 21;
          break;
        case TimeOfDayFilter.night:
          matchesTime = hour >= 21 || hour < 5;
          break;
        case TimeOfDayFilter.any:
          matchesTime = true;
          break;
      }
      if (!matchesTime) return false;
    }

    // Check day filter
    if (_dayFilter != DayFilter.any) {
      final nextOccurrence =
          entry.nextOccurrence(now, _countInProgressFor(parish));
      final eventDay = DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);
      final daysUntil = eventDay.difference(today).inDays;

      bool matchesDay = false;
      switch (_dayFilter) {
        case DayFilter.today:
          matchesDay = daysUntil == 0;
          break;
        case DayFilter.tomorrow:
          matchesDay = daysUntil == 1;
          break;
        case DayFilter.thisWeek:
          matchesDay = daysUntil <= 7;
          break;
        case DayFilter.any:
          matchesDay = true;
          break;
      }
      if (!matchesDay) return false;
    }

    return true;
  }

  /// Check if a parish has any schedule entries matching the current filters
  bool _matchesTimeFilters(Parish parish) {
    if (!_hasActiveFilters()) return true;

    final entries = _filterableEntries(parish);
    if (entries.isEmpty) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return entries.any((e) => _entryMatchesFilters(parish, e, now, today));
  }

  /// The entries matching the active filters, soonest occurrence first — what
  /// the card's times sample shows so it agrees with the filter.
  List<ScheduleEntry> _entriesMatchingFilters(Parish parish) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final countInProgress = _countInProgressFor(parish);
    return _filterableEntries(parish)
        .where((e) => _entryMatchesFilters(parish, e, now, today))
        .toList()
      ..sort((a, b) => a
          .nextOccurrence(now, countInProgress)
          .compareTo(b.nextOccurrence(now, countInProgress)));
  }

  void _showFilterSheet() {
    final isDark = themeNotifier.isDarkMode;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      // The chip sections can outgrow the default half-screen sheet (small
      // phones, large text scale) and the sheet does not scroll on its own —
      // without this the lower filters are clipped and unreachable.
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.filter_list, color: widget.accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Filter by Time',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    if (_hasActiveFilters())
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _dayFilter = DayFilter.any;
                            _timeOfDayFilter = TimeOfDayFilter.any;
                            _languageFilter = LanguageFilter.any;
                            _selectedWeekdays = {};
                          });
                          setState(() {});
                        },
                        child: Text(
                          'Clear',
                          style: GoogleFonts.inter(color: widget.accentColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Everything between the header and Done scrolls, so no
                // filter section can be clipped out of reach.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                    // Day filter
                    Text(
                      'When',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subtextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Any day', _dayFilter == DayFilter.any, () {
                          setSheetState(() => _dayFilter = DayFilter.any);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                        _buildFilterChip('Today', _dayFilter == DayFilter.today, () {
                          setSheetState(() => _dayFilter = DayFilter.today);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                        _buildFilterChip('Tomorrow', _dayFilter == DayFilter.tomorrow, () {
                          setSheetState(() => _dayFilter = DayFilter.tomorrow);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                        _buildFilterChip('This week', _dayFilter == DayFilter.thisWeek, () {
                          setSheetState(() => _dayFilter = DayFilter.thisWeek);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Time of day filter
                    Text(
                      'Time of day',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subtextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Any time', _timeOfDayFilter == TimeOfDayFilter.any, () {
                          setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.any);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                        _buildFilterChip('Morning', _timeOfDayFilter == TimeOfDayFilter.morning, () {
                          setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.morning);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                        _buildFilterChip('Afternoon', _timeOfDayFilter == TimeOfDayFilter.afternoon, () {
                          setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.afternoon);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                        _buildFilterChip('Evening', _timeOfDayFilter == TimeOfDayFilter.evening, () {
                          setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.evening);
                          setState(() {});
                        }, cardColor, textColor, subtextColor),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Language filter (Mass only)
                    if (_languageFilterApplies) ...[
                      Text(
                        'Language',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subtextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip('Any', _languageFilter == LanguageFilter.any, () {
                            setSheetState(() => _languageFilter = LanguageFilter.any);
                            setState(() {});
                          }, cardColor, textColor, subtextColor),
                          _buildFilterChip('Spanish', _languageFilter == LanguageFilter.spanish, () {
                            setSheetState(() => _languageFilter = LanguageFilter.spanish);
                            setState(() {});
                          }, cardColor, textColor, subtextColor),
                          _buildFilterChip('Other language', _languageFilter == LanguageFilter.other, () {
                            setSheetState(() => _languageFilter = LanguageFilter.other);
                            setState(() {});
                          }, cardColor, textColor, subtextColor),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Weekday filter
                    Text(
                      'Day of week',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subtextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final day in [
                          (7, 'Sun'),
                          (1, 'Mon'),
                          (2, 'Tue'),
                          (3, 'Wed'),
                          (4, 'Thu'),
                          (5, 'Fri'),
                          (6, 'Sat'),
                        ])
                          _buildFilterChip(
                            day.$2,
                            _selectedWeekdays.contains(day.$1),
                            () {
                              setSheetState(() {
                                if (_selectedWeekdays.contains(day.$1)) {
                                  _selectedWeekdays.remove(day.$1);
                                } else {
                                  _selectedWeekdays.add(day.$1);
                                }
                              });
                              setState(() {});
                            },
                            cardColor,
                            textColor,
                            subtextColor,
                          ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Done button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: onAccentFor(widget.accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? widget.accentColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? widget.accentColor : subtextColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? onAccentFor(widget.accentColor) : textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: widget.accentColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: widget.accentColor),
            )
          : _filteredParishes.isEmpty
              ? _buildEmptyState()
              : _buildParishList(),
    );
  }

  Widget _buildEmptyState() {
    final isDark = themeNotifier.isDarkMode;
    final subtextColor = isDark ? Colors.white70 : Colors.grey[600];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDark ? Colors.white38 : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No parishes found',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParishList() {
    final canSortByDistance = widget.userLocation != null;
    final isDark = themeNotifier.isDarkMode;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    // Apply time filters first
    final timeFilteredParishes = _hasActiveFilters()
        ? _filteredParishes.where((p) => _matchesTimeFilters(p)).toList()
        : _filteredParishes;

    // Then filter by 2-day limit when in "Soonest" mode (unless showing all)
    final displayedParishes = (_sortOrder == SortOrder.nearestAndSoonest && !_showAllParishes && !_hasActiveFilters())
        ? timeFilteredParishes.where((p) {
            final minutes = _minutesUntilNext[FavoritesManager.keyFor(p)];
            return minutes != null && minutes <= _twoDaysInMinutes;
          }).toList()
        : timeFilteredParishes;

    final hiddenCount = timeFilteredParishes.length - displayedParishes.length;

    return Column(
      children: [
        // Results count and sort toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayedParishes.length == 1
                      ? '1 parish'
                      : '${displayedParishes.length} parishes',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
              const Spacer(),
              // Filter button. Soonest already answers "what is on next", so
              // the day/time filter has nothing left to narrow there — and a
              // filter left over from another sort would silently reshape the
              // list with no control on screen to say so, which is why
              // switching to Soonest clears it below.
              if (_sortOrder != SortOrder.nearestAndSoonest)
                GestureDetector(
                  onTap: _showFilterSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters()
                          ? widget.accentColor.withValues(alpha: 0.1)
                          : (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: _hasActiveFilters()
                          ? Border.all(color: widget.accentColor.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 14,
                          color: _hasActiveFilters() ? widget.accentColor : subtextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filter',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _hasActiveFilters() ? widget.accentColor : subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Sort selector — M3 segmented button replaces the older cycling toggle
        if (canSortByDistance)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<SortOrder>(
                // Three segments across a phone give each about a third of the
                // width, which at large text sizes is narrower than the word
                // inside it — "Soonest" wrapped to "Soone / st". Stacked, each
                // segment gets the full width instead.
                direction: context.prefersStackedLayout
                    ? Axis.vertical
                    : Axis.horizontal,
                segments: const [
                  ButtonSegment(
                    value: SortOrder.nearestAndSoonest,
                    label: Text('Soonest'),
                    icon: Icon(Icons.schedule, size: 16),
                  ),
                  ButtonSegment(
                    value: SortOrder.distance,
                    label: Text('Nearest'),
                    icon: Icon(Icons.near_me, size: 16),
                  ),
                  ButtonSegment(
                    value: SortOrder.alphabetical,
                    label: Text('A–Z'),
                    icon: Icon(Icons.sort_by_alpha, size: 16),
                  ),
                ],
                selected: {_sortOrder},
                onSelectionChanged: (selection) {
                  setState(() {
                    _sortOrder = selection.first;
                    _showAllParishes = false;
                    if (_sortOrder == SortOrder.nearestAndSoonest) {
                      _dayFilter = DayFilter.any;
                      _timeOfDayFilter = TimeOfDayFilter.any;
                      _languageFilter = LanguageFilter.any;
                      _selectedWeekdays = {};
                    }
                    _applySorting();
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: widget.accentColor.withValues(alpha: 0.15),
                  selectedForegroundColor: widget.accentColor,
                  foregroundColor: subtextColor,
                  textStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                showSelectedIcon: false,
              ),
            ),
          ),
        // Parish list
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: displayedParishes.length + (hiddenCount > 0 ? 1 : 0),
            itemBuilder: (context, index) {
              // Show "Show more" button at the end
              if (index == displayedParishes.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllParishes = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: cardBorderFor(isDark: isDark),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.expand_more,
                            color: widget.accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hiddenCount == 1
                                ? 'Show 1 more parish'
                                : 'Show $hiddenCount more parishes',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final parish = displayedParishes[index];
              final parishKey = FavoritesManager.keyFor(parish);
              final distance = _distances[parishKey];
              final minutesUntil = _minutesUntilNext[parishKey];
              return Padding(
                padding: EdgeInsets.only(bottom: index < displayedParishes.length - 1 ? 12 : 0),
                child: _ParishCard(
                  parish: parish,
                  filter: widget.filter,
                  accentColor: widget.accentColor,
                  distance: distance,
                  minutesUntilNext: minutesUntil,
                  showDistance: _sortOrder == SortOrder.distance && distance != null,
                  // Perpetual chapels are ranked at zero minutes above, which
                  // _formatTimeUntil renders as "Happening now" — exactly right
                  // for something open around the clock.
                  showTimeUntil: _sortOrder == SortOrder.nearestAndSoonest &&
                      minutesUntil != null,
                  preferUpcoming: _sortOrder == SortOrder.nearestAndSoonest &&
                      !_hasActiveFilters(),
                  filteredTimes: _hasActiveFilters()
                      ? _entriesMatchingFilters(parish)
                      : null,
                  cardColor: cardColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParishDetailPage(parish: parish, focus: widget.filter),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ParishCard extends StatelessWidget {
  final Parish parish;
  final ParishFilter filter;
  final Color accentColor;
  final double? distance;
  final int? minutesUntilNext;
  final bool showDistance;
  final bool showTimeUntil;

  /// In Soonest mode the times sample shows the next upcoming day's schedule —
  /// what's left today, else tomorrow's, etc. — so it always agrees with the
  /// "Tomorrow morning" badge. Off whenever day/time filters are active, and in
  /// both A-Z and Nearest, which show the full day-grouped weekly schedule
  /// instead: neither sorts by time, so a card claiming to be about "next"
  /// would be answering a question its own ordering never asked.
  final bool preferUpcoming;

  /// When day/time filters are active, the entries that match them (soonest
  /// first) — shown instead of the weekly sample so the card reflects what
  /// was asked for. Null when no filters are active.
  final List<ScheduleEntry>? filteredTimes;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final VoidCallback onTap;

  const _ParishCard({
    required this.parish,
    required this.filter,
    required this.accentColor,
    required this.onTap,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    this.distance,
    this.minutesUntilNext,
    this.showDistance = false,
    this.showTimeUntil = false,
    this.preferUpcoming = false,
    this.filteredTimes,
  });

  /// The trailing pill: distance in Nearest, time-until in Soonest, neither in
  /// A–Z (where the row gets a chevron instead).
  Widget? _badge(Color accentColor) {
    final String label;
    if (showDistance && distance != null) {
      label = '${distance!.toStringAsFixed(1)} mi';
    } else if (showTimeUntil && minutesUntilNext != null) {
      label = _formatTimeUntil(minutesUntilNext!);
    } else {
      return null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge(accentColor);
    final stacked = context.prefersStackedLayout;

    return LayoutBuilder(builder: (context, constraints) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: cardBorderFor(isDark: themeNotifier.isDarkMode),
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
              // Header row.
              //
              // The trailing badge ("2.4 mi", "Tomorrow morning") used to be an
              // unconstrained sibling of the name, so it took whatever width it
              // wanted and left the name — inside an Expanded — with the
              // remainder. At large text sizes that remainder was a couple of
              // characters, and a parish name rendered one letter per line. Now
              // the badge is capped, and past [prefersStackedLayout] it moves
              // under the name entirely rather than competing with it.
              Row(
                children: [
                  ParishGlassHero(
                    seed: parish.parishId ?? parish.name,
                    patron: parish.name,
                    borderRadius: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: StainedGlassHeader(
                          seed: parish.parishId ?? parish.name,
                          patron: parish.name,
                          overlayDarken: 0.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parish.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${parish.city} ${parish.zipCode}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),
                        if (badge != null && stacked) ...[
                          const SizedBox(height: 6),
                          Align(alignment: Alignment.centerLeft, child: badge),
                        ],
                      ],
                    ),
                  ),
                  if (badge != null && !stacked)
                    // A third of the row at most: enough for "Tomorrow morning"
                    // to wrap onto two lines, never enough to starve the name.
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth / 3),
                      child: badge,
                    )
                  else if (badge == null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: subtextColor,
                    ),
                ],
              ),
              // Times section based on filter
              if (_getTimesToShow().isNotEmpty ||
                  (filter == ParishFilter.adoration && parish.adorationIsPerpetual)) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: subtextColor.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                _buildTimesSection(),
              ],
            ],
          ),
        ),
      );
    });
  }

  List<ScheduleEntry> _getTimesToShow() {
    switch (filter) {
      case ParishFilter.massTimes:
        return parish.massTimes;
      case ParishFilter.confession:
        return parish.confTimes;
      case ParishFilter.adoration:
        return parish.adoration;
      case ParishFilter.all:
        return parish.massTimes.isNotEmpty ? parish.massTimes : parish.confTimes;
    }
  }

  /// Whether an in-progress window counts as upcoming — mirrors the page's
  /// `_countInProgressFor` so the sample agrees with the "in Xh" chip.
  bool get _countInProgress {
    switch (filter) {
      case ParishFilter.massTimes:
        return kCountMassInProgress;
      case ParishFilter.confession:
      case ParishFilter.adoration:
        return true;
      case ParishFilter.all:
        return parish.massTimes.isEmpty;
    }
  }

  /// The next day with something upcoming: the soonest occurrence plus every
  /// other entry falling on that same date, sorted by occurrence, with a label
  /// ("Today" / "Tomorrow" / weekday). Null when nothing is upcoming.
  ({List<ScheduleEntry> entries, String label})? _nextUpcomingDay(
      List<ScheduleEntry> times) {
    final now = DateTime.now();
    final soonest =
        ScheduleParser.findNextOccurrence(times, now, _countInProgress);
    if (soonest == null) return null;
    final target = soonest.nextOccurrence(now, _countInProgress);
    final entries = times.where((e) {
      if (e.isPast(now, _countInProgress)) return false;
      final o = e.nextOccurrence(now, _countInProgress);
      return o.year == target.year &&
          o.month == target.month &&
          o.day == target.day;
    }).toList()
      ..sort((a, b) => a
          .nextOccurrence(now, _countInProgress)
          .compareTo(b.nextOccurrence(now, _countInProgress)));
    final today = DateTime(now.year, now.month, now.day);
    final daysUntil =
        DateTime(target.year, target.month, target.day).difference(today).inDays;
    final label = daysUntil == 0
        ? 'Today'
        : daysUntil == 1
            ? 'Tomorrow'
            : soonest.dayName;
    return (entries: entries, label: label);
  }

  /// Time text for entry [i] of a day group, dropping its meridiem when the
  /// following time shares it ("7:30 · 9:00 · 11:00 AM").
  String _groupedTime(List<ScheduleEntry> entries, int i) {
    final e = entries[i];
    final label = e.timeLabel;
    if (e.hasRange) return label;
    if (i + 1 < entries.length) {
      final n = entries[i + 1];
      if (!n.hasRange && (e.hour >= 12) == (n.hour >= 12)) {
        return label.replaceFirst(RegExp(r'\s?(AM|PM)$'), '');
      }
    }
    return label;
  }

  /// One chip per day-run: "Sun 7:30 · 9:00 · 11:00 AM".
  /// Matches the language badge's weight and size — both are the same kind of
  /// mark: a small qualifier on a time.
  TextStyle get _ordinalSpanStyle => GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: accentColor,
        letterSpacing: 0.5,
      );

  Widget _groupChip(ScheduleDayGroup group) {
    final base = GoogleFonts.inter(fontSize: 12, color: textColor);
    final spans = <TextSpan>[
      TextSpan(
        text: '${group.label} ',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: subtextColor,
        ),
      ),
    ];
    for (var i = 0; i < group.entries.length; i++) {
      final e = group.entries[i];
      if (i > 0) spans.add(TextSpan(text: ' · ', style: base));
      spans.add(TextSpan(text: _groupedTime(group.entries, i), style: base));
      // These chips are the *standing weekly schedule* with no note beside
      // them, so a monthly slot would otherwise read as happening every week.
      // A day group can mix rules (groupByDay only keeps whole days apart), so
      // the marker rides on the time, not the day label.
      final ordinal = e.ordinalShortLabel;
      if (ordinal != null) {
        spans.add(TextSpan(text: ' $ordinal', style: _ordinalSpanStyle));
      }
      final badge =
          filter == ParishFilter.adoration ? null : e.languageBadge;
      if (badge != null) {
        spans.add(TextSpan(
          text: ' $badge',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: accentColor,
            letterSpacing: 0.5,
          ),
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: subtextColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  Widget _buildTimesSection() {
    var times = _getTimesToShow();
    String? dayLabel;
    var showingFiltered = false;
    if (filteredTimes != null && filteredTimes!.isNotEmpty) {
      times = filteredTimes!;
      showingFiltered = true;
    } else if (preferUpcoming) {
      final upcoming = _nextUpcomingDay(times);
      if (upcoming != null && upcoming.entries.isNotEmpty) {
        times = upcoming.entries;
        dayLabel = upcoming.label;
      }
    }

    IconData icon;
    switch (filter) {
      case ParishFilter.confession:
        icon = Icons.favorite_outline;
        break;
      case ParishFilter.adoration:
        icon = Icons.brightness_5;
        break;
      default:
        icon = Icons.access_time;
    }

    // The page header already names the schedule, so the per-card row carries
    // only qualifiers. Null hides the row entirely (A-Z, where the grouped
    // chips carry their own days).
    String? label;
    if (showingFiltered) {
      label = 'Filtered';
    } else if (dayLabel != null) {
      // Only Soonest reaches here, and it carries the "Tomorrow morning" badge
      // already, so [showTimeUntil] is the normal path; the [dayLabel] fallback
      // covers a card whose minutes-until never resolved. [times] is the
      // upcoming day's entries, so it answers the only question the label
      // needs: is there one Mass that day, or several?
      final single = times.length == 1;
      label = showTimeUntil
          ? switch (filter) {
              ParishFilter.confession => 'Next Confession',
              ParishFilter.adoration => 'Next Adoration',
              _ => single ? 'Next Mass' : 'Next Masses',
            }
          : dayLabel;
    }

    // Perpetual adoration: show a single descriptive chip instead of times.
    final isPerpetual =
        filter == ParishFilter.adoration && parish.adorationIsPerpetual;

    // Day-focused and filtered samples: up to 3 per-entry chips. The A-Z and
    // Nearest views instead show the whole schedule as day-grouped chips.
    final grouped = !showingFiltered && dayLabel == null;
    final displayTimes =
        grouped ? const <ScheduleEntry>[] : times.take(3).toList();
    final hasMore = !grouped && times.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (isPerpetual)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Perpetual (24/7)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            if (grouped)
              ...ScheduleParser.groupByDay(times).map(_groupChip)
            else ...[
              ...displayTimes.map((time) {
                final badge = filter == ParishFilter.adoration
                    ? null
                    : time.languageBadge;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: subtextColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayLabel != null ? time.timeLabel : time.display,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                      if (time.ordinalShortLabel != null) ...[
                        const SizedBox(width: 4),
                        Text(time.ordinalShortLabel!,
                            style: _ordinalSpanStyle),
                      ],
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        LanguageBadge(label: badge, color: accentColor),
                      ],
                    ],
                  ),
                );
              }),
              if (hasMore)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${times.length - 3} more',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }

  /// Returns a human-friendly time descriptor
  String _formatTimeUntil(int minutes) {
    final now = DateTime.now();
    final eventTime = now.add(Duration(minutes: minutes));

    // Check if event is today, tomorrow, or day after
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventTime.year, eventTime.month, eventTime.day);
    final daysUntil = eventDay.difference(today).inDays;

    // Get time of day descriptor
    final hour = eventTime.hour;
    String timeOfDay;
    if (hour >= 5 && hour < 12) {
      timeOfDay = 'morning';
    } else if (hour >= 12 && hour < 17) {
      timeOfDay = 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      timeOfDay = 'evening';
    } else {
      timeOfDay = 'tonight';
    }

    if (minutes <= 0) {
      // Negative means a ranged entry (adoration/confession) is underway.
      return 'Happening now';
    } else if (minutes <= 30) {
      return 'Starting soon';
    } else if (minutes <= 60) {
      return 'Within the hour';
    } else if (daysUntil == 0) {
      // Today - handle "tonight" specially (not "This tonight")
      if (timeOfDay == 'tonight') {
        return 'Tonight';
      }
      return 'This $timeOfDay';
    } else if (daysUntil == 1) {
      // Tomorrow with time of day
      if (hour >= 5 && hour < 12) {
        return 'Tomorrow morning';
      } else if (hour >= 12 && hour < 17) {
        return 'Tomorrow afternoon';
      } else if (hour >= 17 && hour < 21) {
        return 'Tomorrow evening';
      } else {
        return 'Tomorrow night';
      }
    } else if (daysUntil == 2) {
      return 'In 2 days';
    } else {
      return 'In $daysUntil days';
    }
  }
}
