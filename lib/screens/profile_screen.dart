import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/cloudinary_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/reusable_widgets.dart';

import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'saved_posts_screen.dart';
import 'settings_screen.dart';
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

  static const Color _forest = PlantPalColors.forest;

  Color get _background => PlantPalColors.background(context);
  Color get _card => PlantPalColors.card(context);
  Color get _text => PlantPalColors.text(context);
  Color get _secondary => PlantPalColors.secondaryText(context);
  Color get _accent => PlantPalColors.accent(context);
  Color get _border => PlantPalColors.border(context);
  Color get _soft => PlantPalColors.softBackground(context);

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Choose a profile picture and upload to Cloudinary.
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

      setState(() => _uploadingProfilePicture = true);

      final imageUrl = await _cloudinaryService.uploadImage(image);

      await _databaseService.updateProfilePicture(uid: uid, photoUrl: imageUrl);

      _showMessage('Profile picture updated successfully!');
    } catch (e) {
      _showMessage('Could not upload profile picture: $e');
    } finally {
      if (mounted) {
        setState(() => _uploadingProfilePicture = false);
      }
    }
  }

  // Remove the profile picture URL from Firestore.
  Future<void> _removeProfilePicture(String uid) async {
    if (_uploadingProfilePicture) return;

    try {
      await _databaseService.updateProfilePicture(uid: uid, photoUrl: '');

      _showMessage('Profile picture removed.');
    } catch (e) {
      _showMessage('Could not remove picture: $e');
    }
  }

  // Open photo selection options.
  Future<void> _showPhotoOptions(String uid, bool hasPhoto) async {
    if (_uploadingProfilePicture) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: _accent),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changeProfilePicture(uid);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: _accent),
                  title: const Text('Remove Profile Picture'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeProfilePicture(uid);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  // Reusable dialog for editing profile details.
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
          backgroundColor: PlantPalColors.card(dialogContext),
          title: Text(
            title,
            style: TextStyle(color: PlantPalColors.text(dialogContext)),
          ),
          content: TextFormField(
            initialValue: currentValue,
            maxLength: maxLength,
            maxLines: maxLines,
            style: TextStyle(color: PlantPalColors.text(dialogContext)),
            onChanged: (value) => input = value,
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: PlantPalColors.softBackground(dialogContext),
              labelStyle: TextStyle(
                color: PlantPalColors.secondaryText(dialogContext),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _forest,
                foregroundColor: Colors.white,
              ),
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

  // Update the display name.
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

  // Update the username.
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
        'Username must be 3-20 characters using '
        'letters, numbers, or underscores.',
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

  // Update the user's bio.
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

  // Show the user's email.
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

  // Send a password reset email.
  Future<void> _resetPassword(String email) async {
    if (email.isEmpty) return;

    try {
      await _authService.sendPasswordResetEmail(email);
      _showMessage('Password reset email sent.');
    } catch (e) {
      _showMessage('Unable to send reset email: $e');
    }
  }

  // Log out of PlantPal.
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

  // Display the number of posts, followers, or following.
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: Column(
                children: [
                  Text(
                    snapshot.hasData ? '${snapshot.data!.docs.length}' : '—',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _text),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Reusable row used inside settings cards.
  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _accent),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: _text),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _secondary),
      ),
      trailing: Icon(Icons.chevron_right, color: _accent),
      onTap: onTap,
    );
  }

  // Reusable settings card.
  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                color: _accent,
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

  // Main profile content.
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

        return ColoredBox(
          color: _background,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                child: Column(
                  children: [
                    // Profile header.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.spa_outlined, color: _accent),
                              const SizedBox(width: 8),
                              Text(
                                'My PlantPal Profile',
                                style: TextStyle(
                                  color: _text,
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
                                backgroundColor: _card,
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: _accent,
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
                              child: CircularProgressIndicator(),
                            ),

                          TextButton.icon(
                            onPressed: _uploadingProfilePicture
                                ? null
                                : () => _showPhotoOptions(
                                    user.uid,
                                    photoUrl.isNotEmpty,
                                  ),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Change Profile Picture'),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                          ),

                          if (username.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              username,
                              style: TextStyle(
                                color: _accent,
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
                            style: TextStyle(color: _text, fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Posts, Followers, and Following.
                    Container(
                      decoration: BoxDecoration(
                        color: _card,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
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
                          Container(width: 1, height: 42, color: _border),
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
                          Container(width: 1, height: 42, color: _border),
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
                    ),

                    const SizedBox(height: 18),

                    // Saved Community Posts.
                    _sectionCard(
                      title: 'My Community',
                      children: [
                        _settingTile(
                          icon: Icons.bookmark_outline,
                          title: 'Saved Posts',
                          subtitle: 'View the Community posts you bookmarked.',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SavedPostsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Edit Profile.
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
                        Divider(indent: 16, endIndent: 16, color: _border),
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
                        Divider(indent: 16, endIndent: 16, color: _border),
                        _settingTile(
                          icon: Icons.description_outlined,
                          title: 'Bio',
                          subtitle: bio.isEmpty ? 'Add a bio' : bio,
                          onTap: () => _editBio(uid: user.uid, currentBio: bio),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Account Settings.
                    _sectionCard(
                      title: 'Account Settings',
                      children: [
                        _settingTile(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          subtitle: email,
                          onTap: () => _showEmail(email),
                        ),
                        Divider(indent: 16, endIndent: 16, color: _border),
                        _settingTile(
                          icon: Icons.lock_outline,
                          title: 'Password',
                          subtitle: 'Send password reset email',
                          onTap: () => _resetPassword(email),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // App Settings.
                    _sectionCard(
                      title: 'App Settings',
                      children: [
                        _settingTile(
                          icon: Icons.settings_outlined,
                          title: 'Preferences',
                          subtitle: 'Notifications, appearance, and plant reminder settings',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Log Out.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent,
                          side: BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

    // Respect the selected Light/Dark/System mode.
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
          brightness: baseTheme.brightness,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _accent),
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
              backgroundColor: _background,
              appBar: AppBar(
                title: Text(
                  'Profile',
                  style: TextStyle(color: _text, fontWeight: FontWeight.bold),
                ),
                backgroundColor: _background,
                foregroundColor: _text,
                surfaceTintColor: Colors.transparent,
              ),
              drawer: const AppDrawer(),
              body: _buildProfileContent(user),
            ),
    );
  }
}
