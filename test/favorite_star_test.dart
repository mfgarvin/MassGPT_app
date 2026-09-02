import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/main.dart' show favoritesManager;
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/pages/parish_detail_page.dart';
import 'package:parishfinder/widgets/remove_home_parish_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _parish = Parish.fromJson({
  'name': 'Saint Sebastian Parish',
  'parish_id': '0689',
  'address': '476 Mull Ave',
  'city': 'Akron',
  'zip_code': '44320',
});

Future<void> _pumpDetail(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: ParishDetailPage(parish: _parish)));
  await tester.pump();
}

Finder get _star => find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Icons.star || w.icon == Icons.star_border),
    );

/// Stands in for a My Parishes row: a star that removes through the dialog.
Widget _listRowStar() => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: IconButton(
            icon: const Icon(Icons.star),
            onPressed: () => confirmRemoveHomeParish(context, _parish),
          ),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // The manager is a global singleton, so leave it as we found it.
    if (favoritesManager.isFavorite(_parish)) {
      favoritesManager.toggleFavorite(_parish);
    }
  });

  group('parish detail page — plain toggle, no confirmation', () {
    testWidgets('adding takes one tap', (tester) async {
      await _pumpDetail(tester);

      await tester.tap(_star);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(favoritesManager.isFavorite(_parish), isTrue);
    });

    testWidgets('removing also takes one tap', (tester) async {
      favoritesManager.toggleFavorite(_parish);
      await _pumpDetail(tester);

      await tester.tap(_star);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'the detail star is deliberately unguarded');
      expect(favoritesManager.isFavorite(_parish), isFalse);
    });
  });

  group('My Parishes row — confirmed', () {
    testWidgets('"Keep" leaves it saved', (tester) async {
      favoritesManager.toggleFavorite(_parish);
      await tester.pumpWidget(_listRowStar());

      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();
      expect(find.text('Remove home parish?'), findsOneWidget);

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(favoritesManager.isFavorite(_parish), isTrue,
          reason: 'declining the dialog must not remove it');
    });

    testWidgets('"Remove" removes it', (tester) async {
      favoritesManager.toggleFavorite(_parish);
      await tester.pumpWidget(_listRowStar());

      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(favoritesManager.isFavorite(_parish), isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('dismissing by tapping outside leaves it saved', (tester) async {
      favoritesManager.toggleFavorite(_parish);
      await tester.pumpWidget(_listRowStar());

      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();
      // Barrier tap — the null result must not be read as "yes".
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(favoritesManager.isFavorite(_parish), isTrue);
    });
  });
}
