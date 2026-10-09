import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'user_profile_screen.dart';

class FindUsersScreen
    extends StatefulWidget {
  const FindUsersScreen({
    super.key,
  });

  @override
  State<FindUsersScreen>
      createState() =>
          _FindUsersScreenState();
}

class _FindUsersScreenState
    extends State<FindUsersScreen> {
  final DatabaseService _databaseService =
      DatabaseService();

  final TextEditingController
      _searchController =
      TextEditingController();

  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final currentUser =
        FirebaseAuth
            .instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Find People'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: TextField(
              controller:
                  _searchController,
              onChanged: (value) {
                setState(() {
                  _search =
                      value
                          .trim()
                          .toLowerCase();
                });
              },
              decoration:
                  const InputDecoration(
                hintText:
                    'Search by username or name',
                prefixIcon:
                    Icon(Icons.search),
                border:
                    OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
                  _databaseService
                      .getFollowing(
                currentUser.uid,
              ),
              builder:
                  (context,
                      followingSnapshot) {
                final Set<String>
                    followingIds =
                    followingSnapshot
                            .data
                            ?.docs
                            .map(
                              (doc) =>
                                  doc.id,
                            )
                            .toSet() ??
                        {};

                return StreamBuilder<
                    QuerySnapshot<
                        Map<String,
                            dynamic>>>(
                  stream:
                      _databaseService
                          .getUsers(),
                  builder:
                      (context,
                          userSnapshot) {
                    if (!userSnapshot
                        .hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final users =
                        userSnapshot
                            .data!
                            .docs
                            .where(
                      (doc) {
                        if (doc.id ==
                            currentUser
                                .uid) {
                          return false;
                        }

                        if (_search
                            .isEmpty) {
                          return true;
                        }

                        final data =
                            doc.data();

                        final username =
                            (data['username'] ??
                                    '')
                                .toString()
                                .toLowerCase();

                        final name =
                            (data['displayName'] ??
                                    '')
                                .toString()
                                .toLowerCase();

                        return username
                                .contains(
                              _search,
                            ) ||
                            name.contains(
                              _search,
                            );
                      },
                    ).toList();

                    if (users.isEmpty) {
                      return const Center(
                        child: Text(
                          'No users found.',
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount:
                          users.length,
                      itemBuilder:
                          (context,
                              index) {
                        final userDoc =
                            users[index];

                        final data =
                            userDoc
                                .data();

                        final uid =
                            userDoc.id;

                        final name =
                            data['displayName'] ??
                                'PlantPal User';

                        final username =
                            data['username'] ??
                                '';

                        final bio =
                            data['bio'] ??
                                '';

                        final bool
                            following =
                            followingIds
                                .contains(
                          uid,
                        );

                        return ListTile(
                          leading:
                              const CircleAvatar(
                            child: Icon(
                              Icons.person,
                            ),
                          ),
                          title: Text(
                            username
                                    .toString()
                                    .isNotEmpty
                                ? '@$username'
                                : name,
                          ),
                          subtitle:
                              Text(
                            bio
                                    .toString()
                                    .isNotEmpty
                                ? bio
                                : name,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        UserProfileScreen(
                                  userId:
                                      uid,
                                ),
                              ),
                            );
                          },
                          trailing:
                              ElevatedButton(
                            onPressed:
                                () async {
                              if (following) {
                                await _databaseService
                                    .unfollowUser(
                                  currentUserId:
                                      currentUser.uid,
                                  targetUserId:
                                      uid,
                                );
                              } else {
                                await _databaseService
                                    .followUser(
                                  currentUserId:
                                      currentUser.uid,
                                  targetUserId:
                                      uid,
                                );
                              }
                            },
                            child: Text(
                              following
                                  ? 'Following'
                                  : 'Follow',
                            ),
                          ),
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