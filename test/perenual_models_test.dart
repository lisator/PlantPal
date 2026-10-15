import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/perenual_models.dart';

const _upgrade =
    'Upgrade Plans To Premium/Supreme - https://perenual.com/subscription-api-pricing. Im sorry';

void main() {
  group('PlantSearchPage', () {
    test('parses results and pagination', () {
      final page = PlantSearchPage.fromJson({
        'data': [
          {
            'id': 1,
            'common_name': 'european Silver Fir',
            'scientific_name': ['Abies alba'],
            'other_name': ['Common Silver Fir'],
            'default_image': {
              'thumbnail': 'https://perenual.com/storage/thumb.jpg',
            },
          },
          {
            'id': 5000,
            'common_name': 'paywalled plant',
            'scientific_name': ['Planta premium'],
            'other_name': _upgrade,
            'default_image': null,
          },
        ],
        'current_page': 1,
        'last_page': 3,
        'total': 75,
      });

      expect(page.results, hasLength(2));
      expect(page.hasMore, isTrue);
      expect(page.total, 75);
      expect(page.results[0].commonName, 'European Silver Fir');
      expect(page.results[0].scientificName, 'Abies alba');
      expect(page.results[0].thumbnailUrl, 'https://perenual.com/storage/thumb.jpg');
      expect(page.results[1].otherNames, isEmpty);
      expect(page.results[1].thumbnailUrl, isNull);
    });
  });

  group('PlantDetails', () {
    test('parses care fields', () {
      final details = PlantDetails.fromJson({
        'id': 1,
        'common_name': 'european silver fir',
        'scientific_name': ['Abies alba'],
        'family': 'Pinaceae',
        'type': 'tree',
        'cycle': 'Perennial',
        'watering': 'Frequent',
        'watering_general_benchmark': {'value': '"7-10"', 'unit': 'days'},
        'sunlight': ['full sun', 'part shade'],
        'soil': ['Loamy'],
        'hardiness': {'min': '7', 'max': '7'},
        'indoor': false,
        'poisonous_to_pets': 1,
        'poisonous_to_humans': 0,
        'care_level': 'Medium',
        'care_guides': 'http://perenual.com/api/species-care-guide-list?species_id=1',
        'default_image': {'regular_url': 'https://perenual.com/storage/regular.jpg'},
      });

      expect(details.commonName, 'European Silver Fir');
      expect(details.wateringBenchmark, 'Every 7-10 days');
      expect(details.sunlight, ['Full sun', 'Part shade']);
      expect(details.hardiness, 'Zone 7');
      expect(details.poisonousToPets, isTrue);
      expect(details.poisonousToHumans, isFalse);
      expect(details.type, 'Tree');
      expect(details.imageUrl, 'https://perenual.com/storage/regular.jpg');
    });

    test('treats paywalled fields as missing', () {
      final details = PlantDetails.fromJson({
        'id': 5000,
        'common_name': 'premium plant',
        'scientific_name': ['Planta premium'],
        'watering': _upgrade,
        'sunlight': _upgrade,
        'soil': [_upgrade],
        'hardiness': _upgrade,
        'description': _upgrade,
        'default_image': {
          'regular_url': 'https://perenual.com/storage/image/upgrade_access.jpg',
        },
      });

      expect(details.watering, isNull);
      expect(details.sunlight, isEmpty);
      expect(details.soil, isEmpty);
      expect(details.hardiness, isNull);
      expect(details.description, isNull);
      expect(details.imageUrl, isNull);
    });
  });

  test('parseCareGuide maps sections by type', () {
    final guide = parseCareGuide({
      'data': [
        {
          'section': [
            {'type': 'watering', 'description': 'Water weekly.'},
            {'type': 'sunlight', 'description': 'Full sun.'},
          ],
        },
      ],
    });

    expect(guide, {'watering': 'Water weekly.', 'sunlight': 'Full sun.'});
  });
}
