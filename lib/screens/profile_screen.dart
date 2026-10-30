
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

  // PlantPal profile colors.
  // These colors affect this screen, not the whole application.
  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

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
      await _databaseService.updateProfilePicture(
        uid: uid,
        photoUrl: imageUrl,
      );

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
      await _databaseService.updateProfilePicture(
        uid: uid,
        photoUrl: '',
      );

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
      backgroundColor: _pale,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _forest,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changeProfilePicture(uid);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: _forest,
                  ),
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
  // TextFormField avoids manually disposing a temporary controller.
  Future<String?> _showEditDialog({
    required String title,
    required String label,
    required String currentValue,
    int maxLength = 150,
    int maxLines = 1,
  }) async {
    String input = currentValue;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            initialValue: currentValue,
            maxLength: maxLength,
            maxLines: maxLines,
            onChanged: (value) {
              input = value;
            },
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
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, input.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
      await _databaseService.updateProfile(
        uid: uid,
        displayName: result,
      );
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

      await _databaseService.updateProfile(
        uid: uid,
        username: result,
      );
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
      await _databaseService.updateProfile(
        uid: uid,
        bio: result,
      );
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
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
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
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 14,
              ),
              child: Column(
                children: [
                  Text(
                    snapshot.hasData
                        ? '${snapshot.data!.docs.length}'
                        : '—',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: _forest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _ink,
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

  // Display one reusable setting row.
  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 3,
      ),
      leading: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: _mint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _forest),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: _forest,
      ),
      onTap: onTap,
    );
  }

  // Card used to group profile settings.
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: _forest,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileContent(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _databaseService.getUserStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _forest),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load profile.'),
          );
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};

        final displayName =
            (data['displayName'] ?? 'Plant Friend').toString();

        final username =
            (data['username'] ?? '').toString();

        final bio =
            (data['bio'] ?? '').toString();

        final email =
            (data['email'] ?? user.email ?? '').toString();

        final photoUrl =
            (data['photoUrl'] ?? '').toString();

        return ColoredBox(
          color: _pale,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  16, 18, 16, 30,
                ),
                child: Column(
                  children: [
                    // PROFILE PICTURE
                    // Profile header uses the PlantPal green theme.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _mint,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.spa_outlined,
                                color: _forest,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'My PlantPal Profile',
                                style: TextStyle(
                                  color: _forest,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 58,
                                backgroundColor: Colors.white,
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: _forest,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 19,
                                  backgroundColor: _forest,
                                  child: IconButton(
                                    tooltip: 'Change Profile Picture',
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      size: 19,
                                      color: Colors.white,
                                    ),
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
                              child: CircularProgressIndicator(
                                color: _forest,
                              ),
                            ),

                          TextButton.icon(
                            onPressed: _uploadingProfilePicture
                                ? null
                                : () => _showPhotoOptions(
                                      user.uid,
                                      photoUrl.isNotEmpty,
                                    ),
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                            ),
                            label: const Text(
                              'Change Profile Picture',
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),

                          if (username.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              username,
                              style: const TextStyle(
                                color: _forest,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Text(
                            bio.isEmpty
                                ? 'Add a bio to tell people about your plants 🌱'
                                : bio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // POSTS, FOLLOWERS, FOLLOWING
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _mint),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          _stat(
                            stream: _databaseService.getPostsByUser(
                              user.uid,
                            ),
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
                          Container(
                            width: 1,
                            height: 42,
                            color: _mint,
                          ),
                          _stat(
                            stream: _databaseService.getFollowers(
                              user.uid,
                            ),
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
                          Container(
                            width: 1,
                            height: 42,
                            color: _mint,
                          ),
                          _stat(
                            stream: _databaseService.getFollowing(
                              user.uid,
                            ),
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
                    ),

                    const SizedBox(height: 18),

                    // SAVED COMMUNITY POSTS
                    _sectionCard(
                      title: 'My Community',
                      children: [
                        _settingTile(
                          icon: Icons.bookmark_outline,
                          title: 'Saved Posts',
                          subtitle:
                              'View the Community posts you bookmarked.',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SavedPostsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Profile details can be edited here.
                    _sectionCard(
                      title: 'Edit Profile',
                      children: [
                        _settingTile(
                          icon: Icons.badge_outlined,
                          title: 'Name',
                          subtitle: displayName,
                          onTap: () => _editName(
                            uid: user.uid,
                            currentName: displayName,
                          ),
                        ),
                        const Divider(
                          indent: 16,
                          endIndent: 16,
                          color: _mint,
                        ),
                        _settingTile(
                          icon: Icons.person_outline,
                          title: 'Username',
                          subtitle: username.isEmpty
                              ? 'Add a username'
                              : username,
                          onTap: () => _editUsername(
                            uid: user.uid,
                            currentUsername: username,
                          ),
                        ),
                        const Divider(
                          indent: 16,
                          endIndent: 16,
                          color: _mint,
                        ),
                        _settingTile(
                          icon: Icons.description_outlined,
                          title: 'Bio',
                          subtitle:
                              bio.isEmpty ? 'Add a bio' : bio,
                          onTap: () => _editBio(
                            uid: user.uid,
                            currentBio: bio,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Account information and password settings.
                    _sectionCard(
                      title: 'Account Settings',
                      children: [
                        _settingTile(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          subtitle: email,
                          onTap: () => _showEmail(email),
                        ),
                        const Divider(
                          indent: 16,
                          endIndent: 16,
                          color: _mint,
                        ),
                        _settingTile(
                          icon: Icons.lock_outline,
                          title: 'Password',
                          subtitle: 'Send password reset email',
                          onTap: () => _resetPassword(email),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _forest,
                          side: const BorderSide(color: _sage),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                      ),
                    ),
                  ],
                ),
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

    // Theme is local to the profile to avoid changing teammate screens.
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
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _forest,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      child: widget.insideHome
          ? _buildProfileContent(user)
          : Scaffold(
              backgroundColor: _pale,
              appBar: AppBar(
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: _forest,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: _pale,
                surfaceTintColor: _pale,
              ),
              drawer: const AppDrawer(),
              body: _buildProfileContent(user),
            ),
    );
  }
}
