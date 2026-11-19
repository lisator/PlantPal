import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/my_plant.dart';
import 'notification_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // USER ACCOUNTS

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

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) async {
    return await _db.collection('users').doc(uid).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsers() {
    return _db.collection('users').snapshots();
  }

  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('users').doc(uid).update(data);
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
        'username': '',
        'usernameLower': '',
        'bio': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> isUsernameAvailable(
    String username, {
    String? currentUid,
  }) async {
    final usernameLower = username.trim().toLowerCase();

    final result = await _db
        .collection('users')
        .where('usernameLower', isEqualTo: usernameLower)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return true;
    }

    if (currentUid != null && result.docs.first.id == currentUid) {
      return true;
    }

    return false;
  }

  // PROFILE

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? username,
    String? bio,
  }) async {
    final Map<String, dynamic> updates = {};

    if (displayName != null) {
      updates['displayName'] = displayName.trim();
    }

    if (username != null) {
      updates['username'] = username.trim();
      updates['usernameLower'] = username.trim().toLowerCase();
    }

    if (bio != null) {
      updates['bio'] = bio.trim();
    }

    if (updates.isNotEmpty) {
      await _db.collection('users').doc(uid).update(updates);
    }
  }

  // Save the Cloudinary profile picture URL.
  Future<void> updateProfilePicture({
    required String uid,
    required String photoUrl,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != uid) {
      throw StateError('You can only change your own profile picture.');
    }

    await _db.collection('users').doc(uid).update({'photoUrl': photoUrl});
  }

  // FOLLOWING

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

    batch.set(followingRef, {
      'userId': targetUserId,
      'followedAt': FieldValue.serverTimestamp(),
    });

    batch.set(followerRef, {
      'userId': currentUserId,
      'followedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Notify the person who gained a follower.
    // A notification failure does not undo the follow.
    try {
      await NotificationService().follower(
        followerId: currentUserId,
        recipientId: targetUserId,
      );
    } catch (_) {
      // The follow relationship is already saved.
    }
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getFollowing(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getFollowers(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getFollowStatus({
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

  // Find people followed by accounts you follow.
  Future<Map<String, int>> getSuggestedUserScores(String uid) async {
    final following = await _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .limit(40)
        .get();

    final excluded = <String>{uid, ...following.docs.map((doc) => doc.id)};

    final scores = <String, int>{};

    for (final friend in following.docs) {
      final theirFollowing = await _db
          .collection('users')
          .doc(friend.id)
          .collection('following')
          .limit(100)
          .get();

      for (final other in theirFollowing.docs) {
        if (!excluded.contains(other.id)) {
          scores.update(other.id, (score) => score + 1, ifAbsent: () => 1);
        }
      }
    }

    return scores;
  }

  // COMMUNITY POSTS

  // Supports one picture or up to five pictures.
  // imageUrl is retained for older Community screens.
  Future<void> addPost({
    required String userId,
    required String userEmail,
    required String title,
    required String description,
    String imageUrl = '',
    List<String>? imageUrls,
  }) async {
    final photos = imageUrls ?? (imageUrl.isNotEmpty ? [imageUrl] : <String>[]);

    if (photos.length > 5) {
      throw ArgumentError('A post can have no more than 5 pictures.');
    }

    await _db.collection('posts').add({
      'userId': userId,
      'userEmail': userEmail,
      'title': title,
      'description': description,

      // First picture for older screens.
      'imageUrl': photos.isNotEmpty ? photos.first : '',

      // All pictures for the gallery.
      'imageUrls': photos,

      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPosts() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPostsByUser(String userId) {
    return _db
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  // Get a specific post, including bookmarked posts.
  Future<DocumentSnapshot<Map<String, dynamic>>> getPost(String postId) async {
    return await _db.collection('posts').doc(postId).get();
  }

  // Edit only your own post.
  Future<void> editPost({
    required String postId,
    required String title,
    required String description,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('You must be logged in.');
    }

    final postRef = _db.collection('posts').doc(postId);
    final post = await postRef.get();

    if (!post.exists || post.data()?['userId'] != uid) {
      throw StateError('You can only edit your own posts.');
    }

    final newTitle = title.trim();
    final newDescription = description.trim();

    if (newTitle.isEmpty ||
        newTitle.length > 100 ||
        newDescription.isEmpty ||
        newDescription.length > 1000) {
      throw ArgumentError(
        'Title must be 1-100 characters and '
        'description must be 1-1000 characters.',
      );
    }

    await postRef.update({
      'title': newTitle,
      'description': newDescription,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('You must be logged in.');
    }

    final postRef = _db.collection('posts').doc(postId);
    final post = await postRef.get();

    if (!post.exists || post.data()?['userId'] != uid) {
      throw StateError('You can only delete your own posts.');
    }

    await postRef.delete();
  }

  // COMMENTS

  Future<void> addComment({
    required String postId,
    required String userId,
    required String userEmail,
    required String comment,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid != userId) {
      throw StateError('You must be logged in to comment.');
    }

    final newComment = comment.trim();

    if (newComment.isEmpty || newComment.length > 500) {
      throw ArgumentError('Comment must be 1-500 characters.');
    }

    final createdComment = await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
          'userId': userId,
          'userEmail': userEmail,
          'comment': newComment,
          'createdAt': FieldValue.serverTimestamp(),
        });

    // Notify the author of the original post.
    try {
      final post = await _db.collection('posts').doc(postId).get();

      final recipientId = (post.data()?['userId'] ?? '').toString();

      await NotificationService().comment(
        actorId: userId,
        recipientId: recipientId,
        postId: postId,
        commentId: createdComment.id,
      );
    } catch (_) {
      // Keep the comment even if notification fails.
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> editComment({
    required String postId,
    required String commentId,
    required String comment,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('You must be logged in.');
    }

    final commentRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    final existingComment = await commentRef.get();

    if (!existingComment.exists || existingComment.data()?['userId'] != uid) {
      throw StateError('You can only edit your own comments.');
    }

    final updatedComment = comment.trim();

    if (updatedComment.isEmpty || updatedComment.length > 500) {
      throw ArgumentError('Comment must be 1-500 characters.');
    }

    await commentRef.update({
      'comment': updatedComment,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('You must be logged in.');
    }

    final commentRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    final existingComment = await commentRef.get();

    if (!existingComment.exists || existingComment.data()?['userId'] != uid) {
      throw StateError('You can only delete your own comments.');
    }

    await commentRef.delete();
  }

  // POST LIKES

  Future<void> likePost({
    required String postId,
    required String userId,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .set({'userId': userId, 'createdAt': FieldValue.serverTimestamp()});

    // Notify the post author.
    try {
      final post = await _db.collection('posts').doc(postId).get();

      final recipientId = (post.data()?['userId'] ?? '').toString();

      await NotificationService().like(
        actorId: userId,
        recipientId: recipientId,
        postId: postId,
      );
    } catch (_) {
      // The like remains saved.
    }
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getLikes(String postId) {
    return _db.collection('posts').doc(postId).collection('likes').snapshots();
  }

  // SAVED POSTS

  Future<void> savePost({
    required String userId,
    required String postId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .set({'postId': postId, 'savedAt': FieldValue.serverTimestamp()});
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getSavedPosts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .orderBy('savedAt', descending: true)
        .snapshots();
  }

  // MY PLANTS

  Future<void> addMyPlant({
    required String userId,
    required MyPlant plant,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plant.id)
        .set(plant.toFirestore());
  }

    // Update a saved plant's profile picture without creating
  // a new health analysis.
  Future<void> updateMyPlantPhoto({
    required String userId,
    required String plantId,
    required String imageUrl,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != userId) {
      throw StateError('You can only update your own plants.');
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plantId)
        .update({
          'imageUrl': imageUrl,
        });
  }

  Future<void> removeMyPlant({
    required String userId,
    required String plantId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plantId)
        .delete();
  }

    // Get only the most recent health analysis for a saved plant.
  Stream<QuerySnapshot<Map<String, dynamic>>> getLatestPlantAnalysis({
    required String userId,
    required String plantId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plantId)
        .collection('analyses')
        .orderBy('analyzedAt', descending: true)
        .limit(1)
        .snapshots();
  }

  // Record the last watering date.
  Future<void> setLastWatered({
    required String userId,
    required String plantId,
    DateTime? at,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plantId)
        .update({
          'lastWateredAt': at == null
              ? Timestamp.now()
              : Timestamp.fromDate(at),
        });
  }

  // Change the plant's watering schedule.
  Future<void> setWaterEveryDays({
    required String userId,
    required String plantId,
    required int? days,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plantId)
        .update({'waterEveryDays': days});
  }

  Stream<List<MyPlant>> getMyPlants(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MyPlant.fromFirestore({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  Stream<bool> isInMyPlants({required String userId, required int perenualId}) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc('$perenualId')
        .snapshots()
        .map((doc) => doc.exists);
  }

  // PLANT HEALTH ANALYSES

  Future<void> addPlantAnalysis({
    required String userId,
    required String plantId,
    required String scientificName,
    String? commonName,
    double? confidence,
    required String healthStatus,
    required List<Map<String, dynamic>> issues,
    required List<String> recommendedCare,
    String? imageUrl,
  }) async {
    final createdAnalysis = await _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plantId)
        .collection('analyses')
        .add({
          'scientificName': scientificName,
          'commonName': commonName,
          'confidence': confidence,
          'healthStatus': healthStatus,
          'issues': issues,
          'recommendedCare': recommendedCare,
          'imageUrl': imageUrl,
          'analyzedAt': FieldValue.serverTimestamp(),
        });

    // Notify the owner that an analysis was saved.
    try {
      await NotificationService().analysis(
        userId: userId,
        plantId: plantId,
        analysisId: createdAnalysis.id,
      );
    } catch (_) {
      // The analysis is already saved.
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPlantAnalyses({
    required String userId,
    required String plantId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('myPlants')
        .doc(plantId)
        .collection('analyses')
        .orderBy('analyzedAt', descending: true)
        .snapshots();
  }

  // OTHER PLANT METHODS

  Future<void> addPlant({
    required String userID,
    required String name,
    required String species,
    required String description,
    String? imageUrl,
  }) async {
    await _db.collection('users').doc(userID).collection('plants').add({
      'userID': userID,
      'name': name,
      'species': species,
      'description': description,
      'imageUrl': imageUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserPlants(String userID) {
    return _db
        .collection('users')
        .doc(userID)
        .collection('plants')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updatePlant({
    required String userID,
    required String plantID,
    required Map<String, dynamic> updatedData,
  }) async {
    await _db
        .collection('users')
        .doc(userID)
        .collection('plants')
        .doc(plantID)
        .update(updatedData);
  }

  Future<void> deletePlant({
    required String userID,
    required String plantID,
  }) async {
    await _db
        .collection('users')
        .doc(userID)
        .collection('plants')
        .doc(plantID)
        .delete();
  }
}
