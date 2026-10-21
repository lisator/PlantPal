import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/services/care_ai_service.dart';
import 'package:plantpal/services/wikipedia_service.dart';

void main() {
  const article = '''
Monstera deliciosa is a species of flowering plant.

== Cultivation ==
It prefers bright indirect light. It is usually watered when the soil has
slightly dried out.
It requires a well-draining, peat-based soil.
''';

  group('verifiedExcerpts', () {
    test('keeps sentences copied from the article', () {
      final excerpts = verifiedExcerpts({
        'water': 'It is usually watered when the soil has slightly dried out.',
        'light': 'It prefers bright indirect light.',
        'soil': 'It requires a well-draining, peat-based soil.',
      }, article);

      expect(excerpts[CareTopic.water], startsWith('It is usually watered'));
      expect(excerpts[CareTopic.light], 'It prefers bright indirect light.');
      expect(excerpts[CareTopic.soil], contains('peat-based'));
    });

    test('drops answers the AI made up or reworded', () {
      final excerpts = verifiedExcerpts({
        'water': 'Water it once a week.',
        'light': 'It likes bright, indirect sunlight.',
        // One real sentence plus one invented one: the whole answer is dropped.
        'soil': 'It requires a well-draining, peat-based soil. Add sand.',
      }, article);

      expect(excerpts, isEmpty);
    });

    test('leaves out topics the AI found nothing for', () {
      final excerpts = verifiedExcerpts({
        'water': '',
        'light': 'It prefers bright indirect light.',
      }, article);

      expect(excerpts.keys, [CareTopic.light]);
    });
  });
}
