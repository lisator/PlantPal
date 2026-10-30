import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final bool showFollowers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });


  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  // Display a message when there are no followers or followed users.
  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                showFollowers
                    ? Icons.people_outline
                    : Icons.person_add_alt_outlined,
                size: 42,
                color: _forest,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              showFollowers
                  ? 'No followers yet'
                  : 'Not following anyone yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _forest,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              showFollowers
                  ? 'Followers will appear here when someone follows this account.'
                  : 'Accounts followed by this user will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a card displaying one follower or followed user.
  Widget _userCard({
    required BuildContext context,
    required String otherUserId,
    required Map<String, dynamic> data,
  }) {
    final String name =
        (data['displayName'] ?? 'PlantPal User').toString();

    final String username =
        (data['username'] ?? '').toString().trim();

    final String bio =
        (data['bio'] ?? '').toString().trim();

    // Cloudinary stores the image.
    // Firestore stores the photo URL.
    final String photoUrl =
        (data['photoUrl'] ?? '').toString().trim();

    return Card(
      color: Colors.white,
      elevation: 1,
      shadowColor: _forest.withValues(alpha: 0.10),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _mint),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: otherUserId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          child: Row(
            children: [
              // Show the user's uploaded profile picture.
              CircleAvatar(
                radius: 27,
                backgroundColor: _mint,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: _forest,
                        size: 30,
                      )
                    : null,
              ),

              const SizedBox(width: 13),

              // Display the username, name, and bio.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username.isNotEmpty ? username : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _forest,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (username.isNotEmpty &&
                        name.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Tapping the card opens this user's profile.
              const Icon(
                Icons.chevron_right,
                color: _sage,
              ),
            ],
          ),
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    final DatabaseService databaseService =
        DatabaseService();

    final String title =
        showFollowers ? 'Followers' : 'Following';

    final Stream<QuerySnapshot<Map<String, dynamic>>>
        followStream = showFollowers
            ? databaseService.getFollowers(userId)
            : databaseService.getFollowing(userId);

    // Apply the PlantPal green colors to this screen only.
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
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
        ),

        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: followStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _forest,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load $title.',
                        style: const TextStyle(color: _forest),
                      ),
                    ),
                  );
                }

                final followDocs = snapshot.data?.docs ?? [];

                if (followDocs.isEmpty) {
                  return _emptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16, 16, 16, 24,
                  ),
                  itemCount: followDocs.length,
                  itemBuilder: (context, index) {
                    final String otherUserId =
                        followDocs[index].id;

                    // Load the profile information for each user.
                    return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      future: databaseService.getUser(otherUserId),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !userSnapshot.hasData) {
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: _mint,
                                    child: Icon(
                                      Icons.person,
                                      color: _forest,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Loading user...'),
                                ],
                              ),
                            ),
                          );
                        }

                        if (userSnapshot.hasError) {
                          return const Card(
                            child: ListTile(
                              title: Text(
                                'Unable to load user.',
                              ),
                            ),
                          );
                        }

                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }

                        final data =
                            userSnapshot.data!.data() ?? {};

                        return _userCard(
                          context: context,
                          otherUserId: otherUserId,
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