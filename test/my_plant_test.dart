import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/my_plant.dart';

void main() {
  group('suggestedWaterEveryDays', () {
    test('uses the low end of the Perenual benchmark', () {
      expect(suggestedWaterEveryDays(benchmark: 'Every 7-10 days'), 7);
      expect(suggestedWaterEveryDays(benchmark: 'Every 2 weeks'), 14);
    });

    test('falls back to the watering level, then nothing', () {
      expect(suggestedWaterEveryDays(watering: 'Frequent'), 3);
      expect(suggestedWaterEveryDays(watering: 'Average'), 7);
      expect(suggestedWaterEveryDays(watering: 'Minimum'), 14);
      expect(suggestedWaterEveryDays(watering: 'None'), isNull);
      expect(suggestedWaterEveryDays(), isNull);
    });
  });

  group('daysUntilWatering', () {
    final now = DateTime(2026, 10, 16, 9);

    MyPlant plant({int? every, DateTime? lastWatered, DateTime? added}) =>
        MyPlant(
          perenualId: 1,
          commonName: 'Monstera',
          scientificName: 'Monstera deliciosa',
          waterEveryDays: every,
          lastWateredAt: lastWatered,
          addedAt: added,
        );

    test('counts calendar days from the last watering', () {
      expect(
        plant(every: 7, lastWatered: DateTime(2026, 10, 9, 22))
            .daysUntilWatering(now),
        0,
      );
      expect(
        plant(every: 7, lastWatered: DateTime(2026, 10, 12))
            .daysUntilWatering(now),
        3,
      );
      expect(
        plant(every: 3, lastWatered: DateTime(2026, 10, 10))
            .daysUntilWatering(now),
        -3,
      );
    });

    test('uses the added date when never watered', () {
      expect(
        plant(every: 7, added: DateTime(2026, 10, 14)).daysUntilWatering(now),
        5,
      );
    });

    test('is null without a schedule', () {
      expect(plant(lastWatered: now).daysUntilWatering(now), isNull);
    });
  });

  group('MyPlant.fromFirestore', () {
    final base = {
      'perenualId': 1,
      'commonName': 'Monstera',
      'wateringBenchmark': 'Every 7-10 days',
      'addedAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
    };

    test('gives plants saved before reminders a suggested schedule', () {
      expect(MyPlant.fromFirestore(base).waterEveryDays, 7);
    });

    test('keeps a schedule the user left blank', () {
      expect(
        MyPlant.fromFirestore({...base, 'waterEveryDays': null}).waterEveryDays,
        isNull,
      );
    });

    test('reads the saved schedule and last watering', () {
      final plant = MyPlant.fromFirestore({
        ...base,
        'waterEveryDays': 5,
        'lastWateredAt': Timestamp.fromDate(DateTime(2026, 10, 15)),
      });
      expect(plant.waterEveryDays, 5);
      expect(plant.lastWateredAt, DateTime(2026, 10, 15));
    });
  });
}
