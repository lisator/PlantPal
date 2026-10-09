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

    if (fileName.toLowerCase().endsWith('.png')) return 'image/png';
    if (fileName.toLowerCase().endsWith('.webp')) return 'image/webp';

    return 'image/jpeg';
  }

  Future<void> deleteFile(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  Future<FullMetadata?> getFileMetadata(String fileUrl) async ({
    required String userId;
    required String fileName;
  }) async {
    try {
      final Reference ref = _storage
        .ref()
        .child('post_images')
        .child(userId)
        .child(fileName);

      final FullMetadata metadata = await ref.getMetadata();
      return metadata;
    } catch (e) {
      print('Error retrieving file metadata: $e');
      return null;
    }
  }

  Future<FullMetadata?> updateMetadata({
    required String userId,
    required String fileName,
    Map<String, String>? customMetadata,
    String? contentType,
    String? cacheControl,
  }) async {
    try {
      // 1. Point to the file reference using your standard folder structure
      Reference reference = _storage
        .ref()
        .child('post_images')
        .child(userId)
        .child(fileName);

      // 2. Wrap the fields you want to update in SettableMetadata
      SettableMetadata metadataToUpdate = SettableMetadata(
        customMetadata: customMetadata,
        contentType: contentType,
        cacheControl: cacheControl,
      );

      // 3. Apply the update and return the updated FullMetadata response
      FullMetadata updatedMetadata = await reference.updateMetadata(metadataToUpdate);
      return updatedMetadata;
    } catch (e) {
      print('Error updating metadata: $e');
      return null;
    }
  }

  
}