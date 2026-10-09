import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/reusable_widgets.dart';

import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'user_posts_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool insideHome;

  const ProfileScreen({
    super.key,
    this.insideHome = false,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final DatabaseService _databaseService =
      DatabaseService();

  final AuthService _authService =
      AuthService();

  Future<void> _editName({
    required String uid,
    required String currentName,
  }) async {
    final controller =
        TextEditingController(
      text: currentName,
    );

    final String? result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Name',
          ),
          content: TextField(
            controller: controller,
            decoration:
                const InputDecoration(
              labelText: 'Name',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child:
                  const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null ||
        result.isEmpty) {
      return;
    }

    await _databaseService.updateProfile(
      uid: uid,
      displayName: result,
    );
  }

  Future<void> _editUsername({
    required String uid,
    required String currentUsername,
  }) async {
    final controller =
        TextEditingController(
      text: currentUsername,
    );

    final String? result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Username',
          ),
          content: TextField(
            controller: controller,
            decoration:
                const InputDecoration(
              labelText: 'Username',
              hintText:
                  'Example: plantlover22',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child:
                  const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null ||
        result.isEmpty) {
      return;
    }

    if (!RegExp(
      r'^[a-zA-Z0-9_]{3,20}$',
    ).hasMatch(result)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Username must be 3-20 characters and only contain letters, numbers, or underscores.',
          ),
        ),
      );

      return;
    }

    final bool available =
        await _databaseService
            .isUsernameAvailable(
      result,
      currentUid: uid,
    );

    if (!available) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'That username is already taken.',
          ),
        ),
      );

      return;
    }

    await _databaseService.updateProfile(
      uid: uid,
      username: result,
    );
  }

  Future<void> _editBio({
    required String uid,
    required String currentBio,
  }) async {
    final controller =
        TextEditingController(
      text: currentBio,
    );

    final String? result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Bio',
          ),
          content: TextField(
            controller: controller,
            maxLength: 150,
            maxLines: 4,
            decoration:
                const InputDecoration(
              labelText: 'Bio',
              hintText:
                  'Tell other PlantPal users about yourself...',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child:
                  const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    await _databaseService.updateProfile(
      uid: uid,
      bio: result,
    );
  }

  void _showEmail(
    String email,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Email'),
          content:
              SelectableText(email),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetPassword(
    String email,
  ) async {
    if (email.isEmpty) {
      return;
    }

    try {
      await _authService
          .sendPasswordResetEmail(
        email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send reset email: $e',
          ),
        ),
      );
    }
  }

  Widget _buildProfileContent(
    User user,
  ) {
    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream:
          _databaseService
              .getUserStream(
        user.uid,
      ),
      builder:
          (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load profile.',
            ),
          );
        }

        final data =
            snapshot.data?.data() ?? {};

        final String displayName =
            data['displayName'] ??
                'Plant Friend';

        final String username =
            data['username'] ?? '';

        final String bio =
            data['bio'] ?? '';

        final String email =
            data['email'] ??
                user.email ??
                '';

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(
                height: 24,
              ),

              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              const CircleAvatar(
                radius: 55,
                child: Icon(
                  Icons.person,
                  size: 60,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                displayName,
                style:
                    const TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              if (username
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '@$username',
                  style:
                      const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],

              const SizedBox(
                height: 8,
              ),

              Text(
                bio.isEmpty
                    ? 'Add a bio 🌱'
                    : bio,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 24,
              ),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly,
                children: [
                  StreamBuilder<
                      QuerySnapshot<
                          Map<String,
                              dynamic>>>(
                    stream:
                        _databaseService
                            .getPostsByUser(
                      user.uid,
                    ),
                    builder:
                        (context,
                            postSnapshot) {
                      return _ProfileStat(
                        number:
                            '${postSnapshot.data?.docs.length ?? 0}',
                        label: 'Posts',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      UserPostsScreen(
                                userId:
                                    user.uid,
                                title:
                                    'My Posts',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  StreamBuilder<
                      QuerySnapshot<
                          Map<String,
                              dynamic>>>(
                    stream:
                        _databaseService
                            .getFollowers(
                      user.uid,
                    ),
                    builder:
                        (context,
                            followerSnapshot) {
                      return _ProfileStat(
                        number:
                            '${followerSnapshot.data?.docs.length ?? 0}',
                        label:
                            'Followers',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      FollowListScreen(
                                userId:
                                    user.uid,
                                showFollowers:
                                    true,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  StreamBuilder<
                      QuerySnapshot<
                          Map<String,
                              dynamic>>>(
                    stream:
                        _databaseService
                            .getFollowing(
                      user.uid,
                    ),
                    builder:
                        (context,
                            followingSnapshot) {
                      return _ProfileStat(
                        number:
                            '${followingSnapshot.data?.docs.length ?? 0}',
                        label:
                            'Following',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      FollowListScreen(
                                userId:
                                    user.uid,
                                showFollowers:
                                    false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(
                height: 30,
              ),

              const Divider(),

              ListTile(
                leading:
                    const Icon(
                  Icons.badge_outlined,
                ),
                title:
                    const Text(
                  'Name',
                ),
                subtitle:
                    Text(displayName),
                trailing:
                    const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  _editName(
                    uid: user.uid,
                    currentName:
                        displayName,
                  );
                },
              ),

              const Divider(),

              ListTile(
                leading:
                    const Icon(
                  Icons.person_outline,
                ),
                title:
                    const Text(
                  'Username',
                ),
                subtitle: Text(
                  username.isEmpty
                      ? 'Add a username'
                      : '@$username',
                ),
                trailing:
                    const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  _editUsername(
                    uid: user.uid,
                    currentUsername:
                        username,
                  );
                },
              ),

              const Divider(),

              ListTile(
                leading:
                    const Icon(
                  Icons
                      .description_outlined,
                ),
                title:
                    const Text('Bio'),
                subtitle: Text(
                  bio.isEmpty
                      ? 'Add a bio'
                      : bio,
                ),
                trailing:
                    const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  _editBio(
                    uid: user.uid,
                    currentBio: bio,
                  );
                },
              ),

              const Divider(),

              ListTile(
                leading:
                    const Icon(
                  Icons.email_outlined,
                ),
                title:
                    const Text(
                  'Email',
                ),
                subtitle:
                    Text(email),
                trailing:
                    const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  _showEmail(email);
                },
              ),

              const Divider(),

              ListTile(
                leading:
                    const Icon(
                  Icons.lock_outline,
                ),
                title:
                    const Text(
                  'Password',
                ),
                subtitle:
                    const Text(
                  'Send password reset email',
                ),
                trailing:
                    const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  _resetPassword(
                    email,
                  );
                },
              ),

              const Divider(),

              const SizedBox(
                height: 18,
              ),

              OutlinedButton.icon(
                onPressed: () async {
                  await _authService
                      .signOut();

                  if (!context.mounted) {
                    return;
                  }

                  Navigator
                      .pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              const LoginScreen(),
                    ),
                    (route) =>
                        false,
                  );
                },
                icon:
                    const Icon(
                  Icons.logout,
                ),
                label:
                    const Text(
                  'Log Out',
                ),
              ),

              const SizedBox(
                height: 30,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final User? user =
        FirebaseAuth
            .instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Not logged in.',
        ),
      );
    }

    if (widget.insideHome) {
      return _buildProfileContent(
        user,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Profile'),
      ),
      drawer:
          const AppDrawer(),
      body:
          _buildProfileContent(
        user,
      ),
    );
  }
}

class _ProfileStat
    extends StatelessWidget {
  final String number;
  final String label;
  final VoidCallback? onTap;

  const _ProfileStat({
    required this.number,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Column(
          children: [
            Text(
              number,
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              label,
              style: TextStyle(
                color:
                    onTap != null
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}