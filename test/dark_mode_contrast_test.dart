import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/main.dart';

/// WCAG 2.1 relative luminance / contrast ratio.
///
/// The bug these pin: the dark theme paints on true black, and an accent
/// authored for cream parchment lands at 2:1 there — legible enough on a
/// desk-lit monitor to survive review, and unreadable on a phone. A number
/// catches that where an eye does not.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('accents are legible as ink in dark mode', () {
    // 4.5:1 is AA for body text — the accents label list rows and chips, not
    // just headings, so they are held to the body threshold.
    const scaffold = kBackgroundColorDark;
    const card = kCardColorDark;

    test('confession violet lifts off true black', () {
      final dark = violetAccentFor(isDark: true);
      expect(contrast(dark, scaffold), greaterThanOrEqualTo(4.5));
      expect(contrast(dark, card), greaterThanOrEqualTo(4.5));
    });

    test('confession violet stays dark ink on parchment', () {
      final light = violetAccentFor(isDark: false);
      expect(contrast(light, kBackgroundColor), greaterThanOrEqualTo(4.5));
      expect(contrast(light, kCardColor), greaterThanOrEqualTo(4.5));
    });

    test('all three quick-access accents clear AA in both themes', () {
      for (final isDark in [true, false]) {
        final bg = isDark ? scaffold : kBackgroundColor;
        final accents = <String, Color>{
          'mass': primaryAccentFor(isDark: isDark),
          'confession': violetAccentFor(isDark: isDark),
          'adoration': goldTextAccentFor(isDark: isDark),
        };
        accents.forEach((name, accent) {
          expect(contrast(accent, bg), greaterThanOrEqualTo(4.5),
              reason: '$name accent on the ${isDark ? 'dark' : 'light'} '
                  'background is ${contrast(accent, bg).toStringAsFixed(2)}:1');
        });
      }
    });
  });

  group('filled accents pick legible ink', () {
    test('onAccentFor clears AA on every accent, both themes', () {
      for (final isDark in [true, false]) {
        for (final accent in [
          primaryAccentFor(isDark: isDark),
          violetAccentFor(isDark: isDark),
          goldTextAccentFor(isDark: isDark),
          successAccentFor(isDark: isDark),
          warningAccentFor(isDark: isDark),
          errorAccentFor(isDark: isDark),
          bulletinAccentFor(isDark: isDark),
          kConfessionViolet,
          kPrimaryColor,
        ]) {
          expect(contrast(onAccentFor(accent), accent),
              greaterThanOrEqualTo(4.5),
              reason: 'ink on ${accent.toString()} is too close to the fill');
        }
      }
    });

    test('a light accent gets dark ink, not white', () {
      expect(onAccentFor(kAccentCandlelight), isNot(Colors.white));
      expect(onAccentFor(kPrimaryColor), Colors.white);
    });
  });

  group('semantic hues replace the stock Material swatches', () {
    // What these had been: Colors.purple at 3.00:1 on the dark card,
    // Colors.orange at 2.10:1 on cream. Material's swatches were drawn for a
    // white app bar and hold up against neither of this app's two grounds.
    test('every status hue clears AA on its own theme\'s card', () {
      for (final isDark in [true, false]) {
        final card = isDark ? kCardColorDark : kCardColor;
        final hues = <String, Color>{
          'success': successAccentFor(isDark: isDark),
          'warning': warningAccentFor(isDark: isDark),
          'error': errorAccentFor(isDark: isDark),
          'bulletin': bulletinAccentFor(isDark: isDark),
        };
        hues.forEach((name, hue) {
          expect(contrast(hue, card), greaterThanOrEqualTo(4.5),
              reason: '$name on the ${isDark ? 'dark' : 'light'} card is '
                  '${contrast(hue, card).toStringAsFixed(2)}:1');
        });
      }
    });

    test('the bulletin red stays red rather than following the gold', () {
      // primaryAccentFor turns the oxblood gold in dark mode, which is why the
      // bulletin card cannot just borrow it.
      expect(bulletinAccentFor(isDark: true),
          isNot(primaryAccentFor(isDark: true)));
      expect(bulletinAccentFor(isDark: true).r,
          greaterThan(bulletinAccentFor(isDark: true).b));
    });
  });

  group('cards have an edge on true black', () {
    test('the dark hairline is visible against both card and scaffold', () {
      // The card itself is 1.1:1 on the scaffold — the border is the only
      // thing separating them, so it has to out-contrast both sides.
      expect(contrast(kCardColorDark, kBackgroundColorDark), lessThan(1.2));
      expect(contrast(kCardBorderDark, kBackgroundColorDark),
          greaterThan(contrast(kCardColorDark, kBackgroundColorDark)));
      expect(contrast(kCardBorderDark, kCardColorDark), greaterThan(1.5));
    });

    test('light mode keeps its shadow instead of a border', () {
      expect(cardBorderFor(isDark: false), isNull);
      expect(cardBorderFor(isDark: true), isNotNull);
      expect(cardBorderSideFor(isDark: false), BorderSide.none);
      expect(cardBorderSideFor(isDark: true).color, kCardBorderDark);
    });
  });
}
