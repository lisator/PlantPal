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
    );
  }

  factory MyPlant.fromFirestore(Map<String, dynamic> data) {
    final addedAt = data['addedAt'];
    return MyPlant(
      perenualId: (data['perenualId'] as num).toInt(),
      commonName: data['commonName'] as String? ?? 'Unknown plant',
      scientificName: data['scientificName'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      nickname: data['nickname'] as String?,
      location: data['location'] as String?,
      watering: data['watering'] as String?,
      wateringBenchmark: data['wateringBenchmark'] as String?,
      sunlight: (data['sunlight'] as List?)?.whereType<String>().toList() ??
          const [],
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
        'addedAt': FieldValue.serverTimestamp(),
      };
}
