import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Stores replies beneath the comment they belong to.
class ReplyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _replies(
    String postId,
    String commentId,
  ) =>
      _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies');

  User _currentUser() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    return user;
  }

  String _validated(String value) {
    final text = value.trim();

    if (text.isEmpty || text.length > 500) {
      throw ArgumentError('Reply must be 1–500 characters.');
    }

    return text;
  }

  // Get replies for a comment.
  Stream<QuerySnapshot<Map<String, dynamic>>> getReplies({
    required String postId,
    required String commentId,
  }) =>
      _replies(postId, commentId)
          .orderBy('createdAt')
          .snapshots();

  // Add a new reply.
  Future<void> addReply({
    required String postId,
    required String commentId,
    required String reply,
  }) async {
    final user = _currentUser();

    await _replies(postId, commentId).add({
      'userId': user.uid,
      'userEmail': user.email ?? '',
      'reply': _validated(reply),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Edit your own reply.
  Future<void> editReply({
    required String postId,
    required String commentId,
    required String replyId,
    required String reply,
  }) async {
    final uid = _currentUser().uid;
    final doc = _replies(postId, commentId).doc(replyId);
    final existing = await doc.get();

    if (!existing.exists || existing.data()?['userId'] != uid) {
      throw StateError('You can only edit your own reply.');
    }

    await doc.update({
      'reply': _validated(reply),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete your own reply.
  Future<void> deleteReply({
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    final uid = _currentUser().uid;
    final doc = _replies(postId, commentId).doc(replyId);
    final existing = await doc.get();

    if (!existing.exists || existing.data()?['userId'] != uid) {
      throw StateError('You can only delete your own reply.');
    }

    await doc.delete();
  }
}