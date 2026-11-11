import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';
import 'user_profile_screen.dart';

class FindUsersScreen extends StatefulWidget {
  const FindUsersScreen({super.key});

  @override
  State<FindUsersScreen> createState() => _FindUsersScreenState();
}

class _FindUsersScreenState extends State<FindUsersScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  Future<Map<String, int>>? _suggestionsFuture;
  String? _loadedForUserId;

  Color get _background => PlantPalColors.background(context);
  Color get _card => PlantPalColors.card(context);
  Color get _text => PlantPalColors.text(context);
  Color get _secondary => PlantPalColors.secondaryText(context);
  Color get _accent => PlantPalColors.accent(context);
  Color get _border => PlantPalColors.border(context);
  Color get _soft => PlantPalColors.softBackground(context);

  @override
  void initState() {
    super.initState();
    _refreshSuggestions();
  }

  void _refreshSuggestions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _loadedForUserId = user.uid;
    _suggestionsFuture = _databaseService.getSuggestedUserScores(user.uid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow({
    required String currentUserId,
    required String targetUserId,
    required bool isFollowing,
  }) async {
    try {
      if (isFollowing) {
        await _databaseService.unfollowUser(
          currentUserId: currentUserId,
          targetUserId: targetUserId,
        );
      } else {
        await _databaseService.followUser(
          currentUserId: currentUserId,
          targetUserId: targetUserId,
        );
      }

      if (mounted) {
        setState(_refreshSuggestions);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to update follow: $e')));
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  Widget _emptyState({
    required String title,
    required String description,
    IconData icon = Icons.people_outline,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: _soft,
              child: Icon(icon, size: 42, color: _accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile({
    required QueryDocumentSnapshot<Map<String, dynamic>> userDoc,
    required String currentUserId,
    required Set<String> followingIds,
    required int mutualCount,
  }) {
    final data = userDoc.data();
    final userId = userDoc.id;

    final username = (data['username'] ?? '').toString().trim();
    final name = (data['displayName'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final bio = (data['bio'] ?? '').toString().trim();
    final photoUrl = (data['photoUrl'] ?? '').toString().trim();

    final displayName = username.isNotEmpty
        ? username
        : name.isNotEmpty
        ? name
        : email.isNotEmpty
        ? email
        : 'PlantPal User';

    final isFollowing = followingIds.contains(userId);

    final subtitle = mutualCount > 0
        ? 'Followed by $mutualCount '
              '${mutualCount == 1 ? 'person' : 'people'} '
              'you follow'
        : bio.isNotEmpty
        ? bio
        : name.isNotEmpty
        ? name
        : 'PlantPal member';

    return Card(
      color: _card,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            InkWell(
              onTap: () => _openProfile(userId),
              borderRadius: BorderRadius.circular(30),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: _soft,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Icon(Icons.person, color: _accent, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _openProfile(userId),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
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
                          style: TextStyle(color: _secondary, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _secondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            isFollowing
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                    ),
                    onPressed: () => _toggleFollow(
                      currentUserId: currentUserId,
                      targetUserId: userId,
                      isFollowing: true,
                    ),
                    child: const Text(
                      'Following',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: PlantPalColors.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                    ),
                    onPressed: () => _toggleFollow(
                      currentUserId: currentUserId,
                      targetUserId: userId,
                      isFollowing: false,
                    ),
                    child: const Text('Follow', style: TextStyle(fontSize: 12)),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    if (_loadedForUserId != currentUser.uid) {
      _refreshSuggestions();
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          'Find People',
          style: TextStyle(color: _text, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _background,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: _text),
                  cursorColor: _accent,
                  onChanged: (value) {
                    setState(() {
                      _search = value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by username or name',
                    hintStyle: TextStyle(color: _secondary),
                    prefixIcon: Icon(Icons.search, color: _accent),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: _accent),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _accent, width: 2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _databaseService.getFollowing(currentUser.uid),
                  builder: (context, followingSnapshot) {
                    if (followingSnapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load following list.'),
                      );
                    }

                    if (!followingSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final followingIds = followingSnapshot.data!.docs
                        .map((doc) => doc.id)
                        .toSet();

                    return FutureBuilder<Map<String, int>>(
                      future: _suggestionsFuture,
                      builder: (context, suggestionSnapshot) {
                        if (suggestionSnapshot.hasError && _search.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Unable to load recommendations.'),
                                TextButton(
                                  onPressed: () {
                                    setState(_refreshSuggestions);
                                  },
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (suggestionSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            _search.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final scores = suggestionSnapshot.data ?? {};

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _databaseService.getUsers(),
                          builder: (context, usersSnapshot) {
                            if (usersSnapshot.hasError) {
                              return const Center(
                                child: Text('Unable to load users.'),
                              );
                            }

                            if (!usersSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allUsers = usersSnapshot.data!.docs
                                .where((doc) => doc.id != currentUser.uid)
                                .toList();

                            if (_search.isNotEmpty) {
                              final matchingUsers = allUsers.where((doc) {
                                final data = doc.data();

                                final username = (data['username'] ?? '')
                                    .toString()
                                    .toLowerCase();

                                final name = (data['displayName'] ?? '')
                                    .toString()
                                    .toLowerCase();

                                return username.contains(_search) ||
                                    name.contains(_search);
                              }).toList();

                              if (matchingUsers.isEmpty) {
                                return _emptyState(
                                  title: 'No people found',
                                  description: 'Try another name or username to find a PlantPal member.',
                                  icon: Icons.person_search_outlined,
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  24,
                                ),
                                itemCount: matchingUsers.length,
                                itemBuilder: (context, index) {
                                  final doc = matchingUsers[index];
                                  return _buildUserTile(
                                    userDoc: doc,
                                    currentUserId: currentUser.uid,
                                    followingIds: followingIds,
                                    mutualCount: scores[doc.id] ?? 0,
                                  );
                                },
                              );
                            }

                            final suggested = allUsers
                                .where((doc) => !followingIds.contains(doc.id))
                                .toList();

                            suggested.sort((a, b) {
                              final comparison = (scores[b.id] ?? 0).compareTo(
                                scores[a.id] ?? 0,
                              );

                              return comparison != 0
                                  ? comparison
                                  : a.id.compareTo(b.id);
                            });

                            if (suggested.isEmpty) {
                              return _emptyState(
                                title: 'No new suggestions',
                                description: 'You are already following everyone available right now.',
                                icon: Icons.spa_outlined,
                              );
                            }

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: _soft,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.spa_outlined,
                                        color: _accent,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Suggested for You',
                                              style: TextStyle(
                                                color: _text,
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Discover more plant lovers to follow!',
                                              style: TextStyle(
                                                color: _secondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...suggested.map(
                                  (doc) => _buildUserTile(
                                    userDoc: doc,
                                    currentUserId: currentUser.uid,
                                    followingIds: followingIds,
                                    mutualCount: scores[doc.id] ?? 0,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
