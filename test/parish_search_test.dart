import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/utils/parish_search.dart';

Parish p(String name, String city, String zip) => Parish(
      name: name,
      address: '1 Main St',
      city: city,
      zipCode: zip,
      phone: '',
      website: '',
      massTimes: const [],
      confTimes: const [],
    );

final josephStrongsville = p('St. Joseph Parish', 'Strongsville', '44136');
final josephAmherst = p('St. Joseph Parish', 'Amherst', '44001');
final johnCathedral = p('Cathedral of St. John the Evangelist', 'Cleveland', '44114');
final josaphat = p('St. Josaphat Parish', 'Parma', '44134');

final all = [josephStrongsville, josephAmherst, johnCathedral, josaphat];

List<String> namesCities(List<Parish> r) =>
    [for (final x in r) '${x.name} (${x.city})'];

void main() {
  group('multi-word queries match across fields', () {
    test('name word + city word (the reported gap)', () {
      final results = searchParishes(all, 'joseph strongsville');
      expect(namesCities(results), ['St. Joseph Parish (Strongsville)']);
    });

    test('word order does not matter', () {
      expect(searchParishes(all, 'strongsville joseph'),
          searchParishes(all, 'joseph strongsville'));
    });

    test('name word + zip', () {
      final results = searchParishes(all, 'joseph 44136');
      expect(namesCities(results), ['St. Joseph Parish (Strongsville)']);
    });

    test('saint folding still applies per word', () {
      final results = searchParishes(all, 'st joseph strongsville');
      expect(namesCities(results), ['St. Joseph Parish (Strongsville)']);
    });

    test('every word must match — one stray word means no results', () {
      expect(searchParishes(all, 'joseph bratenahl'), isEmpty);
    });
  });

  group('ranking', () {
    test('contiguous name phrase outranks a same-word scatter', () {
      final results = searchParishes(all, 'joseph');
      // Both Josephs before the mid-word "josaphat"-style neighbours.
      expect(results.first.name, 'St. Joseph Parish');
      expect(results.length, 2);
    });

    test('city-only query returns that city', () {
      expect(namesCities(searchParishes(all, 'parma')),
          ['St. Josaphat Parish (Parma)']);
    });

    test('name start beats a later word', () {
      final results = searchParishes(all, 'john');
      expect(results.single, johnCathedral);
    });

    test('empty / whitespace query returns nothing', () {
      expect(searchParishes(all, ''), isEmpty);
      expect(searchParishes(all, '   '), isEmpty);
    });
  });
}
