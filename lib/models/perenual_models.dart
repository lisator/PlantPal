// Models for plant data returned by the Perenual API (https://perenual.com/docs/api).
//
// Perenual's free tier only returns full data for species with id <= 3000.
// For other species, many fields hold an "Upgrade Plans..." string instead of
// real data, so every parser here treats unexpected shapes as "missing".

/// Highest species id Perenual's free plan returns care details for.
/// The details endpoint answers 429 "Please Upgrade Plan" above this.
const int perenualFreeTierMaxId = 3000;

/// One row in the plant search results list.
class PlantSearchResult {
  const PlantSearchResult({
    required this.id,
    required this.commonName,
    required this.scientificName,
    this.otherNames = const [],
    this.thumbnailUrl,
  });

  final int id;
  final String commonName;
  final String scientificName;
  final List<String> otherNames;
  final String? thumbnailUrl;

  /// False for species whose care details need a paid Perenual plan.
  bool get hasFullDetails => id <= perenualFreeTierMaxId;

  factory PlantSearchResult.fromJson(Map<String, dynamic> json) {
    final scientific = _stringList(json['scientific_name']);
    return PlantSearchResult(
      id: json['id'] as int,
      commonName: _titleCase(_string(json['common_name']) ?? 'Unknown plant'),
      scientificName: scientific.isNotEmpty ? scientific.first : '',
      otherNames: _stringList(json['other_name']),
      thumbnailUrl: _imageUrl(json['default_image'], 'thumbnail'),
    );
  }
}

/// One page of search results.
class PlantSearchPage {
  const PlantSearchPage({
    required this.results,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<PlantSearchResult> results;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory PlantSearchPage.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List?) ?? const [];
    return PlantSearchPage(
      results: data
          .whereType<Map<String, dynamic>>()
          .where((item) => item['id'] is int)
          .map(PlantSearchResult.fromJson)
          .toList(),
      currentPage: _int(json['current_page']) ?? 1,
      lastPage: _int(json['last_page']) ?? 1,
      total: _int(json['total']) ?? data.length,
    );
  }
}

/// Full care details for a single species.
class PlantDetails {
  const PlantDetails({
    required this.id,
    required this.commonName,
    required this.scientificName,
    this.otherNames = const [],
    this.family,
    this.type,
    this.cycle,
    this.description,
    this.imageUrl,
    this.watering,
    this.wateringBenchmark,
    this.sunlight = const [],
    this.soil = const [],
    this.careLevel,
    this.maintenance,
    this.growthRate,
    this.hardiness,
    this.indoor,
    this.droughtTolerant,
    this.poisonousToHumans,
    this.poisonousToPets,
    this.careGuideUrl,
    this.careGuide = const {},
    this.wikipediaUrl,
    this.isLimited = false,
  });

  /// Basic info for a species whose care details need a paid Perenual plan,
  /// built from the search result without calling the API.
  factory PlantDetails.basic(PlantSearchResult result) {
    return PlantDetails(
      id: result.id,
      commonName: result.commonName,
      scientificName: result.scientificName,
      otherNames: result.otherNames,
      imageUrl: result.thumbnailUrl,
      isLimited: true,
    );
  }

  final int id;
  final String commonName;
  final String scientificName;
  final List<String> otherNames;
  final String? family;
  final String? type;
  final String? cycle;
  final String? description;
  final String? imageUrl;

  /// Perenual's watering category: Frequent, Average, Minimum, or None.
  final String? watering;

  /// Human-readable interval, e.g. "Every 7-10 days".
  final String? wateringBenchmark;
  final List<String> sunlight;
  final List<String> soil;
  final String? careLevel;
  final String? maintenance;
  final String? growthRate;

  /// USDA hardiness zones, e.g. "Zones 7-10".
  final String? hardiness;
  final bool? indoor;
  final bool? droughtTolerant;
  final bool? poisonousToHumans;
  final bool? poisonousToPets;

  /// URL for Perenual's care guide endpoint for this species, if provided.
  final String? careGuideUrl;

  /// Care guide sections keyed by type (e.g. "watering", "sunlight", "pruning").
  final Map<String, String> careGuide;

  /// Set when the description or image came from Wikipedia, for attribution.
  final String? wikipediaUrl;

  /// True when only basic info is available (see [PlantDetails.basic]).
  final bool isLimited;

