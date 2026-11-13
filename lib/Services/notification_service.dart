import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _signedInId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _inbox(String userId) {
    return _db.collection('users').doc(userId).collection('notifications');
  }

  CollectionReference<Map<String, dynamic>> _dismissals(String userId) {
    return _db.collection('users').doc(userId).collection('dismissedReminders');
  }

  void _checkOwner(String userId) {
    if (_signedInId == null || _signedInId != userId) {
      throw StateError('You can only manage your own notifications.');
    }
  }

  Stream<List<AppNotification>> watchNotifications(String userId) {
    if (_signedInId != userId) {
      return Stream.value(<AppNotification>[]);
    }

    return _inbox(userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppNotification.fromDocument).toList(),
        );
  }

  // Watch which plant reminder cycles were dismissed.
  Stream<Map<String, String>> watchDismissedReminders(String userId) {
    if (_signedInId != userId) {
      return Stream.value(<String, String>{});
    }

    return _dismissals(userId).snapshots().map((snapshot) {
      final result = <String, String>{};

      for (final doc in snapshot.docs) {
        result[doc.id] = (doc.data()['cycleKey'] ?? '').toString();
      }

      return result;
    });
  }

  // Convert a due date into its reminder-cycle identifier.
  static String cycleKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String reminderId(String type, String plantId) {
    if (type != 'watering' && type != 'progress') {
      throw ArgumentError('Unknown reminder type.');
    }

    return '${type}_$plantId';
  }

  Future<void> markRead(String userId, String notificationId) async {
    _checkOwner(userId);

    await _inbox(userId).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllRead(String userId) async {
    _checkOwner(userId);

    while (true) {
      final unread = await _inbox(userId)
          .where('isRead', isEqualTo: false)
          .limit(100)
          .get();

      if (unread.docs.isEmpty) return;

      final batch = _db.batch();

      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    }
  }

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    _checkOwner(userId);

    if (notificationId.trim().isEmpty) {
      throw ArgumentError('Notification ID is required.');
    }

    await _inbox(userId).doc(notificationId).delete();
  }

  Future<void> clearAllNotifications(String userId) async {
    _checkOwner(userId);

    while (true) {
      final result = await _inbox(userId).limit(100).get();

      if (result.docs.isEmpty) return;

      final batch = _db.batch();

      for (final doc in result.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  // Dismiss one watering or progress reminder.
  Future<void> dismissReminder({
    required String userId,
    required String type,
    required String plantId,
    required DateTime dueDate,
  }) async {
    _checkOwner(userId);

    final id = reminderId(type, plantId);

    await _dismissals(userId).doc(id).set({
      'cycleKey': cycleKey(dueDate),
      'dismissedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete multiple activity notifications and dismiss
  // multiple plant reminders in a single operation.
  //
  // Each activity ID refers to a Firestore notification.
  // Each plant reminder records its due-date cycle.
  Future<void> deleteSelected({
    required String userId,
    required List<String> activityIds,
    required List<PlantReminderSelection> reminders,
  }) async {
    _checkOwner(userId);

    final ids = activityIds.toSet();
    final reminderMap = <String, PlantReminderSelection>{};

    for (final reminder in reminders) {
      final id = reminderId(reminder.type, reminder.plantId);

      reminderMap[id] = reminder;
    }

    final operations = <void Function(WriteBatch)>[];

    for (final id in ids) {
      if (id.trim().isEmpty) continue;

      final ref = _inbox(userId).doc(id);
      operations.add((batch) => batch.delete(ref));
    }

    for (final entry in reminderMap.entries) {
      final ref = _dismissals(userId).doc(entry.key);
      final cycle = cycleKey(entry.value.dueDate);

      operations.add(
        (batch) => batch.set(ref, {
          'cycleKey': cycle,
          'dismissedAt': FieldValue.serverTimestamp(),
        }),
      );
    }

    // Stay comfortably below Firestore batch limits.
    for (var start = 0; start < operations.length; start += 100) {
      final batch = _db.batch();
      final end = (start + 100 < operations.length)
          ? start + 100
          : operations.length;

      for (var i = start; i < end; i++) {
        operations[i](batch);
      }

      await batch.commit();
    }
  }

  // Create an activity notification.
  Future<void> _write({
    required String recipientId,
    required String notificationId,
    required String type,
    required String actorId,
    String postId = '',
    String commentId = '',
    String replyId = '',
    String plantId = '',
  }) async {
    if (recipientId.isEmpty || (recipientId == actorId && type != 'analysis')) {
      return;
    }

    if (_signedInId != actorId) {
      debugPrint('Notification skipped: actor not signed in.');
      return;
    }

    try {
      await _inbox(recipientId).doc(notificationId).set({
        'type': type,
        'actorId': actorId,
        'postId': postId,
        'commentId': commentId,
        'replyId': replyId,
        'plantId': plantId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (error) {
      debugPrint('Notification not created ($type): $error');
    }
  }

  Future<void> follower({
    required String followerId,
    required String recipientId,
  }) {
    return _write(
      recipientId: recipientId,
      notificationId: 'follow_$followerId',
      type: 'follow',
      actorId: followerId,
    );
  }

  Future<void> like({
    required String actorId,
    required String recipientId,
    required String postId,
  }) {
    return _write(
      recipientId: recipientId,
      notificationId: 'like_${postId}_$actorId',
      type: 'like',
      actorId: actorId,
      postId: postId,
    );
  }

  Future<void> comment({
    required String actorId,
    required String recipientId,
    required String postId,
    required String commentId,
  }) {
    return _write(
      recipientId: recipientId,
      notificationId: 'comment_${postId}_$commentId',
      type: 'comment',
      actorId: actorId,
      postId: postId,
      commentId: commentId,
    );
  }

  Future<void> reply({
    required String actorId,
    required String recipientId,
    required String postId,
    required String commentId,
    required String replyId,
  }) {
    return _write(
      recipientId: recipientId,
      notificationId: 'reply_${postId}_${commentId}_$replyId',
      type: 'reply',
      actorId: actorId,
      postId: postId,
      commentId: commentId,
      replyId: replyId,
    );
  }

  Future<void> analysis({
    required String userId,
    required String plantId,
    required String analysisId,
  }) {
    return _write(
      recipientId: userId,
      notificationId: 'analysis_${plantId}_$analysisId',
      type: 'analysis',
      actorId: userId,
      plantId: plantId,
      replyId: analysisId,
    );
  }
}

// Used when deleting selected plant reminders.
class PlantReminderSelection {
  const PlantReminderSelection({
    required this.type,
    required this.plantId,
    required this.dueDate,
  });

  final String type;
  final String plantId;
  final DateTime dueDate;
}
