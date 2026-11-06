import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

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
          responseSchema: Schema.object(properties: {
            for (final topic in CareTopic.values) topic.name: Schema.string(),
          }),
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
        final response =
            await _model(name).generateContent([Content.text(text)]);
        final json = jsonDecode(response.text ?? '');
        return json is Map ? verifiedExcerpts(json, text) : null;
      } catch (e) {
        debugPrint('Gemini care lookup with $name failed: $e');
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
Map<CareTopic, String> verifiedExcerpts(Map<dynamic, dynamic> json, String article) {
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

/// Lowercases and collapses whitespace/quote styles so small formatting
/// differences don't count as a mismatch.
String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[‘’]'), "'")
    .replaceAll(RegExp('[“”]'), '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
