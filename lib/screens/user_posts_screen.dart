
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../widgets/post_photo_gallery.dart';

class UserPostsScreen extends StatelessWidget {
  final String userId;
  final String title;

  const UserPostsScreen({
    super.key,
    required this.userId,
    this.title = 'Posts',
  });

  // PlantPal colors.
  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  // Build a post card with all attached photos.
  Widget _postCard(
    String postId,
    Map<String, dynamic> data,
  ) {
    final postTitle =
        (data['title'] ?? '').toString();

    final description =
        (data['description'] ?? '').toString();

    // Supports multiple pictures and older single-picture posts.
    final List<String> images = postImageUrls(data);

    return Card(
      color: Colors.white,
      elevation: 1,
      shadowColor: _forest.withValues(alpha: 0.12),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _mint),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              postTitle,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _forest,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              description,
              style: const TextStyle(
                color: _ink,
              ),
            ),

            // Swipe through pictures.
            // Tap a picture to open it full screen.
            if (images.isNotEmpty)
              PostPhotoGallery(
                key: ValueKey(postId),
                imageUrls: images,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _pale,
          foregroundColor: _forest,
          surfaceTintColor: _pale,
        ),
      ),
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(
              color: _forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _pale,
          surfaceTintColor: _pale,
          iconTheme: const IconThemeData(
            color: _forest,
          ),
        ),
        body: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: databaseService.getPostsByUser(userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load posts.',
                  style: TextStyle(color: _ink),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _forest,
                ),
              );
            }

            final posts = [...snapshot.data!.docs];

            if (posts.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        color: _sage,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No posts yet!',
                        style: TextStyle(
                          color: _forest,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Community posts shared by this user '
                        'will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show the newest posts first.
            posts.sort((a, b) {
              final aTime =
                  a.data()['createdAt'] as Timestamp?;

              final bTime =
                  b.data()['createdAt'] as Timestamp?;

              if (aTime == null && bTime == null) {
                return 0;
              }

              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime);
            });

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 700,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16, 16, 16, 24,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];

                    return _postCard(
                      post.id,
                      post.data(),
                    );
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
