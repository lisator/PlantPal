import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/my_plant.dart';
import '../services/database_service.dart';
import '../services/cloudinary_service.dart';
import '../screens/home_screen.dart';

Future<void> changePlantPhoto(
  BuildContext context,
  MyPlant plant,
) async {
  final userId = currentUserId();

  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please sign in first.')),
    );
    return;
  }

  // Ask the user where the new photo should come from.
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Change Plant Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a new photo'),
            onTap: () => Navigator.pop(sheetContext, 'camera'),
          ),

          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheetContext, 'gallery'),
          ),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Choose from health history'),
            onTap: () => Navigator.pop(sheetContext, 'history'),
          ),

          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (!context.mounted || choice == null) return;

  try {
    String? imageUrl;

    if (choice == 'camera' || choice == 'gallery') {
      final picker = ImagePicker();

      final photo = await picker.pickImage(
        source: choice == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo == null) return;

      imageUrl = await CloudinaryService().uploadImage(photo);
    } else if (choice == 'history') {
      imageUrl = await selectHealthHistoryPhoto(
        context,
        userId,
        plant.id,
      );
    }

    if (imageUrl == null || imageUrl.isEmpty) return;

    // Update only the saved plant's profile picture.
    await DatabaseService().updateMyPlantPhoto(
      userId: userId,
      plantId: plant.id,
      imageUrl: imageUrl,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plant photo updated successfully!'),
      ),
    );
  } catch (e) {
    debugPrint('Change plant photo error: $e');

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not update the photo. Please try again.',
        ),
      ),
    );
  }
}

Future<String?> selectHealthHistoryPhoto(
  BuildContext context,
  String userId,
  String plantId,
) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Choose a Previous Photo'),

        content: SizedBox(
          width: 350,
          height: 350,

          child: StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: DatabaseService().getPlantAnalyses(
              userId: userId,
              plantId: plantId,
            ),

            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Could not load health history.'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              // Get all available photos from health history.
              final photos = snapshot.data!.docs
                  .map(
                    (doc) =>
                        (doc.data()['imageUrl'] ?? '').toString(),
                  )
                  .where((url) => url.isNotEmpty)
                  .toSet()
                  .toList();

              if (photos.isEmpty) {
                return const Center(
                  child: Text(
                    'No photos found in health history.',
                  ),
                );
              }

              return GridView.builder(
                itemCount: photos.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),

                itemBuilder: (context, index) {
                  final photoUrl = photos[index];

                  return InkWell(
                    onTap: () {
                      Navigator.pop(dialogContext, photoUrl);
                    },

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),

                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                const Icon(
                          Icons.broken_image_outlined,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}