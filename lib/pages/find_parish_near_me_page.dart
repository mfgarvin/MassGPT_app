import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
//import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'dart:convert';
import '../globals.dart';
import '../models/parish.dart';
import 'parish_detail_page.dart';
// import '../services/parish_service.dart';


class FindParishNearMePage extends StatefulWidget {
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
  // @override
  // Widget build(BuildContext context) {final List<Parish> parishes = parishService.parishes;}

  Future<void> _loadParishData() async {
    try {
      final String response =
          await DefaultAssetBundle.of(context).loadString('data/parishes.json');
      final List<dynamic> data = json.decode(response);

      setState(() {
        _parishes = data.map((jsonItem) => Parish.fromJson(jsonItem)).toList();
      });
    } catch (e) {
      print('Error loading parish data: $e');
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          // Permissions are denied, handle appropriately
          print('Location permissions are denied');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // When permissions are granted, get the position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
      // Handle error, e.g., show a message to the user.
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFF003366);
    final localUserLocation = userLocation;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Find a Parish Near Me'),
        backgroundColor: backgroundColor,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFFDD0),
              ),
            )
          : localUserLocation == null
              ? Center(
                  child: Text(
                    'Unable to get your location.',
                    style: TextStyle(color: Color(0xFFFFFDD0)),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: localUserLocation,
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.mass_gpt',
                    ),
                    MarkerLayer(
                      markers: [
                        if (userLocation != null) _buildUserLocationMarker(),
                        ..._buildParishMarkers()
                      ]
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
        color: Colors.blue[400],
        size: 20.0,
      )
    );
  }


  // @override
  // Widget build(BuildContext context) {final List<Parish> parishes = parishService.parishes;}
  List<Marker> _buildParishMarkers() {
    // return parishService.parishes
    return _parishes
        .where((parish) => parish.latitude != null && parish.longitude != null)
        .map(
          (parish) => Marker(
            point: LatLng(parish.latitude!, parish.longitude!),
            width: 80.0,
            height: 80.0,
            child: GestureDetector(
              onTap: () {
                _showParishInfo(parish);
              },
              child: Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40.0,
              ),
            ),
          ),
        )
        .toList();
  }

  void _showParishInfo(Parish parish) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF003366),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                parish.name,
                style: TextStyle(
                    color: Color(0xFFFFFDD0),
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFA500),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close the bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParishDetailPage(parish: parish),
                    ),
                  );
                },
                child: Text(
                  'View Details',
                  style: TextStyle(color: Color(0xFF003366)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
