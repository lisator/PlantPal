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

    test('skips sentences that only mention a keyword in passing', () {
      final excerpts = extractCareExcerpts('''
== Cultivation ==
Most species were introduced from Japan in the 19th century, originating from shady locations with more moisture.
It does best in climates characterised by wet winters and dry summers.
Basil grows best if sown under glass in compost in a pot.
Increasing light intensity can enhance the dry matter content.
Once divided, each grouping must be planted in its own well-draining pot.
''');

      expect(excerpts, isEmpty);
    });

    test('prefers indoor advice over outdoor advice', () {
      final excerpts = extractCareExcerpts('''
== Cultivation ==
When grown outdoors, it prefers part shade to full shade.
When grown indoors, the plant prefers bright indirect light.
''');

      expect(excerpts[CareTopic.light], startsWith('When grown indoors'));
    });

    test('keeps excerpts short', () {
      final excerpts = extractCareExcerpts('''
== Cultivation ==
It prefers bright indirect light, which is easiest to provide near an east-facing window where morning sun is gentle, although a south-facing window shaded by a sheer curtain also works for most growers.
It needs bright, indirect light to keep its leaves variegated and avoid leggy growth.
It tolerates low light conditions.
''');

      expect(excerpts[CareTopic.light]!.length, lessThan(260));
    });

    test('careSectionsText keeps only care sections', () {
      final text = careSectionsText(article);

      expect(text, contains('rich and loose soil'));
      expect(text, contains('bright indirect light'));
      expect(text, isNot(contains('humid tropical forests')));
      expect(text, isNot(contains('mildly toxic')));
    });

    test('returns nothing for an article without a care section', () {
      expect(
        extractCareExcerpts('A fern.\n\n== Description ==\nFerns grow in moist shade.'),
        isEmpty,
      );
    });

    test('does not add advice from an outdoor paragraph', () {
      // from the monstera article: the second paragraph is about gardens,
      // but only its first sentence says so.
      final excerpts = extractCareExcerpts('''
== Cultivation ==
It is commonly grown outdoors in the tropics. It needs to be watered just to keep the soil slightly moist.
It is widely cultivated indoors. It is usually watered when the soil has slightly dried out.
''');

      expect(excerpts[CareTopic.water],
          'It is usually watered when the soil has slightly dried out.');
    });

    test('uses outdoor advice when nothing else covers the topic', () {
      final excerpts = extractCareExcerpts('''
== Cultivation ==
When grown outdoors, it prefers part shade to full shade.
''');

      expect(excerpts[CareTopic.light], startsWith('When grown outdoors'));
    });
  });

  group('cleanArticleText', () {
    test('removes editor notes and footnote marks', () {
      expect(
        cleanArticleText(
          'Currently [when?] about 40 are grown [citation needed]. '
          'It likes shade[1] and moist soil [a] ( ).',
        ),
        'Currently about 40 are grown. It likes shade and moist soil.',
      );
    });

    test('keeps brackets that are part of the text', () {
      expect(cleanArticleText('Called [ʔolˈʔæːs] locally.'),
          'Called [ʔolˈʔæːs] locally.');
      expect(cleanArticleText('An area of 170 m2 [1,800 sq ft].'),
          'An area of 170 m2 [1,800 sq ft].');
    });

    test('careParagraphs returns cleaned text', () {
      final text = careSectionsText(
        '== Cultivation ==\nIt prefers  bright light[2] .',
      );
      expect(text, 'It prefers bright light.');
    });
  });

  group('splitSentences', () {
    test('splits at sentence ends', () {
      expect(splitSentences('It likes sun. Water weekly! Is it toxic? No.'),
          ['It likes sun.', 'Water weekly!', 'Is it toxic?', 'No.']);
    });

    test('does not split after initials or abbreviations', () {
      // from the peperomia article
      expect(
        splitSentences(
          'Species include P. quadrangularis (syn. P. angulata) and P. rugosa. '
          'Use bark, e.g. Orchid bark, cf. Monstera. It grows fast.',
        ),
        [
          'Species include P. quadrangularis (syn. P. angulata) and P. rugosa.',
          'Use bark, e.g. Orchid bark, cf. Monstera.',
          'It grows fast.',
        ],
      );
    });
  });
}
