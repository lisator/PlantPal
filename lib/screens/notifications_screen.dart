import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/my_plant.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/plant_reminder_service.dart';
import '../widgets/watering.dart';

import 'home_screen.dart';
import 'my_plants_screen.dart';
import 'user_profile_screen.dart';

// Extra information displayed inside activity notifications.
class _ActivityDetails {
  const _ActivityDetails({
    this.name = 'Someone',
    this.photoUrl = '',
    this.postTitle = '',
    this.preview = '',
    this.plantName = '',
  });

  final String name;
  final String photoUrl;
  final String postTitle;
  final String preview;
  final String plantName;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notifications = NotificationService();
  final PlantReminderService _reminders = PlantReminderService();
  final DatabaseService _database = DatabaseService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Set<String> _selected = {};
  final Map<String, Future<_ActivityDetails>> _detailsCache = {};

  bool _selectionMode = false;
  bool _deleting = false;

  String? _streamUserId;

  Stream<List<MyPlant>>? _plantStream;
  Stream<List<AppNotification>>? _activityStream;
  Stream<Map<String, String>>? _dismissedStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _settingsStream;

  // Theme-aware colors for light and dark mode.
  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _cardColor => Theme.of(context).colorScheme.surface;

  Color get _textColor => Theme.of(context).colorScheme.onSurface;

  Color get _primaryColor => Theme.of(context).colorScheme.primary;

  Color get _softColor => Theme.of(context).colorScheme.primaryContainer;

  Color get _borderColor => Theme.of(context).colorScheme.outlineVariant;

  // Set up Firestore streams for the signed-in user.
  void _initializeStreams(String userId) {
    if (_streamUserId == userId) return;

    _streamUserId = userId;

    _plantStream = _database.getMyPlants(userId);
    _activityStream = _notifications.watchNotifications(userId);
    _dismissedStream = _notifications.watchDismissedReminders(userId);
    _settingsStream = _db.collection('users').doc(userId).snapshots();

    _detailsCache.clear();
    _selected.clear();
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _activityKey(String id) => 'activity|$id';

  // Add or remove one notification from selection.
  void _toggleSelected(String key) {
    setState(() {
      if (!_selected.add(key)) {
        _selected.remove(key);
      }
    });
  }

  // Leave selection mode.
  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  // Select all visible notifications or deselect them.
  void _selectAll(List<String> keys) {
    setState(() {
      if (keys.isNotEmpty && keys.every(_selected.contains)) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(keys);
      }
    });
  }

  // Choose an icon based on activity type.
  IconData _activityIcon(String type) {
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

  // Choose the heading for an activity notification.
  String _activityTitle(String type) {
    switch (type) {
      case 'follow':
        return 'New follower';
      case 'like':
        return 'New like';
      case 'comment':
        return 'New comment';
      case 'reply':
        return 'New reply';
      case 'analysis':
        return 'Plant analysis saved';
      case 'new_post':
        return 'New Community post';
      default:
        return 'PlantPal notification';
    }
  }

  // Load extra information about a notification.
  Future<_ActivityDetails> _loadDetails(
    AppNotification notification,
    String userId,
  ) async {
    String name = 'Someone';
    String photoUrl = '';
    String postTitle = '';
    String preview = '';
    String plantName = '';

    // Load the actor's username and profile picture.
    if (notification.actorId.isNotEmpty && notification.type != 'analysis') {
      try {
        final doc = await _db
            .collection('users')
            .doc(notification.actorId)
            .get();

        final data = doc.data() ?? {};
        final username = (data['username'] ?? '').toString().trim();
        final displayName = (data['displayName'] ?? '').toString().trim();
        final email = (data['email'] ?? '').toString().trim();

        name = username.isNotEmpty
            ? username
            : displayName.isNotEmpty
            ? displayName
            : email.isNotEmpty
            ? email.split('@').first
            : 'Someone';

        photoUrl = (data['photoUrl'] ?? '').toString().trim();
      } catch (_) {}
    }

    // Load the related Community post title.
    if (notification.postId.isNotEmpty) {
      try {
        final post = await _db
            .collection('posts')
            .doc(notification.postId)
            .get();

        postTitle = (post.data()?['title'] ?? '').toString().trim();
      } catch (_) {}
    }

    // Load a comment preview.
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

        preview = (comment.data()?['comment'] ?? '').toString().trim();
      } catch (_) {}
    }

    // Load a reply preview.
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

