import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final bool showFollowers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  Color bg(BuildContext c) => PlantPalColors.background(c);
  Color card(BuildContext c) => PlantPalColors.card(c);
  Color text(BuildContext c) => PlantPalColors.text(c);
  Color secondary(BuildContext c) => PlantPalColors.secondaryText(c);
  Color accent(BuildContext c) => PlantPalColors.accent(c);
  Color border(BuildContext c) => PlantPalColors.border(c);
  Color soft(BuildContext c) => PlantPalColors.softBackground(c);

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: soft(context),
              child: Icon(
                showFollowers
                    ? Icons.people_outline
                    : Icons.person_add_alt_outlined,
                size: 42,
                color: accent(context),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              showFollowers ? 'No followers yet' : 'Not following anyone yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showFollowers
                  ? 'Followers will appear here when someone follows this account.'
                  : 'Accounts followed by this user will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondary(context), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userCard({
    required BuildContext context,
    required String otherUserId,
    required Map<String, dynamic> data,
  }) {
    final name = (data['displayName'] ?? 'PlantPal User').toString();
    final username = (data['username'] ?? '').toString().trim();
    final bio = (data['bio'] ?? '').toString().trim();
    final photoUrl = (data['photoUrl'] ?? '').toString().trim();

    return Card(
      color: card(context),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: otherUserId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: soft(context),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Icon(Icons.person, color: accent(context), size: 30)
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username.isNotEmpty ? username : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (username.isNotEmpty && name.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent(context)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();
    final title = showFollowers ? 'Followers' : 'Following';

    final followStream = showFollowers
        ? databaseService.getFollowers(userId)
        : databaseService.getFollowing(userId);

    return Scaffold(
      backgroundColor: bg(context),
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(color: text(context), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: bg(context),
        foregroundColor: text(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: followStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load $title.',
                    style: TextStyle(color: text(context)),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final followDocs = snapshot.data!.docs;

              if (followDocs.isEmpty) {
                return _emptyState(context);
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: followDocs.length,
                itemBuilder: (context, index) {
                  final otherUserId = followDocs[index].id;

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: databaseService.getUser(otherUserId),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasError) {
                        return Card(
                          color: card(context),
                          child: const ListTile(
                            title: Text('Unable to load user.'),
                          ),
                        );
                      }

                      if (!userSnapshot.hasData) {
                        return Card(
                          color: card(context),
                          child: const ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Loading user...'),
                          ),
                        );
                      }

                      if (!userSnapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }

                      return _userCard(
                        context: context,
                        otherUserId: otherUserId,
                        data: userSnapshot.data!.data() ?? {},
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
