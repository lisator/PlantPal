
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/my_plant.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/watering.dart';

import 'home_screen.dart';
import 'user_profile_screen.dart';

// Information used to display a detailed notification.
class _NotificationDetails {
  final String actorName;
  final String actorPhoto;
  final String postTitle;
  final String preview;
  final String plantName;

  const _NotificationDetails({
    this.actorName = 'Someone',
    this.actorPhoto = '',
    this.postTitle = '',
    this.preview = '',
    this.plantName = '',
  });
}

// Display Community notifications and plant watering reminders.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // PlantPal colors.
  static const Color _forest = Color(0xFF315F43);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService =
      NotificationService();
  final DatabaseService _databaseService = DatabaseService();

  // Store notification lookups so they are not repeated
  // every time Flutter rebuilds the screen.
  final Map<String, Future<_NotificationDetails>>
      _detailsCache = {};

  // Choose an icon based on the notification type.
  IconData _notificationIcon(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add_alt_1;
      case 'like':
        return Icons.favorite_border;
      case 'comment':
        return Icons.mode_comment_outlined;
      case 'reply':
        return Icons.reply_outlined;
      case 'analysis':
        return Icons.monitor_heart_outlined;
      case 'new_post':
        return Icons.post_add_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  // Choose a title based on the notification type.
  String _notificationTitle(String type) {
    switch (type) {
      case 'follow':
        return 'New follower';
      case 'like':
        return 'New post like';
      case 'comment':
        return 'New comment';
      case 'reply':
        return 'New reply';
      case 'analysis':
        return 'Plant analysis saved';
      case 'new_post':
        return 'New Community post';
      default:
        return 'PlantPal activity';
    }
  }

  // Find details related to the notification.
  Future<_NotificationDetails> _loadDetails(
    AppNotification notification,
    String userId,
  ) async {
    String actorName = 'Someone';
    String actorPhoto = '';
    String postTitle = '';
    String preview = '';
    String plantName = '';

    // Get the username and profile picture.
    if (notification.actorId.isNotEmpty &&
        notification.type != 'analysis') {
      try {
        final actor = await _db
            .collection('users')
            .doc(notification.actorId)
            .get();

        final data = actor.data();

        if (data != null) {
          final username =
              (data['username'] ?? '').toString().trim();

          final displayName =
              (data['displayName'] ?? '').toString().trim();

          final email =
              (data['email'] ?? '').toString().trim();

          if (username.isNotEmpty) {
            actorName = username;
          } else if (displayName.isNotEmpty) {
            actorName = displayName;
          } else if (email.isNotEmpty) {
            actorName = email.split('@').first;
          }

          actorPhoto =
              (data['photoUrl'] ?? '').toString().trim();
        }
      } catch (_) {
        // Keep a general name if the user cannot be loaded.
      }
    }

    // Get the title of the related Community post.
    if (notification.postId.isNotEmpty) {
      try {
        final post = await _db
            .collection('posts')
            .doc(notification.postId)
            .get();

        final data = post.data();

        if (data != null) {
          postTitle =
              (data['title'] ?? '').toString().trim();
        }
      } catch (_) {
        // The post may have been removed.
      }
    }

    // Get the comment text for a comment notification.
    if (notification.type == 'comment' &&
        notification.postId.isNotEmpty &&
        notification.commentId.isNotEmpty) {
      try {
        final comment = await _db
            .collection('posts')
            .doc(notification.postId)
            .collection('comments')
            .doc(notification.commentId)
            .get();

        preview =
            (comment.data()?['comment'] ?? '')
                .toString()
                .trim();
      } catch (_) {
        // The comment may no longer exist.
      }
    }

    // Get the reply text for a reply notification.
    if (notification.type == 'reply' &&
        notification.postId.isNotEmpty &&
        notification.commentId.isNotEmpty &&
        notification.replyId.isNotEmpty) {
      try {
        final reply = await _db
            .collection('posts')
            .doc(notification.postId)
            .collection('comments')
            .doc(notification.commentId)
            .collection('replies')
            .doc(notification.replyId)
            .get();

        preview =
            (reply.data()?['reply'] ?? '')
                .toString()
                .trim();
      } catch (_) {
        // The reply may have been removed.
      }
    }

    // Get the saved plant name for analysis notifications.
    if (notification.type == 'analysis' &&
        notification.plantId.isNotEmpty) {
      try {
        final plant = await _db
            .collection('users')
            .doc(userId)
            .collection('myPlants')
            .doc(notification.plantId)
            .get();

        final data = plant.data();

        if (data != null) {
          final customName =
              (data['nickname'] ?? '').toString().trim();

          final commonName =
              (data['commonName'] ?? '').toString().trim();

          final scientificName =
              (data['scientificName'] ?? '')
                  .toString()
                  .trim();

          if (customName.isNotEmpty) {
            plantName = customName;
          } else if (commonName.isNotEmpty) {
            plantName = commonName;
          } else if (scientificName.isNotEmpty) {
            plantName = scientificName;
          }
        }
      } catch (_) {
        // Use a general description if unavailable.
      }
    }

    return _NotificationDetails(
      actorName: actorName,
      actorPhoto: actorPhoto,
      postTitle: postTitle,
      preview: preview,
      plantName: plantName,
    );
  }

  // Reuse previously loaded notification information.
  Future<_NotificationDetails> _detailsFor(
    AppNotification notification,
    String userId,
  ) {
    return _detailsCache.putIfAbsent(
      '${userId}_${notification.id}',
      () => _loadDetails(notification, userId),
    );
  }

  // Explain exactly who did what.
  String _notificationMessage(
    AppNotification notification,
    _NotificationDetails details,
  ) {
    final name = details.actorName;
    final postTitle = details.postTitle;

    switch (notification.type) {
      case 'follow':
        return '$name started following you.';

      case 'like':
        if (postTitle.isNotEmpty) {
          return '$name liked your post "$postTitle".';
        }
        return '$name liked your Community post.';

      case 'comment':
        if (postTitle.isNotEmpty) {
          return '$name commented on your post "$postTitle".';
        }
        return '$name commented on your post.';

      case 'reply':
        if (postTitle.isNotEmpty) {
          return '$name replied to your comment on "$postTitle".';
        }
        return '$name replied to your comment.';

      case 'analysis':
        if (details.plantName.isNotEmpty) {
          return 'A plant health analysis was saved for '
              '"${details.plantName}".';
        }
        return 'A plant health analysis was saved to My Plants.';

      case 'new_post':
        if (postTitle.isNotEmpty) {
          return '$name shared a new Community post '
              '"$postTitle".';
        }
        return '$name shared a new Community post.';

      default:
        return 'You have new activity in PlantPal.';
    }
  }

  // Display a short preview of a comment or reply.
  String _previewText(String text) {
    if (text.isEmpty) return '';

    final clean = text.replaceAll(RegExp(r'\s+'), ' ');

    if (clean.length > 120) {
      return '"${clean.substring(0, 120)}..."';
    }

    return '"$clean"';
  }

  // Show when the notification was created.
  String _timeAgo(DateTime? createdAt) {
    if (createdAt == null) return 'Just now';

    final difference = DateTime.now().difference(createdAt);

    if (difference.isNegative ||
        difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes min ago';
    }

    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hr ago';
    }

    if (difference.inDays < 7) {
      final days = difference.inDays;
      return days == 1
          ? 'Yesterday'
          : '$days days ago';
    }

    // Show the date for older notifications.
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');

    return '$month/$day/${createdAt.year}';
  }

  // Open the related screen after tapping a notification.
  Future<void> _openNotification(
    BuildContext context,
    String userId,
    AppNotification notification,
  ) async {
    // Mark the notification as read.
    try {
      await _notificationService.markRead(
        userId,
        notification.id,
      );
    } catch (error) {
      debugPrint(
        'Unable to mark notification as read: $error',
      );
    }

    if (!context.mounted) return;

    // A new follower opens that person's profile.
    if (notification.type == 'follow' &&
        notification.actorId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: notification.actorId,
          ),
        ),
      );
      return;
    }

    // A plant analysis opens My Plants.
    if (notification.type == 'analysis') {
      HomeTabs.goTo(context, HomeTabs.myPlants);
      return;
    }

    // Likes, comments, replies, and new posts open Community.
    HomeTabs.goTo(context, HomeTabs.community);
  }

  // Show a user's profile picture or the activity icon.
  Widget _notificationAvatar(
    AppNotification notification,
    _NotificationDetails details,
  ) {
    if (details.actorPhoto.isNotEmpty &&
        notification.type != 'analysis') {
      return CircleAvatar(
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(
          details.actorPhoto,
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: Colors.white,
      child: Icon(
        _notificationIcon(notification.type),
        color: _forest,
      ),
    );
  }

  // Build one detailed notification.
  Widget _notificationCard({
    required BuildContext context,
    required String userId,
    required AppNotification notification,
  }) {
    return FutureBuilder<_NotificationDetails>(
      future: _detailsFor(notification, userId),
      builder: (context, snapshot) {
        final details =
            snapshot.data ?? const _NotificationDetails();

        final message =
            _notificationMessage(notification, details);

        final preview = _previewText(details.preview);

        return Card(
          color: notification.isRead
              ? Colors.white
              : _mint,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            leading: _notificationAvatar(
              notification,
              details,
            ),
            title: Text(
              _notificationTitle(notification.type),
              style: const TextStyle(
                color: _forest,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                    ),
                  ),

                  // Comment or reply preview.
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  const SizedBox(height: 7),

                  Text(
                    _timeAgo(notification.createdAt),
                    style: TextStyle(
                      color: _forest.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            trailing: notification.isRead
                ? const Icon(
                    Icons.chevron_right,
                    color: _forest,
                  )
                : const Icon(
                    Icons.circle,
                    color: _forest,
                    size: 10,
                  ),
            onTap: () {
              _openNotification(
                context,
                userId,
                notification,
              );
            },
          ),
        );
      },
    );
  }

  // Show plants needing water today or overdue.
  Widget _wateringReminders(
    BuildContext context,
    String userId,
  ) {
    return StreamBuilder<List<MyPlant>>(
      stream: _databaseService.getMyPlants(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load watering reminders.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: _forest,
            ),
          );
        }

        // Find plants that need watering.
        final duePlants = snapshot.data!.where((plant) {
          final days = plant.daysUntilWatering();
          return days != null && days <= 0;
        }).toList();

        // Show the most overdue plants first.
        duePlants.sort((a, b) {
          return a.daysUntilWatering()!.compareTo(
            b.daysUntilWatering()!,
          );
        });

        if (duePlants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'All caught up! No plants need watering today.',
              style: TextStyle(color: _ink),
            ),
          );
        }

        return Column(
          children: duePlants.map((plant) {
            return Card(
              color: _mint,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.water_drop_outlined,
                    color: _forest,
                  ),
                ),
                title: Text(
                  plant.displayName,
                  style: const TextStyle(
                    color: _forest,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  wateringStatus(plant),
                  style: const TextStyle(color: _ink),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: _forest,
                ),
                onTap: () {
                  HomeTabs.goTo(
                    context,
                    HomeTabs.myPlants,
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in to view notifications.',
          ),
        ),
      );
    }

    final userId = currentUser.uid;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
        ),
      ),
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: const Text(
            'Notifications',
            style: TextStyle(
              color: _forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _pale,
          foregroundColor: _forest,
          surfaceTintColor: _pale,
          actions: [
            // Mark all notifications as read.
            TextButton(
              onPressed: () async {
                try {
                  await _notificationService
                      .markAllRead(userId);
                } catch (error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to mark notifications as read.',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(color: _forest),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Plant watering section.
                const Text(
                  'Plant Care',
                  style: TextStyle(
                    color: _forest,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _wateringReminders(
                  context,
                  userId,
                ),

                const SizedBox(height: 20),

                // Community and analysis notifications.
                const Text(
                  'Activity',
                  style: TextStyle(
                    color: _forest,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                StreamBuilder<List<AppNotification>>(
                  stream: _notificationService
                      .watchNotifications(userId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Unable to load notifications. '
                        'Please check Firebase permissions.',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _forest,
                        ),
                      );
                    }

                    final notifications = snapshot.data!;

                    if (notifications.isEmpty) {
                      return const Text(
                        'No activity notifications yet.',
                        style: TextStyle(color: _ink),
                      );
                    }

                    return Column(
                      children: notifications.map((notification) {
                        return _notificationCard(
                          context: context,
                          userId: userId,
                          notification: notification,
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
