import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/parish.dart';
import 'services/location_service.dart';
import 'services/parish_service.dart';
import 'pages/parish_detail_page.dart';
import 'pages/find_parish_near_me_page.dart';
import 'pages/filtered_parish_list_page.dart';
import 'widgets/custom_icons.dart';
import 'widgets/today_hero_card.dart';
import 'widgets/next_mass_tile.dart';
import 'widgets/stained_glass_header.dart';
import 'widgets/liturgical_day_tile.dart';
import 'widgets/zip_location_dialog.dart';
import 'theme/app_text.dart';
import 'utils/schedule_parser.dart';
import 'utils/search_normalize.dart';
import 'utils/app_version.dart';
import 'services/feedback_client.dart';
import 'services/diocese_boundary.dart';

// kDevLocation now lives in services/location_service.dart, alongside the
// logic that honours it.

// Fallback only. Coverage is decided by the diocese outline in
// [dioceseBoundary]; this radius is what we fall back to if that asset can't
// be read. It was the original rule, and it was wrong in both directions —
// Kent is five miles from our Stow parishes but belongs to Youngstown, while
// rural Ashland County is genuinely 25 miles from anything we list.
const double kSupportedRadiusMiles = 60;

// One-time first-launch data-accuracy disclaimer. Versioned so we can re-show it
// if the wording materially changes (bump the suffix).
const String kDisclaimerSeenKey = 'disclaimer_seen_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inter and Cormorant Garamond ship in assets/google_fonts/, so never reach
  // out to fonts.gstatic.com. That keeps the user's IP away from Google, and
  // means a first launch with no network renders in the real typefaces instead
  // of falling back to a system font.
  GoogleFonts.config.allowRuntimeFetching = false;

  // The OFL requires the licence text to travel with the fonts. Registering it
  // here surfaces it in the "Open source licenses" page on the About screen.
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Inter', 'CormorantGaramond']) {
      final license =
          await rootBundle.loadString('assets/google_fonts/OFL-$family.txt');
      yield LicenseEntryWithLineBreaks(['google_fonts'], license);
    }
  });

  await themeNotifier.init();
  await favoritesManager.init();
  await AppVersion.load();
  // 2.4 KB off the bundle — parsed here so the coverage check is a synchronous
  // answer by the time the first location fix lands.
  await dioceseBoundary.load();
  runApp(const ParishFinderApp());
}

// Palette: warm parchment + oxblood + gold (light); true black + candlelight (dark)
const Color kBackgroundColor = Color(0xFFFAF6EE); // warm cream parchment
const Color kBackgroundColorDark = Color(0xFF000000); // true black for OLED
const Color kPrimaryColor = Color(0xFF8C1F1F); // deep oxblood — dominant light accent
const Color kSecondaryColor = Color(0xFF4A2828); // deep plum — secondary / headings
const Color kAccentGold = Color(0xFFC9A227); // rich gold — ornament/icons only (fails AA as text on cream)
const Color kAccentGoldDeep = Color(0xFF8C5A14); // deep bronze-gold — text-safe on cream (~5.2:1 on parchment)
const Color kAccentCandlelight = Color(0xFFD4A24A); // candlelight gold — dominant dark accent
const Color kCardColor = Color(0xFFFFFCF4); // warm card surface (very subtle warm white)
const Color kCardColorDark = Color(0xFF14100F); // warm-toned near-black card
const Color kTextLight = Color(0xFF2A1B1B); // warm near-black text
const Color kTextDark = Color(0xFFF4E9D8); // warm cream text on dark

/// In dark mode, the dominant accent shifts to candlelight gold so red doesn't
/// glow uncomfortably on true black. Use this helper anywhere the "primary"
/// accent should adapt to theme.
Color primaryAccentFor({required bool isDark}) =>
    isDark ? kAccentCandlelight : kPrimaryColor;

/// Text-safe gold accent. On cream backgrounds the bright `kAccentGold` falls
/// to ~2.5:1 contrast, failing WCAG AA. Use this helper anywhere gold is used
/// as a foreground color (label text, accent rules, kicker labels).
Color goldTextAccentFor({required bool isDark}) =>
    isDark ? kAccentCandlelight : kAccentGoldDeep;

// Theme notifier for app-wide theme management
class ThemeNotifier extends ChangeNotifier {
  static const String _prefsKey = 'dark_mode';

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  /// Restore the saved choice. Called from `main()` before `runApp`, so the
  /// first frame is already in the right theme and there's no light flash.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefsKey);
    if (saved == null || saved == _isDarkMode) return;
    _isDarkMode = saved;
    notifyListeners();
  }

  void toggleTheme() => setDarkMode(!_isDarkMode);

  void setDarkMode(bool value) {
    if (value == _isDarkMode) return;
    _isDarkMode = value;
    notifyListeners();
    _persist(value);
  }

  /// Fire-and-forget: the toggle shouldn't wait on disk, and a failed write
  /// costs the preference, not the session.
  Future<void> _persist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

