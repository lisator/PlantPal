import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadPostImage({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final String uniqueFileName =
        '${DateTime.now().millisecondsSinceEpoch}_$fileName';

    final Reference reference = _storage
        .ref()
        .child('post_images')
        .child(userId)
        .child(uniqueFileName);

    await reference.putData(
      imageBytes,
      SettableMetadata(
        contentType: _getContentType(fileName),
      ),
    );

    return await reference.getDownloadURL();
  }

  String _getContentType(String fileName) {
    final name = fileName.toLowerCase();

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }
}