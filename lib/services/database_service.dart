import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/my_plant.dart';

class DatabaseService {
  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

 
  Future<void> addUser({
    required String uid,
    required String email,
    required String displayName,
    required String username,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username,
      'usernameLower': username.toLowerCase(),
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(
    String uid,
  ) async {
    return await _db
        .collection('users')
        .doc(uid)
        .get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream(
    String uid,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsers() {
    return _db
        .collection('users')
        .snapshots();
  }

  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .update(data);
  }

  Future<void> ensureUserExists({
    required String uid,
    required String email,
    String displayName = '',
  }) async {
    final userRef =
        _db.collection('users').doc(uid);

    final userDocument =
        await userRef.get();

    if (!userDocument.exists) {
      await userRef.set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'username': '',
        'usernameLower': '',
        'bio': '',
        'createdAt':
            FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> isUsernameAvailable(
    String username, {
    String? currentUid,
  }) async {
    final usernameLower =
        username.trim().toLowerCase();

    final result = await _db
        .collection('users')
        .where(
          'usernameLower',
          isEqualTo: usernameLower,
        )
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return true;
    }

    if (currentUid != null &&
        result.docs.first.id == currentUid) {
      return true;
    }

    return false;
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? username,
    String? bio,
  }) async {
    final Map<String, dynamic> updates = {};

    if (displayName != null) {
      updates['displayName'] =
          displayName.trim();
    }

    if (username != null) {
      updates['username'] =
          username.trim();

      updates['usernameLower'] =
          username.trim().toLowerCase();
    }

    if (bio != null) {
      updates['bio'] =
          bio.trim();
    }

    if (updates.isNotEmpty) {
      await _db
          .collection('users')
          .doc(uid)
          .update(updates);
    }
  }

  // =========================================================
  // FOLLOWING
  // =========================================================

  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) {
      return;
    }

    final batch = _db.batch();

    final followingRef = _db
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    final followerRef = _db
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    batch.set(
      followingRef,
      {
        'userId': targetUserId,
        'followedAt':
            FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      followerRef,
      {
        'userId': currentUserId,
        'followedAt':
            FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final batch = _db.batch();

    final followingRef = _db
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    final followerRef = _db
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    batch.delete(followingRef);
    batch.delete(followerRef);

    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getFollowing(
    String userId,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getFollowers(
    String userId,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>
      getFollowStatus({
    required String currentUserId,
    required String targetUserId,
  }) {
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .snapshots();
  }

  // =========================================================
  // POSTS
  // =========================================================

  Future<void> addPost({
    required String userId,
    required String userEmail,
    required String title,
    required String description,
    String imageUrl = '',
  }) async {
    await _db.collection('posts').add({
      'userId': userId,
      'userEmail': userEmail,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getPosts() {
    return _db
        .collection('posts')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getPostsByUser(
    String userId,
  ) {
    return _db
        .collection('posts')
        .where(
          'userId',
          isEqualTo: userId,
        )
        .snapshots();
  }

  Future<void> deletePost(
    String postId,
  ) async {
    await _db
        .collection('posts')
        .doc(postId)
        .delete();
  }

  // =========================================================
  // COMMENTS
  // =========================================================

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
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getComments(
    String postId,
  ) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots();
  }

  // =========================================================
  // LIKES
  // =========================================================

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
      'createdAt':
          FieldValue.serverTimestamp(),
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

  Stream<DocumentSnapshot<Map<String, dynamic>>>
      getLikeStatus({
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

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getLikes(
    String postId,
  ) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .snapshots();
  }

  // =========================================================
  // SAVED POSTS
  // =========================================================

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
      'savedAt':
          FieldValue.serverTimestamp(),
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

  Stream<DocumentSnapshot<Map<String, dynamic>>>
      getSaveStatus({
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

  // =========================================================
  // MY PLANTS
  // =========================================================

  // Doc id is the Perenual species id, so a species can't be added twice.
  Future<void> addMyPlant({
    required String userId,
    required MyPlant plant,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc('${plant.perenualId}')
        .set(plant.toFirestore());
  }

  Future<void> removeMyPlant({
    required String userId,
    required int perenualId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc('$perenualId')
        .delete();
  }

  /// Records a watering. [at] defaults to now; pass the previous value to undo.
  Future<void> setLastWatered({
    required String userId,
    required int perenualId,
    DateTime? at,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc('$perenualId')
        .update({
      'lastWateredAt': at == null ? Timestamp.now() : Timestamp.fromDate(at),
    });
  }

  /// Sets how often to water, or clears the schedule with null.
  Future<void> setWaterEveryDays({
    required String userId,
    required int perenualId,
    required int? days,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc('$perenualId')
        .update({'waterEveryDays': days});
  }

  Stream<List<MyPlant>> getMyPlants(
    String userId,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .orderBy(
          'addedAt',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MyPlant.fromFirestore(doc.data()))
              .toList(),
        );
  }

  Stream<bool> isInMyPlants({
    required String userId,
    required int perenualId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc('$perenualId')
        .snapshots()
        .map((doc) => doc.exists);
  }
}