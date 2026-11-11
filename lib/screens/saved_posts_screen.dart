import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/post_photo_gallery.dart';

import 'user_profile_screen.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  Color _background(BuildContext context) => PlantPalColors.background(context);

  Color _card(BuildContext context) => PlantPalColors.card(context);

  Color _text(BuildContext context) => PlantPalColors.text(context);

  Color _secondary(BuildContext context) =>
      PlantPalColors.secondaryText(context);

  Color _accent(BuildContext context) => PlantPalColors.accent(context);

  Color _border(BuildContext context) => PlantPalColors.border(context);

  Color _soft(BuildContext context) => PlantPalColors.softBackground(context);

  // Display an error when a post cannot be removed.
  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Unable to unsave post: $error')));
  }

  // Remove a bookmarked post.
  Future<void> _unsavePost({
    required BuildContext context,
    required DatabaseService databaseService,
    required String userId,
    required String postId,
  }) async {
    try {
      await databaseService.unsavePost(userId: userId, postId: postId);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  // Empty screen when there are no bookmarks.
  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _soft(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border,
                color: _accent(context),
                size: 44,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'No saved posts yet!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Found a helpful plant care tip or a post you love? '
              'Tap the bookmark icon in Community to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondary(context), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Display a saved post that was deleted.
  Widget _deletedPost({
    required BuildContext context,
    required DatabaseService databaseService,
    required String userId,
    required String postId,
  }) {
    return Card(
      color: _card(context),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _soft(context),
            child: Icon(Icons.info_outline, color: _accent(context)),
          ),
          title: Text(
            'This post is no longer available.',
            style: TextStyle(
              color: _text(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'The original post may have been deleted.',
            style: TextStyle(color: _secondary(context)),
          ),
          trailing: IconButton(
            tooltip: 'Remove from Saved',
            icon: Icon(Icons.bookmark_remove_outlined, color: _accent(context)),
            onPressed: () {
              _unsavePost(
                context: context,
                databaseService: databaseService,
                userId: userId,
                postId: postId,
              );
            },
          ),
        ),
      ),
    );
  }

  // Display the original author of the post.
  Widget _postAuthor({
    required BuildContext context,
    required DatabaseService databaseService,
    required String authorId,
    required String fallbackEmail,
  }) {
    if (authorId.isEmpty) {
      return Row(
        children: [
          CircleAvatar(
            backgroundColor: _soft(context),
            child: Icon(Icons.person, color: _accent(context)),
          ),
          const SizedBox(width: 10),
          Text(
            'PlantPal User',
            style: TextStyle(
              color: _text(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: databaseService.getUserStream(authorId),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() ?? {};

        final username = (userData['username'] ?? '').toString().trim();

        final name = (userData['displayName'] ?? '').toString().trim();

        final email = (userData['email'] ?? fallbackEmail).toString().trim();

        final photoUrl = (userData['photoUrl'] ?? '').toString().trim();

        final displayName = username.isNotEmpty
            ? username
            : name.isNotEmpty
            ? name
            : email.isNotEmpty
            ? email
            : 'PlantPal User';

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: authorId),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _soft(context),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Icon(Icons.person, color: _accent(context))
                    : null,
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Icon(Icons.chevron_right, color: _accent(context)),
            ],
          ),
        );
      },
    );
  }

  // Display one bookmarked Community post.
  Widget _savedPostCard({
    required BuildContext context,
    required DatabaseService databaseService,
    required String currentUserId,
    required String postId,
    required Map<String, dynamic> data,
  }) {
    final title = (data['title'] ?? '').toString();

    final description = (data['description'] ?? '').toString();

    final List<String> images = postImageUrls(data);

    final authorId = (data['userId'] ?? '').toString();

    final fallbackEmail = (data['userEmail'] ?? '').toString();

    return Card(
      color: _card(context),
      elevation: 1,
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
            // Original post author.
            _postAuthor(
              context: context,
              databaseService: databaseService,
              authorId: authorId,
              fallbackEmail: fallbackEmail,
            ),

            const SizedBox(height: 14),

            // Post title.
            Text(
              title,
              style: TextStyle(
                color: _text(context),
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            // Post description.
            Text(
              description,
              style: TextStyle(color: _text(context), fontSize: 14),
            ),

            // Multiple-image gallery.
            if (images.isNotEmpty)
              PostPhotoGallery(key: ValueKey(postId), imageUrls: images),

            const SizedBox(height: 14),

            Divider(color: _border(context), height: 1),

            const SizedBox(height: 12),

            // Remove this post from Saved Posts.
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent(context),
                  side: BorderSide(color: _border(context)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _unsavePost(
                    context: context,
                    databaseService: databaseService,
                    userId: currentUserId,
                    postId: postId,
                  );
                },
                icon: const Icon(Icons.bookmark_remove_outlined, size: 20),
                label: const Text('Unsave Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final databaseService = DatabaseService();

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view saved posts.')),
      );
    }

    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PlantPalColors.forest,
          brightness: baseTheme.brightness,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _accent(context)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: _accent(context)),
        ),
      ),
      child: Scaffold(
        backgroundColor: _background(context),

        appBar: AppBar(
          title: Text(
            'Saved Posts',
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

        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: databaseService.getSavedPosts(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load saved posts.'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final savedPosts = snapshot.data!.docs;

                if (savedPosts.isEmpty) {
                  return _emptyState(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: savedPosts.length,
                  itemBuilder: (context, index) {
                    final postId = savedPosts[index].id;

                    // Listen to the original post.
                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(postId)
                          .snapshots(),
                      builder: (context, postSnapshot) {
                        if (postSnapshot.hasError) {
                          return const Card(
                            child: ListTile(
                              title: Text('Unable to load post.'),
                            ),
                          );
                        }

                        if (!postSnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        // Show a placeholder if deleted.
                        if (!postSnapshot.data!.exists) {
                          return _deletedPost(
                            context: context,
                            databaseService: databaseService,
                            userId: currentUser.uid,
                            postId: postId,
                          );
                        }

                        final data = postSnapshot.data!.data()!;

                        return _savedPostCard(
                          context: context,
                          databaseService: databaseService,
                          currentUserId: currentUser.uid,
                          postId: postId,
                          data: data,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
