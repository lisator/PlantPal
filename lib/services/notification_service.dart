import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

/// Handles PlantPal's in-app notifications using Firestore.
class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get the currently signed-in user.
  String? get _signedInId =>
      FirebaseAuth.instance.currentUser?.uid;

  // Each user has their own notifications collection.
  CollectionReference<Map<String, dynamic>> _inbox(
    String userId,
  ) =>
      _db
          .collection('users')
          .doc(userId)
          .collection('notifications');

  // Load the user's newest notifications.
  Stream<List<AppNotification>> watchNotifications(
    String userId,
  ) {
    if (_signedInId != userId) {
      return Stream.value(<AppNotification>[]);
    }

    return _inbox(userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AppNotification.fromDocument)
              .toList(),
        );
  }

  // Mark one notification as read.
  Future<void> markRead(
    String userId,
    String notificationId,
  ) async {
    if (_signedInId != userId) return;

    await _inbox(userId)
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark unread notifications as read.
  Future<void> markAllRead(String userId) async {
    if (_signedInId != userId) return;

    final result = await _inbox(userId)
        .where('isRead', isEqualTo: false)
        .limit(400)
        .get();

    if (result.docs.isEmpty) return;

    final batch = _db.batch();

    for (final doc in result.docs) {
      batch.update(
        doc.reference,
        {'isRead': true},
      );
    }

    await batch.commit();
  }

  // Save a notification to the recipient's inbox.
  // If this fails, the original action should still work.
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
    // Do not create notifications about your own activity,
    // except for your own plant analysis.
    if (recipientId.isEmpty ||
        (recipientId == actorId && type != 'analysis')) {
      return;
    }

    try {
      await _inbox(recipientId)
          .doc(notificationId)
          .set({
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
      debugPrint(
        'PlantPal notification not created ($type): $error',
      );
    }
  }

  // Notify someone when they gain a new follower.
  Future<void> follower({
    required String followerId,
    required String recipientId,
  }) =>
      _write(
        recipientId: recipientId,
        notificationId: 'follow_$followerId',
        type: 'follow',
        actorId: followerId,
      );

  // Notify the post author when someone likes their post.
  Future<void> like({
    required String actorId,
    required String recipientId,
    required String postId,
  }) =>
      _write(
        recipientId: recipientId,
        notificationId: 'like_${postId}_$actorId',
        type: 'like',
        actorId: actorId,
        postId: postId,
      );

  // Notify the post author about a new comment.
  Future<void> comment({
    required String actorId,
    required String recipientId,
    required String postId,
    required String commentId,
  }) =>
      _write(
        recipientId: recipientId,
        notificationId: 'comment_${postId}_$commentId',
        type: 'comment',
        actorId: actorId,
        postId: postId,
        commentId: commentId,
      );

  // Notify someone when their comment receives a reply.
  Future<void> reply({
    required String actorId,
    required String recipientId,
    required String postId,
    required String commentId,
    required String replyId,
  }) =>
      _write(
        recipientId: recipientId,
        notificationId:
            'reply_${postId}_${commentId}_$replyId',
        type: 'reply',
        actorId: actorId,
        postId: postId,
        commentId: commentId,
        replyId: replyId,
      );

  // Notify the user when a plant analysis is saved.
  Future<void> analysis({
    required String userId,
    required String plantId,
    required String analysisId,
  }) =>
      _write(
        recipientId: userId,
        notificationId:
            'analysis_${plantId}_$analysisId',
        type: 'analysis',
        actorId: userId,
        plantId: plantId,
        replyId: analysisId,
      );
}
