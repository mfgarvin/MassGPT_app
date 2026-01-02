import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../main.dart' show kPrimaryColor, kSecondaryColor, kBackgroundColor, kCardColor;
import 'parish_detail_page.dart';

// Dev override: set to a LatLng to skip GPS, or null to use real location
const LatLng? kDevLocation = kDebugMode
    ? LatLng(41.48, -81.78) // Lakewood, OH - near several parishes
    : null;

class FindParishNearMePage extends StatefulWidget {
  const FindParishNearMePage({Key? key}) : super(key: key);

  @override
  _FindParishNearMePageState createState() => _FindParishNearMePageState();
}

class _FindParishNearMePageState extends State<FindParishNearMePage> {
  LatLng? userLocation;
  List<Parish> _parishes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParishData();
    _getUserLocation();
  }

  Future<void> _loadParishData() async {
    try {
      final String response = await DefaultAssetBundle.of(context)
          .loadString('data/parishes.json');
      final List<dynamic> data = json.decode(response);

      setState(() {
        _parishes = data.map((jsonItem) => Parish.fromJson(jsonItem)).toList();
      });
    } catch (e) {
      debugPrint('Error loading parish data: $e');
    }
  }

  Future<void> _getUserLocation() async {
    // Use dev override if set
    if (kDevLocation != null) {
      debugPrint('Using dev location: ${kDevLocation!.latitude}, ${kDevLocation!.longitude}');
      setState(() {
        userLocation = kDevLocation;
        _isLoading = false;
      });
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
            _isLoading = false;
          });
          return;
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localUserLocation = userLocation;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kCardColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                    style: GoogleFonts.lato(
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
                    // Map
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: localUserLocation,
                        initialZoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: 'com.example.mass_gpt',
                        ),
                        MarkerLayer(
                          markers: [
                            if (userLocation != null) _buildUserLocationMarker(),
                            ..._buildParishMarkers(),
                          ],
                        ),
                      ],
                    ),
                    // Top Info Card
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 60,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: kCardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on,
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
                                    'Parishes Near You',
                                    style: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap a marker to view details',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                color: Colors.orange.withOpacity(0.1),
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
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enable location services and grant permission to use this feature.',
              style: GoogleFonts.lato(
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
                _getUserLocation();
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
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              color: kPrimaryColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildParishMarkers() {
    return _parishes
        .where((parish) => parish.latitude != null && parish.longitude != null)
        .map(
          (parish) => Marker(
            point: LatLng(parish.latitude!, parish.longitude!),
            width: 50.0,
            height: 50.0,
            child: GestureDetector(
              onTap: () => _showParishInfo(parish),
              child: Container(
                decoration: BoxDecoration(
                  color: kSecondaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.church,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  void _showParishInfo(Parish parish) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Parish info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kSecondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.church,
                      color: kSecondaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parish.name,
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${parish.address}, ${parish.city}',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // View Details Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParishDetailPage(parish: parish),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'View Details',
                    style: GoogleFonts.lato(
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
}
