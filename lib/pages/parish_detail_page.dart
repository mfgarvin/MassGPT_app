import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/parish.dart';
import '../main.dart' show kPrimaryColor, kSecondaryColor, kBackgroundColor, kBackgroundColorDark, kCardColor, kCardColorDark, favoritesManager, themeNotifier;

class ParishDetailPage extends StatefulWidget {
  final Parish parish;

  const ParishDetailPage({Key? key, required this.parish}) : super(key: key);

  @override
  State<ParishDetailPage> createState() => _ParishDetailPageState();
}

class _ParishDetailPageState extends State<ParishDetailPage> {
  @override
  void initState() {
    super.initState();
    favoritesManager.addListener(_onChanged);
    themeNotifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    favoritesManager.removeListener(_onChanged);
    themeNotifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  Parish get parish => widget.parish;

  Future<void> _launchMaps() async {
    final address = '${parish.address}, ${parish.city} ${parish.zipCode}';
    final encodedAddress = Uri.encodeComponent(address);
    final Uri mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');

    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone() async {
    final phoneNumber = parish.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUrl = Uri.parse('tel:$phoneNumber');

    if (await canLaunchUrl(phoneUrl)) {
      await launchUrl(phoneUrl);
    }
  }

  Future<void> _launchWebsite() async {
    if (parish.website.isEmpty || parish.website == 'No Website') return;

    String url = parish.website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final Uri websiteUrl = Uri.parse(url);
    if (await canLaunchUrl(websiteUrl)) {
      await launchUrl(websiteUrl, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildHeaderBackground() {
    final hasImage = parish.imageUrl != null && parish.imageUrl!.isNotEmpty;

    if (hasImage) {
      // Show actual parish image with gradient overlay
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: parish.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholderBackground(),
            errorWidget: (context, url, error) => _buildPlaceholderBackground(),
          ),
          // Gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Parish name at bottom
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: Text(
              parish.name,
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      // Show placeholder background
      return _buildPlaceholderBackground();
    }
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kSecondaryColor,
            kSecondaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.church,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              parish.name,
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = favoritesManager.isFavorite(parish.name);
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: kSecondaryColor,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: kPrimaryColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : kPrimaryColor,
                    size: 24,
                  ),
                  onPressed: () {
                    favoritesManager.toggleFavorite(parish.name);
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderBackground(),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Card (tappable to open in maps)
                  _TappableInfoCard(
                    icon: Icons.location_on,
                    title: 'Address',
                    content: '${parish.address}\n${parish.city} ${parish.zipCode}',
                    color: kPrimaryColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    actionIcon: Icons.directions,
                    actionLabel: 'Get Directions',
                    onTap: _launchMaps,
                  ),
                  const SizedBox(height: 16),

                  // Mass Times Card
                  _ScheduleCard(
                    icon: Icons.access_time,
                    title: 'Mass Times',
                    items: parish.massTimes,
                    emptyMessage: 'No Mass times available',
                    color: kSecondaryColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Confession Times Card
                  _ScheduleCard(
                    icon: Icons.favorite,
                    title: 'Confession Times',
                    items: parish.confTimes,
                    emptyMessage: 'By Appointment Only',
                    color: kPrimaryColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Contact Info Card
                  _buildContactCard(cardColor, textColor, subtextColor),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contact_phone,
                  color: kSecondaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Contact Information',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Phone (tappable to call)
          _TappableContactRow(
            icon: Icons.phone,
            label: 'Phone',
            value: parish.phone,
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: parish.phone != 'No Phone Listed' ? _launchPhone : null,
          ),
          const SizedBox(height: 12),
          // Website (tappable to open)
          _TappableContactRow(
            icon: Icons.language,
            label: 'Website',
            value: parish.website.isNotEmpty ? parish.website : 'N/A',
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: (parish.website.isNotEmpty && parish.website != 'No Website') ? _launchWebsite : null,
          ),
        ],
      ),
    );
  }
}

class _TappableInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback? onTap;

  const _TappableInfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.actionIcon,
    required this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        actionIcon,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      actionLabel,
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final String emptyMessage;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final bool isDark;

  const _ScheduleCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: subtextColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    emptyMessage,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: subtextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _TappableContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color subtextColor;
  final VoidCallback? onTap;

  const _TappableContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subtextColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isClickable ? kPrimaryColor : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isClickable ? kPrimaryColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      color: isClickable ? kPrimaryColor : textColor,
                      decoration: isClickable ? TextDecoration.underline : null,
                      decorationColor: kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isClickable)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: kPrimaryColor.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }
}
