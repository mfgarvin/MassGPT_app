import 'package:flutter/material.dart';
import '../models/parish.dart';

class ParishDetailPage extends StatelessWidget {
  final Parish parish;

  const ParishDetailPage({Key? key, required this.parish}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final textTheme = theme.textTheme;
    final accentColor = theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(parish.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Optional Hero Image or Placeholder
            // If you don't have an actual image, you can use a placeholder.
            _buildParishImage(),
            
            // 2. A Card for Parish Information
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 3.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address
                    _InfoRow(
                      icon: Icons.location_on,
                      title: 'Address',
                      text: parish.address,
                      theme: textTheme,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 16.0),

                    // Mass Times
                    Text(
                      'Mass Times:',
                      // icon: Icons.access_time,
                      style: textTheme.titleLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    ..._buildMassTimes(parish.massTimes, textTheme),
                    const SizedBox(height: 16.0),

                    // Confession Times
                    Text(
                      'Confession Times:',
                      style: textTheme.titleLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    ..._buildConfTimes(parish.confTimes, textTheme),
                    const SizedBox(height: 16.0),

                    // Website
                    _InfoRow(
                      icon: Icons.language,
                      title: 'Website',
                      text: parish.website ?? 'N/A',
                      theme: textTheme,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 16.0),

                    // Phone Number
                    _InfoRow(
                      icon: Icons.phone,
                      title: 'Phone Number',
                      text: parish.phone,
                      theme: textTheme,
                      accentColor: accentColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A Hero image or placeholder (if you have an actual image to display for the parish)
  Widget _buildParishImage() {
    // If you have a real image URL, you can use Image.network() or Image.asset()
    // For demonstration, let's do a placeholder with a Hero widget.
    return Hero(
      tag: parish.name, // If you used a hero tag from a previous screen
      child: Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(
            Icons.church,
            size: 80,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // Build the list of mass times with bullet points, or just plain text.
  List<Widget> _buildMassTimes(List<String> times, TextTheme textTheme) {
    if (times.isEmpty) {
      return [
        Text(
          'No Mass times available',
          style: textTheme.displaySmall,
        ),
      ];
    }
    return times.map((time) {
      return Row(
        children: [
          const Text("• "),
          Expanded(
            child: Text(
              time,
              style: textTheme.displaySmall,
            ),
          ),
        ],
      );
    }).toList();
  }
List<Widget> _buildConfTimes(List<String> times, TextTheme textTheme) {
    if (times.isEmpty) {
      return [
        Text(
          'By Appointment Only',
          style: textTheme.displaySmall,
        ),
      ];
    }
    return times.map((time) {
      return Row(
        children: [
          const Text("• "),
          Expanded(
            child: Text(
              time,
              style: textTheme.displaySmall,
            ),
          ),
        ],
      );
    }).toList();
  }
}

// A helper widget to display an icon + label + content in a more structured way.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final TextTheme theme;
  final Color accentColor;

  const _InfoRow({
    Key? key,
    required this.icon,
    required this.title,
    required this.text,
    required this.theme,
    required this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: accentColor,
          size: 28.0,
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title:',
                style: theme.titleMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                text,
                style: theme.displaySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
