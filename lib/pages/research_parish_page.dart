import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/parish.dart';
import '../main.dart' show kPrimaryColor, kBackgroundColor, kCardColor;
import 'parish_detail_page.dart';

class ResearchParishPage extends StatefulWidget {
  @override
  _ResearchParishPageState createState() => _ResearchParishPageState();
}

class _ResearchParishPageState extends State<ResearchParishPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Parish> _parishes = [];
  List<Parish> _searchResults = [];
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadParishData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadParishData() async {
    try {
      final String response = await rootBundle.loadString('data/parishes.json');
      final List<dynamic> data = json.decode(response);

      setState(() {
        _parishes = data.map((json) => Parish.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading parish data: $e');
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _updateSearchResults(query);
    });
  }

  void _updateSearchResults(String query) {
    final lowerCaseQuery = query.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _searchResults.clear();
      } else {
        _searchResults = _parishes.where((parish) {
          return parish.name.toLowerCase().contains(lowerCaseQuery) ||
              parish.city.toLowerCase().contains(lowerCaseQuery) ||
              parish.zipCode.contains(query);
        }).toList();
      }
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
          icon: const Icon(Icons.arrow_back_ios, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Research a Parish',
          style: GoogleFonts.lato(
            color: kPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Search Bar (travel_app style)
                  Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name, city, or ZIP',
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
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Results Section
                  if (_searchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _searchResults.isEmpty
                            ? 'No results found'
                            : '${_searchResults.length} parish${_searchResults.length == 1 ? '' : 'es'} found',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  // Results List
                  Expanded(
                    child: _searchController.text.isEmpty
                        ? _buildEmptyState()
                        : _searchResults.isEmpty
                            ? _buildNoResultsState()
                            : _buildResultsList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search,
              color: kPrimaryColor,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Search for parishes',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a parish name, city, or ZIP code',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
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
              Icons.search_off,
              color: Colors.orange,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No parishes found',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final parish = _searchResults[index];
        return _ParishCard(
          parish: parish,
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
    );
  }
}

class _ParishCard extends StatelessWidget {
  final Parish parish;
  final VoidCallback onTap;

  const _ParishCard({
    required this.parish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
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
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${parish.address}, ${parish.city}',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (parish.massTimes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: kPrimaryColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            parish.massTimes.first,
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: kPrimaryColor,
                              fontWeight: FontWeight.w500,
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
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
