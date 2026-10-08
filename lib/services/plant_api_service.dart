import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PlantApiService {
  static const String workerUrl =
      'https://plantpal-api.plantpal-breeze.workers.dev';

  Future<Map<String, dynamic>> identifyPlant({
    required Uint8List imageBytes,
  }) async {
    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse(workerUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'image': base64Image,
      }),
    );

    print('Worker status code: ${response.statusCode}');
    print('Worker response: ${response.body}');

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Plant analysis failed: ${response.body}',
    );
  }
}