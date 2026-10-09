import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'add_post_screen.dart';
import 'find_users_screen.dart';
import 'user_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final DatabaseService _databaseService = DatabaseService();

  Future<void> _addComment(String postId) async {
    final commentController = TextEditingController();

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final bool? shouldPost = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Comment'),
          content: TextField(
            controller: commentController,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write a comment...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Post'),
            ),
          ],
        );
      },
    );

    if (shouldPost != true) {
      commentController.dispose();
      return;
    }

    final comment = commentController.text.trim();

    commentController.dispose();

    if (comment.isEmpty) {
      return;
    }

    await _databaseService.addComment(
      postId: postId,
      userId: user.uid,
      userEmail: user.email ?? '',
      comment: comment,
    );
  }

  Future<void> _deletePost(String postId) async {
    final bool? shouldDelete = await showDialog<bool>(
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
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _databaseService.deletePost(postId);
    }
  }

  Future<void> _toggleLike({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    if (isLiked) {
      await _databaseService.unlikePost(
        postId: postId,
        userId: userId,
      );
    } else {
      await _databaseService.likePost(
        postId: postId,
        userId: userId,
      );
    }
  }

  Future<void> _toggleSave({
    required String postId,
    required String userId,
    required bool isSaved,
  }) async {
    if (isSaved) {
      await _databaseService.unsavePost(
        userId: userId,
        postId: postId,
      );
    } else {
      await _databaseService.savePost(
        userId: userId,
        postId: postId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _databaseService.getFollowing(currentUser.uid),
        builder: (context, followingSnapshot) {
          final Set<String> followingIds =
              followingSnapshot.data?.docs.map((doc) => doc.id).toSet() ?? {};

          final Set<String> allowedUserIds = {
            currentUser.uid,
            ...followingIds,
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  4,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'People You May Know',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const FindUsersScreen(),
                          ),
                        );
                      },
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: 145,
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _databaseService.getUsers(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final recommended = userSnapshot.data!.docs
                        .where(
                          (doc) =>
                              doc.id != currentUser.uid &&
                              !followingIds.contains(doc.id),
                        )
                        .take(8)
                        .toList();

                    if (recommended.isEmpty) {
                      return const Center(
                        child: Text(
                          'You are following everyone!',
                        ),
                      );
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      itemCount: recommended.length,
                      itemBuilder: (context, index) {
                        final userDoc = recommended[index];
                        final data = userDoc.data();

                        final String username =
                            data['username'] ?? '';

                        final String name =
                            data['displayName'] ??
                                'PlantPal User';

                        return SizedBox(
                          width: 135,
                          child: Card(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        UserProfileScreen(
                                      userId: userDoc.id,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(
                                        Icons.person,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      username.isNotEmpty
                                          ? '@$username'
                                          : name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await _databaseService
                                              .followUser(
                                            currentUserId:
                                                currentUser.uid,
                                            targetUserId:
                                                userDoc.id,
                                          );
                                        },
                                        child: const Text(
                                          'Follow',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your Feed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                      icon: const Icon(Icons.add),
                      label: const Text('Add Post'),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _databaseService.getPosts(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final posts = snapshot.data!.docs.where(
                      (post) {
                        final postUserId =
                            post.data()['userId'] ?? '';

                        return allowedUserIds.contains(
                          postUserId,
                        );
                      },
                    ).toList();

                    if (posts.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Your feed is empty. Create a post or follow someone to see their posts.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final data = post.data();

                        final String postId = post.id;
                        final String userId =
                            data['userId'] ?? '';
                        final String userEmail =
                            data['userEmail'] ?? '';
                        final String title =
                            data['title'] ?? '';
                        final String description =
                            data['description'] ?? '';
                        final String imageUrl =
                            data['imageUrl'] ?? '';

                        final bool isOwner =
                            userId == currentUser.uid;

                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: 16,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(
                                        Icons.person,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        userEmail,
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isOwner)
                                      IconButton(
                                        onPressed: () {
                                          _deletePost(postId);
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(description),

                                if (imageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 14),

                                  Center(
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                        12,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        height: 320,
                                        color: Colors.black12,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return const Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .broken_image_outlined,
                                                    size: 42,
                                                  ),
                                                  SizedBox(
                                                    height: 8,
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
                                  ),
                                ],

                                const SizedBox(height: 8),
                                const Divider(),

                                Row(
                                  children: [
                                    StreamBuilder<
                                        DocumentSnapshot<
                                            Map<String, dynamic>>>(
                                      stream: _databaseService
                                          .getLikeStatus(
                                        postId: postId,
                                        userId:
                                            currentUser.uid,
                                      ),
                                      builder:
                                          (context, likeSnapshot) {
                                        final bool isLiked =
                                            likeSnapshot
                                                    .data
                                                    ?.exists ??
                                                false;

                                        return IconButton(
                                          onPressed: () {
                                            _toggleLike(
                                              postId: postId,
                                              userId:
                                                  currentUser.uid,
                                              isLiked: isLiked,
                                            );
                                          },
                                          icon: Icon(
                                            isLiked
                                                ? Icons.favorite
                                                : Icons
                                                    .favorite_border,
                                          ),
                                        );
                                      },
                                    ),

                                    StreamBuilder<
                                        QuerySnapshot<
                                            Map<String, dynamic>>>(
                                      stream:
                                          _databaseService.getLikes(
                                        postId,
                                      ),
                                      builder:
                                          (context, likesSnapshot) {
                                        return Text(
                                          '${likesSnapshot.data?.docs.length ?? 0}',
                                        );
                                      },
                                    ),

                                    const SizedBox(width: 12),

                                    IconButton(
                                      onPressed: () {
                                        _addComment(postId);
                                      },
                                      icon: const Icon(
                                        Icons.comment_outlined,
                                      ),
                                    ),

                                    const Spacer(),

                                    StreamBuilder<
                                        DocumentSnapshot<
                                            Map<String, dynamic>>>(
                                      stream: _databaseService
                                          .getSaveStatus(
                                        userId:
                                            currentUser.uid,
                                        postId: postId,
                                      ),
                                      builder:
                                          (context, saveSnapshot) {
                                        final bool isSaved =
                                            saveSnapshot
                                                    .data
                                                    ?.exists ??
                                                false;

                                        return IconButton(
                                          onPressed: () {
                                            _toggleSave(
                                              postId: postId,
                                              userId:
                                                  currentUser.uid,
                                              isSaved: isSaved,
                                            );
                                          },
                                          icon: Icon(
                                            isSaved
                                                ? Icons.bookmark
                                                : Icons
                                                    .bookmark_border,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                StreamBuilder<
                                    QuerySnapshot<
                                        Map<String, dynamic>>>(
                                  stream: _databaseService
                                      .getComments(
                                    postId,
                                  ),
                                  builder:
                                      (context, commentSnapshot) {
                                    final comments =
                                        commentSnapshot
                                                .data
                                                ?.docs ??
                                            [];

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: comments.map(
                                        (commentDoc) {
                                          final commentData =
                                              commentDoc.data();

                                          final String email =
                                              commentData[
                                                      'userEmail'] ??
                                                  '';

                                          final String comment =
                                              commentData[
                                                      'comment'] ??
                                                  '';

                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(
                                              top: 5,
                                            ),
                                            child: RichText(
                                              text: TextSpan(
                                                style:
                                                    DefaultTextStyle
                                                        .of(context)
                                                        .style,
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        '$email: ',
                                                    style:
                                                        const TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        comment,
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
          );
        },
      ),
    );
  }
}