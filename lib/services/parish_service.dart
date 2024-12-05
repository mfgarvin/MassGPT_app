// lib/services/parish_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parish.dart';

class ParishService {
  List<Parish> parishes = [];
  bool hasError = false;
  String errorMessage = '';

  Future<void> loadParishData() async {
    try {
      const url = 'http://localhost/parishes.json'; // Replace with your actual URL
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        parishes = data.map((jsonItem) => Parish.fromJson(jsonItem)).toList();
        hasError = false;
      } else {
        errorMessage = 'Failed to load parish data: ${response.statusCode}';
        hasError = true;
        // throw Exception('Failed to load parish data: ${response.statusCode}');
      }
    } catch (e) {
      hasError = true;
      errorMessage = 'Error loading parish data: $e';
      print(errorMessage);
      // print('Error loading parish data: $e');
      throw e;
    }
  }
}
