import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/perenual_models.dart';
import 'wikipedia_service.dart' show speciesTitle;

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
  static const Duration _cacheDuration = Duration(days: 7);
  static const String _cachePrefix = 'perenual_cache:';

  /// Requests allowed per day on the free plan.
  static const int _dailyLimit = 100;
  static const String _countDateKey = 'perenual_requests_date';
  static const String _countKey = 'perenual_requests_count';

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

  /// The search tab only shows indoor plants ([indoorOnly]), since PlantPal
  /// is for houseplants. Plants identified by plant analysis can be any
  /// plant (e.g. a rose), so [findByName] searches everything.
  Future<PlantSearchPage> searchPlants(
    String query, {
    int page = 1,
    bool indoorOnly = true,
  }) async {
    final normalized = query.trim().toLowerCase();
    final cacheKey = '$normalized|$page|$indoorOnly';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final json = await _getCached(
      Uri.parse('$_baseUrl/species-list').replace(
        queryParameters: {
          'q': normalized,
          'page': '$page',
          if (indoorOnly) 'indoor': '1',
        },
      ),
    );

    final result = PlantSearchPage.fromJson(json);
    _searchCache[cacheKey] = result;
    return result;
  }

  /// Perenual's details for a plant known only by name, e.g. one identified
  /// by plant analysis: searches for its species and picks the result whose
  /// scientific name matches best. Returns null if Perenual doesn't have it.
  /// For species outside the free plan, only the basic details are returned.
  Future<PlantDetails?> findByName({
    required String scientificName,
    required String commonName,
  }) async {
    final species = speciesTitle(scientificName);
    final query = species.isNotEmpty ? species : commonName.trim();
    if (query.isEmpty) return null;

    final results = (await searchPlants(query, indoorOnly: false)).results;
    if (results.isEmpty) return null;

    final wanted = species.toLowerCase();
    final match = results.firstWhere(
      (r) => r.scientificName.toLowerCase().startsWith(wanted),
      orElse: () => results.first,
    );
    return match.hasFullDetails
        ? getPlantDetails(match.id)
        : PlantDetails.basic(match);
  }

  Future<PlantDetails> getPlantDetails(int id) async {
    final cached = _detailsCache[id];
    if (cached != null) return cached;

    // Each Perenual request can take 15+ seconds, so the care guide is
    // requested at the same time as the details instead of after them.
    final careGuide = _getCareGuide(id);
    final json = await _getCached(Uri.parse('$_baseUrl/species/details/$id'));
    final details = PlantDetails.fromJson(json)
        .copyWith(careGuide: await careGuide);

    _detailsCache[id] = details;
    return details;
  }

  /// Perenual's written care guide (watering, sunlight, pruning). It's a
  /// nice-to-have, so if it fails the details still show without it.
  Future<Map<String, String>> _getCareGuide(int id) async {
    try {
      final json = await _getCached(
        Uri.parse(
          'https://perenual.com/api/species-care-guide-list'
          '?species_id=$id&page=1',
        ),
      );
      return parseCareGuide(json);
    } catch (e) {
      debugPrint('Perenual care guide for $id failed: $e');
      return const {};
    }
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
        final savedAt = DateTime.fromMillisecondsSinceEpoch(
          entry['savedAt'] as int,
        );
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
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'body': body,
        }),
      );
    } catch (e) {
      debugPrint('Perenual cache write failed: $e');
    }
    return body;
  }

  /// Logs each real (not cached) request with how many this device has sent
  /// today, e.g. "Perenual request 12/100 today (88 left per Perenual):
  /// /api/v2/species-list?q=fern&page=1".
  ///
  /// The device keeps its own count because Perenual's remaining-quota
  /// header can't be read in the web build (browsers hide it). When the
  /// header is readable, it's shown too. The count is per device, while the
  /// limit is shared by everyone using the same API key.
  Future<void> _logRequest(Uri uri, http.Response response) async {
    var count = 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (prefs.getString(_countDateKey) == today) {
        count = (prefs.getInt(_countKey) ?? 0) + 1;
      }
      await prefs.setString(_countDateKey, today);
      await prefs.setInt(_countKey, count);
    } catch (_) {
      // Counting is only for the log; never let it break a request.
    }

    final remaining = response.headers['x-ratelimit-remaining'];
    debugPrint(
      'Perenual request $count/$_dailyLimit today'
      '${remaining == null ? '' : ' ($remaining left per Perenual)'}'
      ': ${uri.path}?${uri.query} -> HTTP ${response.statusCode}',
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final key = await _getApiKey();

    final http.Response response;
    try {
      // No time limit: Perenual's server often takes 15-20 seconds to
      // answer, and a slow answer is better than an error.
      response = await http.get(
        uri.replace(queryParameters: {...uri.queryParameters, 'key': key}),
      );
    } catch (_) {
      throw const PerenualException(
        'Could not reach the plant database. Check your connection and try again.',
      );
    }

    await _logRequest(uri, response);

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
      throw const PerenualException(
        'Unexpected response from the plant database.',
      );
    }
    // Perenual reports some errors (bad key, rate limit) as 200 + "message".
    if (body.containsKey('message') &&
        !body.containsKey('data') &&
        !body.containsKey('id')) {
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
