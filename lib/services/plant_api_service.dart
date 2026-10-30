import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class PlantApiService {
  static const String workerUrl =
      'https://plantpal-api.plantpal-breeze.workers.dev';

  Future<Map<String, dynamic>> identifyPlant({
    required List<Uint8List> imageBytesList,
    }) async {
      final base64Images = imageBytesList
          .map((imageBytes) => base64Encode(imageBytes))
          .toList();

      final response = await http.post(
        Uri.parse(workerUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'images': base64Images,
        }),
      );

      debugPrint('Worker status code: ${response.statusCode}');
      debugPrint('Worker response: ${response.body}');

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      throw Exception(
        'Plant analysis failed: ${response.body}',
      );
    }
}