import 'package:flutter/material.dart';
import '../models/parish.dart';

class ParishDetailPage extends StatelessWidget {
  final Parish parish;

  ParishDetailPage({required this.parish});

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFF003366);
    final Color textColor = const Color(0xFFFFFDD0);
    final Color accentColor = const Color(0xFFFFA500);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(parish.name),
        backgroundColor: backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Address
            Text(
              'Address:',
              style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              parish.address,
              style: TextStyle(color: textColor, fontSize: 18),
            ),
            const SizedBox(height: 20),
            // Mass Times
            Text(
              'Mass Times:',
              style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            ...parish.massTimes.map(
              (time) => Text(
                time,
                style: TextStyle(color: textColor, fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            // Additional Details (if any)
            // For example, contact information, website, etc.
            Text(
              'Website:',
              style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              parish.website!,
              style: TextStyle(color: textColor, fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              'Phone Number:',
              style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              parish.phone,
              style: TextStyle(color: textColor, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
