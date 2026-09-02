import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart'
    show kCardColor, kCardColorDark, favoritesManager, themeNotifier, primaryAccentFor;
import '../models/parish.dart';

/// Ask before dropping a home parish, then drop it.
///
/// This guards the **My Parishes** list star only. That star sits on every
/// row, next to a card whose whole surface is a tap target, and the row it
/// unsaves disappears with it — so a stray tap there both is likelier and
/// costs more than elsewhere. The detail page's star is deliberately left as a
/// plain one-tap toggle: the parish stays on screen, and the star itself shows
/// the new state.
///
/// Returns true when the parish was actually removed.
Future<bool> confirmRemoveHomeParish(BuildContext context, Parish parish) async {
  final isDark = themeNotifier.isDarkMode;
  final accent = primaryAccentFor(isDark: isDark);
  final textColor = isDark ? Colors.white : Colors.black87;
  final subtext = isDark ? Colors.white70 : Colors.black54;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: isDark ? kCardColorDark : kCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.star_outline, color: accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Remove home parish?',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        '${parish.name} will no longer appear in My Parishes.',
        style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: subtext),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: subtext),
          child: Text('Keep', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text('Remove', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  // Dismissing by barrier or system back returns null — only an explicit
  // "Remove" counts. The favorite can also have been toggled elsewhere while
  // the dialog was up, so re-check rather than blindly toggling, which would
  // otherwise re-add a parish that is already gone.
  if (confirmed != true) return false;
  if (!favoritesManager.isFavorite(parish)) return false;
  favoritesManager.toggleFavorite(parish);
  return true;
}
