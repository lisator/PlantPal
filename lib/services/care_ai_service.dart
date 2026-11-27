import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wikipedia_service.dart';

/// Uses Gemini (through Firebase AI Logic's free tier) to pick the care
/// sentences for Water/Light/Soil out of a Wikipedia article's care sections.
///
/// Gemini only *chooses* sentences; it doesn't write its own advice. Every
/// sentence it returns is checked against the text ([verifiedExcerpts]),
/// so anything it made up or reworded is thrown away.
///
/// Lookups never throw: any failure returns null, and the caller falls back
/// to the keyword parser ([extractCareExcerpts]).
class CareAiService {
  CareAiService._();

  static final CareAiService instance = CareAiService._();

  /// Models to try, in order. Small, fast models are enough for picking
  /// sentences. On the free tier a model sometimes answers "500: This model
  /// is currently experiencing high demand", so a busy model is skipped and
  /// the next one is tried. Google retires old models (they then answer
  /// 404), so this list may need updating over time.
  static const List<String> modelNames = [
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
  ];

  /// Cut-off for unusually long care sections, to keep requests small.
  static const int _maxTextLength = 8000;

  static const String _instructions = '''
You help a houseplant care app. You will be given the care sections of a Wikipedia article about one plant.

For each topic, copy the 1 or 2 sentences that best tell someone how to care for this plant indoors:
- water: how often or how much to water, or how moist/dry to keep the soil
- light: how much sun or shade it needs
- soil: what soil or potting mix to grow it in

Rules:
- Copy sentences exactly as written. Do not reword, summarize, or add anything.
- Only use care advice. Ignore history, the wild habitat, research, propagation, sowing seeds, pests, and uses.
- Prefer advice for indoor or potted plants over garden or outdoor advice.
- Keep each answer under 250 characters.
- If there is no care advice for a topic, return an empty string for it.''';

  GenerativeModel _model(String name) => FirebaseAI.googleAI().generativeModel(
    model: name,
    systemInstruction: Content.system(_instructions),
    generationConfig: GenerationConfig(
      // 0 = always pick the most likely answer, so results are consistent.
      temperature: 0,
      // Forces the reply to be JSON with exactly these three fields.
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          for (final topic in CareTopic.values) topic.name: Schema.string(),
        },
      ),
    ),
  );

  /// Care sentences Gemini picked from [careText] (an article's care
  /// sections), by topic, or null if no model could be reached.
  Future<Map<CareTopic, String>?> pickExcerpts(String careText) async {
    final text = careText.length > _maxTextLength
        ? careText.substring(0, _maxTextLength)
        : careText;

    for (final name in modelNames) {
      try {
        // No time limit: a slow answer is better than no care info.
        final response = await _model(name)
            .generateContent([Content.text(text)]);
        final json = jsonDecode(response.text ?? '');
        return json is Map ? verifiedExcerpts(json, text) : null;
      } catch (e) {
        debugPrint('Gemini care lookup with $name failed: $e');
        if (!_tryNextModel(e)) return null;
      }
    }
    return null;
  }

  static const String _tipInstructions = '''
You write care tips for a houseplant care app. You will be given JSON with source text for some care topics (water, light, soil, pruning).

For each topic in the input, write a tip:
- 1 or 2 short sentences, under 140 characters in total.
- Plain, friendly words, written to the plant owner, e.g. "Water when the top inch of soil is dry."
- Use only facts from that topic's source text. Do not add advice of your own.
- Only cover that topic. Leave out anything that belongs to another topic, so no fact appears in two tips.
- Prefer advice for indoor or potted plants.

Also return "quote": the shortest exact phrase from that topic's source text that backs up the tip, copied word for word.

If a topic's source has no real advice for that topic, return empty strings for it.''';

  GenerativeModel _tipsModel(String name, List<String> topics) =>
      FirebaseAI.googleAI().generativeModel(
        model: name,
        systemInstruction: Content.system(_tipInstructions),
        generationConfig: GenerationConfig(
          temperature: 0,
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              for (final topic in topics)
                topic: Schema.object(
                  properties: {
                    'tip': Schema.string(),
                    'quote': Schema.string(),
                  },
                ),
            },
          ),
        ),
      );

  /// Short tips Gemini wrote from [sources] (topic name -> source text), by
  /// topic, or null if no model could be reached. Tips that fail
  /// [verifiedTips] are left out.
  Future<Map<String, String>?> rewriteTips(Map<String, String> sources) async {
    if (sources.isEmpty) return const {};
    final topics = sources.keys.toList();

    for (final name in modelNames) {
      try {
        final response = await _tipsModel(
          name,
          topics,
        ).generateContent([Content.text(jsonEncode(sources))]);
        final json = jsonDecode(response.text ?? '');
        return json is Map ? verifiedTips(json, sources) : null;
      } catch (e) {
        debugPrint('Gemini care tips with $name failed: $e');
        if (!_tryNextModel(e)) return null;
      }
    }
    return null;
  }

  /// Busy (5xx) or retired (404) models are worth skipping for the next
  /// one. Other errors, like a used-up free-tier limit or AI Logic not being
  /// set up, would fail the same way on every model.
  static bool _tryNextModel(Object error) =>
      error is ServerException ||
      RegExp(r'Server Error \[5|\b404\b|not found|no longer available')
          .hasMatch(error.toString());
}

