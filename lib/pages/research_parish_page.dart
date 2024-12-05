import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import the Parish model
import '../models/parish.dart';
import 'parish_detail_page.dart';

// import '../services/parish_service.dart';

class ResearchParishPage extends StatefulWidget {
  @override
  _ResearchParishPageState createState() => _ResearchParishPageState();
}

class _ResearchParishPageState extends State<ResearchParishPage> {
  // @overrideWidget build(BuildContext context) {
  //   final List<Parish> parishes = parishService.parishes;
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
      print('Error loading parish data: $e');
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
    final Color backgroundColor = const Color(0xFF003366);
    final Color textColor = const Color(0xFFFFFDD0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Research a Parish'),
        backgroundColor: backgroundColor,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: textColor),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Enter parish name, city, or ZIP code',
                      hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textColor),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 10),
                  // Suggestions List
                  Expanded(
                    child: _searchController.text.isEmpty
                        ? Center(
                            child: Text(
                              'Type to search for parishes.',
                              style: TextStyle(color: textColor, fontSize: 18.0),
                            ),
                          )
                        : _searchResults.isEmpty
                            ? Center(
                                child: Text(
                                  'No parishes found.',
                                  style:
                                      TextStyle(color: textColor, fontSize: 18.0),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final parish = _searchResults[index];
                                  return Card(
                                    color: backgroundColor,
                                    child: ListTile(
                                      title: Text(
                                        parish.name,
                                        style: TextStyle(
                                            color: textColor, fontSize: 20),
                                      ),
                                      subtitle: Text(
                                        '${parish.address}, ${parish.city}',
                                        style: TextStyle(
                                            color: textColor.withOpacity(0.7)),
                                      ),
                                      onTap: () {
                                        // Navigate to Parish Detail Page
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ParishDetailPage(parish: parish),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}
