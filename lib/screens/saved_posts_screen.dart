
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../widgets/post_photo_gallery.dart';
import 'user_profile_screen.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  // Display an error if a saved post cannot be removed.
  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to unsave post: $error'),
      ),
    );
  }

  // Remove a bookmarked post from the user's Saved Posts.
  Future<void> _unsavePost({
    required BuildContext context,
    required DatabaseService databaseService,
    required String userId,
    required String postId,
  }) async {
    try {
      await databaseService.unsavePost(
        userId: userId,
        postId: postId,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  // Display a friendly message when nothing has been saved.
  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border,
                color: _forest,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No saved posts yet!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _forest,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Found a helpful plant care tip or a post you love? '
              'Tap the bookmark icon in Community to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Display a saved post that has been deleted by its author.
  Widget _deletedPost({
    required BuildContext context,
    required DatabaseService databaseService,
    required String userId,
    required String postId,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _mint),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: _mint,
            child: Icon(
              Icons.info_outline,
              color: _forest,
            ),
          ),
          title: const Text(
            'This post is no longer available.',
            style: TextStyle(
              color: _ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'The original post may have been deleted.',
          ),
          trailing: IconButton(
            tooltip: 'Remove from Saved',
            icon: const Icon(
              Icons.bookmark_remove_outlined,
              color: _forest,
            ),
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

  // Display the original author of a bookmarked post.
  // Tapping the author opens their profile.
  Widget _postAuthor({
    required DatabaseService databaseService,
    required String authorId,
    required String fallbackEmail,
  }) {
    if (authorId.isEmpty) {
      return const Row(
        children: [
          CircleAvatar(
            backgroundColor: _mint,
            child: Icon(Icons.person, color: _forest),
          ),
          SizedBox(width: 10),
          Text(
            'PlantPal User',
            style: TextStyle(
              color: _forest,
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

        final username =
            (userData['username'] ?? '').toString().trim();

        final name =
            (userData['displayName'] ?? '').toString().trim();

        final email =
            (userData['email'] ?? fallbackEmail)
                .toString()
                .trim();

        final photoUrl =
            (userData['photoUrl'] ?? '').toString().trim();

        final displayName = username.isNotEmpty
            ? username
            : (name.isNotEmpty
                ? name
                : (email.isNotEmpty ? email : 'PlantPal User'));

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userId: authorId,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _mint,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: _forest,
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _forest,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: _sage,
              ),
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
    final title =
        (data['title'] ?? '').toString();

    final description =
        (data['description'] ?? '').toString();

    final List<String> images = postImageUrls(data);

    final authorId =
        (data['userId'] ?? '').toString();

    final fallbackEmail =
        (data['userEmail'] ?? '').toString();

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
            // POST AUTHOR
            _postAuthor(
              databaseService: databaseService,
              authorId: authorId,
              fallbackEmail: fallbackEmail,
            ),

            const SizedBox(height: 14),

            // POST TITLE
            Text(
              title,
              style: const TextStyle(
                color: _forest,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            // POST DESCRIPTION
            Text(
              description,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
              ),
            ),

            // Swipe and open all pictures.
            if (images.isNotEmpty)
              PostPhotoGallery(
                key: ValueKey(postId),
                imageUrls: images,
              ),

            const SizedBox(height: 14),

            const Divider(
              color: _mint,
              height: 1,
            ),

            const SizedBox(height: 12),

            // UNSAVE BUTTON
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _forest,
                  side: const BorderSide(color: _sage),
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
                icon: const Icon(
                  Icons.bookmark_remove_outlined,
                  size: 20,
                ),
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
        body: Center(
          child: Text('Please log in to view saved posts.'),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _forest,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _forest,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: const Text(
            'Saved Posts',
            style: TextStyle(
              color: _forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _pale,
          surfaceTintColor: _pale,
        ),

        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: databaseService.getSavedPosts(
                currentUser.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load saved posts.',
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

                final savedPosts = snapshot.data!.docs;

                if (savedPosts.isEmpty) {
                  return _emptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16, 16, 16, 24,
                  ),
                  itemCount: savedPosts.length,
                  itemBuilder: (context, index) {
                    final postId = savedPosts[index].id;

                    // Load the original post from Firestore.
                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(postId)
                          .snapshots(),
                      builder: (context, postSnapshot) {
                        if (postSnapshot.hasError) {
                          return const Card(
                            child: ListTile(
                              title: Text(
                                'Unable to load post.',
                              ),
                            ),
                          );
                        }

                        if (!postSnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _forest,
                              ),
                            ),
                          );
                        }

                        // The original author may have deleted
                        // the post after it was bookmarked.
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
