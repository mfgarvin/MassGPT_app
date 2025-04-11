import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../globals.dart'; // If needed
import '../models/parish.dart';
import 'parish_detail_page.dart';

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
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          // Permissions are denied, handle appropriately
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
    final theme = Theme.of(context);
    final localUserLocation = userLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Parish Near Me'),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.secondary,
              ),
            )
          : localUserLocation == null
              ? Center(
                  child: Text(
                    'Unable to get your location.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: localUserLocation,
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
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
    );
  }

  Marker _buildUserLocationMarker() {
    return Marker(
      point: userLocation!,
      width: 40.0,
      height: 40.0,
      child: Icon(
        Icons.circle,
        color:Colors.blue[400],
        size: 20.0,
      )
    );
  }

  List<Marker> _buildParishMarkers() {
    return _parishes
        .where((parish) => parish.latitude != null && parish.longitude != null)
        .map(
          (parish) => Marker(
            point: LatLng(parish.latitude!, parish.longitude!),
            width: 80.0,
            height: 80.0,
            child:GestureDetector(
              onTap: () => _showParishInfo(parish),
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40.0,
              )
            )
          ),
        )
        .toList();
  }

  void _showParishInfo(Parish parish) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                parish.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  // Example: override color if needed:
                  color: theme.textTheme.displayLarge?.color,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParishDetailPage(parish: parish),
                    ),
                  );
                },
                child: const Text('View Details'),
              ),
            ],
          ),
        );
      },
    );
  }
}
