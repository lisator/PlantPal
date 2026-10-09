import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // USERS 

  Future<void> addUser({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(
    String uid,
  ) async {
    return await _db.collection('users').doc(uid).get();
  }

  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // POSTS

  Future<void> addPost({
    required String userId,
    required String userEmail,
    required String title,
    required String description,
  }) async {
    await _db.collection('posts').add({
      'userId': userId,
      'userEmail': userEmail,
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPosts() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  // COMMENTS 

  Future<void> addComment({
    required String postId,
    required String userId,
    required String userEmail,
    required String comment,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
      'userId': userId,
      'userEmail': userEmail,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getComments(
    String postId,
  ) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots();
  }

  // LIKES 

  Future<void> likePost({
    required String postId,
    required String userId,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .set({
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlikePost({
    required String postId,
    required String userId,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .delete();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getLikeStatus({
    required String postId,
    required String userId,
  }) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getLikes(
    String postId,
  ) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .snapshots();
  }

  //  SAVED POSTS 

  Future<void> savePost({
    required String userId,
    required String postId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .set({
      'postId': postId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsavePost({
    required String userId,
    required String postId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .delete();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getSaveStatus({
    required String userId,
    required String postId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .snapshots();
  }
  
  Future<void> ensureUserExists({
    required String uid,
    required String email,
    String displayName = '',
  }) async {
    final userRef = _db.collection('users').doc(uid);

    final userDocument = await userRef.get();

    if (!userDocument.exists) {
      await userRef.set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}