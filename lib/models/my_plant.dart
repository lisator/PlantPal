import 'package:cloud_firestore/cloud_firestore.dart';

import 'perenual_models.dart';

/// A plant the user has added to My Plants.
///
/// Stored at users/{uid}/myPlants/{perenualId}. A small snapshot of the care
/// info is saved with it so My Plants can render without calling Perenual.
class MyPlant {
  const MyPlant({
    required this.perenualId,
    required this.commonName,
    required this.scientificName,
    this.imageUrl,
    this.nickname,
    this.location,
    this.watering,
    this.wateringBenchmark,
    this.sunlight = const [],
    this.waterEveryDays,
    this.lastWateredAt,
    this.addedAt,
  });

  final int perenualId;
  final String commonName;
  final String scientificName;
  final String? imageUrl;
  final String? nickname;
  final String? location;
  final String? watering;
  final String? wateringBenchmark;
  final List<String> sunlight;

  /// How often to water, chosen by the user (prefilled from Perenual when it
  /// has data). Null means no schedule yet, so no watering reminders.
  final int? waterEveryDays;

  /// When the user last marked this plant watered.
  final DateTime? lastWateredAt;
  final DateTime? addedAt;

  String get displayName => nickname ?? commonName;

  /// One-line watering summary, e.g. "Average - every 7-10 days".
  String? get wateringSummary {
    final parts = [
      ?watering,
      if (wateringBenchmark != null) wateringBenchmark!.toLowerCase(),
    ];
    return parts.isEmpty ? null : parts.join(' - ');
  }

  /// The next watering date, or null without a schedule. Plants saved before
  /// reminders existed count from when they were added.
  DateTime? get nextWateringAt {
    final every = waterEveryDays;
    if (every == null) return null;
    final from = lastWateredAt ?? addedAt ?? DateTime.now();
    return from.add(Duration(days: every));
  }

  /// Calendar days until the next watering: 0 is today, negative is overdue.
  /// Null without a schedule.
  int? daysUntilWatering([DateTime? now]) {
    final next = nextWateringAt;
    if (next == null) return null;
    // Compare dates in UTC so daylight saving changes don't shift a day.
    DateTime day(DateTime t) => DateTime.utc(t.year, t.month, t.day);
    return day(next).difference(day(now ?? DateTime.now())).inDays;
  }

  PlantSearchResult toSearchResult() => PlantSearchResult(
        id: perenualId,
        commonName: commonName,
        scientificName: scientificName,
        thumbnailUrl: imageUrl,
      );

  factory MyPlant.fromDetails(
    PlantDetails details, {
    String? nickname,
    String? location,
    int? waterEveryDays,
  }) {
    String? clean(String? value) =>
        (value == null || value.trim().isEmpty) ? null : value.trim();

    return MyPlant(
      perenualId: details.id,
      commonName: details.commonName,
      scientificName: details.scientificName,
      imageUrl: details.imageUrl,
      nickname: clean(nickname),
      location: clean(location),
      watering: details.watering,
      wateringBenchmark: details.wateringBenchmark,
      sunlight: details.sunlight,
      waterEveryDays: waterEveryDays,
    );
  }

  factory MyPlant.fromFirestore(Map<String, dynamic> data) {
    final addedAt = data['addedAt'];
    final lastWateredAt = data['lastWateredAt'];
    final watering = data['watering'] as String?;
    final wateringBenchmark = data['wateringBenchmark'] as String?;
    return MyPlant(
      perenualId: (data['perenualId'] as num).toInt(),
      commonName: data['commonName'] as String? ?? 'Unknown plant',
      scientificName: data['scientificName'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      nickname: data['nickname'] as String?,
      location: data['location'] as String?,
      watering: watering,
      wateringBenchmark: wateringBenchmark,
      sunlight: (data['sunlight'] as List?)?.whereType<String>().toList() ??
          const [],
      // Plants saved before reminders existed have no field at all; give them
      // the Perenual suggestion. A saved null means the user left it blank.
      waterEveryDays: data.containsKey('waterEveryDays')
          ? (data['waterEveryDays'] as num?)?.toInt()
          : suggestedWaterEveryDays(
              benchmark: wateringBenchmark,
              watering: watering,
            ),
      lastWateredAt:
          lastWateredAt is Timestamp ? lastWateredAt.toDate() : null,
      addedAt: addedAt is Timestamp ? addedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'perenualId': perenualId,
        'commonName': commonName,
        'scientificName': scientificName,
        'imageUrl': imageUrl,
        'nickname': nickname,
        'location': location,
        'watering': watering,
        'wateringBenchmark': wateringBenchmark,
        'sunlight': sunlight,
        'waterEveryDays': waterEveryDays,
        // A newly added plant counts as watered today.
        'lastWateredAt': Timestamp.fromDate(lastWateredAt ?? DateTime.now()),
        'addedAt': FieldValue.serverTimestamp(),
      };
}

/// Longest watering interval the app accepts.
const int maxWaterEveryDays = 365;

/// A starting watering interval from Perenual's data, for the user to
/// confirm or change. Uses the low end of the benchmark ("Every 7-10 days"
/// gives 7), else a rough value for Perenual's watering level. Null when
/// Perenual has neither. Never derived from Wikipedia text.
int? suggestedWaterEveryDays({String? benchmark, String? watering}) {
  final match = RegExp(r'(\d+)').firstMatch(benchmark ?? '');
  if (match != null) {
    final value = int.parse(match.group(1)!);
    final unit = benchmark!.toLowerCase();
    final days = unit.contains('week')
        ? value * 7
        : unit.contains('month')
            ? value * 30
            : unit.contains('day')
                ? value
                : null;
    if (days != null && days > 0 && days <= maxWaterEveryDays) return days;
  }
  return switch (watering?.toLowerCase()) {
    'frequent' => 3,
    'average' => 7,
    'minimum' => 14,
    _ => null,
  };
}
