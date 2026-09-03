import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parishfinder/main.dart';

/// The theme choice is a stored preference, not session state — it has to
/// survive a relaunch. These exercise the global [themeNotifier] directly;
/// there is one instance, so each test resets it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => themeNotifier.setDarkMode(false));

  test('defaults to light when nothing was ever saved', () async {
    SharedPreferences.setMockInitialValues({});
    await themeNotifier.init();
    expect(themeNotifier.choice, ThemeChoice.light,
        reason: 'a fresh install starts on the parchment theme; "system" is '
            'an opt-in in Settings');
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

  group('migrating from the old dark_mode switch', () {
    test('an explicit dark choice is kept as an explicit choice', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': true});
      await themeNotifier.init();
      expect(themeNotifier.choice, ThemeChoice.dark,
          reason: 'someone who turned the old switch on meant it — the '
              "phone's setting must not override them");
      expect(themeNotifier.isDarkMode, isTrue);
    });

    test('an explicit light choice is kept too', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': false});
      await themeNotifier.init();
      expect(themeNotifier.choice, ThemeChoice.light);
    });

    test('the new key wins once it exists', () async {
      SharedPreferences.setMockInitialValues({
        'dark_mode': true,
        'theme_choice': 'system',
      });
      await themeNotifier.init();
      expect(themeNotifier.choice, ThemeChoice.system);
    });

    test('an unrecognised stored value falls back to the default', () async {
      SharedPreferences.setMockInitialValues({'theme_choice': 'sepia'});
      await themeNotifier.init();
      expect(themeNotifier.choice, ThemeChoice.light);
    });
  });

  test('an explicit choice still writes the legacy key', () async {
    SharedPreferences.setMockInitialValues({});
    await themeNotifier.init();

    themeNotifier.setChoice(ThemeChoice.dark);
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_choice'), 'dark');
    // Kept so an older build reinstalled over this one still finds it.
    expect(prefs.getBool('dark_mode'), isTrue);
  });
}
