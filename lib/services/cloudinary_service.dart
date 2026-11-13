import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = 'peldvvua';
  static const String uploadPreset = 'plantpal_unsigned';

  Future<String> uploadImage(XFile image) async {
    final Uri uploadUrl = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uploadUrl);

    request.fields['upload_preset'] = uploadPreset;

    final bytes = await image.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: image.name),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Image upload failed: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final String? imageUrl = data['secure_url'] as String?;

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Cloudinary did not return an image URL.');
    }

    return imageUrl;
  }
}
