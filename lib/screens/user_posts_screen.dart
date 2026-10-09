import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';

class UserPostsScreen
    extends StatelessWidget {
  final String userId;
  final String title;

  const UserPostsScreen({
    super.key,
    required this.userId,
    this.title = 'Posts',
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final DatabaseService databaseService =
        DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream:
            databaseService
                .getPostsByUser(
          userId,
        ),
        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load posts.',
              ),
            );
          }

          final posts =
              snapshot.data?.docs ?? [];

          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet.',
              ),
            );
          }

          final sortedPosts = [
            ...posts,
          ];

          sortedPosts.sort(
            (a, b) {
              final aData =
                  a.data();

              final bData =
                  b.data();

              final Timestamp? aTime =
                  aData['createdAt']
                      as Timestamp?;

              final Timestamp? bTime =
                  bData['createdAt']
                      as Timestamp?;

              if (aTime == null &&
                  bTime == null) {
                return 0;
              }

              if (aTime == null) {
                return 1;
              }

              if (bTime == null) {
                return -1;
              }

              return bTime.compareTo(
                aTime,
              );
            },
          );

          return ListView.builder(
            padding:
                const EdgeInsets.all(
              12,
            ),
            itemCount:
                sortedPosts.length,
            itemBuilder:
                (context, index) {
              final post =
                  sortedPosts[index];

              final data =
                  post.data();

              final String postTitle =
                  data['title'] ?? '';

              final String description =
                  data['description'] ??
                      '';

              final String imageUrl =
                  data['imageUrl'] ??
                      '';

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 16,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        postTitle,
                        style:
                            const TextStyle(
                          fontSize: 21,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        description,
                      ),

                      if (imageUrl
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 14,
                        ),

                        ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                          child:
                              Container(
                            width:
                                double.infinity,
                            height: 320,
                            color:
                                Colors.black12,
                            child:
                                Image.network(
                              imageUrl,
                              fit:
                                  BoxFit.contain,
                              errorBuilder:
                                  (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return const Center(
                                  child:
                                      Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      Icon(
                                        Icons
                                            .broken_image_outlined,
                                        size:
                                            42,
                                      ),
                                      SizedBox(
                                        height:
                                            8,
                                      ),
                                      Text(
                                        'Unable to load image',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}