/// Keeps only the answers in [json] whose every sentence really appears in
/// [article], so the app never shows text Gemini invented or reworded.
@visibleForTesting
Map<CareTopic, String> verifiedExcerpts(
  Map<dynamic, dynamic> json,
  String article,
) {
  final normalizedArticle = _normalize(article);
  bool inArticle(String sentence) =>
      normalizedArticle.contains(_normalize(sentence));

  return {
    for (final topic in CareTopic.values)
      if (json[topic.name] case final String answer
          when answer.trim().isNotEmpty &&
              answer.length <= _maxAnswerLength &&
              splitSentences(answer).every(inArticle))
        topic: answer.trim(),
  };
}

const int _maxAnswerLength = 300;

/// Keeps the tips in [json] that are short and whose quote really appears in
/// that topic's text in [sources], so each tip is backed by its source.
@visibleForTesting
Map<String, String> verifiedTips(
  Map<dynamic, dynamic> json,
  Map<String, String> sources,
) {
  final tips = <String, String>{};
  for (final MapEntry(key: topic, value: source) in sources.entries) {
    final answer = json[topic];
    if (answer is! Map) continue;
    final tip = answer['tip'];
    final quote = answer['quote'];
    if (tip is! String || quote is! String) continue;
    if (tip.trim().isEmpty || tip.length > _maxTipLength) continue;
    // a quoted phrase may end with a period the source doesn't have there
    final phrase = _normalize(quote)
        .replaceAll(RegExp(r'''^["']+|[.,;:!?"']+$'''), '');
    if (phrase.isEmpty || !_normalize(source).contains(phrase)) continue;
    tips[topic] = tip.trim();
  }
  return tips;
}

const int _maxTipLength = 200;

/// Lowercases and collapses whitespace/quote styles so small formatting
/// differences don't count as a mismatch.
String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[‘’]'), "'")
    .replaceAll(RegExp('[“”]'), '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Short care tips rewritten by Gemini from Perenual's or Wikipedia's long
/// care text, one per topic ("water", "light", "soil", "pruning").
///
/// Tips are saved on the device and in Firestore (shared by all users), keyed
/// by the plant and its source text, so each plant only needs Gemini once.
/// Never throws: on any failure the result is empty and the app shows the
/// original text. Failures aren't saved, so Gemini is tried again next time.
class CareTipsService {
  CareTipsService._();

  static final CareTipsService instance = CareTipsService._();

  // change the version when the tips prompt changes, so old tips are dropped.
  static const String _version = 'v1';
  static const String _collection = 'plant_care_tips_$_version';
  static const String _cachePrefix = 'care_tips_$_version:';

  /// Replaces the Gemini call in widget tests.
  @visibleForTesting
  static Future<Map<String, String>?> Function(Map<String, String> sources)?
  rewriteForTesting;

  final Map<String, Future<Map<String, String>>> _tips = {};

  /// Tips for [sources] (topic name -> source text). Calling it again with the
  /// same text returns the same future, so it's safe to call from build().
  Future<Map<String, String>> tipsFor({
    required String scientificName,
    required Map<String, String> sources,
  }) {
    if (sources.isEmpty) return Future.value(const {});
    final key = _key(scientificName, sources);
    return _tips[key] ??= _load(key, sources);
  }

  Future<Map<String, String>> _load(
    String key,
    Map<String, String> sources,
  ) async {
    final saved = await _readDevice(key) ?? await _readShared(key);
    if (saved != null) {
      await _writeDevice(key, saved);
      return saved;
    }

    final rewrite = rewriteForTesting ?? CareAiService.instance.rewriteTips;
    final tips = await rewrite(sources);
    if (tips == null) {
      _tips.remove(key);
      return const {};
    }
    await _writeDevice(key, tips);
    await _writeShared(key, tips);
    return tips;
  }

  /// e.g. "monstera deliciosa_3fa2c1d0": the species plus a hash of the
  /// source text, so new Perenual or Wikipedia text gets new tips.
  static String _key(String scientificName, Map<String, String> sources) {
    final species = speciesTitle(scientificName).toLowerCase();
    final text = jsonEncode([
      for (final topic in sources.keys.toList()..sort())
        [topic, sources[topic]],
    ]);
    return '${species.replaceAll('/', '_')}_${_hash(text)}';
  }

  /// 32-bit FNV-1a, written so it gives the same result on web and mobile.
  static String _hash(String text) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(text)) {
      hash ^= byte;
      hash = (hash * 0x193 + ((hash << 24) & 0xffffffff)) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Map<String, String> _fromJson(Object? json) => {
    if (json is Map)
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String && value is String) key: value,
  };

  Future<Map<String, String>?> _readDevice(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_cachePrefix + key);
      return saved == null ? null : _fromJson(jsonDecode(saved));
    } catch (e) {
      debugPrint('Reading saved care tips failed: $e');
      return null;
    }
  }

  Future<void> _writeDevice(String key, Map<String, String> tips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachePrefix + key, jsonEncode(tips));
    } catch (e) {
      debugPrint('Saving care tips failed: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String key) =>
      FirebaseFirestore.instance.collection(_collection).doc(key);

  Future<Map<String, String>?> _readShared(String key) async {
    try {
      final data = (await _doc(key).get()).data();
      return data == null ? null : _fromJson(data['tips']);
    } catch (e) {
      debugPrint('Reading shared care tips failed: $e');
      return null;
    }
  }

  Future<void> _writeShared(String key, Map<String, String> tips) async {
    try {
      await _doc(key)
          .set({'tips': tips, 'savedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Saving shared care tips failed: $e');
    }
  }
}
