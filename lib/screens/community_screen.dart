import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/reply_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/post_photo_gallery.dart';

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

  static const Color _forest = PlantPalColors.forest;

  bool _showExplore = true;

  final Set<String> _expandedComments = {};
  final Set<String> _expandedReplies = {};

  Color get _background => PlantPalColors.background(context);
  Color get _card => PlantPalColors.card(context);
  Color get _text => PlantPalColors.text(context);
  Color get _secondary => PlantPalColors.secondaryText(context);
  Color get _accent => PlantPalColors.accent(context);
  Color get _border => PlantPalColors.border(context);
  Color get _soft => PlantPalColors.softBackground(context);

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Something went wrong: $error')));
  }

  // Keep dialogs consistent with the current app theme.
  ThemeData _dialogTheme(BuildContext context) {
    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _forest,
        brightness: base.brightness,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PlantPalColors.card(context),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: PlantPalColors.accent(context),
        selectionHandleColor: PlantPalColors.accent(context),
        selectionColor: PlantPalColors.softBackground(context),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PlantPalColors.accent(context),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _forest,
          foregroundColor: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF304237) : Colors.white,
        hintStyle: TextStyle(color: PlantPalColors.secondaryText(context)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: PlantPalColors.accent(context),
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PlantPalColors.border(context)),
        ),
      ),
    );
  }

  // Confirmation popup for posts, comments, and replies.
  Future<bool> _confirm(String subject) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _dialogTheme(dialogContext),
        child: AlertDialog(
          title: Text('Delete $subject?'),
          content: Text('Are you sure you want to delete this $subject?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    return answer ?? false;
  }

  // Popup for writing and editing post text.
  Future<String?> _askForText({
    required String title,
    String existing = '',
    int maximum = 500,
  }) async {
    final controller = TextEditingController(text: existing);

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => Theme(
          data: _dialogTheme(dialogContext),
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: maximum,
              style: TextStyle(color: PlantPalColors.text(dialogContext)),
              decoration: const InputDecoration(
                hintText: 'Write something...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (result == null || result.isEmpty || result.length > maximum) {
        return null;
      }

      return result;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  // Add a comment to a Community post.
  Future<void> _addComment(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = await _askForText(title: 'Add comment');
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

  // Edit an existing comment.
  Future<void> _editComment(
    String postId,
    String commentId,
    String current,
  ) async {
    final text = await _askForText(title: 'Edit comment', existing: current);
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

  // Delete a comment.
  Future<void> _deleteComment(String postId, String commentId) async {
    if (!await _confirm('comment')) return;

    try {
      await _db.deleteComment(postId: postId, commentId: commentId);
    } catch (e) {
      _error(e);
    }
  }

  // Add a reply underneath a comment.
  Future<void> _addReply(String postId, String commentId) async {
    final text = await _askForText(title: 'Reply to comment');

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

  // Edit a reply.
  Future<void> _editReply(
    String postId,
    String commentId,
    String replyId,
    String current,
  ) async {
    final text = await _askForText(title: 'Edit reply', existing: current);

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

  // Delete a reply.
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

  // Edit a post's title and description.
  Future<void> _editPost(String postId, Map<String, dynamic> data) async {
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

  // Delete a Community post.
  Future<void> _deletePost(String postId) async {
    if (!await _confirm('post')) return;

    try {
      await _db.deletePost(postId);
    } catch (e) {
      _error(e);
    }
  }

  // Like or unlike a post.
  Future<void> _toggleLike(String postId, String uid, bool liked) async {
    try {
      if (liked) {
        await _db.unlikePost(postId: postId, userId: uid);
      } else {
        await _db.likePost(postId: postId, userId: uid);
      }
    } catch (e) {
      _error(e);
    }
  }

  // Save or unsave a post.
  Future<void> _toggleSave(String postId, String uid, bool saved) async {
    try {
      if (saved) {
        await _db.unsavePost(userId: uid, postId: postId);
      } else {
        await _db.savePost(userId: uid, postId: postId);
      }
    } catch (e) {
      _error(e);
    }
  }

  // Display the post or comment author's username.
  Widget _author(String uid, String fallback, {bool small = false}) {
    if (uid.isEmpty) {
      return Text(
        fallback.isEmpty ? 'PlantPal User' : fallback,
        style: TextStyle(color: _text),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.getUserStream(uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final username = (data['username'] ?? '').toString().trim();

        final email = (data['email'] ?? fallback).toString();

        final photo = (data['photoUrl'] ?? '').toString();

        final name = username.isNotEmpty
            ? username
            : email.isNotEmpty
            ? email
            : 'PlantPal User';

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: uid),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: small ? 12 : 17,
                backgroundColor: _soft,
                backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                child: photo.isEmpty
                    ? Icon(Icons.person, size: small ? 14 : 20, color: _accent)
                    : null,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Display replies underneath a comment.
  Widget _replyList(String postId, String commentId) {
    final key = '$postId/$commentId';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _replies.getReplies(postId: postId, commentId: commentId),
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
          margin: const EdgeInsets.only(left: 16, top: 2, bottom: 6),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: _border, width: 2)),
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
                      : 'View ${docs.length} '
                            '${docs.length == 1 ? 'reply' : 'replies'}',
                ),
              ),

              if (expanded)
                ...docs.map((doc) {
                  final data = doc.data();

                  final uid = (data['userId'] ?? '').toString();

                  final text = (data['reply'] ?? '').toString();

                  final mine = FirebaseAuth.instance.currentUser?.uid == uid;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _author(
                                uid,
                                (data['userEmail'] ?? '').toString(),
                                small: true,
                              ),

                              const SizedBox(height: 4),

                              Text(text, style: TextStyle(color: _text)),

                              if (data['updatedAt'] != null)
                                Text(
                                  'Edited',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _secondary,
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
                                _editReply(postId, commentId, doc.id, text);
                              }

                              if (value == 'delete') {
                                _deleteReply(postId, commentId, doc.id);
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

  // Display comments underneath a Community post.
  Widget _comments(String postId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.getComments(postId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load comments.');
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final expanded = _expandedComments.contains(postId);

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
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                expanded ? 'Hide comments' : 'View all ${docs.length} comments',
              ),
            ),

            if (expanded)
              ...docs.map((doc) {
                final data = doc.data();

                final uid = (data['userId'] ?? '').toString();

                final text = (data['comment'] ?? '').toString();

                final mine = FirebaseAuth.instance.currentUser?.uid == uid;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _author(
                              uid,
                              (data['userEmail'] ?? '').toString(),
                              small: true,
                            ),

                            const SizedBox(height: 5),

                            Text(text, style: TextStyle(color: _text)),

                            if (data['updatedAt'] != null)
                              Text(
                                'Edited',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _secondary,
                                ),
                              ),

                            TextButton(
                              onPressed: () => _addReply(postId, doc.id),
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
                              _editComment(postId, doc.id, text);
                            }

                            if (choice == 'delete') {
                              _deleteComment(postId, doc.id);
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

  // Display one Community post.
  Widget _post(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data();

    final owner = (data['userId'] ?? '').toString();

    final images = postImageUrls(data);

    final mine = owner == uid;

    return Card(
      color: _card,
      elevation: 1,
      shadowColor: _forest.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _border),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _author(owner, (data['userEmail'] ?? '').toString()),
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
                      PopupMenuItem(value: 'edit', child: Text('Edit post')),
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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: _text, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 6),

            // Post description: fixes light text on white.
            Text(
              (data['description'] ?? '').toString(),
              style: TextStyle(color: _text),
            ),

            // Keep existing multiple-image gallery.
            if (images.isNotEmpty)
              PostPhotoGallery(key: ValueKey(doc.id), imageUrls: images),

            const SizedBox(height: 10),

            Divider(color: _border, height: 1),

            Row(
              children: [
                // LIKE BUTTON
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _db.getLikeStatus(postId: doc.id, userId: uid),
                  builder: (context, snapshot) {
                    final liked = snapshot.data?.exists ?? false;

                    return IconButton(
                      tooltip: liked ? 'Unlike' : 'Like',
                      onPressed: () => _toggleLike(doc.id, uid, liked),
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? const Color(0xFFD35D65) : _accent,
                      ),
                    );
                  },
                ),

                // LIKE COUNT
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.getLikes(doc.id),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data?.docs.length ?? 0}',
                      style: TextStyle(color: _text),
                    );
                  },
                ),

                // ADD COMMENT BUTTON
                IconButton(
                  tooltip: 'Add comment',
                  onPressed: () => _addComment(doc.id),
                  icon: Icon(Icons.mode_comment_outlined, color: _accent),
                ),

                // COMMENT COUNT
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.getComments(doc.id),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data?.docs.length ?? 0}',
                      style: TextStyle(color: _text),
                    );
                  },
                ),

                const Spacer(),

                // SAVE / UNSAVE BUTTON
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _db.getSaveStatus(userId: uid, postId: doc.id),
                  builder: (context, snapshot) {
                    final saved = snapshot.data?.exists ?? false;

                    return IconButton(
                      tooltip: saved ? 'Unsave post' : 'Save post',
                      onPressed: () => _toggleSave(doc.id, uid, saved),
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                        color: _accent,
                      ),
                    );
                  },
                ),
              ],
            ),

            _comments(doc.id),
          ],
        ),
      ),
    );
  }

  // Explore displays every post.
  // Following displays posts by followed users and the user.
  Widget _communityFeed(String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.getFollowing(userId),
      builder: (context, followingSnapshot) {
        if (followingSnapshot.hasError) {
          return const Center(child: Text('Unable to load followed users.'));
        }

        if (!followingSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final followed =
            followingSnapshot.data!.docs.map((doc) => doc.id).toSet()
              ..add(userId);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.getPosts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load posts.'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data!.docs.where((post) {
              return _showExplore ||
                  followed.contains((post.data()['userId'] ?? '').toString());
            }).toList();

            if (posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _showExplore
                        ? 'No Community posts yet. '
                              'Be the first to share!'
                        : 'No posts yet. Follow someone '
                              'or create a post!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _text),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 20, top: 4),
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

  // Explore and Following tabs.
  Widget _feedTab(String text, IconData icon, bool explore) {
    final selected = _showExplore == explore;

    final backgroundColor = selected ? _forest : _soft;

    final foregroundColor = selected ? Colors.white : _text;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _showExplore = explore;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foregroundColor),

              const SizedBox(width: 7),

              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view Community.')),
      );
    }

    final theme = Theme.of(context);

    // Respect the selected appearance instead
    // of forcing a light color scheme.
    return Theme(
      data: theme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
          brightness: theme.brightness,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _accent),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _forest,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: _accent),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: _accent,
          selectionColor: _soft,
          selectionHandleColor: _accent,
        ),
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: Text(
            'Community',
            style: TextStyle(color: _text, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _text,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grow together, one leaf at a time 🌱',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Share plants, ask questions, '
                                'and find new friends.',
                                style: TextStyle(color: _text),
                              ),
                            ],
                          ),
                        ),

                        // Find users and create posts.
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
                                  icon: const Icon(Icons.people_outline),
                                  label: const Text('Find People'),
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
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Post'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Explore and Following buttons.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
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
              body: _communityFeed(user.uid),
            ),
          ),
        ),
      ),
    );
  }
}