  PlantDetails copyWith({
    String? description,
    String? imageUrl,
    Map<String, String>? careGuide,
    String? wikipediaUrl,
  }) {
    return PlantDetails(
      id: id,
      commonName: commonName,
      scientificName: scientificName,
      otherNames: otherNames,
      family: family,
      type: type,
      cycle: cycle,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      watering: watering,
      wateringBenchmark: wateringBenchmark,
      sunlight: sunlight,
      soil: soil,
      careLevel: careLevel,
      maintenance: maintenance,
      growthRate: growthRate,
      hardiness: hardiness,
      indoor: indoor,
      droughtTolerant: droughtTolerant,
      poisonousToHumans: poisonousToHumans,
      poisonousToPets: poisonousToPets,
      careGuideUrl: careGuideUrl,
      careGuide: careGuide ?? this.careGuide,
      wikipediaUrl: wikipediaUrl ?? this.wikipediaUrl,
      isLimited: isLimited,
    );
  }

  factory PlantDetails.fromJson(Map<String, dynamic> json) {
    final scientific = _stringList(json['scientific_name']);

    String? benchmark;
    final rawBenchmark = json['watering_general_benchmark'];
    if (rawBenchmark is Map) {
      // Perenual sometimes wraps the value in literal quotes: "\"7-10\"".
      final value = _string(rawBenchmark['value'])?.replaceAll('"', '');
      final unit = _string(rawBenchmark['unit']);
      if (value != null && value.isNotEmpty) {
        benchmark = 'Every $value ${unit ?? 'days'}';
      }
    }

    String? hardiness;
    final rawHardiness = json['hardiness'];
    if (rawHardiness is Map) {
      final min = _string(rawHardiness['min']);
      final max = _string(rawHardiness['max']);
      if (min != null && max != null) {
        hardiness = min == max ? 'Zone $min' : 'Zones $min-$max';
      }
    }

    return PlantDetails(
      id: json['id'] as int,
      commonName: _titleCase(_string(json['common_name']) ?? 'Unknown plant'),
      scientificName: scientific.isNotEmpty ? scientific.first : '',
      otherNames: _stringList(json['other_name']),
      family: _string(json['family']),
      type: _capitalize(_string(json['type'])),
      cycle: _capitalize(_string(json['cycle'])),
      description: _string(json['description']),
      imageUrl: _imageUrl(json['default_image'], 'regular_url') ??
          _imageUrl(json['default_image'], 'medium_url'),
      watering: _capitalize(_string(json['watering'])),
      wateringBenchmark: benchmark,
      sunlight: _stringList(json['sunlight']).map(_capitalize).whereType<String>().toList(),
      soil: _stringList(json['soil']).map(_capitalize).whereType<String>().toList(),
      careLevel: _capitalize(_string(json['care_level'])),
      maintenance: _capitalize(_string(json['maintenance'])),
      growthRate: _capitalize(_string(json['growth_rate'])),
      hardiness: hardiness,
      indoor: _bool(json['indoor']),
      droughtTolerant: _bool(json['drought_tolerant']),
      poisonousToHumans: _bool(json['poisonous_to_humans']),
      poisonousToPets: _bool(json['poisonous_to_pets']),
      careGuideUrl: _string(json['care_guides']),
    );
  }
}

/// Parses the care guide list response into {section type: description}.
Map<String, String> parseCareGuide(Map<String, dynamic> json) {
  final guide = <String, String>{};
  final data = json['data'];
  if (data is! List || data.isEmpty || data.first is! Map) return guide;

  final sections = (data.first as Map)['section'];
  if (sections is! List) return guide;

  for (final section in sections.whereType<Map>()) {
    final type = _string(section['type']);
    final description = _string(section['description']);
    if (type != null && description != null) {
      guide[type.toLowerCase()] = description;
    }
  }
  return guide;
}

// ---------------------------------------------------------------------------
// Defensive JSON helpers
// ---------------------------------------------------------------------------

bool _isPaywalled(String value) =>
    value.startsWith('Upgrade Plans') || value.contains('upgrade_access');

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || _isPaywalled(text)) return null;
  return text;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _bool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    if (value == '1' || value.toLowerCase() == 'true') return true;
    if (value == '0' || value.toLowerCase() == 'false') return false;
  }
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map(_string).whereType<String>().toList();
  }
  final single = _string(value);
  return single == null ? const [] : [single];
}

String? _imageUrl(dynamic image, String key) {
  if (image is! Map) return null;
  return _string(image[key]);
}

String? _capitalize(String? value) {
  if (value == null || value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _titleCase(String value) {
  return value
      .split(' ')
      .map((word) => word.isEmpty ? word : _capitalize(word)!)
      .join(' ');
}
