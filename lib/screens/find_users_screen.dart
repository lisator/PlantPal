 import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
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

  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  @override
  void initState() {
    super.initState();
    _refreshSuggestions();
  }

  void _refreshSuggestions() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _loadedForUserId = user.uid;
    _suggestionsFuture =
        _databaseService.getSuggestedUserScores(user.uid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Follow or unfollow a selected user.
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

      // Update suggested people after the follow list changes.
      if (mounted) {
        setState(_refreshSuggestions);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update follow: $e')),
      );
    }
  }

  // Open another user's PlantPal profile.
  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  // Display a friendly message when no users match the search.
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 42,
                color: _forest,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _forest,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Display a user with their profile picture and follow button.
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

    // Display usernames without the @ symbol.
    final displayName = username.isNotEmpty
        ? username
        : (name.isNotEmpty
            ? name
            : (email.isNotEmpty ? email : 'PlantPal User'));

    final isFollowing = followingIds.contains(userId);

    String subtitle;

    if (mutualCount > 0) {
      subtitle =
          'Followed by $mutualCount ${mutualCount == 1 ? 'person' : 'people'} you follow';
    } else if (bio.isNotEmpty) {
      subtitle = bio;
    } else if (name.isNotEmpty) {
      subtitle = name;
    } else {
      subtitle = 'PlantPal member';
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      shadowColor: _forest.withValues(alpha: 0.10),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _mint),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        child: Row(
          children: [
            // Tapping the profile picture opens the user's profile
            InkWell(
              onTap: () => _openProfile(userId),
              borderRadius: BorderRadius.circular(30),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: _mint,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: _forest,
                        size: 28,
                      )
                    : null,
              ),
            ),

            const SizedBox(width: 12),

            // Username and suggested connection information.
            Expanded(
              child: InkWell(
                onTap: () => _openProfile(userId),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _forest,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (username.isNotEmpty &&
                          name.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      const SizedBox(height: 4),

                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Follow and unfollow using existing Firebase methods.
            isFollowing
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _forest,
                      side: const BorderSide(color: _sage),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                      backgroundColor: _forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _toggleFollow(
                      currentUserId: currentUserId,
                      targetUserId: userId,
                      isFollowing: false,
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(fontSize: 12),
                    ),
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
      return const Scaffold(
        body: Center(
          child: Text('Please log in.'),
        ),
      );
    }

    if (_loadedForUserId != currentUser.uid) {
      _refreshSuggestions();
    }

    // Apply PlantPal colors to Find People only.
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _forest,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: _sage),
          prefixIconColor: _forest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _mint),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _mint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _forest,
              width: 2,
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: const Text(
            'Find People',
            style: TextStyle(
              color: _forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _pale,
          surfaceTintColor: _pale,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                // SEarch BAR
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16, 14, 16, 10,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by username or name',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Suggested users and search results.
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: _databaseService.getFollowing(
                      currentUser.uid,
                    ),
                    builder: (context, followingSnapshot) {
                      if (followingSnapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Unable to load following list.',
                          ),
                        );
                      }

                      if (!followingSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _forest,
                          ),
                        );
                      }

                      final followingIds =
                          followingSnapshot.data!.docs
                              .map((doc) => doc.id)
                              .toSet();

                      return FutureBuilder<Map<String, int>>(
                        future: _suggestionsFuture,
                        builder: (context, suggestionSnapshot) {
                          if (suggestionSnapshot.hasError &&
                              _search.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Unable to load recommendations.',
                                  ),
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
                              child: CircularProgressIndicator(
                                color: _forest,
                              ),
                            );
                          }

                          final scores =
                              suggestionSnapshot.data ?? {};

                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: _databaseService.getUsers(),
                            builder: (context, usersSnapshot) {
                              if (usersSnapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'Unable to load users.',
                                  ),
                                );
                              }

                              if (!usersSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _forest,
                                  ),
                                );
                              }

                              final allUsers = usersSnapshot
                                  .data!.docs
                                  .where(
                                    (doc) =>
                                        doc.id != currentUser.uid,
                                  )
                                  .toList();

                              // When searching, show matching accounts.
                              if (_search.isNotEmpty) {
                                final matchingUsers =
                                    allUsers.where((doc) {
                                  final data = doc.data();

                                  final username =
                                      (data['username'] ?? '')
                                          .toString()
                                          .toLowerCase();

                                  final name =
                                      (data['displayName'] ?? '')
                                          .toString()
                                          .toLowerCase();

                                  return username.contains(_search) ||
                                      name.contains(_search);
                                }).toList();

                                if (matchingUsers.isEmpty) {
                                  return _emptyState(
                                    title: 'No people found',
                                    description:
                                        'Try another name or username to find a PlantPal member.',
                                    icon: Icons.person_search_outlined,
                                  );
                                }

                                return ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 24,
                                  ),
                                  itemCount: matchingUsers.length,
                                  itemBuilder: (context, index) =>
                                      _buildUserTile(
                                    userDoc: matchingUsers[index],
                                    currentUserId: currentUser.uid,
                                    followingIds: followingIds,
                                    mutualCount:
                                        scores[matchingUsers[index].id] ??
                                            0,
                                  ),
                                );
                              }

                              // Suggested users are people you don't
                              // follow yet, sorted by mutual connections.
                              final suggested = allUsers
                                  .where(
                                    (doc) =>
                                        !followingIds.contains(doc.id),
                                  )
                                  .toList();

                              suggested.sort((a, b) {
                                final comparison =
                                    (scores[b.id] ?? 0)
                                        .compareTo(scores[a.id] ?? 0);

                                if (comparison != 0) {
                                  return comparison;
                                }

                                return a.id.compareTo(b.id);
                              });

                              if (suggested.isEmpty) {
                                return _emptyState(
                                  title: 'No new suggestions',
                                  description:
                                      'You are already following everyone available right now.',
                                  icon: Icons.spa_outlined,
                                );
                              }

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16, 6, 16, 24,
                                ),
                                children: [
                                  // Display the recommended users section.
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(
                                      bottom: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _mint,
                                      borderRadius:
                                          BorderRadius.circular(18),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.spa_outlined,
                                          color: _forest,
                                          size: 30,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Suggested for You',
                                                style: TextStyle(
                                                  color: _forest,
                                                  fontSize: 19,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Discover more plant lovers to follow!',
                                                style: TextStyle(
                                                  color: _ink,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Display people with mutual connections first.
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
      ),
    );
  }
}
