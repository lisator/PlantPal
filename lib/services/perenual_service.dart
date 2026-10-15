import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/perenual_models.dart';

/// Thrown when a Perenual request fails. [message] is safe to show to users.
class PerenualException implements Exception {
  const PerenualException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Plant search and care details from the Perenual API.
///
/// The API key is read from Firestore (config/perenual, field "apiKey") the
/// first time it's needed. For local testing it can be overridden with
///   flutter run --dart-define=PERENUAL_API_KEY=your_key
///
/// The free tier allows 100 requests/day, so every response is cached on the
/// device for [_cacheDuration]. Restarting the app does not re-fetch anything.
class PerenualService {
  PerenualService._();

  static final PerenualService instance = PerenualService._();

  static const String _keyOverride = String.fromEnvironment('PERENUAL_API_KEY');
  static const String _baseUrl = 'https://perenual.com/api/v2';
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _cacheDuration = Duration(days: 7);
  static const String _cachePrefix = 'perenual_cache:';

  final Map<String, PlantSearchPage> _searchCache = {};
  final Map<int, PlantDetails> _detailsCache = {};
  String? _apiKey;

  Future<String> _getApiKey() async {
    if (_keyOverride.isNotEmpty) return _keyOverride;
    if (_apiKey != null) return _apiKey!;

    if (Firebase.apps.isEmpty) {
      throw const PerenualException(
        'Plant search needs Firebase, which is not set up on this platform.',
      );
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('perenual')
          .get();
      final key = doc.data()?['apiKey'];
      if (key is String && key.isNotEmpty) {
        return _apiKey = key;
      }
    } catch (e) {
      debugPrint('Could not load Perenual API key: $e');
    }
    throw const PerenualException(
      'Plant search is not configured. Could not load the Perenual API key.',
    );
  }

  Future<PlantSearchPage> searchPlants(String query, {int page = 1}) async {
    final normalized = query.trim().toLowerCase();
    final cacheKey = '$normalized|$page';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final json = await _getCached(Uri.parse('$_baseUrl/species-list').replace(
      queryParameters: {
        'q': normalized,
        'page': '$page',
      },
    ));

    final result = PlantSearchPage.fromJson(json);
    _searchCache[cacheKey] = result;
    return result;
  }

  Future<PlantDetails> getPlantDetails(int id) async {
    final cached = _detailsCache[id];
    if (cached != null) return cached;

    final json = await _getCached(Uri.parse('$_baseUrl/species/details/$id'));

    var details = PlantDetails.fromJson(json);

    // The care guide is a nice-to-have; if it fails, still show the details.
    final guideUrl = details.careGuideUrl;
    if (guideUrl != null) {
      try {
        final guideUri = Uri.parse(guideUrl.replaceFirst('http://', 'https://'));
        final guideJson = await _getCached(guideUri);
        details = details.copyWithCareGuide(parseCareGuide(guideJson));
      } catch (_) {}
    }

    _detailsCache[id] = details;
    return details;
  }

  /// Returns a saved response for [uri] if one is fresh, otherwise fetches it
  /// and saves it.
  Future<Map<String, dynamic>> _getCached(Uri uri) async {
    final cacheKey = _cachePrefix + uri.toString();

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(cacheKey);
      if (saved != null) {
        final entry = jsonDecode(saved) as Map<String, dynamic>;
        final savedAt = DateTime.fromMillisecondsSinceEpoch(entry['savedAt'] as int);
        if (DateTime.now().difference(savedAt) < _cacheDuration) {
          return entry['body'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Perenual cache read failed: $e');
    }

    final body = await _get(uri);
    try {
      await prefs?.setString(
        cacheKey,
        jsonEncode({'savedAt': DateTime.now().millisecondsSinceEpoch, 'body': body}),
      );
    } catch (e) {
      debugPrint('Perenual cache write failed: $e');
    }
    return body;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    debugPrint('Perenual request: ${uri.path}?${uri.query}');
    final key = await _getApiKey();

    final http.Response response;
    try {
      response = await http
          .get(uri.replace(queryParameters: {...uri.queryParameters, 'key': key}))
          .timeout(_timeout);
    } on TimeoutException {
      throw const PerenualException(
        'The plant database took too long to respond. Please try again.',
      );
    } catch (_) {
      throw const PerenualException(
        'Could not reach the plant database. Check your connection and try again.',
      );
    }

    debugPrint(
      'Perenual requests left today: '
      '${response.headers['x-ratelimit-remaining'] ?? 'unknown'}'
      '/${response.headers['x-ratelimit-limit'] ?? '100'}',
    );

    if (response.statusCode == 429) {
      // Perenual also uses 429 for species outside the free plan.
      if (response.body.contains('Upgrade')) {
        throw const PerenualException(
          'Care details for this plant need a paid Perenual plan.',
        );
      }
      throw const PerenualException(
        'Daily plant search limit reached. Please try again tomorrow.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const PerenualException(
        'The Perenual API key was rejected. Check that it is valid.',
      );
    }
    if (response.statusCode == 404) {
      throw const PerenualException('That plant could not be found.');
    }
    if (response.statusCode != 200) {
      throw PerenualException(
        'The plant database returned an error (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const PerenualException('Unexpected response from the plant database.');
    }
    // Perenual reports some errors (bad key, rate limit) as 200 + "message".
    if (body.containsKey('message') && !body.containsKey('data') && !body.containsKey('id')) {
      final message = body['message'].toString();
      if (message.toLowerCase().contains('rate limit')) {
        throw const PerenualException(
          'Daily plant search limit reached. Please try again tomorrow.',
        );
      }
      throw PerenualException('Plant database error: $message');
    }
    return body;
  }
}
