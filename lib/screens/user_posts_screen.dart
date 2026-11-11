import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/post_photo_gallery.dart';

class UserPostsScreen extends StatelessWidget {
  final String userId;
  final String title;

  const UserPostsScreen({
    super.key,
    required this.userId,
    this.title = 'Posts',
  });

  static const Color _forest = PlantPalColors.forest;

  Color _background(BuildContext context) => PlantPalColors.background(context);

  Color _card(BuildContext context) => PlantPalColors.card(context);

  Color _text(BuildContext context) => PlantPalColors.text(context);

  Color _secondary(BuildContext context) =>
      PlantPalColors.secondaryText(context);

  Color _accent(BuildContext context) => PlantPalColors.accent(context);

  Color _border(BuildContext context) => PlantPalColors.border(context);

  Color _soft(BuildContext context) => PlantPalColors.softBackground(context);

  // Build one post card with all attached photos.
  Widget _postCard(
    BuildContext context,
    String postId,
    Map<String, dynamic> data,
  ) {
    final postTitle = (data['title'] ?? '').toString();

    final description = (data['description'] ?? '').toString();

    // Supports multiple pictures and older single-picture posts.
    final List<String> images = postImageUrls(data);

    return Card(
      color: _card(context),
      elevation: 1,
      shadowColor: _forest.withValues(alpha: 0.12),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post title.
            Text(
              postTitle,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _text(context),
              ),
            ),

            const SizedBox(height: 8),

            // Post description.
            Text(description, style: TextStyle(color: _text(context))),

            // Swipe through pictures.
            // Tap a picture to open it full screen.
            if (images.isNotEmpty)
              PostPhotoGallery(key: ValueKey(postId), imageUrls: images),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();

    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
          brightness: baseTheme.brightness,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _background(context),
          foregroundColor: _text(context),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: _background(context),
        appBar: AppBar(
          title: Text(
            title,
            style: TextStyle(
              color: _text(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _background(context),
          foregroundColor: _text(context),
          surfaceTintColor: Colors.transparent,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: databaseService.getPostsByUser(userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load posts.',
                  style: TextStyle(color: _text(context)),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: _accent(context)),
              );
            }

            final posts = [...snapshot.data!.docs];

            if (posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _card(context),
                      border: Border.all(color: _border(context)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _soft(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.spa_outlined,
                            color: _accent(context),
                            size: 48,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'No posts yet!',
                          style: TextStyle(
                            color: _text(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Community posts shared by this user '
                          'will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _secondary(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Show the newest posts first.
            posts.sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;

              final bTime = b.data()['createdAt'] as Timestamp?;

              if (aTime == null && bTime == null) {
                return 0;
              }

              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime);
            });

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];

                    return _postCard(context, post.id, post.data());
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