        preview = (reply.data()?['reply'] ?? '').toString().trim();
      } catch (_) {}
    }

    // Load the name of the plant related to an analysis.
    if (notification.type == 'analysis' && notification.plantId.isNotEmpty) {
      try {
        final plant = await _db
            .collection('users')
            .doc(userId)
            .collection('myPlants')
            .doc(notification.plantId)
            .get();

        final data = plant.data() ?? {};

        plantName =
            [data['nickname'], data['commonName'], data['scientificName']]
                .map((value) => (value ?? '').toString().trim())
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      } catch (_) {}
    }

    return _ActivityDetails(
      name: name,
      photoUrl: photoUrl,
      postTitle: postTitle,
      preview: preview,
      plantName: plantName,
    );
  }

  // Cache activity details so they are not loaded repeatedly.
  Future<_ActivityDetails> _detailsFor(
    AppNotification notification,
    String userId,
  ) {
    return _detailsCache.putIfAbsent(
      '${userId}_${notification.id}',
      () => _loadDetails(notification, userId),
    );
  }

  // Build a readable message based on activity type.
  String _activityMessage(
    AppNotification notification,
    _ActivityDetails details,
  ) {
    final name = details.name;
    final title = details.postTitle;

    switch (notification.type) {
      case 'follow':
        return '$name started following you.';

      case 'like':
        return title.isEmpty
            ? '$name liked your post.'
            : '$name liked "$title".';

      case 'comment':
        return title.isEmpty
            ? '$name commented on your post.'
            : '$name commented on "$title".';

      case 'reply':
        return title.isEmpty
            ? '$name replied to your comment.'
            : '$name replied to your comment on "$title".';

      case 'analysis':
        return details.plantName.isEmpty
            ? 'Your plant analysis was saved.'
            : 'Analysis saved for ${details.plantName}.';

      case 'new_post':
        return title.isEmpty
            ? '$name shared a new post.'
            : '$name shared "$title".';

      default:
        return 'You have new PlantPal activity.';
    }
  }

  // Keep comment previews short.
  String _shortPreview(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) return '';

    return text.length > 120 ? '"${text.substring(0, 120)}..."' : '"$text"';
  }

  // Convert timestamps into readable times.
  String _timeAgo(DateTime? date) {
    if (date == null) return 'Just now';

    final difference = DateTime.now().difference(date);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays < 7) {
      return difference.inDays == 1
          ? 'Yesterday'
          : '${difference.inDays} days ago';
    }

    return '${date.month}/${date.day}/${date.year}';
  }

  // Open a specific plant associated with a reminder.
  Future<void> _openPlant(String userId, String plantId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('myPlants')
          .doc(plantId)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        _message('This plant is no longer available.');
        return;
      }

      final plant = MyPlant.fromFirestore({...doc.data()!, 'id': doc.id});

      openMyPlantDetails(context, plant);
    } catch (e) {
      _message('Unable to open plant: $e');
    }
  }

  // Open the content related to an activity notification.
  Future<void> _openActivity(
    String userId,
    AppNotification notification,
  ) async {
    try {
      await _notifications.markRead(userId, notification.id);
    } catch (_) {}

    if (!mounted) return;

    if (notification.type == 'follow' && notification.actorId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(userId: notification.actorId),
        ),
      );
      return;
    }

    if (notification.type == 'analysis' && notification.plantId.isNotEmpty) {
      await _openPlant(userId, notification.plantId);
      return;
    }

    HomeTabs.goTo(context, HomeTabs.community);
  }

  // Display one watering or progress reminder card.
  Widget _reminderCard(String userId, PlantCareReminder reminder) {
    final key = reminder.selectionKey;
    final selected = _selected.contains(key);

    return Card(
      color: selected ? _softColor : _cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? _primaryColor : _borderColor),
      ),
      child: ListTile(
        onLongPress: _deleting
            ? null
            : () {
                setState(() => _selectionMode = true);
                _toggleSelected(key);
              },
        onTap: _selectionMode
            ? () => _toggleSelected(key)
            : () => _openPlant(userId, reminder.plant.id),
        leading: _selectionMode
            ? Checkbox(
                value: selected,
                onChanged: _deleting ? null : (_) => _toggleSelected(key),
              )
            : CircleAvatar(
                backgroundColor: _softColor,
                child: Icon(
                  reminder.type == 'watering'
                      ? Icons.water_drop
                      : Icons.camera_alt_outlined,
                  color: reminder.type == 'watering'
                      ? wateringColor(reminder.plant.daysUntilWatering()) ??
                            _primaryColor
                      : _primaryColor,
                ),
              ),
        title: Text(
          reminder.plant.displayName,
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(reminder.message),
        trailing: _selectionMode ? null : const Icon(Icons.chevron_right),
      ),
    );
  }

  // Display one stored Community or activity notification.
  Widget _activityCard(String userId, AppNotification notification) {
    final key = _activityKey(notification.id);
    final selected = _selected.contains(key);

    return FutureBuilder<_ActivityDetails>(
      future: _detailsFor(notification, userId),
      builder: (context, snapshot) {
        final details = snapshot.data ?? const _ActivityDetails();
        final preview = _shortPreview(details.preview);

        return Card(
          color: selected || !notification.isRead ? _softColor : _cardColor,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? _primaryColor : _borderColor),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            onLongPress: _deleting
                ? null
                : () {
                    setState(() => _selectionMode = true);
                    _toggleSelected(key);
                  },
            onTap: _selectionMode
                ? () => _toggleSelected(key)
                : () => _openActivity(userId, notification),
            leading: _selectionMode
                ? Checkbox(
                    value: selected,
                    onChanged: _deleting ? null : (_) => _toggleSelected(key),
                  )
                : CircleAvatar(
                    backgroundColor: _cardColor,
                    backgroundImage: details.photoUrl.isNotEmpty
                        ? NetworkImage(details.photoUrl)
                        : null,
                    child: details.photoUrl.isEmpty
                        ? Icon(
                            _activityIcon(notification.type),
                            color: _primaryColor,
                          )
                        : null,
                  ),
            title: Text(
              _activityTitle(notification.type),
              style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(_activityMessage(notification, details)),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _timeAgo(notification.createdAt),
                  style: TextStyle(color: _primaryColor, fontSize: 12),
                ),
              ],
            ),
            trailing: _selectionMode
                ? null
                : IconButton(
                    tooltip: 'Delete notification',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleting
                        ? null
                        : () => _confirmDelete(userId, [key], const []),
                  ),
          ),
        );
      },
    );
  }

  // Confirm and process notification deletion.
  Future<void> _confirmDelete(
    String userId,
    List<String> selectedKeys,
    List<PlantCareReminder> reminders,
  ) async {
    if (selectedKeys.isEmpty || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notifications?'),
        content: Text(
          'Remove ${selectedKeys.length} selected '
          '${selectedKeys.length == 1 ? 'notification' : 'notifications'}? '
          'Plant reminders will be dismissed for '
          'their current reminder cycle.',
        ),
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
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      final activityIds = <String>[];
      final plantSelections = <PlantReminderSelection>[];

      for (final key in selectedKeys) {
        if (key.startsWith('activity|')) {
          activityIds.add(key.substring('activity|'.length));
        } else {
          for (final reminder in reminders) {
            if (reminder.selectionKey == key) {
              plantSelections.add(reminder.selection);
              break;
            }
          }
        }
      }

      await _notifications.deleteSelected(
        userId: userId,
        activityIds: activityIds,
        reminders: plantSelections,
      );

      if (!mounted) return;

      for (final id in activityIds) {
        _detailsCache.remove('${userId}_$id');
      }

      setState(() {
        _selected.removeAll(selectedKeys);

        if (_selected.isEmpty) {
          _selectionMode = false;
        }
      });

      _message('Selected notifications removed.');
    } catch (e) {
      _message('Unable to delete notifications: $e');
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  // Section heading.
  Widget _sectionTitle(String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 10),
      child: Text(
        value,
        style: TextStyle(
          color: _textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Read the saved settings and build notification sections.
  Widget _notificationContent(
    String userId,
    List<MyPlant> plants,
    Map<String, String> dismissed,
    List<AppNotification> activities,
    Map<String, dynamic> settings,
  ) {
    final communityEnabled = settings['communityNotifications'] != false;

    final wateringEnabled = settings['wateringReminders'] != false;

    final progressEnabled = settings['progressReminders'] != false;

    final savedInterval = settings['progressIntervalDays'];

    final intervalDays =
        savedInterval is int && [7, 14, 30].contains(savedInterval)
        ? savedInterval
        : 14;

    // Only calculate enabled reminder categories.
    final watering = wateringEnabled
        ? _reminders.getWateringReminders(plants, dismissed: dismissed)
        : <PlantCareReminder>[];

    final progress = progressEnabled
        ? _reminders.getProgressReminders(
            plants,
            intervalDays: intervalDays,
            dismissed: dismissed,
          )
        : <PlantCareReminder>[];

    // Hide Community notifications when disabled.
    final visibleActivities = communityEnabled
        ? activities.where((activity) => activity.type != 'analysis').toList()
        : <AppNotification>[];

    // Plant analysis notifications are separate
    // from the Community preference.
    final analysisActivities = activities
        .where((activity) => activity.type == 'analysis')
        .toList();

    final allActivities = [...visibleActivities, ...analysisActivities];

    final allReminders = [...watering, ...progress];

    final allKeys = [
      ...allReminders.map((reminder) => reminder.selectionKey),
      ...allActivities.map((activity) => _activityKey(activity.id)),
    ];

    final selectedKeys = allKeys.where(_selected.contains).toList();

    final allSelected = allKeys.isNotEmpty && allKeys.every(_selected.contains);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        if (_selectionMode) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _softColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedKeys.length} selected',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _deleting ? null : () => _selectAll(allKeys),
                  child: Text(allSelected ? 'Deselect All' : 'Select All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // WATERING REMINDERS
        if (wateringEnabled) ...[
          _sectionTitle('Watering Reminders'),

          if (watering.isEmpty) const Text('No watering reminders are due.'),

          ...watering.map((reminder) => _reminderCard(userId, reminder)),

          if (watering.isNotEmpty) ...[
            const SizedBox(height: 2),
            const WateringColorGuide(),
          ],
        ],

        // PLANT PROGRESS REMINDERS
        if (progressEnabled) ...[
          _sectionTitle('Plant Progress'),

          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Progress reminders are currently set '
              'to every $intervalDays days.',
              style: const TextStyle(fontSize: 12),
            ),
          ),

          if (progress.isEmpty)
            const Text('No plant progress updates are due.'),

          ...progress.map((reminder) => _reminderCard(userId, reminder)),
        ],

        // ACTIVITY NOTIFICATIONS
        if (communityEnabled || analysisActivities.isNotEmpty) ...[
          _sectionTitle('Activity'),

          if (allActivities.isEmpty)
            const Text('No activity notifications yet.'),

          ...allActivities.map((activity) => _activityCard(userId, activity)),
        ],

        if (!wateringEnabled &&
            !progressEnabled &&
            !communityEnabled &&
            analysisActivities.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 25),
            child: Center(
              child: Text(
                'Your notification categories are disabled. '
                'You can enable them in Settings.',
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // BULK DELETION BUTTON
        if (_selectionMode) ...[
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _deleting || selectedKeys.isEmpty
                ? null
                : () => _confirmDelete(userId, selectedKeys, allReminders),
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(
              _deleting
                  ? 'Deleting...'
                  : 'Delete Selected (${selectedKeys.length})',
            ),
          ),
        ],
      ],
    );
  }

  // Read settings while maintaining the existing
  // plant, activity, and dismissal streams.
  Widget _buildNotificationStreams(String userId) {
    return StreamBuilder<List<MyPlant>>(
      stream: _plantStream,
      builder: (context, plantSnapshot) {
        if (plantSnapshot.hasError) {
          return const Center(child: Text('Unable to load saved plants.'));
        }

        if (!plantSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<Map<String, String>>(
          stream: _dismissedStream,
          builder: (context, dismissedSnapshot) {
            if (dismissedSnapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load dismissed reminders. '
                  'Check Firestore permissions.',
                ),
              );
            }

            if (!dismissedSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<AppNotification>>(
              stream: _activityStream,
              builder: (context, activitySnapshot) {
                if (activitySnapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load activity notifications.'),
                  );
                }

                if (!activitySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _settingsStream,
                  builder: (context, settingsSnapshot) {
                    if (settingsSnapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load notification preferences.'),
                      );
                    }

                    if (!settingsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userData = settingsSnapshot.data?.data();

                    final rawSettings = userData?['settings'];

                    final settings = rawSettings is Map
                        ? Map<String, dynamic>.from(rawSettings)
                        : <String, dynamic>{};

                    return _notificationContent(
                      userId,
                      plantSnapshot.data!,
                      dismissedSnapshot.data!,
                      activitySnapshot.data!,
                      settings,
                    );
                  },
                );
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
        body: Center(child: Text('Please sign in to view notifications.')),
      );
    }

    final userId = user.uid;
    _initializeStreams(userId);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () {
                    if (_selectionMode) {
                      _exitSelection();
                    } else {
                      setState(() => _selectionMode = true);
                    }
                  },
            child: Text(_selectionMode ? 'Cancel' : 'Select'),
          ),

          if (!_selectionMode)
            PopupMenuButton<String>(
              tooltip: 'Notification options',
              onSelected: (value) async {
                if (value == 'read') {
                  try {
                    await _notifications.markAllRead(userId);
                  } catch (e) {
                    _message('Unable to mark all read: $e');
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'read', child: Text('Mark all read')),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _buildNotificationStreams(userId),
        ),
      ),
    );
  }
}
