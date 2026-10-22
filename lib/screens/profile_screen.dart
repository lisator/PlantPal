
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/reusable_widgets.dart';

import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'saved_posts_screen.dart';
import 'user_posts_screen.dart';


class ProfileScreen extends StatefulWidget {
  final bool insideHome;

  const ProfileScreen({
    super.key,
    this.insideHome = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();


  Future<void> _editName({
    required String uid,
    required String currentName,
  }) async {
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    try {
      await _databaseService.updateProfile(
        uid: uid,
        displayName: result,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editUsername({
    required String uid,
    required String currentUsername,
  }) async {
    final controller = TextEditingController(
      text: currentUsername,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Username'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Example: plantlover22',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    // Usernames can contain letters, numbers,
    // and underscores, and must be 3-20 characters.
    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(result)) {
      _showMessage(
        'Username must be 3-20 characters and only contain '
        'letters, numbers, or underscores.',
      );
      return;
    }

    try {
      final available =
          await _databaseService.isUsernameAvailable(
        result,
        currentUid: uid,
      );

      if (!available) {
        _showMessage('That username is already taken.');
        return;
      }

      await _databaseService.updateProfile(
        uid: uid,
        username: result,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editBio({
    required String uid,
    required String currentBio,
  }) async {
    final controller = TextEditingController(text: currentBio);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Bio'),
          content: TextField(
            controller: controller,
            maxLength: 150,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Bio',
              hintText:
                  'Tell other PlantPal users about yourself...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    try {
      await _databaseService.updateProfile(
        uid: uid,
        bio: result,
      );
    } catch (e) {
      _showError(e);
    }
  }


  void _showEmail(String email) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Email'),
          content: SelectableText(email),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }



  Future<void> _resetPassword(String email) async {
    if (email.isEmpty) {
      _showMessage('No email is available for this account.');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      _showMessage('Password reset email sent.');
    } catch (e) {
      _showError(e);
    }
  }


  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(Object error) {
    _showMessage('Something went wrong: $error');
  }

  void _openMyPosts(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPostsScreen(
          userId: uid,
          title: 'My Posts',
        ),
      ),
    );
  }

  void _openFollowList(
    String uid, {
    required bool showFollowers,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: uid,
          showFollowers: showFollowers,
        ),
      ),
    );
  }

  // NEW: Open posts bookmarked by the current user.
  void _openSavedPosts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SavedPostsScreen(),
      ),
    );
  }


  Future<void> _logOut() async {
    try {
      await _authService.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      _showError(e);
    }
  }


  Widget _buildProfileContent(User user) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _databaseService.getUserStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load profile.'),
          );
        }

        final data = snapshot.data?.data() ?? {};

        final displayName =
            (data['displayName'] ?? 'Plant Friend').toString();

        final username =
            (data['username'] ?? '').toString();

        final bio = (data['bio'] ?? '').toString();

        final email =
            (data['email'] ?? user.email ?? '').toString();

        final photoUrl =
            (data['photoUrl'] ?? '').toString().trim();

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // PROFILE TITLE
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // PROFILE PICTURE
              CircleAvatar(
                radius: 55,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 60,
                      )
                    : null,
              ),

              const SizedBox(height: 12),

              // DISPLAY NAME
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // USERNAME
              if (username.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: const TextStyle(fontSize: 16),
                ),
              ],

              const SizedBox(height: 8),

              // BIO
              Text(
                bio.isEmpty ? 'Add a bio 🌱' : bio,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

            
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  // POSTS COUNT
                  StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        _databaseService.getPostsByUser(user.uid),
                    builder: (context, postSnapshot) {
                      return _ProfileStat(
                        number:
                            '${postSnapshot.data?.docs.length ?? 0}',
                        label: 'Posts',
                        onTap: () => _openMyPosts(user.uid),
                      );
                    },
                  ),

                  // FOLLOWERS COUNT
                  StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        _databaseService.getFollowers(user.uid),
                    builder: (context, followerSnapshot) {
                      return _ProfileStat(
                        number:
                            '${followerSnapshot.data?.docs.length ?? 0}',
                        label: 'Followers',
                        onTap: () => _openFollowList(
                          user.uid,
                          showFollowers: true,
                        ),
                      );
                    },
                  ),

                  // FOLLOWING COUNT
                  StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        _databaseService.getFollowing(user.uid),
                    builder: (context, followingSnapshot) {
                      return _ProfileStat(
                        number:
                            '${followingSnapshot.data?.docs.length ?? 0}',
                        label: 'Following',
                        onTap: () => _openFollowList(
                          user.uid,
                          showFollowers: false,
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Divider(),

        
              // This is the new section we are adding.
              // It appears underneath the profile statistics
              // and above the editable profile settings.

              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline,
                ),
                title: const Text('Saved'),
                subtitle: const Text(
                  'View your bookmarked posts',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: _openSavedPosts,
              ),

              const Divider(),

      
              // EDIT NAME
              ListTile(
                leading: const Icon(
                  Icons.badge_outlined,
                ),
                title: const Text('Name'),
                subtitle: Text(displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editName(
                  uid: user.uid,
                  currentName: displayName,
                ),
              ),

              const Divider(),

              // EDIT USERNAME
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                ),
                title: const Text('Username'),
                subtitle: Text(
                  username.isEmpty
                      ? 'Add a username'
                      : '@$username',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editUsername(
                  uid: user.uid,
                  currentUsername: username,
                ),
              ),

              const Divider(),

              // EDIT BIO
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                ),
                title: const Text('Bio'),
                subtitle: Text(
                  bio.isEmpty ? 'Add a bio' : bio,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editBio(
                  uid: user.uid,
                  currentBio: bio,
                ),
              ),

              const Divider(),

              // EMAIL
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                ),
                title: const Text('Email'),
                subtitle: Text(email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEmail(email),
              ),

              const Divider(),

              // PASSWORD RESET
              ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                ),
                title: const Text('Password'),
                subtitle: const Text(
                  'Send password reset email',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _resetPassword(email),
              ),

              const Divider(),
              const SizedBox(height: 18),

              // LOG OUT
              OutlinedButton.icon(
                onPressed: _logOut,
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
              ),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Not logged in.'),
      );
    }

    // When Profile is inside HomeScreen, avoid
    // creating a second AppBar or navigation drawer.
    if (widget.insideHome) {
      return _buildProfileContent(user);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      drawer: const AppDrawer(),
      body: _buildProfileContent(user),
    );
  }
}


class _ProfileStat extends StatelessWidget {
  final String number;
  final String label;
  final VoidCallback? onTap;

  const _ProfileStat({
    required this.number,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Column(
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
