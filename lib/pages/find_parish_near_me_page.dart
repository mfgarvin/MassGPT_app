import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/parish.dart';
import '../services/location_service.dart';
import '../services/parish_service.dart';
import '../main.dart' show kPrimaryColor, kSecondaryColor, kBackgroundColor, kCardColor;
import '../widgets/stained_glass_header.dart';
import '../widgets/zip_location_dialog.dart';
import 'parish_detail_page.dart';

class FindParishNearMePage extends StatefulWidget {
  /// When the map is shown as a root tab (inside RootShell), there's nothing
  /// to pop back to — so we hide the floating back button.
  final bool inTab;

  const FindParishNearMePage({super.key, this.inTab = false});

  @override
  State<FindParishNearMePage> createState() => _FindParishNearMePageState();
}

class _FindParishNearMePageState extends State<FindParishNearMePage>
    with WidgetsBindingObserver {
  LatLng? userLocation;
  LocationFix? _fix;
  LocationFailure? _locationFailure;
  List<Parish> _parishes = [];
  List<Parish> _nearbyParishes = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.85);

  /// True once the map has been built, so [MapController] is safe to drive.
  bool _mapReady = false;

  /// Set when the user pans or zooms by hand. Their framing then wins over a
  /// background refresh — we only auto-recenter until they take the wheel.
  bool _userMovedCamera = false;

  /// Where the parish list is sorted from, when that isn't the user. Set by
  /// "Search this area" so a later background refresh doesn't quietly drag the
  /// list back to the user's own position. Cleared by recentering.
  LatLng? _areaOrigin;

  // Parchment/sepia tone — a soft warm wash that desaturates the map without
  // going full Stamen-Watercolor. Built from a standard sepia matrix scaled
  // back toward identity.
  static const _parchmentFilter = ColorFilter.matrix(<double>[
    0.55, 0.30, 0.10, 0, 18, // R
    0.20, 0.62, 0.10, 0, 14, // G
    0.12, 0.20, 0.50, 0, 5,  // B
    0,    0,    0,    1, 0,  // A
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    locationService.addListener(_onSharedLocation);
    _loadParishData();
    _getUserLocation();
  }

  /// Adopt a fix the Home tab obtained — both tabs stay alive side by side.
  void _onSharedLocation() {
    final fix = locationService.lastFix;
    if (fix == null || !mounted) return;
    if (userLocation == fix.position && _fix?.source == fix.source) return;
    _applyFix(fix);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    locationService.removeListener(_onSharedLocation);
    _mapController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh location on foreground (catches movement + a permission grant
    // made while backgrounded). Updates the marker/nearby list without moving
    // the camera, so a user's manual pan/zoom is preserved.
    if (state == AppLifecycleState.resumed) {
      _getUserLocation();
    }
  }

  void _rebuildNearby() {
    final origin = _areaOrigin ?? userLocation;
    if (origin == null) return;
    final withCoords = _parishes
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();
    withCoords.sort((a, b) {
      final da = _distance(origin, a);
      final db = _distance(origin, b);
      return da.compareTo(db);
    });
    _nearbyParishes = withCoords.take(40).toList();
  }

  /// Re-sort the list around whatever the map is looking at. Every parish is
  /// already in memory — the 40 on screen are just the 40 nearest the origin —
  /// so this is a local re-sort, not a fetch, and needs no spinner.
  void _searchThisArea() {
    if (!_mapReady) return;
    setState(() {
      _areaOrigin = _mapController.camera.center;
      _userMovedCamera = false;
      _rebuildNearby();
      _selectedIndex = 0;
    });
    // The carousel is showing a card from the old ordering; put it back to the
    // top without animating across forty pages.
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  double _distance(LatLng from, Parish p) {
    // Squared great-circle approximation; we only need to sort.
    final dLat = (p.latitude! - from.latitude);
    final dLon = (p.longitude! - from.longitude);
    return dLat * dLat + dLon * dLon;
  }

  void _selectParish(int index, {bool moveCamera = true, bool animatePage = true}) {
    if (index < 0 || index >= _nearbyParishes.length) return;
    setState(() => _selectedIndex = index);
    final parish = _nearbyParishes[index];
    if (moveCamera) {
      _mapController.move(
        LatLng(parish.latitude!, parish.longitude!),
        math.max(_mapController.camera.zoom, 14.0),
      );
    }
    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadParishData() async {
    try {
      final parishes = await parishService.getParishes();

      setState(() {
        _parishes = parishes;
        _rebuildNearby();
      });

      // Same race as on Home: a stored ZIP can't resolve until the parish
      // data it resolves against has arrived.
      if (userLocation == null) {
        final fallback = await locationService.manualFallback(_parishes);
        if (fallback != null && mounted && userLocation == null) {
          _applyFix(fallback, recenter: true);
        }
      }
    } catch (e) {
      debugPrint('Error loading parish data: $e');
    }
  }

  /// Fetch a position and apply it. [recenter] moves the camera even if the
  /// user has panned — used by the my-location button, where recentring is
  /// the whole point.
  Future<void> _getUserLocation({bool recenter = false}) async {
    // Something on screen fast: a cached fix costs nothing and spares the
    // spinner on every resume.
    if (userLocation == null) {
      final cached = await locationService.lastKnown();
      if (cached != null && mounted && userLocation == null) {
        _applyFix(cached, recenter: true);
      }
    }

    final outcome = await locationService.current();
    if (!mounted) return;

    if (outcome.ok) {
      _applyFix(outcome.fix!, recenter: recenter);
      return;
    }

    // No device fix — fall back to a ZIP the user entered earlier, if any.
    final fallback = await locationService.manualFallback(_parishes);
    if (!mounted) return;
    if (fallback != null) {
      _applyFix(fallback, recenter: recenter);
      return;
    }

    setState(() {
      _locationFailure = outcome.failure;
      _isLoading = false;
    });
  }

  void _applyFix(LocationFix fix, {bool recenter = false}) {
    setState(() {
      userLocation = fix.position;
      _fix = fix;
      _locationFailure = null;
      _isLoading = false;
      // Asking to be recentred is asking to be the origin again.
      if (recenter) _areaOrigin = null;
      _rebuildNearby();
    });

    // The camera used to be set once, through MapOptions.initialCenter, so a
    // later fix moved the marker off screen with no way to follow it.
    if (_mapReady && (recenter || !_userMovedCamera)) {
      _mapController.move(fix.position, _mapController.camera.zoom);
      if (recenter) _userMovedCamera = false;
    }
  }

  Future<void> _promptForZip() async {
    final fix = await showZipLocationDialog(context, _parishes);
    if (fix == null || !mounted) return;
    _applyFix(fix, recenter: true);
  }

  @override
  Widget build(BuildContext context) {
    final localUserLocation = userLocation;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: widget.inTab
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kCardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: kPrimaryColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: kPrimaryColor),
                  const SizedBox(height: 24),
                  Text(
                    'Finding your location...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : localUserLocation == null
              ? _buildLocationErrorState()
              : Stack(
                  children: [
                    // Map with parchment color filter applied to tiles only
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: localUserLocation,
                        initialZoom: 13.0,
                        minZoom: 8.0,
                        maxZoom: 18.0,
                        // North is always up. A twist gesture rotating the
                        // map is disorienting when the point is "where am I
                        // relative to these parishes", and nothing here draws
                        // a compass to rotate back with.
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          cursorKeyboardRotationOptions:
                              CursorKeyboardRotationOptions.disabled(),
                        ),
                        onMapReady: () => _mapReady = true,
                        onPositionChanged: (position, hasGesture) {
                          // A hand-driven pan/zoom pins the view; refreshes
                          // stop stealing it until the user asks to recenter.
                          if (hasGesture && !_userMovedCamera) {
                            // setState, not a bare assignment: the top pill
                            // reads this to swap to "Search this area". The
                            // guard keeps it to one rebuild per pan, not one
                            // per frame.
                            setState(() => _userMovedCamera = true);
                          }
                        },
                      ),
                      children: [
                        ColorFiltered(
                          colorFilter: _parchmentFilter,
                          child: TileLayer(
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            // OSM's tile usage policy requires a real
                            // identifying User-Agent and blocks generic ones —
                            // keep this the actual application id.
                            userAgentPackageName: 'app.parishfinder',
                          ),
                        ),
                        MarkerLayer(
                          markers: [
                            ..._buildParishMarkers(),
                            if (userLocation != null) _buildUserLocationMarker(),
                          ],
                        ),
                      ],
                    ),
                    // Top pill. Once the user pans, the count describes where
                    // they used to be — so the same slot becomes the offer to
                    // re-sort around the new view instead of stating a stale
                    // number beside it.
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 60,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildTopPill()),
                    ),
                    // Recenter control. Also the only way back to yourself
                    // after panning, so it sits above the carousel.
                    Positioned(
                      right: 16,
                      bottom: 186,
                      child: _buildRecenterButton(),
                    ),
                    // OSM credit. The ODbL wants attribution where the map is
                    // actually shown, not buried in About — so it stays put
                    // rather than hiding behind a tap. Sits level with the
                    // recenter button, clear of the carousel below.
                    Positioned(
                      left: 12,
                      bottom: 186,
                      child: _buildMapAttribution(),
                    ),
                    // Bottom: swipeable parish carousel
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      height: 150,
                      child: _buildParishCarousel(),
                    ),
                  ],
                ),
    );
  }

  /// The count pill, or — once the view has been panned away — a tappable
  /// "Search this area". One slot, two states, so nothing new competes for
  /// space with the carousel and the controls above it.
  Widget _buildTopPill() {
    final searching = _userMovedCamera;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.search : Icons.location_on,
            color: kPrimaryColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            searching
                ? 'Search this area'
                : '${_nearbyParishes.length} parishes nearby',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );

    if (!searching) {
      return Semantics(
        label: '${_nearbyParishes.length} parishes nearby',
        child: pill,
      );
    }

    return Semantics(
      button: true,
      label: 'Search this area for parishes',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _searchThisArea,
          child: pill,
        ),
      ),
    );
  }

  /// Tapping opens OSM's copyright page, which is what the licence points
  /// readers at. Failing to launch is silent — a dead tap on a credit line is
  /// better than an error over the map.
  Future<void> _openOsmCopyright() async {
    final url = Uri.parse('https://www.openstreetmap.org/copyright');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing to recover; the credit text itself still discharges the licence.
    }
  }

  Widget _buildMapAttribution() {
    return Semantics(
      link: true,
      label: 'Map data from OpenStreetMap contributors. Opens the OpenStreetMap '
          'copyright page.',
      child: Material(
        color: kCardColor.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: _openOsmCopyright,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              '© OpenStreetMap contributors',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: kSecondaryColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    final usingZip = _fix?.source == LocationSource.manualZip;
    return Semantics(
      button: true,
      label: usingZip
          ? 'Centre on ZIP code ${_fix?.zip}'
          : 'Centre on my location',
      child: Material(
        color: kCardColor,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _getUserLocation(recenter: true),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              usingZip ? Icons.pin_drop_outlined : Icons.my_location,
              color: kPrimaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationErrorState() {
    return Center(
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
                Icons.location_off,
                color: Colors.orange,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to get location',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _locationFailureMessage(_locationFailure),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _getUserLocation(recenter: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Some devices simply never produce a fix — a Wi-Fi-only tablet
            // out of range of known networks, or a user who declined the
            // permission outright. A ZIP keeps the map usable for them.
            TextButton.icon(
              onPressed: _parishes.isEmpty ? null : _promptForZip,
              icon: const Icon(Icons.pin_drop_outlined, size: 18),
              label: Text(
                'Enter a ZIP code instead',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  static String _locationFailureMessage(LocationFailure? failure) {
    switch (failure) {
      case LocationFailure.permissionDeniedForever:
        return 'Location permission is turned off for ParishFinder. '
            'You can enable it in your device settings.';
      case LocationFailure.serviceDisabled:
        return 'Location services are turned off on this device.';
      case LocationFailure.timeout:
        return "We couldn't get a location fix — that's common indoors, "
            'and on tablets without GPS.';
      case LocationFailure.permissionDenied:
      case LocationFailure.unavailable:
      case null:
        return 'Please enable location services and grant permission '
            'to use this feature.';
    }
  }

  Marker _buildUserLocationMarker() {
    return Marker(
      point: userLocation!,
      width: 30.0,
      height: 30.0,
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildParishMarkers() {
    final markers = <Marker>[];
    for (int i = 0; i < _nearbyParishes.length; i++) {
      final parish = _nearbyParishes[i];
      final isSelected = i == _selectedIndex;
      markers.add(
        Marker(
          point: LatLng(parish.latitude!, parish.longitude!),
          width: isSelected ? 52.0 : 38.0,
          height: isSelected ? 52.0 : 38.0,
          child: GestureDetector(
            onTap: () => _selectParish(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : kSecondaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? kPrimaryColor : Colors.black)
                        .withValues(alpha: isSelected ? 0.4 : 0.25),
                    blurRadius: isSelected ? 14 : 6,
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.church,
                color: Colors.white,
                size: isSelected ? 26 : 20,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildParishCarousel() {
    if (_nearbyParishes.isEmpty) return const SizedBox.shrink();
    return PageView.builder(
      controller: _pageController,
      itemCount: _nearbyParishes.length,
      onPageChanged: (i) => _selectParish(i, animatePage: false),
      itemBuilder: (context, i) {
        final parish = _nearbyParishes[i];
        final selected = i == _selectedIndex;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: selected ? 0 : 8,
          ),
          child: _MapParishCard(
            parish: parish,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ParishDetailPage(parish: parish),
              ),
            ),
          ),
        );
      },
    );
  }

}

class _MapParishCard extends StatelessWidget {
  final Parish parish;
  final VoidCallback onTap;

  const _MapParishCard({required this.parish, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstMass = parish.massTimes.isNotEmpty ? parish.massTimes.first.display : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ParishGlassHero(
                seed: parish.parishId ?? parish.name,
                patron: parish.name,
                borderRadius: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: StainedGlassHeader(
                      seed: parish.parishId ?? parish.name,
                      patron: parish.name,
                      overlayDarken: 0.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      parish.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parish.city,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (firstMass != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: kSecondaryColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              firstMass,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: kSecondaryColor,
                                fontWeight: FontWeight.w600,
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
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
