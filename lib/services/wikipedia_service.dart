import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The parts of a Wikipedia article summary PlantPal uses.
class WikipediaSummary {
  const WikipediaSummary({
    required this.title,
    required this.extract,
    required this.pageUrl,
    this.imageUrl,
    this.thumbnailUrl,
  });

  final String title;

  /// Plain-text first paragraph of the article.
  final String extract;
  final String pageUrl;

  /// A large-enough image for the details page header.
  final String? imageUrl;

  /// A small image for list rows.
  final String? thumbnailUrl;

  /// Returns null for pages that aren't about a single plant (disambiguation
  /// pages, "index of plants with the same common name", missing extracts).
  static WikipediaSummary? fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'standard') return null;
    final description = (json['description'] as String? ?? '').toLowerCase();
    if (description.contains('same common name') ||
        description.startsWith('index of') ||
        description.startsWith('topics referred to')) {
      return null;
    }

    final extract = (json['extract'] as String?)?.trim();
    final title = json['title'] as String?;
    if (extract == null || extract.isEmpty || title == null) return null;

    final urls = json['content_urls'];
    final pageUrl = urls is Map && urls['desktop'] is Map
        ? urls['desktop']['page'] as String?
        : null;

    String? source(dynamic image) =>
        image is Map ? image['source'] as String? : null;

    final original = json['originalimage'];
    final thumbnail = source(json['thumbnail']);
    // Originals can be many megabytes, so only use modest-sized ones.
    final originalWidth = original is Map ? original['width'] : null;
    final useOriginal = originalWidth is int && originalWidth <= _maxImageWidth;

    return WikipediaSummary(
      title: title,
      extract: extract,
      pageUrl: pageUrl ??
          'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
      imageUrl: (useOriginal ? source(original) : null) ?? thumbnail,
      thumbnailUrl: thumbnail ?? (useOriginal ? source(original) : null),
    );
  }

  static const int _maxImageWidth = 1600;
}

/// Fills in descriptions, images, and care excerpts that Perenual doesn't
/// provide, using Wikipedia's free APIs (no key, no daily limit).
///
/// Lookups never throw: any failure just means "no Wikipedia data". Results,
/// including misses, are cached on the device for [_cacheDuration].
class WikipediaService {
  WikipediaService._();

  static final WikipediaService instance = WikipediaService._();

  static const String _summaryUrl = 'https://en.wikipedia.org/api/rest_v1/page/summary';
  static const String _actionApiUrl = 'https://en.wikipedia.org/w/api.php';
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _cacheDuration = Duration(days: 30);
  static const String _cachePrefix = 'wikipedia_cache:';
  // Bump the version when extractCareExcerpts changes, so old picks are dropped.
  static const String _careCachePrefix = 'wikipedia_care_v1:';

  /// Wikimedia asks API clients to identify themselves. Browsers don't allow
  /// setting User-Agent, so this is the header they read instead.
  static const Map<String, String> _headers = {
    'Api-User-Agent': 'PlantPal/1.0 (student plant care app)',
  };

  final Map<String, Future<WikipediaSummary?>> _summaries = {};
  final Map<String, Future<Map<CareTopic, String>>> _careExcerpts = {};

  /// Finds the article for a plant, trying the scientific name first (most
  /// precise), then the common name.
  Future<WikipediaSummary?> findPlant({
    required String scientificName,
    required String commonName,
  }) async {
    for (final title in [speciesTitle(scientificName), commonName.trim()]) {
      if (title.isEmpty) continue;
      final summary = await _summary(title);
      if (summary != null) return summary;
    }
    return null;
  }

  /// Care sentences quoted from [article]'s cultivation sections, by topic.
  /// Topics the article doesn't cover are left out.
  Future<Map<CareTopic, String>> careExcerpts(WikipediaSummary article) {
    return _careExcerpts[article.title] ??= _loadCareExcerpts(article.title);
  }

  Future<WikipediaSummary?> _summary(String title) {
    final key = title.toLowerCase();
    return _summaries[key] ??= _loadSummary(key);
  }

