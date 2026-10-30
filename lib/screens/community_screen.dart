
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/reply_service.dart';

import 'add_post_screen.dart';
import 'find_users_screen.dart';
import 'user_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final DatabaseService _db = DatabaseService();
  final ReplyService _replies = ReplyService();

  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  bool _showExplore = true;

  // Keeps track of opened comments and replies.
  final Set<String> _expandedComments = {};
  final Set<String> _expandedReplies = {};

  // Show errors without crashing the screen.
  void _error(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Something went wrong: $error'),
      ),
    );
  }

  // Ask the user before deleting something.
  Future<bool> _confirm(String subject) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete $subject?'),
            content: Text(
              'Are you sure you want to delete this $subject?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Text box for creating and editing comments or replies.
  Future<String?> _askForText({
    required String title,
    String existing = '',
    int maximum = 500,
  }) async {
    String input = existing;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: existing,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: maximum,
          onChanged: (value) {
            input = value;
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                input.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null ||
        result.isEmpty ||
        result.length > maximum) {
      return null;
    }

    return result;
  }

  // Add a new comment to a post.
  Future<void> _addComment(String postId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final text = await _askForText(
      title: 'Add comment',
    );

    if (text == null) return;

    try {
      await _db.addComment(
        postId: postId,
        userId: user.uid,
        userEmail: user.email ?? '',
        comment: text,
      );

      if (mounted) {
        setState(() {
          _expandedComments.add(postId);
        });
      }
    } catch (e) {
      _error(e);
    }
  }

  // Edit a comment you created.
  Future<void> _editComment(
    String postId,
    String commentId,
    String current,
  ) async {
    final text = await _askForText(
      title: 'Edit comment',
      existing: current,
    );

    if (text == null) return;

    try {
      await _db.editComment(
        postId: postId,
        commentId: commentId,
        comment: text,
      );
    } catch (e) {
      _error(e);
    }
  }

  // Delete a comment you created.
  Future<void> _deleteComment(
    String postId,
    String commentId,
  ) async {
    if (!await _confirm('comment')) return;

    try {
      await _db.deleteComment(
        postId: postId,
        commentId: commentId,
      );
    } catch (e) {
      _error(e);
    }
  }

  // Add a reply underneath a specific comment.
  Future<void> _addReply(
    String postId,
    String commentId,
  ) async {
    final text = await _askForText(
      title: 'Reply to comment',
    );

    if (text == null) return;

    try {
      await _replies.addReply(
        postId: postId,
        commentId: commentId,
        reply: text,
      );

      if (mounted) {
        setState(() {
          _expandedReplies.add('$postId/$commentId');
        });
      }
    } catch (e) {
      _error(e);
    }
  }

  // Edit one of your replies.
  Future<void> _editReply(
    String postId,
    String commentId,
    String replyId,
    String current,
  ) async {
    final text = await _askForText(
      title: 'Edit reply',
      existing: current,
    );

    if (text == null) return;

    try {
      await _replies.editReply(
        postId: postId,
        commentId: commentId,
        replyId: replyId,
        reply: text,
      );
    } catch (e) {
      _error(e);
    }
  }

  // Delete one of your replies.
  Future<void> _deleteReply(
    String postId,
    String commentId,
    String replyId,
  ) async {
    if (!await _confirm('reply')) return;

    try {
      await _replies.deleteReply(
        postId: postId,
        commentId: commentId,
        replyId: replyId,
      );
    } catch (e) {
      _error(e);
    }
  }

  // Edit a post.
  Future<void> _editPost(
    String postId,
    Map<String, dynamic> data,
  ) async {
    final title = await _askForText(
      title: 'Edit title',
      existing: (data['title'] ?? '').toString(),
      maximum: 100,
    );

    if (title == null || !mounted) return;

    final description = await _askForText(
      title: 'Edit description',
      existing: (data['description'] ?? '').toString(),
      maximum: 1000,
    );

    if (description == null) return;

    try {
      await _db.editPost(
        postId: postId,
        title: title,
        description: description,
      );
    } catch (e) {
      _error(e);
    }
  }

  // Delete a post.
  Future<void> _deletePost(String postId) async {
    if (!await _confirm('post')) return;

    try {
      await _db.deletePost(postId);
    } catch (e) {
      _error(e);
    }
  }

  // Like or unlike a post.
  Future<void> _toggleLike(
    String postId,
    String uid,
    bool liked,
  ) async {
    try {
      if (liked) {
        await _db.unlikePost(
          postId: postId,
          userId: uid,
        );
      } else {
        await _db.likePost(
          postId: postId,
          userId: uid,
        );
      }
    } catch (e) {
      _error(e);
    }
  }

  // Save or unsave a post.
  Future<void> _toggleSave(
    String postId,
    String uid,
    bool saved,
  ) async {
    try {
      if (saved) {
        await _db.unsavePost(
          userId: uid,
          postId: postId,
        );
      } else {
        await _db.savePost(
          userId: uid,
          postId: postId,
        );
      }
    } catch (e) {
      _error(e);
    }
  }

  // Display a user's username without the @ symbol.
  // Tapping the username opens their profile.
  Widget _author(
    String uid,
    String fallback, {
    bool small = false,
  }) {
    if (uid.isEmpty) {
      return Text(
        fallback.isEmpty ? 'PlantPal User' : fallback,
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.getUserStream(uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final username =
            (data['username'] ?? '').toString().trim();

        final email =
            (data['email'] ?? fallback).toString();

        final photo =
            (data['photoUrl'] ?? '').toString();

        final name = username.isNotEmpty
            ? username
            : (email.isNotEmpty ? email : 'PlantPal User');

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    UserProfileScreen(userId: uid),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: small ? 12 : 17,
                backgroundImage: photo.isEmpty
                    ? null
                    : NetworkImage(photo),
                child: photo.isEmpty
                    ? Icon(
                        Icons.person,
                        size: small ? 14 : 20,
                      )
                    : null,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Display replies under a comment.
  Widget _replyList(
    String postId,
    String commentId,
  ) {
    final key = '$postId/$commentId';

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _replies.getReplies(
        postId: postId,
        commentId: commentId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load replies.');
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final expanded = _expandedReplies.contains(key);

        return Container(
          margin: const EdgeInsets.only(
            left: 16,
            top: 2,
            bottom: 6,
          ),
          padding: const EdgeInsets.only(left: 12),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _sage,
                width: 2,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    if (expanded) {
                      _expandedReplies.remove(key);
                    } else {
                      _expandedReplies.add(key);
                    }
                  });
                },
                child: Text(
                  expanded
                      ? 'Hide replies'
                      : 'View ${docs.length} ${docs.length == 1 ? 'reply' : 'replies'}',
                ),
              ),
              if (expanded)
                ...docs.map((doc) {
                  final data = doc.data();

                  final uid =
                      (data['userId'] ?? '').toString();

                  final text =
                      (data['reply'] ?? '').toString();

                  final mine =
                      FirebaseAuth.instance.currentUser?.uid ==
                          uid;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _pale,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _author(
                                uid,
                                (data['userEmail'] ?? '')
                                    .toString(),
                                small: true,
                              ),
                              const SizedBox(height: 3),
                              Text(text),
                              if (data['updatedAt'] != null)
                                const Text(
                                  'Edited',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (mine)
                          PopupMenuButton<String>(
                            tooltip: 'Reply options',
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editReply(
                                  postId,
                                  commentId,
                                  doc.id,
                                  text,
                                );
                              }

                              if (value == 'delete') {
                                _deleteReply(
                                  postId,
                                  commentId,
                                  doc.id,
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit reply'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete reply'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // Display comments underneath a post.
  Widget _comments(String postId) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.getComments(postId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load comments.');
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final expanded =
            _expandedComments.contains(postId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (expanded) {
                    _expandedComments.remove(postId);
                  } else {
                    _expandedComments.add(postId);
                  }
                });
              },
              icon: Icon(
                expanded
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              label: Text(
                expanded
                    ? 'Hide comments'
                    : 'View all ${docs.length} comments',
              ),
            ),
            if (expanded)
              ...docs.map((doc) {
                final data = doc.data();

                final uid =
                    (data['userId'] ?? '').toString();

                final text =
                    (data['comment'] ?? '').toString();

                final mine =
                    FirebaseAuth.instance.currentUser?.uid ==
                        uid;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _pale,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _author(
                              uid,
                              (data['userEmail'] ?? '')
                                  .toString(),
                              small: true,
                            ),
                            const SizedBox(height: 5),
                            Text(text),
                            if (data['updatedAt'] != null)
                              const Text(
                                'Edited',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            TextButton(
                              onPressed: () {
                                _addReply(postId, doc.id);
                              },
                              child: const Text('Reply'),
                            ),
                            _replyList(postId, doc.id),
                          ],
                        ),
                      ),
                      if (mine)
                        PopupMenuButton<String>(
                          tooltip: 'Comment options',
                          onSelected: (choice) {
                            if (choice == 'edit') {
                              _editComment(
                                postId,
                                doc.id,
                                text,
                              );
                            }

                            if (choice == 'delete') {
                              _deleteComment(
                                postId,
                                doc.id,
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit comment'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete comment'),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // RESPONSIVE POST IMAGE
  //
  // This is the updated part.
  // On phones, images fit the available width.
  // On computers, images stop growing at 550 pixels.
  // BoxFit.contain keeps the full picture visible.

  Widget _postImage(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

          // Maximum image width on larger screens.
          final imageWidth =
              availableWidth > 550 ? 550.0 : availableWidth;

          // Use a shorter height on phone screens.
          final imageHeight =
              imageWidth < 400 ? 230.0 : 320.0;

          return Center(
            child: Container(
              width: imageWidth,
              height: imageHeight,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                imageUrl,
                width: imageWidth,
                height: imageHeight,

                // Show the whole plant without cutting it off.
                fit: BoxFit.contain,

                // Show loading while the picture downloads.
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },

                // Show a message if the image cannot load.
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined),
                          SizedBox(height: 8),
                          Text('Image unavailable'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // Build one Community post.
  Widget _post(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) {
    final data = doc.data();

    final owner =
        (data['userId'] ?? '').toString();

    final imageUrl =
        (data['imageUrl'] ?? '').toString();

    final mine = owner == uid;

    return Card(
      color: Colors.white,
      elevation: 1,
      shadowColor: _forest.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _mint),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username and post settings.
            Row(
              children: [
                Expanded(
                  child: _author(
                    owner,
                    (data['userEmail'] ?? '').toString(),
                  ),
                ),
                if (mine)
                  PopupMenuButton<String>(
                    tooltip: 'Post options',
                    onSelected: (choice) {
                      if (choice == 'edit') {
                        _editPost(doc.id, data);
                      }

                      if (choice == 'delete') {
                        _deletePost(doc.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit post'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete post'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Post title.
            Text(
              (data['title'] ?? '').toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),

            // Post description.
            Text(
              (data['description'] ?? '').toString(),
            ),

            // Responsive picture.
            if (imageUrl.isNotEmpty)
              _postImage(imageUrl),

            const SizedBox(height: 10),
            const Divider(color: _mint, height: 1),

            // Like, comment, and bookmark buttons.
            Row(
              children: [
                StreamBuilder<
                    DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _db.getLikeStatus(
                    postId: doc.id,
                    userId: uid,
                  ),
                  builder: (context, snapshot) {
                    final liked =
                        snapshot.data?.exists ?? false;

                    return IconButton(
                      tooltip: liked ? 'Unlike' : 'Like',
                      onPressed: () {
                        _toggleLike(doc.id, uid, liked);
                      },
                      icon: Icon(
                        liked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: liked
                            ? const Color(0xFFD35D65)
                            : _forest,
                      ),
                    );
                  },
                ),
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.getLikes(doc.id),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data?.docs.length ?? 0}',
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Add comment',
                  onPressed: () {
                    _addComment(doc.id);
                  },
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: _forest,
                  ),
                ),
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.getComments(doc.id),
                  builder: (context, snapshot) => Text(
                    '${snapshot.data?.docs.length ?? 0}',
                    style: const TextStyle(color: _forest),
                  ),
                ),
                const Spacer(),
                StreamBuilder<
                    DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _db.getSaveStatus(
                    userId: uid,
                    postId: doc.id,
                  ),
                  builder: (context, snapshot) {
                    final saved =
                        snapshot.data?.exists ?? false;

                    return IconButton(
                      tooltip:
                          saved ? 'Unsave post' : 'Save post',
                      onPressed: () {
                        _toggleSave(
                          doc.id,
                          uid,
                          saved,
                        );
                      },
                      icon: Icon(
                        saved
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: _forest,
                      ),
                    );
                  },
                ),
              ],
            ),

            // Comments and replies.
            _comments(doc.id),
          ],
        ),
      ),
    );
  }

  // Show the available Community posts using the selected feed.
  Widget _communityFeed(String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.getFollowing(userId),
      builder: (context, followingSnapshot) {
        if (followingSnapshot.hasError) {
          return const Center(
            child: Text('Unable to load followed users.'),
          );
        }

        if (!followingSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final followed = followingSnapshot.data!.docs
            .map((doc) => doc.id)
            .toSet()
          ..add(userId);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.getPosts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Unable to load posts.'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final posts = snapshot.data!.docs.where((post) {
              // Explore shows everyone. Following keeps the original filter.
              return _showExplore ||
                  followed.contains(
                    (post.data()['userId'] ?? '').toString(),
                  );
            }).toList();

            if (posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.spa_outlined,
                        size: 48,
                        color: _sage,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _showExplore
                            ? 'No Community posts yet. Be the first to share!'
                            : 'No posts yet. Follow someone or create a post!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _forest),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(
                bottom: 20,
                top: 4,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return _post(posts[index], userId);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Sign in to view Community.'),
        ),
      );
    }

    // Apply PlantPal colors to the Community screen.
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
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _forest,
            foregroundColor: Colors.white,
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
            'Community',
            style: TextStyle(
              color: _forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _pale,
          surfaceTintColor: _pale,
        ),

        // The header now scrolls away with the posts.
        // This gives posts more space on smaller screens.
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        // Community welcome message.
                        const Padding(
                          padding: EdgeInsets.fromLTRB(
                            16, 12, 16, 8,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grow together, one leaf at a time 🌱',
                                style: TextStyle(
                                  color: _forest,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Share plants, ask questions, and find new friends.',
                                style: TextStyle(
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Find People and Add Post buttons.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const FindUsersScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.people_outline,
                                  ),
                                  label: const Text(
                                    'Find People',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddPostScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.add,
                                  ),
                                  label: const Text(
                                    'Add Post',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Explore and Following feed tabs.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            12, 6, 12, 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _feedTab(
                                  'Explore',
                                  Icons.explore_outlined,
                                  true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _feedTab(
                                  'Following',
                                  Icons.people_alt_outlined,
                                  false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },

              // Posts scroll beneath the upper header.
              body: _communityFeed(user.uid),
            ),
          ),
        ),
      ),
    );
  }


  // Button used to switch between Explore and Following.
  Widget _feedTab(
    String text,
    IconData icon,
    bool explore,
  ) {
    final selected = _showExplore == explore;

    return Material(
      color: selected ? _forest : _mint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _showExplore = explore;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : _forest,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : _forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}