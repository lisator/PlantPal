import 'package:cloud_firestore/cloud_firestore.dart';

/// An activity record shown in PlantPal's in-app notifications inbox.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.createdAt,
    required this.isRead,
    this.postId = '',
    this.plantId = '',
    this.commentId = '',
    this.replyId = '',
  });

  final String id;
  final String type;
  final String actorId;
  final DateTime? createdAt;
  final bool isRead;
  final String postId;
  final String plantId;
  final String commentId;
  final String replyId;

  factory AppNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['createdAt'];

    return AppNotification(
      id: document.id,
      type: (data['type'] ?? '').toString(),
      actorId: (data['actorId'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      isRead: data['isRead'] == true,
      postId: (data['postId'] ?? '').toString(),
      plantId: (data['plantId'] ?? '').toString(),
      commentId: (data['commentId'] ?? '').toString(),
      replyId: (data['replyId'] ?? '').toString(),
    );
  }
}
