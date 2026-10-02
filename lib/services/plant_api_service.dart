import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PlantApiService {
  static const String baseUrl = 'https://api.plant.id/v3';

  Future<Map<String, dynamic>> identifyPlant({
    required String apiKey,
    required Uint8List imageBytes,
  }) async {
    final url = Uri.parse('$baseUrl/identification');

    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      url,
      headers: {
        'Api-Key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'images': [
          base64Image,
        ],
        'similar_images': true,
      }),
    );

    print('Plant ID status code: ${response.statusCode}');
    print('Plant ID response: ${response.body}');

    if (response.statusCode == 201 ||
        response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Plant identification failed: ${response.body}',
    );
  }
}