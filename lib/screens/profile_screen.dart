import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/reusable_widgets.dart';

import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'saved_posts_screen.dart';
import 'user_posts_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool insideHome;

  const ProfileScreen({super.key, this.insideHome = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool _uploadingProfilePicture = false;

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Upload a selected picture to Cloudinary.
  Future<void> _changeProfilePicture(String uid) async {
    if (_uploadingProfilePicture) return;

    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null || !mounted) return;

      setState(() {
        _uploadingProfilePicture = true;
      });

      // Cloudinary stores the image and returns its URL.
      final imageUrl = await _cloudinaryService.uploadImage(image);

      // Firestore stores only the image URL.
      await _databaseService.updateProfilePicture(uid: uid, photoUrl: imageUrl);

      _showMessage('Profile picture updated successfully!');
    } catch (e) {
      _showMessage('Could not upload profile picture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingProfilePicture = false;
        });
      }
    }
  }

  // Remove the picture from the profile.
  // This does not delete the uploaded file from Cloudinary.
  Future<void> _removeProfilePicture(String uid) async {
    if (_uploadingProfilePicture) return;

    try {
      await _databaseService.updateProfilePicture(uid: uid, photoUrl: '');

      _showMessage('Profile picture removed.');
    } catch (e) {
      _showMessage('Could not remove picture: $e');
    }
  }

  // Show options for changing or removing the picture.
  Future<void> _showPhotoOptions(String uid, bool hasPhoto) async {
    if (_uploadingProfilePicture) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changeProfilePicture(uid);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove Profile Picture'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeProfilePicture(uid);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () {
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Reusable dialog for editing profile information.
  Future<String?> _showEditDialog({
    required String title,
    required String label,
    required String currentValue,
    int maxLength = 150,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: currentValue);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  // Update display name.
  Future<void> _editName({
    required String uid,
    required String currentName,
  }) async {
    final result = await _showEditDialog(
      title: 'Edit Name',
      label: 'Name',
      currentValue: currentName,
      maxLength: 80,
    );

    if (result == null || result.isEmpty) return;

    try {
      await _databaseService.updateProfile(uid: uid, displayName: result);
    } catch (e) {
      _showMessage('Unable to update name: $e');
    }
  }

  // Update username.
  Future<void> _editUsername({
    required String uid,
    required String currentUsername,
  }) async {
    final result = await _showEditDialog(
      title: 'Edit Username',
      label: 'Username',
      currentValue: currentUsername,
      maxLength: 20,
    );

    if (result == null || result.isEmpty) return;

    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(result)) {
      _showMessage(
        'Username must be 3-20 characters using letters, numbers, or underscores.',
      );
      return;
    }

    try {
      final available = await _databaseService.isUsernameAvailable(
        result,
        currentUid: uid,
      );

      if (!available) {
        _showMessage('That username is already taken.');
        return;
      }

      await _databaseService.updateProfile(uid: uid, username: result);
    } catch (e) {
      _showMessage('Unable to update username: $e');
    }
  }

  // Update bio.
  Future<void> _editBio({
    required String uid,
    required String currentBio,
  }) async {
    final result = await _showEditDialog(
      title: 'Edit Bio',
      label: 'Bio',
      currentValue: currentBio,
      maxLength: 150,
      maxLines: 4,
    );

    if (result == null) return;

    try {
      await _databaseService.updateProfile(uid: uid, bio: result);
    } catch (e) {
      _showMessage('Unable to update bio: $e');
    }
  }

  void _showEmail(String email) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Email'),
        content: SelectableText(email),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Email the user a password reset link.
  Future<void> _resetPassword(String email) async {
    if (email.isEmpty) return;

    try {
      await _authService.sendPasswordResetEmail(email);
      _showMessage('Password reset email sent.');
    } catch (e) {
      _showMessage('Unable to send reset email: $e');
    }
  }

  // Sign out of PlantPal.
  Future<void> _signOut() async {
    try {
      await _authService.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showMessage('Unable to sign out: $e');
    }
  }

  // A small widget for profile statistics.
  Widget _stat({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                children: [
                  Text(
                    '${snapshot.data?.docs.length ?? 0}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _databaseService.getUserStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load profile.'));
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};

        final displayName = (data['displayName'] ?? 'Plant Friend').toString();

        final username = (data['username'] ?? '').toString();
        final bio = (data['bio'] ?? '').toString();

        final email = (data['email'] ?? user.email ?? '').toString();

        final photoUrl = (data['photoUrl'] ?? '').toString();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // PROFILE PICTURE
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),

                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 19,
                          child: IconButton(
                            tooltip: 'Change Profile Picture',
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.camera_alt, size: 19),
                            onPressed: _uploadingProfilePicture
                                ? null
                                : () => _showPhotoOptions(
                                    user.uid,
                                    photoUrl.isNotEmpty,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_uploadingProfilePicture)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),

                  TextButton.icon(
                    onPressed: _uploadingProfilePicture
                        ? null
                        : () =>
                              _showPhotoOptions(user.uid, photoUrl.isNotEmpty),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Change Profile Picture'),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(username),
                  ],

                  const SizedBox(height: 10),

                  Text(
                    bio.isEmpty ? 'Add a bio 🌱' : bio,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // POSTS, FOLLOWERS, FOLLOWING
                  Row(
                    children: [
                      _stat(
                        stream: _databaseService.getPostsByUser(user.uid),
                        label: 'Posts',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserPostsScreen(
                                userId: user.uid,
                                title: 'My Posts',
                              ),
                            ),
                          );
                        },
                      ),
                      _stat(
                        stream: _databaseService.getFollowers(user.uid),
                        label: 'Followers',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FollowListScreen(
                                userId: user.uid,
                                showFollowers: true,
                              ),
                            ),
                          );
                        },
                      ),
                      _stat(
                        stream: _databaseService.getFollowing(user.uid),
                        label: 'Following',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FollowListScreen(
                                userId: user.uid,
                                showFollowers: false,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // SAVED COMMUNITY POSTS
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: const Text('Saved Posts'),
                    subtitle: const Text(
                      'View the Community posts you bookmarked.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedPostsScreen(),
                        ),
                      );
                    },
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Name'),
                    subtitle: Text(displayName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _editName(uid: user.uid, currentName: displayName),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Username'),
                    subtitle: Text(
                      username.isEmpty ? 'Add a username' : username,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _editUsername(uid: user.uid, currentUsername: username),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Bio'),
                    subtitle: Text(bio.isEmpty ? 'Add a bio' : bio),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editBio(uid: user.uid, currentBio: bio),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(email),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showEmail(email),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Password'),
                    subtitle: const Text('Send password reset email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _resetPassword(email),
                  ),

                  const Divider(),

                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out'),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Not logged in.'));
    }

    if (widget.insideHome) {
      return _buildProfileContent(user);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: const AppDrawer(),
      body: _buildProfileContent(user),
    );
  }
}