// Global theme notifier instance
final themeNotifier = ThemeNotifier();

// Favorites manager for storing favorite ("home") parishes with persistence.
//
// Entries are keyed per *parish*, not per name — several parishes in the
// diocese share a name (there are two "Saint Francis de Sales", three "Saint
// Mary", …) and keying by name favorited all of them at once. The
// SharedPreferences key stays `favorite_parishes` so existing saves survive;
// legacy bare-name entries are upgraded by [migrateLegacyKeys] once parish
// data is available.
class FavoritesManager extends ChangeNotifier {
  static const String _prefsKey = 'favorite_parishes';
  final Set<String> _favoriteKeys = {};
  bool _initialized = false;

  bool get initialized => _initialized;

  /// Stable identity for a parish: its `parish_id` when present, otherwise
  /// name + city + address (a handful of records ship without an id).
  static String keyFor(Parish parish) {
    final id = parish.parishId?.trim();
    if (id != null && id.isNotEmpty) return 'id:$id';
    return 'np:${parish.name}|${parish.city}|${parish.address}';
  }

  static bool _isLegacyName(String entry) =>
      !entry.startsWith('id:') && !entry.startsWith('np:');

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final savedFavorites = prefs.getStringList(_prefsKey) ?? [];
    _favoriteKeys.addAll(savedFavorites);
    _initialized = true;
    notifyListeners();
  }

  /// Rewrite pre-keying saves (bare parish names) into stable keys. A name
  /// shared by several parishes resolves to the first match in the data — the
  /// old save simply doesn't say which one was meant. No-op once migrated.
  void migrateLegacyKeys(List<Parish> parishes) {
    if (parishes.isEmpty) return;
    final legacy = _favoriteKeys.where(_isLegacyName).toList();
    if (legacy.isEmpty) return;

    for (final name in legacy) {
      _favoriteKeys.remove(name);
      final match = parishes.where((p) => p.name == name);
      if (match.isNotEmpty) _favoriteKeys.add(keyFor(match.first));
    }
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _favoriteKeys.toList());
  }

  bool isFavorite(Parish parish) => _favoriteKeys.contains(keyFor(parish));

  void toggleFavorite(Parish parish) {
    final key = keyFor(parish);
    if (_favoriteKeys.contains(key)) {
      _favoriteKeys.remove(key);
    } else {
      _favoriteKeys.add(key);
    }
    _save();
    notifyListeners();
  }

  void addFavorite(Parish parish) {
    _favoriteKeys.add(keyFor(parish));
    _save();
    notifyListeners();
  }

  void removeFavorite(Parish parish) {
    _favoriteKeys.remove(keyFor(parish));
    _save();
    notifyListeners();
  }

  Set<String> get favorites => Set.unmodifiable(_favoriteKeys);
  int get count => _favoriteKeys.length;
}

// Global favorites manager instance
final favoritesManager = FavoritesManager();

class ParishFinderApp extends StatefulWidget {
  const ParishFinderApp({super.key});

  @override
  State<ParishFinderApp> createState() => _ParishFinderAppState();
}

class _ParishFinderAppState extends State<ParishFinderApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDark ? kBackgroundColorDark : kBackgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? kBackgroundColorDark : kBackgroundColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'ParishFinder',
      theme: ThemeData.light().copyWith(
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        cardColor: kCardColor,
        colorScheme: const ColorScheme.light(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
          tertiary: kAccentGold,
          surface: kCardColor,
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: kBackgroundColorDark,
        primaryColor: kAccentCandlelight,
        colorScheme: const ColorScheme.dark(
          primary: kAccentCandlelight,
          secondary: kPrimaryColor,
          tertiary: kAccentGold,
          surface: kCardColorDark,
        ),
        cardColor: kCardColorDark,
        splashFactory: InkRipple.splashFactory,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const RootShell(),
    );
  }
}

/// Top-level shell hosting the three primary destinations as tabs.
/// Pre-audit, Map and Favorites lived behind a "View All" link and a
/// hidden popup menu respectively. Persistent navigation surfaces them.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onChanged);
    // Show the one-time data-accuracy disclaimer after the first frame so a
    // dialog context (Overlay/Navigator) is available.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowFirstRunDisclaimer());
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _go(int i) {
    if (mounted) setState(() => _index = i);
  }

  /// [IndexedStack] keeps every tab alive, so all three sit in the tree at once
  /// and the same parish can own a [Hero] on more than one of them — Home's
  /// nearby row and the Map tab's carousel both render its glass chip with the
  /// same tag. Two heroes sharing a tag on one route means a flight can start
  /// from the offstage one: the carousel card, parked at the bottom of the
  /// screen at an x-offset set by its page index, which is why a chip appeared
  /// to fly in from the bottom corner. [HeroMode] keeps only the visible tab's
  /// heroes in play.
  ///
  /// Debug builds assert on the duplicate tag; release builds strip the assert
  /// and silently pick one, so this only showed up on an installed APK.
  static const List<Widget> _tabs = [
    HomePage(),
    FindParishNearMePage(inTab: true),
    FavoritesPage(inTab: true),
  ];

  Future<void> _maybeShowFirstRunDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kDisclaimerSeenKey) ?? false) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstRunDisclaimerDialog(),
    );
    // Only mark as seen once acknowledged, so an early kill re-shows it.
    await prefs.setBool(kDisclaimerSeenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final accent = primaryAccentFor(isDark: isDark);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            HeroMode(enabled: i == _index, child: _tabs[i]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        backgroundColor: isDark ? kCardColorDark : kCardColor,
        indicatorColor: accent.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'My Parishes',
          ),
        ],
      ),
    );
  }
}