  Future<WikipediaSummary?> _loadSummary(String title) async {
    try {
      final body = await _cachedJson(_cachePrefix + title, () => _fetchSummary(title));
      return body is Map<String, dynamic> ? WikipediaSummary.fromJson(body) : null;
    } catch (e) {
      // Network problems aren't cached, so the next visit can try again.
      debugPrint('Wikipedia lookup for "$title" failed: $e');
      _summaries.remove(title);
      return null;
    }
  }

  Future<Map<CareTopic, String>> _loadCareExcerpts(String title) async {
    try {
      // Only the excerpts are cached; whole articles are too big to keep.
      final body = await _cachedJson(_careCachePrefix + title, () async {
        final text = await _fetchArticleText(title);
        if (text == null) return <String, String>{};
        return {
          for (final entry in extractCareExcerpts(text).entries)
            entry.key.name: entry.value,
        };
      });
      if (body is! Map) return const {};
      return {
        for (final topic in CareTopic.values)
          if (body[topic.name] is String) topic: body[topic.name] as String,
      };
    } catch (e) {
      debugPrint('Wikipedia care lookup for "$title" failed: $e');
      _careExcerpts.remove(title);
      return const {};
    }
  }

  /// Returns the saved JSON for [cacheKey] if it is fresh, otherwise runs
  /// [fetch] and saves the result. Errors from [fetch] are not saved.
  Future<Object?> _cachedJson(
    String cacheKey,
    Future<Object?> Function() fetch,
  ) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(cacheKey);
      if (saved != null) {
        final entry = jsonDecode(saved) as Map<String, dynamic>;
        final savedAt = DateTime.fromMillisecondsSinceEpoch(entry['savedAt'] as int);
        if (DateTime.now().difference(savedAt) < _cacheDuration) {
          return entry['body'];
        }
      }
    } catch (e) {
      debugPrint('Wikipedia cache read failed: $e');
    }

    final body = await fetch();
    try {
      await prefs?.setString(
        cacheKey,
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'body': body,
        }),
      );
    } catch (e) {
      debugPrint('Wikipedia cache write failed: $e');
    }
    return body;
  }

  /// Returns the raw summary JSON, or null when there is no such article.
  /// Throws on network errors.
  Future<Map<String, dynamic>?> _fetchSummary(String title) async {
    final path = Uri.encodeComponent(title.replaceAll(' ', '_'));
    final response = await http
        .get(Uri.parse('$_summaryUrl/$path'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    return body is Map<String, dynamic> ? body : null;
  }

  /// Returns the whole article as plain text with "== Heading ==" lines, or
  /// null when there is no such article. Throws on network errors.
  Future<String?> _fetchArticleText(String title) async {
    final response = await http
        .get(
          Uri.parse(_actionApiUrl).replace(queryParameters: {
            'action': 'query',
            'format': 'json',
            'formatversion': '2',
            'prop': 'extracts',
            'explaintext': '1',
            'exsectionformat': 'wiki',
            'redirects': '1',
            'titles': title,
            // Allows the request from the web build.
            'origin': '*',
          }),
          headers: _headers,
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    final query = body is Map ? body['query'] : null;
    final pages = query is Map ? query['pages'] : null;
    if (pages is! List || pages.isEmpty || pages.first is! Map) return null;
    final extract = (pages.first as Map)['extract'];
    return extract is String ? extract : null;
  }
}

/// Care sections on the plant details page that can fall back to Wikipedia.
enum CareTopic { water, light, soil }

/// Picks sentences about each [CareTopic] from a plain-text Wikipedia
/// article, as written.
///
/// Wikipedia doesn't have structured care data, so these sentences are meant
/// to be shown as quotes, never turned into values like "every 7 days". Only
/// cultivation/care sections are used (not habitat, which describes the wild),
/// and sentences from indoor/houseplant sections come first.
Map<CareTopic, String> extractCareExcerpts(String article) {
  final candidates = <CareTopic, List<(bool, String)>>{
    for (final topic in CareTopic.values) topic: [],
  };

  var inCareSection = false;
  var isIndoorSection = false;
  for (final line in article.split('\n')) {
    final heading = RegExp(r'^(=+)\s*(.*?)\s*=+$').firstMatch(line.trim());
    if (heading != null) {
      final name = heading.group(2)!;
      if (heading.group(1)!.length == 2) {
        inCareSection = _careHeading.hasMatch(name);
        isIndoorSection = _indoorHeading.hasMatch(name);
      } else if (_careHeading.hasMatch(name)) {
        // e.g. "=== As a houseplant ===" under "Uses".
        inCareSection = true;
        isIndoorSection = _indoorHeading.hasMatch(name);
      }
      continue;
    }
    if (!inCareSection) continue;

    for (final sentence in line.trim().split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'))) {
      if (sentence.isEmpty ||
          sentence.length > _maxSentenceLength ||
          _skipSentence.hasMatch(sentence)) {
        continue;
      }
      final isWater = _waterPattern.hasMatch(sentence);
      final matches = {
        CareTopic.water: isWater,
        CareTopic.light: _lightPattern.hasMatch(sentence),
        // "Water when the soil feels dry" is about watering, not soil.
        CareTopic.soil: _soilMaterialPattern.hasMatch(sentence) ||
            (!isWater && RegExp(r'\bsoils?\b', caseSensitive: false).hasMatch(sentence)),
      };
      for (final topic in CareTopic.values) {
        if (matches[topic]!) candidates[topic]!.add((isIndoorSection, sentence));
      }
    }
  }

  return {
    for (final MapEntry(key: topic, value: sentences) in candidates.entries)
      if (sentences.isNotEmpty)
        topic: ([...sentences.where((s) => s.$1), ...sentences.where((s) => !s.$1)])
            .take(_maxSentencesPerTopic)
            .map((s) => s.$2)
            .join(' '),
  };
}

const int _maxSentencesPerTopic = 2;
const int _maxSentenceLength = 350;

final RegExp _careHeading =
    RegExp(r'cultivat|\bcare\b|growing|horticultur|houseplant|indoor', caseSensitive: false);
final RegExp _indoorHeading = RegExp(r'indoor|houseplant', caseSensitive: false);

/// Propagation and nursery sentences mention soil and water but aren't care advice.
final RegExp _skipSentence =
    RegExp(r'propagat|\bcuttings?\b|commercially|tissue culture', caseSensitive: false);

final RegExp _waterPattern = RegExp(
  r'\b(watered|watering|waterings|overwater\w*|underwater(ed|ing)|moist\w*|drought\w*|dry|dries|dried|drying)\b',
  caseSensitive: false,
);

// Bare "light" is skipped because it often means a color ("light green").
final RegExp _lightPattern = RegExp(
  r'\b(sun|sunny|sunlight|sunshine|shade|shaded|shady|luminosity'
  r'|(low|bright|indirect|direct|filtered|natural|artificial|full|partial|dappled|medium|high) light'
  r'|light (levels?|conditions|requirements|intensity)'
  r'|bright,? (indirect |filtered )?(exposure|location|position|spot|window|room))\b',
  caseSensitive: false,
);

final RegExp _soilMaterialPattern = RegExp(
  r'\b(compost|potting (mix|soil|medium)|peat\w*|perlite|vermiculite|well[- ]drain\w*|drainage|loam\w*|substrate|sandy|(rich|loose|acidic|alkaline|fertile|neutral) soils?)\b',
  caseSensitive: false,
);

/// Reduces a scientific name to "Genus species" so cultivars and varieties
/// ("Monstera deliciosa 'Thai Constellation'", "Ficus elastica var. ...")
/// match the species article.
@visibleForTesting
String speciesTitle(String scientificName) {
  final words = scientificName
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .takeWhile((word) =>
          !word.startsWith("'") &&
          !word.startsWith('"') &&
          !word.startsWith('(') &&
          !const {'var.', 'subsp.', 'ssp.', 'f.', 'cv.', 'x', '×'}.contains(word))
      .take(2)
      .toList();
  return words.join(' ');
}
