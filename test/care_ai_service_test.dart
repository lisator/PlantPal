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

  group('verifiedTips', () {
    const sources = {
      'water': 'Average - 7-10 days\n\nWater your plant thoroughly about '
          'once a week, letting the top inch of soil dry out between waterings.',
      'light': 'It prefers bright indirect light.',
    };

    test('keeps short tips whose quote is in the source', () {
      final tips = verifiedTips({
        'water': {
          'tip': 'Water about once a week, once the top inch of soil is dry.',
          'quote': 'letting the top inch of soil dry out between waterings.',
        },
        'light': {
          'tip': 'Give it bright, indirect light.',
          'quote': '"It prefers bright indirect light"',
        },
      }, sources);

      expect(tips['water'], startsWith('Water about once a week'));
      expect(tips['light'], 'Give it bright, indirect light.');
    });

    test('drops tips with a made-up quote, no quote, or too much text', () {
      final tips = verifiedTips({
        'water': {'tip': 'Mist it daily.', 'quote': 'mist it daily'},
        'light': {'tip': 'Bright light.', 'quote': ''},
      }, sources);
      expect(tips, isEmpty);

      final long = verifiedTips({
        'light': {
          'tip': 'Bright indirect light. ' * 12,
          'quote': 'bright indirect light',
        },
      }, sources);
      expect(long, isEmpty);
    });

    test('ignores topics that were not asked for', () {
      final tips = verifiedTips({
        'soil': {'tip': 'Use peat.', 'quote': 'bright indirect light'},
      }, sources);

      expect(tips, isEmpty);
    });
  });
}
