
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

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
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
        ? '@$username'
        : (email.isNotEmpty ? email : (name.isNotEmpty ? name : 'PlantPal User'));

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

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : null,
        child: photoUrl.isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _openProfile(userId),
      trailing: OutlinedButton(
        onPressed: () => _toggleFollow(
          currentUserId: currentUserId,
          targetUserId: userId,
          isFollowing: isFollowing,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find People'),
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),
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
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _databaseService.getFollowing(currentUser.uid),
              builder: (context, followingSnapshot) {
                if (followingSnapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load following list.'),
                  );
                }

                if (!followingSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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
                        QuerySnapshot<Map<String, dynamic>>>(
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

                        // When searching, show matching accounts.
                        if (_search.isNotEmpty) {
                          final matchingUsers = allUsers.where((doc) {
                            final data = doc.data();

                            final username =
                                (data['username'] ?? '').toString().toLowerCase();

                            final name =
                                (data['displayName'] ?? '').toString().toLowerCase();

                            return username.contains(_search) ||
                                name.contains(_search);
                          }).toList();

                          if (matchingUsers.isEmpty) {
                            return const Center(
                              child: Text('No people found.'),
                            );
                          }

                          return ListView.builder(
                            itemCount: matchingUsers.length,
                            itemBuilder: (context, index) => _buildUserTile(
                              userDoc: matchingUsers[index],
                              currentUserId: currentUser.uid,
                              followingIds: followingIds,
                              mutualCount: scores[matchingUsers[index].id] ?? 0,
                            ),
                          );
                        }

                        // Suggested users are people you don't
                        // follow yet, sorted by mutual connections.
                        final suggested = allUsers
                            .where((doc) => !followingIds.contains(doc.id))
                            .toList();

                        suggested.sort((a, b) {
                          final comparison =
                              (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);

                          if (comparison != 0) return comparison;
                          return a.id.compareTo(b.id);
                        });

                        if (suggested.isEmpty) {
                          return const Center(
                            child: Text(
                              'No more people to suggest right now.',
                            ),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
                              child: Text(
                                'Suggested for You',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
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
    );
  }
}
