import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Register the app's bundled fonts with the test binding.
///
/// Without this, text in a widget test measures in whatever fallback font the
/// harness has, and google_fonts registers the real face *asynchronously* — so
/// a test that measures text gets fallback metrics or Inter metrics depending
/// on whether an earlier test in the same file happened to trigger the load.
/// That difference is large (a chip that fits at one metric wraps at the
/// other), which makes any layout assertion about text width order-dependent.
///
/// Call this from `setUpAll` in any test that asserts on measured text.
/// google_fonts names a loaded family `<Family>_<weight>`, e.g. `Inter_600`;
/// `w400` is spelled `regular`. See `test/bundled_fonts_test.dart` for the
/// asset names.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const faces = {
    'Inter_regular': 'assets/google_fonts/Inter-Regular.ttf',
    'Inter_500': 'assets/google_fonts/Inter-Medium.ttf',
    'Inter_600': 'assets/google_fonts/Inter-SemiBold.ttf',
    'Inter_700': 'assets/google_fonts/Inter-Bold.ttf',
    'Inter_800': 'assets/google_fonts/Inter-ExtraBold.ttf',
    'CormorantGaramond_600':
        'assets/google_fonts/CormorantGaramond-SemiBold.ttf',
    'CormorantGaramond_700': 'assets/google_fonts/CormorantGaramond-Bold.ttf',
  };
  for (final entry in faces.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

/// Width of [text] in [style] at [scale], measured the way the widgets do.
double measureText(String text, TextStyle style, {double scale = 1.0}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: TextScaler.linear(scale),
  )..layout();
  return painter.width;
}
