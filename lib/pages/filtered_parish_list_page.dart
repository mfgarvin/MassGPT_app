import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../main.dart' show kBackgroundColor, kCardColor;
import 'parish_detail_page.dart';

enum ParishFilter {
  massTimes,
  confession,
  all,
}

enum SortOrder {
  distance,
  alphabetical,
}

class FilteredParishListPage extends StatefulWidget {
  final ParishFilter filter;
  final String title;
  final Color accentColor;
  final LatLng? userLocation;

  const FilteredParishListPage({
    Key? key,
    required this.filter,
    required this.title,
    required this.accentColor,
    this.userLocation,
  }) : super(key: key);

  @override
  State<FilteredParishListPage> createState() => _FilteredParishListPageState();
}

class _FilteredParishListPageState extends State<FilteredParishListPage> {
  List<Parish> _parishes = [];
  List<Parish> _filteredParishes = [];
  Map<String, double> _distances = {};
  bool _isLoading = true;
  SortOrder _sortOrder = SortOrder.distance;

  @override
  void initState() {
    super.initState();
    _loadParishData();
  }

  Future<void> _loadParishData() async {
    try {
      final String response = await rootBundle.loadString('data/parishes.json');
      final List<dynamic> data = json.decode(response);

      setState(() {
        _parishes = data.map((json) => Parish.fromJson(json)).toList();
        _calculateDistances();
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
        _distances[parish.name] = _calculateDistance(
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
      case ParishFilter.all:
        _filteredParishes = List.from(_parishes);
        break;
    }
    _applySorting();
  }

  void _applySorting() {
    if (_sortOrder == SortOrder.distance && widget.userLocation != null) {
      _filteredParishes.sort((a, b) {
        final distA = _distances[a.name] ?? double.infinity;
        final distB = _distances[b.name] ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else {
      _filteredParishes.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == SortOrder.distance
          ? SortOrder.alphabetical
          : SortOrder.distance;
      _applySorting();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: widget.accentColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.lato(
            color: Colors.black87,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No parishes found',
            style: GoogleFonts.lato(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParishList() {
    final canSortByDistance = widget.userLocation != null;

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
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filteredParishes.length} parishes',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
              const Spacer(),
              // Sort toggle button
              if (canSortByDistance)
                GestureDetector(
                  onTap: _toggleSortOrder,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sortOrder == SortOrder.distance
                              ? Icons.near_me
                              : Icons.sort_by_alpha,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sortOrder == SortOrder.distance ? 'Nearest' : 'A-Z',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Parish list
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _filteredParishes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final parish = _filteredParishes[index];
              final distance = _distances[parish.name];
              return _ParishCard(
                parish: parish,
                filter: widget.filter,
                accentColor: widget.accentColor,
                distance: distance,
                showDistance: _sortOrder == SortOrder.distance && distance != null,
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
      ],
    );
  }
}

class _ParishCard extends StatelessWidget {
  final Parish parish;
  final ParishFilter filter;
  final Color accentColor;
  final double? distance;
  final bool showDistance;
  final VoidCallback onTap;

  const _ParishCard({
    required this.parish,
    required this.filter,
    required this.accentColor,
    required this.onTap,
    this.distance,
    this.showDistance = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.church,
                    color: accentColor,
                    size: 22,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                if (showDistance && distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${distance!.toStringAsFixed(1)} mi',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
              ],
            ),
            // Times section based on filter
            if (_getTimesToShow().isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 12),
              _buildTimesSection(),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _getTimesToShow() {
    switch (filter) {
      case ParishFilter.massTimes:
        return parish.massTimes;
      case ParishFilter.confession:
        return parish.confTimes;
      case ParishFilter.all:
        return parish.massTimes.isNotEmpty ? parish.massTimes : parish.confTimes;
    }
  }

  Widget _buildTimesSection() {
    final times = _getTimesToShow();
    final icon = filter == ParishFilter.confession
        ? Icons.favorite_outline
        : Icons.access_time;
    final label = filter == ParishFilter.confession ? 'Confession' : 'Mass Times';

    // Show up to 3 times
    final displayTimes = times.take(3).toList();
    final hasMore = times.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...displayTimes.map((time) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                )),
            if (hasMore)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${times.length - 3} more',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