/// One-time, first-launch modal reminding users that schedule data may be
/// inaccurate and that the parish bulletin / parish office is the final say.
/// Shown once (gated by [kDisclaimerSeenKey]); not location-dependent.
class FirstRunDisclaimerDialog extends StatelessWidget {
  const FirstRunDisclaimerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final accent = primaryAccentFor(isDark: isDark);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1512);
    final subtext = isDark ? Colors.white70 : const Color(0xFF6B5D54);
    return AlertDialog(
      backgroundColor: isDark ? kCardColorDark : kCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You should know',
              style: AppText.titleLarge(color: textColor),
            ),
          ),
        ],
      ),
      content: Text(
        'ParishFinder gathers its information through automated processes, and '
        'could occasionally be wrong.\n\n'
        'You are encouraged to double check with the parish bulletin or parish '
        'offices before making plans.',
        style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: subtext),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'I understand',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Parish> _parishes = [];
  List<Parish> _searchResults = [];
  List<Parish> _nearbyParishes = [];
  bool _isLoading = true;
  bool _showResults = false;
  Timer? _debounce;
  LatLng? _userLocation;
  LocationFix? _locationFix;
  LocationFailure? _locationFailure;
  bool _locationLoading = true;
  // True when the user's nearest parish is beyond kSupportedRadiusMiles — i.e.
  // they're outside the supported diocese. Drives the coverage notice banner.
  bool _outsideCoverage = false;
  bool _coverageNoticeDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadParishData();
    _getUserLocation();
    _searchFocusNode.addListener(_onFocusChange);
    themeNotifier.addListener(_onThemeChanged);
    favoritesManager.addListener(_onThemeChanged);
    locationService.addListener(_onSharedLocation);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _debounce?.cancel();
    themeNotifier.removeListener(_onThemeChanged);
    favoritesManager.removeListener(_onThemeChanged);
    locationService.removeListener(_onSharedLocation);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-fetch location when the app returns to the foreground so "nearby"
    // reflects where the user actually is now (and picks up a permission grant
    // made in Settings while we were backgrounded). Silent — no spinner flash.
    if (state == AppLifecycleState.resumed) {
      _getUserLocation();
    }
  }

  List<Parish> get _favoriteParishes =>
      _parishes.where((p) => favoritesManager.isFavorite(p)).toList();

  void _onThemeChanged() {
    setState(() {});
  }

  void _onFocusChange() {
    if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() {
        _showResults = false;
      });
    }
  }

  Future<void> _loadParishData() async {
    try {
      final parishes = await parishService.getParishes();
      favoritesManager.migrateLegacyKeys(parishes);

      setState(() {
        _parishes = parishes;
        _isLoading = false;
      });

      // Check if internet is required (first run with no connection)
      if (parishService.requiresInternet && mounted) {
        return; // Will show the "requires internet" screen
      }

      _updateNearbyParishes();

      // The location lookup starts in parallel with this load and usually
      // finishes first — a denied permission returns instantly. If it fell
      // back to a stored ZIP it had no parishes to resolve against yet, so
      // give it the data now.
      if (_userLocation == null) {
        await _applyManualFallbackIfAny();
      }

      // Show warning if using cached/offline data
      if (parishService.isUsingCachedData && mounted) {
        _showOfflineWarning();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading parish data: $e');
    }
  }

  Future<void> _retryLoadData() async {
    setState(() {
      _isLoading = true;
    });
    await parishService.refreshParishes();
    await _loadParishData();
  }

  void _showOfflineWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Offline mode - data may be out of date',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildRequiresInternetScreen() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Internet Connection Required',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'ParishFinder needs to download parish data on first launch. Please connect to the internet and try again.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: _subtextColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _retryLoadData,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _isLoading ? 'Connecting...' : 'Try Again',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Future<void> _getUserLocation() async {
    // A cached fix paints the nearby list immediately; the fresh one below
    // corrects it a moment later. Keeps the spinner off every resume.
    if (_userLocation == null) {
      final cached = await locationService.lastKnown();
      if (cached != null && mounted && _userLocation == null) {
        _applyFix(cached);
      }
    }

    final outcome = await locationService.current();
    if (!mounted) return;

    if (outcome.ok) {
      _applyFix(outcome.fix!);
      return;
    }

    // No device fix — fall back to a ZIP the user entered earlier, if any.
    final fallback = await locationService.manualFallback(_parishes);
    if (!mounted) return;
    if (fallback != null) {
      _applyFix(fallback);
      return;
    }

    setState(() {
      _locationFailure = outcome.failure;
      _locationLoading = false;
    });
  }

  /// Resolve a previously stored ZIP, once parish data is available.
  Future<void> _applyManualFallbackIfAny() async {
    final fallback = await locationService.manualFallback(_parishes);
    if (fallback == null || !mounted || _userLocation != null) return;
    _applyFix(fallback);
  }

  /// Adopt a fix another tab obtained — chiefly a ZIP typed on the map.
  void _onSharedLocation() {
    final fix = locationService.lastFix;
    if (fix == null || !mounted) return;
    if (_userLocation == fix.position && _locationFix?.source == fix.source) {
      return; // Our own fix coming back around.
    }
    _applyFix(fix);
  }

  void _applyFix(LocationFix fix) {
    setState(() {
      _userLocation = fix.position;
      _locationFix = fix;
      _locationFailure = null;
      _locationLoading = false;
    });
    _updateNearbyParishes();
  }

  Future<void> _promptForZip() async {
    final fix = await showZipLocationDialog(context, _parishes);
    if (fix == null || !mounted) return;
    _applyFix(fix);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for distance in miles
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

  void _updateNearbyParishes() {
    if (_userLocation == null || _parishes.isEmpty) return;

    final parishesWithDistance = _parishes
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => MapEntry(
              p,
              _calculateDistance(
                _userLocation!.latitude,
                _userLocation!.longitude,
                p.latitude!,
                p.longitude!,
              ),
            ))
        .toList();

    parishesWithDistance.sort((a, b) => a.value.compareTo(b.value));

    // Nearest parish distance tells us whether the user is in a supported area.
    final nearestMiles =
        parishesWithDistance.isEmpty ? double.infinity : parishesWithDistance.first.value;

    // County boundaries, not mileage: dioceses abut each other, so "how far is
    // the nearest parish" answers a different question than "whose diocese is
    // this". Falls back to the radius only if the outline failed to load.
    final insideDiocese = dioceseBoundary.contains(_userLocation!);

    setState(() {
      _nearbyParishes = parishesWithDistance.take(10).map((e) => e.key).toList();
      _outsideCoverage = insideDiocese == null
          ? nearestMiles > kSupportedRadiusMiles
          : !insideDiocese;
    });
  }

  /// Dismissible notice shown when the user's location falls outside the
  /// supported diocese (nearest parish beyond [kSupportedRadiusMiles]).
  /// Collapses to nothing when in-coverage, location-unknown, or dismissed.
  Widget _buildCoverageBanner() {
    if (_userLocation == null ||
        !_outsideCoverage ||
        _coverageNoticeDismissed) {
      return const SizedBox.shrink();
    }
    final accent = goldTextAccentFor(isDark: _isDark);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_off_outlined, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your diocese is not yet supported',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ParishFinder currently covers the Diocese of Cleveland '
                  '(NE Ohio). Parishes shown are located there, and may be '
                  'quite far from you.',
                  style: GoogleFonts.inter(fontSize: 13, color: _subtextColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: _subtextColor),
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _coverageNoticeDismissed = true),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _updateSearchResults(query);
    });
  }

  void _updateSearchResults(String query) {
    final normalizedQuery = normalizeForSearch(query);

    setState(() {
      _showResults = query.isNotEmpty;
      if (query.isEmpty) {
        _searchResults.clear();
      } else {
        _searchResults = _parishes.where((parish) {
          return normalizeForSearch(parish.name).contains(normalizedQuery) ||
              normalizeForSearch(parish.city).contains(normalizedQuery) ||
              parish.zipCode.contains(query);
        }).take(5).toList(); // Limit to 5 results for autocomplete
      }
    });
  }

  void _selectParish(Parish parish) {
    _searchController.clear();
    setState(() {
      _showResults = false;
      _searchResults.clear();
    });
    _searchFocusNode.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParishDetailPage(parish: parish),
      ),
    );
  }

  // Theme-aware color getters
  bool get _isDark => themeNotifier.isDarkMode;
  Color get _backgroundColor => _isDark ? kBackgroundColorDark : kBackgroundColor;
  Color get _cardColor => _isDark ? kCardColorDark : kCardColor;
  Color get _textColor => _isDark ? Colors.white : Colors.black87;
  Color get _subtextColor => _isDark ? Colors.white70 : Colors.black54;

  @override
  Widget build(BuildContext context) {
    // Show "requires internet" screen on first run with no connection
    if (parishService.requiresInternet && !_isLoading) {
      return _buildRequiresInternetScreen();
    }

    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
        setState(() {
          if (_searchController.text.isEmpty) {
            _showResults = false;
          }
        });
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ParishFinder',
                        style: AppText.titleHuge(color: primaryAccentFor(isDark: _isDark)),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'settings':
                              _showSettingsPage();
                              break;
                            case 'feedback':
                              _showFeedbackPage();
                              break;
                            case 'about':
                              _showAboutPage();
                              break;
                          }
                        },
                        offset: const Offset(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'settings',
                            child: Row(
                              children: [
                                const Icon(Icons.settings_outlined, color: kPrimaryColor, size: 20),
                                const SizedBox(width: 12),
                                Text('Settings', style: GoogleFonts.inter()),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'feedback',
                            child: Row(
                              children: [
                                const Icon(Icons.feedback_outlined, color: kPrimaryColor, size: 20),
                                const SizedBox(width: 12),
                                Text('Feedback', style: GoogleFonts.inter()),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'about',
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: kPrimaryColor, size: 20),
                                const SizedBox(width: 12),
                                Text('About', style: GoogleFonts.inter()),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: kPrimaryColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover the Life of the Church',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: _subtextColor,
                    ),
                  ),
                  // Location-triggered notice when the user is outside the
                  // supported diocese. Independent of the first-run disclaimer.
                  _buildCoverageBanner(),
                  const SizedBox(height: 24),

                  // Today hero card — day-aware suggestion
                  TodayHeroCard(
                    isDark: _isDark,
                    accentColor: primaryAccentFor(isDark: _isDark),
                    onSelect: (intent) {
                      final filter = parishFilterForIntent(intent);
                      final title = switch (intent) {
                        HeroIntent.mass => 'Mass Times',
                        HeroIntent.confession => 'Confession',
                        HeroIntent.adoration => 'Adoration',
                      };
                      final accent = switch (intent) {
                        HeroIntent.mass => primaryAccentFor(isDark: _isDark),
                        HeroIntent.confession => const Color(0xFF5E3370),
                        HeroIntent.adoration => goldTextAccentFor(isDark: _isDark),
                      };
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FilteredParishListPage(
                            filter: filter,
                            title: title,
                            accentColor: accent,
                            userLocation: _userLocation,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),

                  // Looking For Section
                  Text(
                    'Looking for',
                    style: AppText.titleLarge(color: _textColor),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickAccessButtons(),
                  const SizedBox(height: 30),

                  // Search Section
                  Text(
                    'Search Parishes',
                    style: AppText.titleLarge(color: _textColor),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar with Autocomplete
                  _buildSearchBar(),
                  const SizedBox(height: 30),

                  // Your Home Parishes — quick launcher for saved parishes, so
                  // returning users can jump straight into the parishes they
                  // care about. Hidden entirely when there are no favorites.
                  ..._buildHomeParishesSection(),

                  // Nearby Parishes Section
                  Text(
                    'Nearby Parishes',
                    style: AppText.titleLarge(color: _textColor),
                  ),
                  // Say so plainly when "nearby" means a typed ZIP rather
                  // than the device — the distances are to its centre, not
                  // to the user, and that difference is theirs to know.
                  if (_locationFix?.source == LocationSource.manualZip)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.pin_drop_outlined,
                              size: 14, color: _subtextColor),
                          const SizedBox(width: 4),
                          Text(
                            'Near ZIP ${_locationFix?.zip}',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _subtextColor),
                          ),
                          TextButton(
                            onPressed: () async {
                              await locationService.clearManualZip();
                              if (!mounted) return;
                              setState(() {
                                _locationFix = null;
                                _userLocation = null;
                                _locationLoading = true;
                              });
                              _getUserLocation();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Use my location',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Live "Next Mass" tiles (nearby + favorite). Expanded
                  // square tiles when any next Mass is within 60 min; otherwise
                  // compact full-width banners stacked vertically so the hero
                  // card above stays the single dominant surface.
                  ..._buildNextMassTiles(),

                  // Nearby Parishes Horizontal List
                  _buildNearbyParishesList(),
                  const SizedBox(height: 30),

                  // Today's Liturgy
                  LiturgicalDayTile(
                    cardColor: _cardColor,
                    textColor: _textColor,
                    subtextColor: _subtextColor,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: _textColor,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name, city, or ZIP code',
              hintStyle: GoogleFonts.inter(
                color: _subtextColor,
                fontSize: 16,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: kPrimaryColor,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: _subtextColor),
                      onPressed: () {
                        _searchController.clear();
                        _updateSearchResults('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
        // Autocomplete Results
        if (_showResults && _searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: _searchResults.asMap().entries.map((entry) {
                  final index = entry.key;
                  final parish = entry.value;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _selectParish(parish),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.church,
                                  color: kPrimaryColor,
                                  size: 20,
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
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${parish.city} ${parish.zipCode}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: _subtextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: _subtextColor.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index < _searchResults.length - 1)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: _subtextColor.withValues(alpha: 0.2),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        // No results message
        if (_showResults && _searchResults.isEmpty && _searchController.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_off,
                  color: _subtextColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No parishes found',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: _subtextColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuickAccessButtons() {
    return Row(
      children: [
        Expanded(
          child: Builder(builder: (context) {
            final massAccent = primaryAccentFor(isDark: _isDark);
            return _QuickAccessButton(
              icon: Icon(Icons.access_time, color: massAccent, size: 28),
              label: 'Mass Times',
              color: massAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FilteredParishListPage(
                      filter: ParishFilter.massTimes,
                      title: 'Mass Times',
                      accentColor: massAccent,
                      userLocation: _userLocation,
                    ),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessButton(
            icon: CustomIcon.confession(color: const Color(0xFF5E3370), size: 28),
            label: 'Confession',
            color: const Color(0xFF5E3370),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FilteredParishListPage(
                    filter: ParishFilter.confession,
                    title: 'Confession Times',
                    accentColor: const Color(0xFF5E3370),
                    userLocation: _userLocation,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Builder(builder: (context) {
            final goldAccent = goldTextAccentFor(isDark: _isDark);
            return _QuickAccessButton(
              icon: CustomIcon.monstrance(color: goldAccent, size: 28),
              label: 'Adoration',
              color: goldAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FilteredParishListPage(
                      filter: ParishFilter.adoration,
                      title: 'Adoration',
                      accentColor: goldAccent,
                      userLocation: _userLocation,
                    ),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessButton(
            icon: const Icon(Icons.event, color: kSecondaryColor, size: 28),
            label: 'Parish Events',
            color: kSecondaryColor,
            onTap: () {
              _showComingSoon(
                icon: Icons.event,
                title: 'Parish Events',
                message: 'Parish event listings are coming soon. Check back later for updates!',
                color: kSecondaryColor,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFeedbackPage() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Feedback',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const FeedbackPage();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }

  void _showSettingsPage() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SettingsPage();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }

  void _showAboutPage() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'About',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AboutPage();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }

  void _showComingSoon({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _subtextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _subtextColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got It',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Renders the live "Next Mass Nearby" tile. Returns a list of widgets so the
  /// parent can splat them into its Column with the existing spacing. Home
  /// parishes now have their own quick-launcher section (see
  /// [_buildHomeParishesSection]), so this is nearby-only.
  List<Widget> _buildNextMassTiles() {
    if (_nearbyParishes.isEmpty) return const [];

    final nearbyMin = NextMassTile.findSoonestMinutes(_nearbyParishes);
    final imminent = nearbyMin != null && nearbyMin <= 60;

    void open(Parish p) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ParishDetailPage(parish: p)),
        );

    final nearbyTile = NextMassTile(
      parishes: _nearbyParishes,
      label: imminent ? 'NEXT MASS\nNEARBY' : 'NEXT MASS NEARBY',
      accentColor: primaryAccentFor(isDark: _isDark),
      cardColor: _cardColor,
      textColor: _textColor,
      subtextColor: _subtextColor,
      compact: !imminent,
      announceNoMoreToday: true,
      onTap: open,
    );

    if (imminent) {
      // Imminent → prominent square, kept to the left half.
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: nearbyTile),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 16),
      ];
    }
    // Quieter compact banner when nothing's imminent.
    return [nearbyTile, const SizedBox(height: 16)];
  }

  /// Horizontal quick-launcher of every home (favorite) parish, so returning
  /// users can jump straight into the parishes they follow. Each card shows the
  /// parish and its next upcoming Mass. Empty when no favorites are saved.
  List<Widget> _buildHomeParishesSection() {
    final favorites = _favoriteParishes;
    if (favorites.isEmpty) return const [];

    return [
      Text(
        'Your Home Parishes',
        style: AppText.titleLarge(color: _textColor),
      ),
      const SizedBox(height: 16),
      SizedBox(
        // Tall enough for a 2-line parish name plus the avatar row and the
        // pinned "Next ·" line without overflowing the card (was 150 → 19px
        // overflow when the name wrapped to two lines).
        height: 176,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: favorites.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final parish = favorites[index];
            return _HomeParishCard(
              parish: parish,
              cardColor: _cardColor,
              textColor: _textColor,
              subtextColor: _subtextColor,
              accentColor: primaryAccentFor(isDark: _isDark),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParishDetailPage(parish: parish),
                  ),
                );
              },
            );
          },
        ),
      ),
      const SizedBox(height: 30),
    ];
  }

  Widget _buildNearbyParishesList() {
    if (_locationLoading || _isLoading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Finding nearby parishes...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _subtextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_userLocation == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                color: _subtextColor,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                _locationFailure == LocationFailure.serviceDisabled
                    ? 'Location services are off'
                    : 'Location unavailable',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _subtextColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _locationLoading = true;
                      });
                      _getUserLocation();
                    },
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.inter(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Works when nothing else will: no GPS, no permission, no
                  // fix. Resolved from our own parish data, entirely offline.
                  TextButton(
                    onPressed: _parishes.isEmpty ? null : _promptForZip,
                    child: Text(
                      'Use a ZIP code',
                      style: GoogleFonts.inter(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_nearbyParishes.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.church,
                color: _subtextColor,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'No parishes found nearby',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _subtextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _nearbyParishes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final parish = _nearbyParishes[index];
          final distance = _calculateDistance(
            _userLocation!.latitude,
            _userLocation!.longitude,
            parish.latitude!,
            parish.longitude!,
          );
          return _NearbyParishCard(
            parish: parish,
            distance: distance,
            cardColor: _cardColor,
            textColor: _textColor,
            subtextColor: _subtextColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ParishDetailPage(parish: parish),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuickAccessButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyParishCard extends StatelessWidget {
  final Parish parish;
  final double distance;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final VoidCallback onTap;

  const _NearbyParishCard({
    required this.parish,
    required this.distance,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
            Row(
              children: [
                ParishGlassHero(
                  seed: parish.parishId ?? parish.name,
                  patron: parish.name,
                  borderRadius: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: StainedGlassHeader(
                        seed: parish.parishId ?? parish.name,
                        patron: parish.name,
                        overlayDarken: 0.0,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(1)} mi',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              parish.name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              parish.city,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subtextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (parish.massTimes.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: subtextColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      parish.massTimes.first.display,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact card for a saved "home parish" on the Home tab's quick-launcher.
/// Shows the parish and its next upcoming Mass. Deliberately does NOT wrap the
/// stained-glass avatar in a [Hero] — a favorited parish can also appear in the
/// Nearby list on the same screen, and two Heroes sharing a tag on one route is
/// a runtime error.
class _HomeParishCard extends StatelessWidget {
  final Parish parish;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _HomeParishCard({
    required this.parish,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final next = ScheduleParser.findNextOccurrence(
        parish.massTimes, null, kCountMassInProgress);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
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
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: StainedGlassHeader(
                      seed: parish.parishId ?? parish.name,
                      overlayDarken: 0.0,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.star, color: Colors.amber, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              parish.name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              parish.city,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subtextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    next != null ? 'Next · ${next.display}' : 'Schedule unavailable',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _emailController.dispose();
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your feedback', style: GoogleFonts.inter()),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await submitFeedback(
      kind: 'general',
      body: _feedbackController.text.trim(),
      replyEmail: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback sent — thank you!', style: GoogleFonts.inter()),
          backgroundColor: Colors.green[600],
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not send feedback', style: GoogleFonts.inter()),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return SafeArea(
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Send Feedback',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.send_outlined, color: kPrimaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your feedback is sent directly to the ParishFinder team. Add your email if you\'d like a reply.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: subtextColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Your email (optional)
              Text(
                'Your Email (optional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: 15, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    hintStyle: GoogleFonts.inter(color: subtextColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Feedback
              Text(
                'Your Feedback',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 6,
                  style: GoogleFonts.inter(fontSize: 15, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Tell us what you think, report a bug, or suggest a feature...',
                    hintStyle: GoogleFonts.inter(color: subtextColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit Feedback',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return SafeArea(
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance section
              Text(
                'Appearance',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),

              // Dark mode toggle
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: kPrimaryColor,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Dark Mode',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'Currently using dark theme' : 'Currently using light theme',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: subtextColor,
                    ),
                  ),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (value) {
                      themeNotifier.setDarkMode(value);
                    },
                    activeThumbColor: kPrimaryColor,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(height: 32),

              // App info section
              Text(
                'About',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: kPrimaryColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        'Version',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      trailing: Text(
                        AppVersion.display,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: subtextColor,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  /// Optional pre-loaded parish list. If null, the page loads its own via
  /// `parishService` — used when this page is a tab inside RootShell.
  final List<Parish>? parishes;

  /// When the page is shown as a tab, hide the close button (there's nothing
  /// to pop back to).
  final bool inTab;

  const FavoritesPage({super.key, this.parishes, this.inTab = false});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Parish> _parishes = [];

  @override
  void initState() {
    super.initState();
    favoritesManager.addListener(_onFavoritesChanged);
    themeNotifier.addListener(_onFavoritesChanged);
    if (widget.parishes != null) {
      _parishes = widget.parishes!;
    } else {
      _loadParishes();
    }
  }

  Future<void> _loadParishes() async {
    final ps = await parishService.getParishes();
    favoritesManager.migrateLegacyKeys(ps);
    if (mounted) setState(() => _parishes = ps);
  }

  @override
  void dispose() {
    favoritesManager.removeListener(_onFavoritesChanged);
    themeNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  List<Parish> get _favoriteParishes {
    return _parishes
        .where((p) => favoritesManager.isFavorite(p))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final favorites = _favoriteParishes;

    return SafeArea(
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: widget.inTab
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          title: Text(
            'Home Parishes',
            style: AppText.titleLarge(color: textColor),
          ),
          centerTitle: true,
        ),
        body: favorites.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No home parishes yet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: subtextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Tap the star icon on a parish page to mark it as a home parish',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: subtextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: favorites.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final parish = favorites[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ParishDetailPage(parish: parish),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.church,
                              color: kPrimaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
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
                                const SizedBox(height: 4),
                                Text(
                                  '${parish.city} ${parish.zipCode}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: subtextColor,
                                  ),
                                ),
                                if (parish.massTimes.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: subtextColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          parish.massTimes.first.display,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: subtextColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            onPressed: () {
                              favoritesManager.toggleFavorite(parish);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

const String _kContactEmail = 'contact@parishfinder.app';
// Not live yet — the page is written (site/privacy.html) but the domain isn't
// serving it, so this link will 404 until parishfinder.app goes up.
const String _kPrivacyUrl = 'https://parishfinder.app/privacy';

class _AboutPageState extends State<AboutPage> {
  Future<void> _launchContactEmail() async {
    final uri = Uri(scheme: 'mailto', path: _kContactEmail);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      // No mail client (common on desktop/emulator) — leave the user with the
      // address on the clipboard rather than a dead tap.
      await Clipboard.setData(const ClipboardData(text: _kContactEmail));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied $_kContactEmail to the clipboard'),
        ),
      );
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final uri = Uri.parse(_kPrivacyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open $_kPrivacyUrl')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return SafeArea(
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'About',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // App icon — the same roundel the launcher icons are rendered from
              // (assets/icons/app_icon.png, generated by tool/gen_icons.py).
              Image.asset(
                'assets/icons/app_icon.png',
                width: 112,
                height: 112,
              ),
              const SizedBox(height: 24),
              // App name
              Text('ParishFinder', style: AppText.titleHuge(color: textColor)),
              const SizedBox(height: 8),
              Text(
                'Version ${AppVersion.display}',
                style: AppText.body(color: subtextColor),
              ),
              const SizedBox(height: 32),
              // Description card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
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
                    Text(
                      'About This App',
                      style: AppText.titleLarge(color: textColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ParishFinder helps you to connect with Roman Catholic '
                      'Churches in the Diocese of Cleveland.\n\n'
                      'Schedules are compiled from the parish bulletin and can '
                      'occasionally be mistaken or change without notice, '
                      'especially on holy days and holidays. It’s always a '
                      'good idea to double check with the parish before making '
                      'plans.',
                      style: AppText.body(color: subtextColor).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Credits card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
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
                    Text(
                      'Credits',
                      style: AppText.titleLarge(color: textColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      // The Noun Project icons are CC BY 3.0: attribution is a
                      // license condition, so this card is where the credit
                      // actually discharges it — keep the names below intact.
                      'With thanks to Tim Garvin and Tony Lofreso for their '
                      'assistance and know-how.\n\n'
                      'Map data © OpenStreetMap contributors, available under '
                      'the Open Database License.\n\n'
                      'Liturgical calendar data from '
                      'calapi.inadiutorium.cz.\n\n'
                      'Icons: “Monstrance” by Ahmad Roaayala and “Confession” '
                      'by Luis Prado, from the Noun Project (CC BY 3.0).\n\n'
                      'Typefaces: Inter and Cormorant Garamond (SIL Open Font '
                      'License 1.1).',
                      style: AppText.body(color: subtextColor).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Psalm 103:1',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: goldTextAccentFor(isDark: isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Contact card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
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
                    Text(
                      'Contact',
                      style: AppText.titleLarge(color: textColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Something wrong? Let us know.',
                      style: AppText.body(color: subtextColor).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _launchContactEmail,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.mail_outline,
                              size: 18,
                              color: primaryAccentFor(isDark: isDark),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _kContactEmail,
                                style: AppText.body(
                                  color: primaryAccentFor(isDark: isDark),
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor:
                                      primaryAccentFor(isDark: isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _launchPrivacyPolicy,
                  icon: Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: goldTextAccentFor(isDark: isDark),
                  ),
                  label: Text(
                    'Privacy policy',
                    style: AppText.body(
                      color: goldTextAccentFor(isDark: isDark),
                    ),
                  ),
                ),
              ),
              // The full dependency licence tree (OFL for the typefaces, BSD
              // for the Flutter packages, and so on). Flutter aggregates these
              // automatically, which is the reliable way to stay compliant as
              // dependencies change — the Credits card above only calls out
              // the attributions a human reader is owed by name.
              Center(
                child: TextButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'ParishFinder',
                    applicationVersion: AppVersion.version,
                    applicationLegalese: '© 2026 ParishFinder',
                  ),
                  icon: Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: goldTextAccentFor(isDark: isDark),
                  ),
                  label: Text(
                    'Open source licenses',
                    style: AppText.body(
                      color: goldTextAccentFor(isDark: isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '© 2026 Fr. Michael Garvin',
                style: AppText.caption(color: subtextColor),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
