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

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: followStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load $title.',
              ),
            );
          }

          final followDocs =
              snapshot.data?.docs ?? [];

          if (followDocs.isEmpty) {
            return Center(
              child: Text(
                showFollowers
                    ? 'No followers yet.'
                    : 'Not following anyone yet.',
              ),
            );
          }

          return ListView.separated(
            itemCount: followDocs.length,
            separatorBuilder:
                (context, index) =>
                    const Divider(height: 1),
            itemBuilder: (context, index) {
              final followDoc =
                  followDocs[index];

              final String otherUserId =
                  followDoc.id;

              return FutureBuilder<
                  DocumentSnapshot<
                      Map<String, dynamic>>>(
                future: databaseService.getUser(
                  otherUserId,
                ),
                builder:
                    (context, userSnapshot) {
                  if (userSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          Icons.person,
                        ),
                      ),
                      title: Text(
                        'Loading...',
                      ),
                    );
                  }

                  if (!userSnapshot.hasData ||
                      !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final data =
                      userSnapshot.data!.data() ?? {};

                  final String name =
                      data['displayName'] ??
                          'PlantPal User';

                  final String username =
                      data['username'] ?? '';

                  final String bio =
                      data['bio'] ?? '';

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    leading: const CircleAvatar(
                      radius: 24,
                      child: Icon(
                        Icons.person,
                      ),
                    ),
                    title: Text(
                      username.isNotEmpty
                          ? '@$username'
                          : name,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        if (username.isNotEmpty)
                          Text(name),
                        if (bio.isNotEmpty)
                          Text(
                            bio,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfileScreen(
                            userId: otherUserId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}