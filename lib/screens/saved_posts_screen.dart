
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'user_profile_screen.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: databaseService.getSavedPosts(
          currentUser.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load saved posts.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final savedPosts = snapshot.data!.docs;

          if (savedPosts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text('You have no saved posts yet.'),
                  SizedBox(height: 6),
                  Text(
                    'Bookmark a post in Community to save it here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
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
                    return const ListTile(
                      title: Text('Unable to load post.'),
                    );
                  }

                  if (!postSnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // The original author may have deleted
                  // the post after it was bookmarked.
                  if (!postSnapshot.data!.exists) {
                    return Card(
                      child: ListTile(
                        title: const Text(
                          'This post is no longer available.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove from Saved',
                          icon: const Icon(
                            Icons.bookmark_remove_outlined,
                          ),
                          onPressed: () async {
                            await databaseService.unsavePost(
                              userId: currentUser.uid,
                              postId: postId,
                            );
                          },
                        ),
                      ),
                    );
                  }

                  final data = postSnapshot.data!.data()!;

                  final title =
                      (data['title'] ?? '').toString();
                  final description =
                      (data['description'] ?? '').toString();
                  final imageUrl =
                      (data['imageUrl'] ?? '').toString();
                  final authorId =
                      (data['userId'] ?? '').toString();
                  final fallbackEmail =
                      (data['userEmail'] ?? '').toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // POST AUTHOR
                          StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: databaseService
                                .getUserStream(authorId),
                            builder: (context, userSnapshot) {
                              final userData =
                                  userSnapshot.data?.data() ?? {};

                              final username =
                                  (userData['username'] ?? '')
                                      .toString()
                                      .trim();

                              final email =
                                  (userData['email'] ??
                                          fallbackEmail)
                                      .toString();

                              final displayName =
                                  username.isNotEmpty
                                      ? '@$username'
                                      : (email.isNotEmpty
                                          ? email
                                          : 'PlantPal User');

                              return InkWell(
                                onTap: authorId.isEmpty
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                UserProfileScreen(
                                              userId: authorId,
                                            ),
                                          ),
                                        ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // POST TITLE
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // POST DESCRIPTION
                          Text(description),

                          // POST IMAGE
                          if (imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: 260,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(
                                  height: 100,
                                  child: Center(
                                    child: Text(
                                      'Unable to load image.',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          const Divider(),

                          // UNSAVE BUTTON
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                try {
                                  await databaseService.unsavePost(
                                    userId: currentUser.uid,
                                    postId: postId,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Unable to unsave post: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.bookmark_remove_outlined,
                              ),
                              label: const Text('Unsave'),
                            ),
                          ),
                        ],
                      ),
                    ),
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
