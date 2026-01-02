import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'models/parish.dart';
import 'pages/parish_detail_page.dart';
import 'pages/find_parish_near_me_page.dart';

// Dev override: set to a LatLng to skip GPS, or null to use real location
const LatLng? kDevLocation = kDebugMode
    ? LatLng(41.48, -81.78) // Lakewood, OH - near several parishes
    : null;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MassGPTApp());
}

// Colors inspired by travel_app
const Color kBackgroundColor = Color(0xffFEFEFE);
const Color kPrimaryColor = Color(0xff3F95A1); // Teal accent
const Color kSecondaryColor = Color(0xFF003366); // Original dark blue
const Color kCardColor = Colors.white;

class MassGPTApp extends StatelessWidget {
  const MassGPTApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: kBackgroundColor,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: kBackgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'MassGPT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        textTheme: GoogleFonts.latoTextTheme(),
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        colorScheme: ColorScheme.light(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Parish> _parishes = [];
  List<Parish> _searchResults = [];
  List<Parish> _nearbyParishes = [];
  bool _isLoading = true;
  bool _showResults = false;
  Timer? _debounce;
  LatLng? _userLocation;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParishData();
    _getUserLocation();
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
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
      final String response = await rootBundle.loadString('data/parishes.json');
      final List<dynamic> data = json.decode(response);

      setState(() {
        _parishes = data.map((json) => Parish.fromJson(json)).toList();
        _isLoading = false;
      });
      _updateNearbyParishes();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading parish data: $e');
    }
  }

  Future<void> _getUserLocation() async {
    // Use dev override if set
    if (kDevLocation != null) {
      debugPrint('Using dev location: ${kDevLocation!.latitude}, ${kDevLocation!.longitude}');
      setState(() {
        _userLocation = kDevLocation;
        _locationLoading = false;
      });
      _updateNearbyParishes();
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          debugPrint('Location permissions are denied');
          setState(() {
            _locationLoading = false;
          });
          return;
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationLoading = false;
      });
      _updateNearbyParishes();
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _locationLoading = false;
      });
    }
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

    setState(() {
      _nearbyParishes = parishesWithDistance.take(10).map((e) => e.key).toList();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _updateSearchResults(query);
    });
  }

  void _updateSearchResults(String query) {
    final lowerCaseQuery = query.toLowerCase();

    setState(() {
      _showResults = query.isNotEmpty;
      if (query.isEmpty) {
        _searchResults.clear();
      } else {
        _searchResults = _parishes.where((parish) {
          return parish.name.toLowerCase().contains(lowerCaseQuery) ||
              parish.city.toLowerCase().contains(lowerCaseQuery) ||
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

  @override
  Widget build(BuildContext context) {
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
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MassGPT',
                        style: GoogleFonts.lato(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.church,
                          color: kPrimaryColor,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find Catholic masses near you',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Search Section
                  Text(
                    'Search Parishes',
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar with Autocomplete
                  _buildSearchBar(),
                  const SizedBox(height: 30),

                  // Looking For Section
                  Text(
                    'Looking for',
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickAccessButtons(),
                  const SizedBox(height: 30),

                  // Nearby Parishes Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nearby Parishes',
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FindParishNearMePage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map, size: 18),
                        label: Text(
                          'View All',
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nearby Parishes Horizontal List
                  _buildNearbyParishesList(),
                  const SizedBox(height: 30),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info_outline,
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
                                'Cleveland/Akron Area',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '80+ parishes with mass times',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name, city, or ZIP code',
              hintStyle: GoogleFonts.lato(
                color: Colors.grey,
                fontSize: 16,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: kPrimaryColor,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
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
              color: kCardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
                                  color: kPrimaryColor.withOpacity(0.1),
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
                                      style: GoogleFonts.lato(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${parish.city} ${parish.zipCode}',
                                      style: GoogleFonts.lato(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index < _searchResults.length - 1)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: Colors.grey.withOpacity(0.2),
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
              color: kCardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
                  color: Colors.grey[400],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No parishes found',
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    color: Colors.grey[600],
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
          child: _QuickAccessButton(
            icon: Icons.access_time,
            label: 'Mass Times',
            color: kPrimaryColor,
            onTap: () {
              // TODO: Filter for mass times
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessButton(
            icon: Icons.favorite_outline,
            label: 'Confession',
            color: kSecondaryColor,
            onTap: () {
              // TODO: Filter for confession
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessButton(
            icon: Icons.brightness_5,
            label: 'Adoration',
            color: const Color(0xFFE67E22),
            onTap: () {
              // TODO: Filter for adoration
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessButton(
            icon: Icons.church,
            label: 'Parish Details',
            color: const Color(0xFF9B59B6),
            onTap: () {
              // TODO: Show parish details
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyParishesList() {
    if (_locationLoading || _isLoading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.black54,
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
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                color: Colors.grey[400],
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Location unavailable',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _locationLoading = true;
                  });
                  _getUserLocation();
                },
                child: Text(
                  'Try Again',
                  style: GoogleFonts.lato(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                color: Colors.grey[400],
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'No parishes found nearby',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.black54,
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
  final IconData icon;
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
  final VoidCallback onTap;

  const _NearbyParishCard({
    required this.parish,
    required this.distance,
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
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.church,
                    color: kSecondaryColor,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(1)} mi',
                    style: GoogleFonts.lato(
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
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              parish.city,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: Colors.black54,
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
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      parish.massTimes.first,
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        color: Colors.grey[600],
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
