import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';

class UserProfileScreen
    extends StatelessWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final DatabaseService databaseService =
        DatabaseService();

    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Profile'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream:
            databaseService
                .getUserStream(userId),
        builder:
            (context, snapshot) {
          if (snapshot
                  .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'User not found.',
              ),
            );
          }

          final data =
              snapshot.data!.data()!;

          final displayName =
              data['displayName'] ??
                  'PlantPal User';

          final username =
              data['username'] ?? '';

          final bio =
              data['bio'] ?? '';

          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 55,
                  child: Icon(
                    Icons.person,
                    size: 60,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  displayName,
                  style:
                      const TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                if (username
                    .toString()
                    .isNotEmpty)
                  Text(
                    '@$username',
                    style:
                        const TextStyle(
                      fontSize: 16,
                    ),
                  ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  bio.toString().isEmpty
                      ? 'No bio yet.'
                      : bio,
                ),

                const SizedBox(
                  height: 24,
                ),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceEvenly,
                  children: [
                    StreamBuilder<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>(
                      stream:
                          databaseService
                              .getPostsByUser(
                        userId,
                      ),
                      builder:
                          (context,
                              postSnapshot) {
                        return _Stat(
                          number:
                              '${postSnapshot.data?.docs.length ?? 0}',
                          label:
                              'Posts',
                        );
                      },
                    ),

                    StreamBuilder<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>(
                      stream:
                          databaseService
                              .getFollowers(
                        userId,
                      ),
                      builder:
                          (context,
                              followerSnapshot) {
                        return _Stat(
                          number:
                              '${followerSnapshot.data?.docs.length ?? 0}',
                          label:
                              'Followers',
                        );
                      },
                    ),

                    StreamBuilder<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>(
                      stream:
                          databaseService
                              .getFollowing(
                        userId,
                      ),
                      builder:
                          (context,
                              followingSnapshot) {
                        return _Stat(
                          number:
                              '${followingSnapshot.data?.docs.length ?? 0}',
                          label:
                              'Following',
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(
                  height: 25,
                ),

                if (currentUser != null &&
                    currentUser.uid !=
                        userId)
                  StreamBuilder<
                      DocumentSnapshot<
                          Map<String,
                              dynamic>>>(
                    stream:
                        databaseService
                            .getFollowStatus(
                      currentUserId:
                          currentUser.uid,
                      targetUserId:
                          userId,
                    ),
                    builder:
                        (context,
                            followSnapshot) {
                      final bool
                          following =
                          followSnapshot
                                  .data
                                  ?.exists ??
                              false;

                      return SizedBox(
                        width:
                            double.infinity,
                        child:
                            ElevatedButton(
                          onPressed:
                              () async {
                            if (following) {
                              await databaseService
                                  .unfollowUser(
                                currentUserId:
                                    currentUser.uid,
                                targetUserId:
                                    userId,
                              );
                            } else {
                              await databaseService
                                  .followUser(
                                currentUserId:
                                    currentUser.uid,
                                targetUserId:
                                    userId,
                              );
                            }
                          },
                          child: Text(
                            following
                                ? 'Unfollow'
                                : 'Follow',
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(
                  height: 30,
                ),

                const Divider(),

                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Posts',
                    style:
                        TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                StreamBuilder<
                    QuerySnapshot<
                        Map<String,
                            dynamic>>>(
                  stream:
                      databaseService
                          .getPostsByUser(
                    userId,
                  ),
                  builder:
                      (context,
                          postSnapshot) {
                    if (!postSnapshot
                        .hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final posts =
                        postSnapshot
                            .data!.docs;

                    if (posts.isEmpty) {
                      return const Text(
                        'No posts yet.',
                      );
                    }

                    return Column(
                      children:
                          posts.map(
                        (post) {
                          final data =
                              post.data();

                          final title =
                              data['title'] ??
                                  '';

                          final description =
                              data['description'] ??
                                  '';

                          final imageUrl =
                              data['imageUrl'] ??
                                  '';

                          return Card(
                            margin:
                                const EdgeInsets
                                    .only(
                              bottom: 12,
                            ),
                            child:
                                Padding(
                              padding:
                                  const EdgeInsets
                                      .all(
                                14,
                              ),
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    title,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          18,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        6,
                                  ),

                                  Text(
                                    description,
                                  ),

                                  if (imageUrl
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(
                                      height:
                                          12,
                                    ),

                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                        10,
                                      ),
                                      child:
                                          Image.network(
                                        imageUrl,
                                        width:
                                            double.infinity,
                                        fit:
                                            BoxFit.contain,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String number;
  final String label;

  const _Stat({
    required this.number,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Text(
          number,
          style:
              const TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        Text(label),
      ],
    );
  }
}