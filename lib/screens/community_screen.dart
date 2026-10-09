import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'add_post_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() =>
      _CommunityScreenState();
}

class _CommunityScreenState
    extends State<CommunityScreen> {
  final DatabaseService _databaseService =
      DatabaseService();

  Future<void> _addComment(
    String postId,
  ) async {
    final TextEditingController controller =
        TextEditingController();

    final String? comment =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Comment'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Write a comment...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text =
                    controller.text.trim();

                if (text.isNotEmpty) {
                  Navigator.pop(
                    context,
                    text,
                  );
                }
              },
              child: const Text('Comment'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (comment == null ||
        comment.isEmpty) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await _databaseService.addComment(
        postId: postId,
        userId: user.uid,
        userEmail: user.email ?? '',
        comment: comment,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to add comment: $e',
          ),
        ),
      );
    }
  }

  Future<void> _deletePost(
    String postId,
  ) async {
    final bool? shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text(
            'Are you sure you want to delete this post?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _databaseService.deletePost(
        postId,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete post: $e',
          ),
        ),
      );
    }
  }

  Future<void> _toggleLike({
    required String postId,
    required User user,
    required bool isLiked,
  }) async {
    try {
      if (isLiked) {
        await _databaseService.unlikePost(
          postId: postId,
          userId: user.uid,
        );
      } else {
        await _databaseService.likePost(
          postId: postId,
          userId: user.uid,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update like: $e',
          ),
        ),
      );
    }
  }

  Future<void> _toggleSave({
    required String postId,
    required User user,
    required bool isSaved,
  }) async {
    try {
      if (isSaved) {
        await _databaseService.unsavePost(
          userId: user.uid,
          postId: postId,
        );
      } else {
        await _databaseService.savePost(
          userId: user.uid,
          postId: postId,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update saved post: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Align(
              alignment:
                  Alignment.centerRight,
              child:
                  OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const AddPostScreen(),
                    ),
                  );
                },
                icon:
                    const Icon(Icons.add),
                label:
                    const Text('Add Post'),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream:
                  _databaseService.getPosts(),
              builder:
                  (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load posts.\n${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final posts =
                    snapshot.data?.docs ?? [];

                if (posts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Icon(
                          Icons.local_florist,
                          size: 70,
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        Text(
                          'Your feed is empty',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Create a post to get started!',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  itemCount:
                      posts.length,
                  itemBuilder:
                      (context, index) {
                    final document =
                        posts[index];

                    final data =
                        document.data();

                    final String userId =
                        data['userId'] ??
                            '';

                    final String email =
                        data['userEmail'] ??
                            'PlantPal User';

                    final String title =
                        data['title'] ??
                            '';

                    final String description =
                        data['description'] ??
                            '';

                    final bool isOwner =
                        currentUser?.uid ==
                            userId;

                    return Card(
                      margin:
                          const EdgeInsets
                              .only(
                        bottom: 20,
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(
                                    Icons
                                        .person,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: Text(
                                    email,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                                if (isOwner)
                                  IconButton(
                                    tooltip:
                                        'Delete Post',
                                    onPressed:
                                        () {
                                      _deletePost(
                                        document
                                            .id,
                                      );
                                    },
                                    icon:
                                        const Icon(
                                      Icons
                                          .delete_outline,
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            Text(
                              title,
                              style:
                                  const TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Text(
                              description,
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            const Divider(),

                            Row(
                              children: [
                                StreamBuilder<
                                    DocumentSnapshot<
                                        Map<String,
                                            dynamic>>>(
                                  stream:
                                      currentUser ==
                                              null
                                          ? null
                                          : _databaseService
                                              .getLikeStatus(
                                              postId:
                                                  document.id,
                                              userId:
                                                  currentUser.uid,
                                            ),
                                  builder:
                                      (context,
                                          likeSnapshot) {
                                    final bool
                                        isLiked =
                                        likeSnapshot
                                                .data
                                                ?.exists ??
                                            false;

                                    return IconButton(
                                      tooltip:
                                          isLiked
                                              ? 'Unlike'
                                              : 'Like',
                                      icon:
                                          Icon(
                                        isLiked
                                            ? Icons
                                                .favorite
                                            : Icons
                                                .favorite_border,
                                      ),
                                      onPressed:
                                          currentUser ==
                                                  null
                                              ? null
                                              : () {
                                                  _toggleLike(
                                                    postId:
                                                        document.id,
                                                    user:
                                                        currentUser,
                                                    isLiked:
                                                        isLiked,
                                                  );
                                                },
                                    );
                                  },
                                ),

                                StreamBuilder<
                                    QuerySnapshot<
                                        Map<String,
                                            dynamic>>>(
                                  stream:
                                      _databaseService
                                          .getLikes(
                                    document.id,
                                  ),
                                  builder:
                                      (context,
                                          likesSnapshot) {
                                    final int
                                        likeCount =
                                        likesSnapshot
                                                .data
                                                ?.docs
                                                .length ??
                                            0;

                                    return Text(
                                      '$likeCount',
                                    );
                                  },
                                ),

                                const SizedBox(
                                  width: 20,
                                ),

                                IconButton(
                                  tooltip:
                                      'Comment',
                                  icon:
                                      const Icon(
                                    Icons
                                        .comment_outlined,
                                  ),
                                  onPressed:
                                      () {
                                    _addComment(
                                      document
                                          .id,
                                    );
                                  },
                                ),

                                const Spacer(),

                                StreamBuilder<
                                    DocumentSnapshot<
                                        Map<String,
                                            dynamic>>>(
                                  stream:
                                      currentUser ==
                                              null
                                          ? null
                                          : _databaseService
                                              .getSaveStatus(
                                              userId:
                                                  currentUser.uid,
                                              postId:
                                                  document.id,
                                            ),
                                  builder:
                                      (context,
                                          saveSnapshot) {
                                    final bool
                                        isSaved =
                                        saveSnapshot
                                                .data
                                                ?.exists ??
                                            false;

                                    return IconButton(
                                      tooltip:
                                          isSaved
                                              ? 'Unsave'
                                              : 'Save',
                                      icon:
                                          Icon(
                                        isSaved
                                            ? Icons
                                                .bookmark
                                            : Icons
                                                .bookmark_border,
                                      ),
                                      onPressed:
                                          currentUser ==
                                                  null
                                              ? null
                                              : () {
                                                  _toggleSave(
                                                    postId:
                                                        document.id,
                                                    user:
                                                        currentUser,
                                                    isSaved:
                                                        isSaved,
                                                  );
                                                },
                                    );
                                  },
                                ),
                              ],
                            ),

                            StreamBuilder<
                                QuerySnapshot<
                                    Map<String,
                                        dynamic>>>(
                              stream:
                                  _databaseService
                                      .getComments(
                                document.id,
                              ),
                              builder:
                                  (context,
                                      commentSnapshot) {
                                if (!commentSnapshot
                                        .hasData ||
                                    commentSnapshot
                                        .data!
                                        .docs
                                        .isEmpty) {
                                  return const SizedBox();
                                }

                                final comments =
                                    commentSnapshot
                                        .data!
                                        .docs;

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children:
                                      comments.map(
                                    (commentDoc) {
                                      final comment =
                                          commentDoc
                                              .data();

                                      final String
                                          commentEmail =
                                          comment[
                                                  'userEmail'] ??
                                              'User';

                                      final String
                                          commentText =
                                          comment[
                                                  'comment'] ??
                                              '';

                                      return Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          top: 8,
                                        ),
                                        child:
                                            RichText(
                                          text:
                                              TextSpan(
                                            style:
                                                DefaultTextStyle.of(
                                              context,
                                            ).style,
                                            children: [
                                              TextSpan(
                                                text:
                                                    '$commentEmail: ',
                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    commentText,
                                              ),
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}