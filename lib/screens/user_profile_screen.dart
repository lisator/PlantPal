import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/post_photo_gallery.dart';

import 'follow_list_screen.dart';
import 'user_posts_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  static const Color _forest = PlantPalColors.forest;

  Color _background(BuildContext context) => PlantPalColors.background(context);

  Color _card(BuildContext context) => PlantPalColors.card(context);

  Color _text(BuildContext context) => PlantPalColors.text(context);

  Color _secondary(BuildContext context) =>
      PlantPalColors.secondaryText(context);

  Color _accent(BuildContext context) => PlantPalColors.accent(context);

  Color _border(BuildContext context) => PlantPalColors.border(context);

  Color _soft(BuildContext context) => PlantPalColors.softBackground(context);

  // Display an error if following or unfollowing fails.
  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to update follow: $error')));
  }

  // Display a profile statistic.
  // Tapping it opens the corresponding screen.
  Widget _stat({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.hasData
              ? '${snapshot.data!.docs.length}'
              : '—';

          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: Column(
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: _accent(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _text(context), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Follow or Unfollow button.
  Widget _followButton({
    required BuildContext context,
    required DatabaseService databaseService,
    required String currentUserId,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: databaseService.getFollowStatus(
        currentUserId: currentUserId,
        targetUserId: userId,
      ),
      builder: (context, followSnapshot) {
        if (followSnapshot.hasError) {
          return Text(
            'Unable to load follow status.',
            style: TextStyle(color: _text(context)),
          );
        }

        final bool following = followSnapshot.data?.exists ?? false;

        final bool loading = !followSnapshot.hasData;

        return SizedBox(
          width: double.infinity,
          child: following
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent(context),
                    side: BorderSide(color: _border(context)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          try {
                            await databaseService.unfollowUser(
                              currentUserId: currentUserId,
                              targetUserId: userId,
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            _showError(context, e);
                          }
                        },
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Following'),
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          try {
                            await databaseService.followUser(
                              currentUserId: currentUserId,
                              targetUserId: userId,
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            _showError(context, e);
                          }
                        },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Follow'),
                ),
        );
      },
    );
  }

  // Display a Community post on the user's profile.
  Widget _postCard(
    BuildContext context,
    String postId,
    Map<String, dynamic> data,
  ) {
    final title = (data['title'] ?? '').toString();

    final description = (data['description'] ?? '').toString();

    // Supports old single-photo posts and new galleries.
    final List<String> images = postImageUrls(data);

    return Card(
      color: _card(context),
      elevation: 1,
      shadowColor: _forest.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _border(context)),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _text(context),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              description,
              style: TextStyle(fontSize: 14, color: _text(context)),
            ),

            // Swipe through all attached pictures.
            // Tap to open the full-screen viewer.
            if (images.isNotEmpty)
              PostPhotoGallery(key: ValueKey(postId), imageUrls: images),
          ],
        ),
      ),
    );
  }

  // Display Community posts created by this user.
  Widget _userPosts(DatabaseService databaseService) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: databaseService.getPostsByUser(userId),
      builder: (context, postSnapshot) {
        if (postSnapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Unable to load posts.'),
            ),
          );
        }

        if (!postSnapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final posts = [...postSnapshot.data!.docs];

        // Display newest posts first.
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

        if (posts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border(context)),
            ),
            child: Column(
              children: [
                Icon(Icons.spa_outlined, color: _accent(context), size: 42),
                const SizedBox(height: 10),
                Text(
                  'No posts yet.',
                  style: TextStyle(
                    color: _text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'This user has not shared any Community posts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _secondary(context)),
                ),
              ],
            ),
          );
        }

        return Column(
          children: posts.map((post) {
            return _postCard(context, post.id, post.data());
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseService databaseService = DatabaseService();

    final User? currentUser = FirebaseAuth.instance.currentUser;

    final baseTheme = Theme.of(context);

    // Keep the selected brightness instead of forcing
    // a light color scheme.
    return Theme(
      data: baseTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
          brightness: baseTheme.brightness,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _accent(context)),
        ),
      ),
      child: Scaffold(
        backgroundColor: _background(context),
        appBar: AppBar(
          title: Text(
            'Profile',
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
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: databaseService.getUserStream(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load profile.'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('User not found.'));
            }

            final data = snapshot.data!.data()!;

            final displayName = (data['displayName'] ?? 'PlantPal User')
                .toString();

            final username = (data['username'] ?? '').toString();

            final bio = (data['bio'] ?? '').toString();

            // Cloudinary stores the picture;
            // Firestore stores its URL.
            final photoUrl = (data['photoUrl'] ?? '').toString();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                  child: Column(
                    children: [
                      // PROFILE HEADER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: _soft(context),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.spa_outlined,
                                  color: _accent(context),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PlantPal Member',
                                  style: TextStyle(
                                    color: _text(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Show the user's profile picture.
                            CircleAvatar(
                              radius: 58,
                              backgroundColor: _card(context),
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: _accent(context),
                                    )
                                  : null,
                            ),

                            const SizedBox(height: 14),

                            Text(
                              displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _text(context),
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            if (username.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                username,
                                style: TextStyle(
                                  color: _accent(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            Text(
                              bio.isEmpty ? 'No bio yet.' : bio,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _text(context),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // POSTS, FOLLOWERS, FOLLOWING
                      Container(
                        decoration: BoxDecoration(
                          color: _card(context),
                          border: Border.all(color: _border(context)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            _stat(
                              stream: databaseService.getPostsByUser(userId),
                              label: 'Posts',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserPostsScreen(
                                      userId: userId,
                                      title: 'Posts',
                                    ),
                                  ),
                                );
                              },
                            ),

                            Container(
                              width: 1,
                              height: 42,
                              color: _border(context),
                            ),

                            _stat(
                              stream: databaseService.getFollowers(userId),
                              label: 'Followers',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FollowListScreen(
                                      userId: userId,
                                      showFollowers: true,
                                    ),
                                  ),
                                );
                              },
                            ),

                            Container(
                              width: 1,
                              height: 42,
                              color: _border(context),
                            ),

                            _stat(
                              stream: databaseService.getFollowing(userId),
                              label: 'Following',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FollowListScreen(
                                      userId: userId,
                                      showFollowers: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FOLLOW OR UNFOLLOW
                      if (currentUser != null && currentUser.uid != userId)
                        _followButton(
                          context: context,
                          databaseService: databaseService,
                          currentUserId: currentUser.uid,
                        ),

                      const SizedBox(height: 26),

                      // USER COMMUNITY POSTS
                      Row(
                        children: [
                          Icon(Icons.spa_outlined, color: _accent(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Community Posts',
                              style: TextStyle(
                                color: _text(context),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _userPosts(databaseService),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
