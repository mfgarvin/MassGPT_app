import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parishfinder/main.dart';

/// Dark mode is a stored preference, not session state — it has to survive a
/// relaunch. These exercise the global [themeNotifier] directly; there is one
/// instance, so each test resets it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => themeNotifier.setDarkMode(false));

  test('defaults to light when nothing was ever saved', () async {
    SharedPreferences.setMockInitialValues({});
    await themeNotifier.init();
    expect(themeNotifier.isDarkMode, isFalse);
  });

  test('restores dark mode saved by a previous launch', () async {
    SharedPreferences.setMockInitialValues({'dark_mode': true});
    await themeNotifier.init();
    expect(themeNotifier.isDarkMode, isTrue);
  });

  test('writes the choice so the next launch can restore it', () async {
    SharedPreferences.setMockInitialValues({});
    await themeNotifier.init();

    themeNotifier.setDarkMode(true);
    // The write is fire-and-forget; let it land.
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), isTrue);
  });

  test('turning dark mode back off persists too', () async {
    SharedPreferences.setMockInitialValues({'dark_mode': true});
    await themeNotifier.init();

    themeNotifier.toggleTheme();
    await Future<void>.delayed(Duration.zero);

    expect(themeNotifier.isDarkMode, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), isFalse);
  });
}
