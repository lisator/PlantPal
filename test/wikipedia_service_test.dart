import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/services/wikipedia_service.dart';

void main() {
  group('WikipediaSummary.fromJson', () {
    test('parses a plant article', () {
      final summary = WikipediaSummary.fromJson({
        'type': 'standard',
        'title': 'Monstera deliciosa',
        'description': 'Species of plant',
        'extract': 'Monstera deliciosa, the Swiss cheese plant, is a species.',
        'thumbnail': {'source': 'https://upload.wikimedia.org/thumb.jpg', 'width': 330},
        'originalimage': {'source': 'https://upload.wikimedia.org/orig.jpg', 'width': 1200},
        'content_urls': {
          'desktop': {'page': 'https://en.wikipedia.org/wiki/Monstera_deliciosa'},
        },
      })!;

      expect(summary.extract, startsWith('Monstera deliciosa'));
      expect(summary.imageUrl, 'https://upload.wikimedia.org/orig.jpg');
      expect(summary.thumbnailUrl, 'https://upload.wikimedia.org/thumb.jpg');
      expect(summary.pageUrl, 'https://en.wikipedia.org/wiki/Monstera_deliciosa');
    });

    test('uses the thumbnail when the original image is huge', () {
      final summary = WikipediaSummary.fromJson({
        'type': 'standard',
        'title': 'Fern',
        'extract': 'A fern is a vascular plant.',
        'thumbnail': {'source': 'https://upload.wikimedia.org/thumb.jpg'},
        'originalimage': {'source': 'https://upload.wikimedia.org/orig.jpg', 'width': 6000},
      })!;

      expect(summary.imageUrl, 'https://upload.wikimedia.org/thumb.jpg');
    });

    test('rejects pages that are not about one plant', () {
      expect(
        WikipediaSummary.fromJson({
          'type': 'disambiguation',
          'title': 'Pothos',
          'extract': 'Pothos may refer to:',
        }),
        isNull,
      );
      expect(
        WikipediaSummary.fromJson({
          'type': 'standard',
          'title': 'Snakeplant',
          'description': 'Index of plants with the same common name',
          'extract': 'Snakeplant is a common name for:',
        }),
        isNull,
      );
    });
  });

  test('speciesTitle drops cultivars and varieties', () {
    expect(speciesTitle("Monstera deliciosa 'Thai Constellation'"), 'Monstera deliciosa');
    expect(speciesTitle('Ficus elastica var. decora'), 'Ficus elastica');
    expect(speciesTitle('Dracaena trifasciata'), 'Dracaena trifasciata');
    expect(speciesTitle(''), '');
  });

  group('extractCareExcerpts', () {
    const article = '''
Monstera deliciosa is a species of flowering plant.

== Distribution and growth ==
It is native to humid tropical forests and rarely grows in full sun.

== Cultivation ==
The plant requires a rich and loose soil. It needs very bright exposure, but not full sun.
The plant can be propagated by taking cuttings in moist soil.

=== Indoor cultivation ===
It prefers bright indirect light. It is usually watered when the soil has slightly dried out. It requires a well-draining, peat-based soil.

== Toxicity ==
The leaves are mildly toxic and should not be eaten in direct sunlight.
''';

    test('quotes care sentences, indoor sections first', () {
      final excerpts = extractCareExcerpts(article);

      expect(excerpts[CareTopic.water],
          'It is usually watered when the soil has slightly dried out.');
      expect(
        excerpts[CareTopic.light],
        'It prefers bright indirect light. '
        'It needs very bright exposure, but not full sun.',
      );
      expect(
        excerpts[CareTopic.soil],
        'It requires a well-draining, peat-based soil. '
        'The plant requires a rich and loose soil.',
      );
    });

    test('ignores habitat, propagation, and other sections', () {
      final excerpts = extractCareExcerpts(article).values.join(' ');

      expect(excerpts, isNot(contains('humid tropical forests')));
      expect(excerpts, isNot(contains('cuttings')));
      expect(excerpts, isNot(contains('toxic')));
    });

    test('does not treat a color as light or watering as soil', () {
      final excerpts = extractCareExcerpts('''
== Cultivation and uses ==
Cultivars have light green variegation. It only needs watering when the soil is dry.
''');

      expect(excerpts[CareTopic.light], isNull);
      expect(excerpts[CareTopic.soil], isNull);
      expect(excerpts[CareTopic.water], contains('only needs watering'));
    });

    test('returns nothing for an article without a care section', () {
      expect(
        extractCareExcerpts('A fern.\n\n== Description ==\nFerns grow in moist shade.'),
        isEmpty,
      );
    });
  });
}
