import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'care_ai_service.dart';

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
  static const Duration _cacheDuration = Duration(days: 30);
  static const String _cachePrefix = 'wikipedia_cache:';
  // Change the name when the care prompt changes, so old picks are dropped.
  static const String _careCollection = 'plant_care_v2';

  /// Wikimedia requires API clients to identify themselves, and quickly
  /// blocks (HTTP 429) the generic "Dart/x.y" User-Agent that apps send by
  /// default. Browsers don't allow setting User-Agent, so on the web the
  /// Api-User-Agent header is read instead.
  static const String _userAgent =
      'PlantPal/1.0 (https://github.com/lisator/PlantPal; student plant care app)';
  static const Map<String, String> _headers = {
    'Api-User-Agent': _userAgent,
    if (!kIsWeb) 'User-Agent': _userAgent,
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

  /// Care excerpts for a plant: from its own [article] first, then from its
  /// genus's article (e.g. "Begonia") for any topic the species article
  /// doesn't cover. Many species articles have no care section, but the
  /// genus article often describes care for the whole group.
  Future<Map<CareTopic, CareExcerpt>> plantCare(
    WikipediaSummary article, {
    required String scientificName,
  }) async {
    final care = {
      for (final MapEntry(:key, :value) in (await careExcerpts(article)).entries)
        key: CareExcerpt(text: value, article: article),
    };
    if (care.length == CareTopic.values.length) return care;

    final genusName = speciesTitle(scientificName).split(' ').first;
    if (genusName.isNotEmpty &&
        genusName.toLowerCase() != article.title.toLowerCase()) {
      final genus = await _summary(genusName);
      if (genus != null && genus.title != article.title) {
        for (final MapEntry(:key, :value) in (await careExcerpts(genus)).entries) {
          care.putIfAbsent(
            key,
            () => CareExcerpt(text: value, article: genus, fromGenus: true),
          );
        }
      }
    }
    return care;
  }

  /// Care sentences quoted from [article], by topic. Topics the article
  /// doesn't cover are left out.
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

  /// 1. Use the excerpts saved in Firestore, if any user has opened this
  ///    plant before.
  /// 2. Otherwise fetch the article and have Gemini pick sentences from its
  ///    care sections, then save them to Firestore so nobody has to ask
  ///    Gemini again. Articles without care sections skip Gemini entirely.
  /// 3. If Gemini fails (offline, free-tier limit), use the keyword parser.
  ///    That result isn't saved, so Gemini is tried again next time.
  Future<Map<CareTopic, String>> _loadCareExcerpts(String title) async {
    final saved = await _savedCare(title);
    if (saved != null) return saved;

    try {
      final text = await _fetchArticleText(title);
      if (text == null) return const {};
      final careText = careSectionsText(text);
      if (careText.isEmpty) return const {};

      final picked = await CareAiService.instance.pickExcerpts(careText);
      if (picked != null) {
        await _saveCare(title, picked);
        return picked;
      }
      return extractCareExcerpts(text);
    } catch (e) {
      debugPrint('Wikipedia care lookup for "$title" failed: $e');
      _careExcerpts.remove(title);
      return const {};
    }
  }

  /// Gemini's picks, shared by all users: one document per article title.
  DocumentReference<Map<String, dynamic>> _careDoc(String title) =>
      FirebaseFirestore.instance
          .collection(_careCollection)
          .doc(title.replaceAll('/', '_'));

  Future<Map<CareTopic, String>?> _savedCare(String title) async {
    try {
      final data = (await _careDoc(title).get()).data();
      if (data == null) return null;
      return {
        for (final topic in CareTopic.values)
          if (data[topic.name] is String) topic: data[topic.name] as String,
      };
    } catch (e) {
      debugPrint('Reading saved care for "$title" failed: $e');
      return null;
    }
  }

  Future<void> _saveCare(String title, Map<CareTopic, String> excerpts) async {
    try {
      await _careDoc(title).set({
        for (final entry in excerpts.entries) entry.key.name: entry.value,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Saving care for "$title" failed: $e');
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
    final response =
        await http.get(Uri.parse('$_summaryUrl/$path'), headers: _headers);

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
        );

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

/// A care excerpt and the article it was quoted from.
class CareExcerpt {
  const CareExcerpt({
    required this.text,
    required this.article,
    this.fromGenus = false,
  });

  final String text;

  /// The article the text was quoted from (the plant's, or its genus's).
  final WikipediaSummary article;

  /// True when the plant's own article had nothing on this topic, so the
  /// excerpt describes its genus (e.g. all begonias) instead.
  final bool fromGenus;

  /// Where the text came from, shown above it on the details page.
  String get sourceLabel => fromGenus
      ? 'Excerpt from Wikipedia, about the ${article.title} genus'
      : 'Excerpt from Wikipedia';
}

/// The paragraphs of a plain-text article that are in a care section
/// ("Cultivation", "Care", "As a houseplant", ...), and whether that section
/// is about growing indoors. Habitat, history, and other sections are left
/// out. Both Gemini and the keyword parser only look at these.
List<({String text, bool indoor})> careParagraphs(String article) {
  final paragraphs = <({String text, bool indoor})>[];
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
    final text = line.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (inCareSection && text.isNotEmpty) {
      paragraphs.add((text: text, indoor: isIndoorSection));
    }
  }
  return paragraphs;
}

/// The care sections of [article] as one block of text ('' if it has none).
String careSectionsText(String article) =>
    careParagraphs(article).map((p) => p.text).join('\n');

/// Splits [text] into sentences at ". ", "! " or "? " before a capital.
List<String> splitSentences(String text) =>
    text.trim().split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'));

/// Backup for when [CareAiService] can't be reached: picks sentences about
/// each [CareTopic] from a plain-text Wikipedia article, as written.
///
/// Wikipedia doesn't have structured care data, so these sentences are meant
/// to be shown as quotes, never turned into values like "every 7 days". Only
/// cultivation/care sections are used (not habitat, which describes the wild),
/// and sentences from indoor/houseplant sections come first.
///
/// A keyword alone isn't enough: each sentence is scored on how strongly it
/// matches the topic, whether it reads like care advice ("prefers", "needs",
/// "should"), and whether it drifts into history, research, sowing, and so on.
/// Only sentences that clear [_minScore] are kept, and a second sentence is
/// added only if the excerpt stays short.
Map<CareTopic, String> extractCareExcerpts(String article) {
  final candidates = <CareTopic, List<_Candidate>>{
    for (final topic in CareTopic.values) topic: [],
  };

  for (final (:text, :indoor) in careParagraphs(article)) {
    final isIndoorSection = indoor;
    for (final sentence in splitSentences(text)) {
      if (sentence.length < _minSentenceLength ||
          sentence.length > _maxSentenceLength ||
          _skipSentence.hasMatch(sentence)) {
        continue;
      }
      // "Dry matter"/"dry weight" are lab measurements, not watering.
      final forMatching = sentence.replaceAll(
        RegExp(r'\bdry (matter|weight|mass)\b', caseSensitive: false),
        '',
      );
      final hits = {
        CareTopic.water: _waterHits(forMatching),
        CareTopic.light: _count(_lightPattern, forMatching) * 2,
        CareTopic.soil: _soilHits(forMatching),
      };

      var shared = 0;
      if (_adviceCue.hasMatch(sentence)) shared += 2;
      if (isIndoorSection) shared += 1;
      // PlantPal is for houseplants, so garden/outdoor advice ranks last.
      if (_indoorSentence.hasMatch(sentence)) {
        shared += 2;
      } else if (_outdoorSentence.hasMatch(sentence)) {
        shared -= 2;
      }
      shared -= 4 * _count(_offTopic, sentence);
      if (sentence.length > 180) shared -= 1;

      for (final topic in CareTopic.values) {
        final topicHits = hits[topic]!;
        if (topicHits == 0) continue;
        final score = topicHits + shared;
        if (score >= _minScore) {
          candidates[topic]!.add((
            sentence: sentence,
            score: score,
            indoor: isIndoorSection,
          ));
        }
      }
    }
  }

  final excerpts = <CareTopic, String>{};
  for (final MapEntry(key: topic, value: options) in candidates.entries) {
    if (options.isEmpty) continue;
    // Indoor sections first, then the best score, then the shorter sentence.
    options.sort((a, b) {
      if (a.indoor != b.indoor) return a.indoor ? -1 : 1;
      if (a.score != b.score) return b.score.compareTo(a.score);
      return a.sentence.length.compareTo(b.sentence.length);
    });
    final best = options.first;
    var excerpt = best.sentence;
    for (final next in options.skip(1)) {
      if (next.sentence == best.sentence) continue;
      if (excerpt.length + next.sentence.length < _maxExcerptLength) {
        excerpt = '$excerpt ${next.sentence}';
      }
      break;
    }
    excerpts[topic] = excerpt;
  }
  return excerpts;
}

typedef _Candidate = ({String sentence, int score, bool indoor});

const int _minScore = 4;
const int _minSentenceLength = 15;
const int _maxSentenceLength = 240;
const int _maxExcerptLength = 260;

int _count(RegExp pattern, String text) => pattern.allMatches(text).length.clamp(0, 2);

/// Strong watering words count double. Weak ones ("dry", "moisture") only
/// count when the sentence is about the plant's soil or pot, so climate
/// descriptions like "wet winters and dry summers" are skipped.
int _waterHits(String sentence) {
  final strong = _count(_waterPattern, sentence);
  if (strong > 0) return strong * 2;
  if (_weakWaterPattern.hasMatch(sentence) && _potContext.hasMatch(sentence)) {
    return 2;
  }
  return 0;
}

/// Soil materials ("peat", "well-draining") count double; a bare "soil" counts
/// once, unless the sentence is really about watering ("water when the soil
/// feels dry").
int _soilHits(String sentence) {
  final materials = _count(_soilMaterialPattern, sentence);
  if (materials > 0) return materials * 2;
  final isWater = _waterHits(sentence) > 0;
  return !isWater && RegExp(r'\bsoils?\b', caseSensitive: false).hasMatch(sentence)
      ? 1
      : 0;
}

/// Wording that reads like care advice rather than description.
final RegExp _adviceCue = RegExp(
  r'\b(prefers?|preferr\w*|needs?|needed|requires?|requiring|required|should|best'
  r'|ideal\w*|thrives?|tolerat\w*|tolerant|avoid\w*|keep|kept|allow\w*|recommended'
  r'|must|does well|grows? well|benefits?|suscept\w*|sensitive|enjoys?|likes?)\b',
  caseSensitive: false,
);

final RegExp _indoorSentence = RegExp(
  r'\b(indoors?|houseplants?|house plants?|potted|in pots?|containers?)\b',
  caseSensitive: false,
);

final RegExp _outdoorSentence = RegExp(
  r'\b(outdoors?|outside|gardens?|landscap\w*|borders?|lawns?|hedges?|in the ground)\b',
  caseSensitive: false,
);

/// Sentences about history, the wild, research, sowing, pests, frost, or uses
/// mention water/light/soil in passing but aren't advice for a potted plant.
final RegExp _offTopic = RegExp(
  r'\b(originat\w*|introduced|native|habitats?|in the wild|centur\w*|named|discover\w*'
  r'|research\w*|stud(y|ies)|photosynth\w*|yields?|harvest\w*|sown|sow|sowing|seeds?'
  r'|seedlings?|germinat\w*|frosts?|pests?|diseases?|toxic\w*|edible|culinary'
  r'|1[5-9]\d\d|20\d\d)\b',
  caseSensitive: false,
);

final RegExp _careHeading =
    RegExp(r'cultivat|\bcare\b|growing|horticultur|houseplant|indoor', caseSensitive: false);
final RegExp _indoorHeading = RegExp(r'indoor|houseplant', caseSensitive: false);

/// Propagation and nursery sentences mention soil and water but aren't care advice.
final RegExp _skipSentence = RegExp(
  r'propagat|\bcuttings?\b|commercially|tissue culture|\bdivid(e|ed|ing)\b|\bdivision\b',
  caseSensitive: false,
);

final RegExp _waterPattern = RegExp(
  r'\b(watered|watering|waterings|overwater\w*|underwater(ed|ing)|waterlogged'
  r'|(kept|keep|kept evenly|stay|remain) moist|moist (but|soil|compost|substrate)'
  r'|(dry|dried|dries) out|drought[- ]toleran\w*|toleran\w* (of|to) drought'
  r'|(consistent|regular|frequent|plenty of|little) water|soggy|root rot)\b',
  caseSensitive: false,
);

final RegExp _weakWaterPattern = RegExp(
  r'\b(moist\w*|drought\w*|dry|dries|dried|drying|wet|damp)\b',
  caseSensitive: false,
);

final RegExp _potContext = RegExp(
  r'\b(soil|substrate|compost|pots?|potted|roots?|tubers?|rhizomes?|mix|kept|keep)\b',
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
