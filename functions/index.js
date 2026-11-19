
const {onDocumentCreated} = require(
    "firebase-functions/v2/firestore"
  );

  const {logger} = require("firebase-functions");

  const {initializeApp} = require("firebase-admin/app");

  const {getFirestore, FieldValue} = require(
    "firebase-admin/firestore"
  );

  // Connect Cloud Functions to the existing Firebase project.
  initializeApp();

  const db = getFirestore();

  // Save a notification in the correct user's inbox.
  async function createNotification({
    recipientId,
    notificationId,
    type,
    actorId,
    postId = "",
    commentId = "",
    replyId = "",
    plantId = "",
  }) {
    // Make sure the notification has a recipient.
    if (!recipientId || !notificationId) {
      return;
    }

    // Do not notify users about their own social activity.
    if (recipientId === actorId && type !== "analysis") {
      return;
    }

    const notificationRef = db
      .collection("users")
      .doc(recipientId)
      .collection("notifications")
      .doc(notificationId);

    try {
      // Create only if this notification does not exist.
      // This prevents duplicate notifications if an event
      // is processed more than once.
      await notificationRef.create({
        type: type,
        actorId: actorId,
        postId: postId,
        commentId: commentId,
        replyId: replyId,
        plantId: plantId,
        createdAt: FieldValue.serverTimestamp(),
        isRead: false,
      });

      logger.info("PlantPal notification created", {
        recipientId: recipientId,
        type: type,
        notificationId: notificationId,
      });
    } catch (error) {
      // The notification already exists.
      if (error.code === 6 ||
          error.code === "already-exists") {
        return;
      }

      // Report unexpected errors so they can be investigated.
      logger.error("Unable to create notification", error);
      throw error;
    }
  }

  // ---------------------------------------------------------
  // 1. NEW FOLLOWER
  // ---------------------------------------------------------
  // Runs when someone starts following another user.

  exports.notifyNewFollower = onDocumentCreated(
    "users/{userId}/followers/{followerUserId}",
    async (event) => {
      if (!event.data) return;

      const recipientId = event.params.userId;
      const followerId = event.params.followerUserId;

      await createNotification({
        recipientId: recipientId,
        notificationId: `follow_${followerId}`,
        type: "follow",
        actorId: followerId,
      });
    }
  );

  // ---------------------------------------------------------
  // 2. NEW POST LIKE
  // ---------------------------------------------------------
  // Runs when someone likes a Community post.

  exports.notifyPostLike = onDocumentCreated(
    "posts/{postId}/likes/{userId}",
    async (event) => {
      if (!event.data) return;

      const postId = event.params.postId;
      const actorId = event.params.userId;

      // Find the person who created the post.
      const post = await db
        .collection("posts")
        .doc(postId)
        .get();

      if (!post.exists) return;

      const recipientId = post.data().userId;

      await createNotification({
        recipientId: recipientId,
        notificationId: `like_${postId}_${actorId}`,
        type: "like",
        actorId: actorId,
        postId: postId,
      });
    }
  );

  // ---------------------------------------------------------
  // 3. NEW COMMENT
  // ---------------------------------------------------------
  // Runs when someone comments on a Community post.

  exports.notifyPostComment = onDocumentCreated(
    "posts/{postId}/comments/{commentId}",
    async (event) => {
      if (!event.data) return;

      const postId = event.params.postId;
      const commentId = event.params.commentId;

      const commentData = event.data.data();
      const actorId = commentData.userId;

      // Find the original post author.
      const post = await db
        .collection("posts")
        .doc(postId)
        .get();

      if (!post.exists) return;

      const recipientId = post.data().userId;

      await createNotification({
        recipientId: recipientId,
        notificationId: `comment_${postId}_${commentId}`,
        type: "comment",
        actorId: actorId,
        postId: postId,
        commentId: commentId,
      });
    }
  );

  // ---------------------------------------------------------
  // 4. NEW COMMENT REPLY
  // ---------------------------------------------------------
  // Runs when someone replies to a Community comment.

  exports.notifyCommentReply = onDocumentCreated(
    "posts/{postId}/comments/{commentId}/replies/{replyId}",
    async (event) => {
      if (!event.data) return;

      const postId = event.params.postId;
      const commentId = event.params.commentId;
      const replyId = event.params.replyId;

      const replyData = event.data.data();
      const actorId = replyData.userId;

      // Find the person who wrote the original comment.
      const comment = await db
        .collection("posts")
        .doc(postId)
        .collection("comments")
        .doc(commentId)
        .get();

      if (!comment.exists) return;

      const recipientId = comment.data().userId;

      await createNotification({
        recipientId: recipientId,
        notificationId:
          `reply_${postId}_${commentId}_${replyId}`,
        type: "reply",
        actorId: actorId,
        postId: postId,
        commentId: commentId,
        replyId: replyId,
      });
    }
  );

  // ---------------------------------------------------------
  // 5. PLANT HEALTH ANALYSIS
  // ---------------------------------------------------------
  // Runs when an analysis is saved to a user's plant.

  exports.notifyPlantAnalysis = onDocumentCreated(
    "users/{userId}/myPlants/{plantId}/analyses/{analysisId}",
    async (event) => {
      if (!event.data) return;

      const userId = event.params.userId;
      const plantId = event.params.plantId;
      const analysisId = event.params.analysisId;

      await createNotification({
        recipientId: userId,
        notificationId:
          `analysis_${plantId}_${analysisId}`,
        type: "analysis",
        actorId: userId,
        plantId: plantId,
        // Matches the existing Flutter notification model.
        replyId: analysisId,
      });
    }
  );
