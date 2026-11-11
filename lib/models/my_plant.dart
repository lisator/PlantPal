import 'package:cloud_firestore/cloud_firestore.dart';

import 'perenual_models.dart';

/// A plant saved in the user's My Plants collection.
///
/// Plants may come from Perenual or PlantPal's AI analysis.
/// Perenual plants have a perenualId, while analysis-created
/// plants use a PlantPal-generated ID.
class MyPlant {
  const MyPlant({
    required this.id,
    this.perenualId,
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
    this.lastProgressAt,
  });

  final String id;
  final int? perenualId;
  final String commonName;
  final String scientificName;

  final String? imageUrl;
  final String? nickname;
  final String? location;
  final String? watering;
  final String? wateringBenchmark;
  final List<String> sunlight;

  /// How often to water the plant.
  /// Null means watering reminders are disabled.
  final int? waterEveryDays;

  /// Last time the user marked this plant as watered.
  final DateTime? lastWateredAt;

  /// When this plant was added to My Plants.
  final DateTime? addedAt;

  /// Last time the user recorded a progress update.
  /// Null means no separate progress update was recorded.
  final DateTime? lastProgressAt;

  String get displayName => nickname ?? commonName;

  /// Example: "Average - every 7-10 days".
  String? get wateringSummary {
    final parts = [
      ?watering,
      if (wateringBenchmark != null) wateringBenchmark!.toLowerCase(),
    ];

    return parts.isEmpty ? null : parts.join(' - ');
  }

  /// Calculate the next watering date.
  DateTime? get nextWateringAt {
    final every = waterEveryDays;

    if (every == null) return null;

    final from = lastWateredAt ?? addedAt ?? DateTime.now();

    return from.add(Duration(days: every));
  }

  /// Days until watering.
  /// 0 = today, negative = overdue.
  int? daysUntilWatering([DateTime? now]) {
    final next = nextWateringAt;

    if (next == null) return null;

    DateTime day(DateTime value) =>
        DateTime.utc(value.year, value.month, value.day);

    return day(next).difference(day(now ?? DateTime.now())).inDays;
  }

  /// Calculate the next date for a progress update.
  ///
  /// Default: 14 days after the latest progress update,
  /// or 14 days after the plant was first added.
  DateTime? nextProgressUpdateAt({int intervalDays = 14}) {
    if (intervalDays <= 0) return null;

    final from = lastProgressAt ?? addedAt;

    // Without a saved starting date we cannot
    // accurately calculate when a reminder is due.
    if (from == null) return null;

    return from.add(Duration(days: intervalDays));
  }

  /// Days until the next progress reminder.
  ///
  /// 0 = due today.
  /// Negative = overdue.
  /// Null = no available starting date.
  int? daysUntilProgressUpdate({int intervalDays = 14, DateTime? now}) {
    final next = nextProgressUpdateAt(intervalDays: intervalDays);

    if (next == null) return null;

    DateTime day(DateTime value) =>
        DateTime.utc(value.year, value.month, value.day);

    return day(next).difference(day(now ?? DateTime.now())).inDays;
  }

  /// True if the next progress update is due.
  bool needsProgressUpdate({int intervalDays = 14, DateTime? now}) {
    final days = daysUntilProgressUpdate(intervalDays: intervalDays, now: now);

    return days != null && days <= 0;
  }

  PlantSearchResult toSearchResult() => PlantSearchResult(
    id: perenualId ?? -1,
    commonName: commonName,
    scientificName: scientificName,
    thumbnailUrl: imageUrl,
  );

  /// Create a plant from Perenual details.
  factory MyPlant.fromDetails(
    PlantDetails details, {
    String? nickname,
    String? location,
    int? waterEveryDays,
  }) {
    String? clean(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();

    return MyPlant(
      id: '${details.id}',
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

  /// Create a plant from AI analysis.
  factory MyPlant.fromAnalysis({
    required String id,
    required String commonName,
    required String scientificName,
    String? imageUrl,
    String? nickname,
    String? location,
  }) {
    String? clean(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();

    return MyPlant(
      id: id,
      perenualId: null,
      commonName: commonName,
      scientificName: scientificName,
      imageUrl: imageUrl,
      nickname: clean(nickname),
      location: clean(location),
    );
  }

  /// Read a plant from Firestore.
  factory MyPlant.fromFirestore(Map<String, dynamic> data) {
    final addedAt = data['addedAt'];
    final lastWateredAt = data['lastWateredAt'];
    final lastProgressAt = data['lastProgressAt'];

    final watering = data['watering'] as String?;
    final wateringBenchmark = data['wateringBenchmark'] as String?;

    return MyPlant(
      id:
          data['id'] as String? ??
          '${(data['perenualId'] as num?)?.toInt() ?? 0}',

      perenualId: (data['perenualId'] as num?)?.toInt(),

      commonName: data['commonName'] as String? ?? 'Unknown plant',

      scientificName: data['scientificName'] as String? ?? '',

      imageUrl: data['imageUrl'] as String?,
      nickname: data['nickname'] as String?,
      location: data['location'] as String?,
      watering: watering,
      wateringBenchmark: wateringBenchmark,

      sunlight:
          (data['sunlight'] as List?)?.whereType<String>().toList() ?? const [],

      // Keep the existing watering fallback.
      waterEveryDays: data.containsKey('waterEveryDays')
          ? (data['waterEveryDays'] as num?)?.toInt()
          : suggestedWaterEveryDays(
              benchmark: wateringBenchmark,
              watering: watering,
            ),

      lastWateredAt: lastWateredAt is Timestamp ? lastWateredAt.toDate() : null,

      addedAt: addedAt is Timestamp ? addedAt.toDate() : null,

      // Older plants may not have this field yet.
      lastProgressAt: lastProgressAt is Timestamp
          ? lastProgressAt.toDate()
          : null,
    );
  }

  /// Save a new plant to Firestore.
  Map<String, dynamic> toFirestore() => {
    'id': id,
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

    // Preserve the existing watering behavior.
    'lastWateredAt': Timestamp.fromDate(lastWateredAt ?? DateTime.now()),

    'addedAt': FieldValue.serverTimestamp(),

    // A new plant has no separate progress update.
    'lastProgressAt': lastProgressAt == null
        ? null
        : Timestamp.fromDate(lastProgressAt!),
  };
}

/// Longest watering interval the app accepts.
const int maxWaterEveryDays = 365;

/// Suggest a watering schedule using Perenual data.
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

    if (days != null && days > 0 && days <= maxWaterEveryDays) {
      return days;
    }
  }

  return switch (watering?.toLowerCase()) {
    'frequent' => 3,
    'average' => 7,
    'minimum' => 14,
    _ => null,
  };
}
