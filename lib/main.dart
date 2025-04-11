import 'package:flutter/material.dart';
// import 'services/parish_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/research_parish_page.dart';
import 'pages/find_parish_near_me_page.dart';
import 'globals.dart';

//void main() => runApp(MassGPTApp());

// final ParishService parishService = ParishService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await dotenv.load(fileName: ".env");
  // await parishService.loadParishData();
  runApp(MassGPTApp());
}

class MassGPTApp extends StatelessWidget {
  const MassGPTApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MassGPT',
      theme: _buildThemeData(),
      home: const HomePage(),
    );
  }

  ThemeData _buildThemeData() {
    // Define your color scheme in one place
    const Color backgroundColor = Color(0xFF003366); // Dark blue
    const Color accentColor = Color(0xFFFFA500);     // Orange
    const Color textColor = Color(0xFFFFFDD0);       // Cream

    return ThemeData(
      primaryColor: backgroundColor,
      // primarySwatch can be generated from a MaterialColor if needed.
      // For example, if you have the brand color in different shades.
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: backgroundColor,
        secondary: accentColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 48.0,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displayMedium: TextStyle(
          fontSize: 24.0,
          color: textColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 18.0,
          color: const Color.fromARGB(255, 251, 251, 251),
        ),
        titleLarge: TextStyle(
          fontSize: 18.0,
          color: textColor,
        ),
        displaySmall: TextStyle(
          fontSize: 18.0,
          color: backgroundColor,
        )
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: backgroundColor,      
          padding: const EdgeInsets.symmetric(vertical: 20.0),
        ),
      ),
    );
  }
}


class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline1 = theme.textTheme.displayLarge;
    final headline2 = theme.textTheme.displayMedium;

    return Scaffold(
      // Because we set scaffoldBackgroundColor in _buildThemeData,
      // we don’t need to set it here again. 
      body: SafeArea(
        child: Column(
          children: <Widget>[
            /// Top Section
            Expanded(
              flex: 1,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'MassGPT',
                      style: headline1,
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      'Find masses near you!',
                      style: headline2,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            /// Bottom Section
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    /// "Research a Parish" Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>  ResearchParishPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Research a Parish',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20.0),

                    /// "Find a Parish near me" Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FindParishNearMePage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Find a Parish near me',
                          textAlign: TextAlign.center,
                        ),
                      ),
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
}
