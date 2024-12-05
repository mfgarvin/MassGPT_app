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
  await dotenv.load(fileName: ".env");
  // await parishService.loadParishData();
  runApp(MassGPTApp());
}

class MassGPTApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MassGPT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Define the color scheme
    final Color backgroundColor = Color(0xFF003366); // Dark blue
    final Color accentColor = Color(0xFFFFA500); // Orange
    final Color textColor = Color(0xFFFFFDD0); // Cream

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'MassGPT',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 48.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    'Find masses near you!',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // "Research a Parish" Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: backgroundColor,
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResearchParishPage(),
                          ),
                        );
                      },
                      child: Text(
                        'Research a Parish',
                        style: TextStyle(
                          fontSize: 18.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(width: 20.0),
                  // "Find a Parish near me" Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: backgroundColor,
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FindParishNearMePage(),
                          ),
                        );
                        // Implement navigation to FindParishNearMePage when ready
                      },
                      child: Text(
                        'Find a Parish near me',
                        style: TextStyle(
                          fontSize: 18.0,
                        ),
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
    );
  }
}
