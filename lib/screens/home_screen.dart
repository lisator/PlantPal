import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/notification_bell.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/watering.dart';

import 'community_screen.dart';
import 'my_plants_screen.dart';
import 'plant_analysis_screen.dart';
import 'plant_info_screen.dart';
import 'profile_screen.dart';

// Shared PlantPal theme helpers.
Color _background(BuildContext context) => PlantPalColors.background(context);

Color _cardColor(BuildContext context) => PlantPalColors.card(context);

Color _textColor(BuildContext context) => PlantPalColors.text(context);

Color _secondaryText(BuildContext context) =>
    PlantPalColors.secondaryText(context);

Color _accent(BuildContext context) => PlantPalColors.accent(context);

Color _border(BuildContext context) => PlantPalColors.border(context);

RoundedRectangleBorder _cardShape(BuildContext context) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: BorderSide(color: _border(context)),
  );
}

// Preserve the active light or dark theme.
ThemeData _screenTheme(ThemeData base) {
  final isDark = base.brightness == Brightness.dark;

  final accent = isDark ? PlantPalColors.darkAccent : PlantPalColors.forest;

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: PlantPalColors.forest,
      brightness: base.brightness,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PlantPalColors.forest,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: accent),
    ),
  );
}

// Bottom navigation indexes.
class HomeTabs {
  static const int dashboard = 0;
  static const int myPlants = 1;
  static const int upload = 2;
  static const int search = 3;
  static const int community = 4;

  // Allows other screens to switch tabs.
  static final ValueNotifier<int> selected = ValueNotifier(dashboard);

  // Return to HomeScreen and open the requested tab.
  static void goTo(BuildContext context, int tab) {
    Navigator.of(context).popUntil((route) => route.isFirst);

    selected.value = tab;
  }
}

// Get the currently signed-in user's ID.
String? currentUserId() {
  if (Firebase.apps.isEmpty) return null;

  return FirebaseAuth.instance.currentUser?.uid;
}

// Main PlantPal Home screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = HomeTabs.dashboard;
  bool _showProfile = false;

  @override
  void initState() {
    super.initState();

    HomeTabs.selected.value = HomeTabs.dashboard;
    HomeTabs.selected.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    HomeTabs.selected.removeListener(_onTabRequested);
    super.dispose();
  }

  // Switch tabs when another screen requests it.
  void _onTabRequested() {
    if (HomeTabs.selected.value != _selectedIndex || _showProfile) {
      _selectBottomTab(HomeTabs.selected.value);
    }
  }

  // Keep the screens in bottom-navigation order.
  List<Widget> get _screens => [
    DashboardScreen(onViewAllPlants: () => _selectBottomTab(HomeTabs.myPlants)),
    const MyPlantsScreen(),
    const UploadScreen(),
    const PlantSearch(),
    const CommunityScreen(),
  ];

  // Open Profile from the sidebar.
  void _openProfile() {
    setState(() {
      _showProfile = true;
    });
  }

  // Switch to a bottom-navigation tab.
  void _selectBottomTab(int index) {
    HomeTabs.selected.value = index;

    setState(() {
      _selectedIndex = index;
      _showProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final background = _background(context);
    final cardColor = _cardColor(context);
    final accent = _accent(context);
    final secondary = _secondaryText(context);
    final textColor = _textColor(context);

    return Scaffold(
      backgroundColor: background,

      // Top navigation now changes with light/dark mode.
      appBar: AppBar(
        title: Text(
          'PlantPal',
          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        // Existing notification bell.
        actions: const [NotificationBell(), SizedBox(width: 12)],
      ),

      // Existing sidebar.
      drawer: AppDrawer(onProfileTap: _openProfile),

      // Keep all existing screens.
      body: _showProfile
          ? const ProfileScreen(insideHome: true)
          : _screens[_selectedIndex],

      // Bottom navigation now changes with dark mode.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: cardColor,
        selectedItemColor: accent,
        unselectedItemColor: secondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        elevation: 4,
        onTap: _selectBottomTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: 'My Plants',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'Upload'),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Plant Search',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
        ],
      ),
    );
  }
}

// Dashboard with watering reminders, saved plants,
// and recent Community posts.
class DashboardScreen extends StatefulWidget {
  final VoidCallback onViewAllPlants;

  const DashboardScreen({super.key, required this.onViewAllPlants});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String? _userId = currentUserId();

  // Load the user's saved plants.
  late final Stream<List<MyPlant>>? _myPlants = _userId == null
      ? null
      : DatabaseService().getMyPlants(_userId);

  // Load plants for watering reminders.
  late final Stream<List<MyPlant>>? _reminderPlants = _userId == null
      ? null
      : DatabaseService().getMyPlants(_userId);

  // Load plants for the dashboard greeting.
  late final Stream<List<MyPlant>>? _summaryPlants = _userId == null
      ? null
      : DatabaseService().getMyPlants(_userId);

  // Load the user's profile information.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _userProfile =
      _userId == null ? null : DatabaseService().getUserStream(_userId);

  // Load recent Community posts.
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _recentPosts =
      _userId == null ? null : DatabaseService().getPosts();

  // Display a personalized greeting.
  Widget _buildGreeting(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    // The greeting banner intentionally stays green.
    // White text is readable in both appearance modes.
    final greetingStyle = textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );

    final summaryStyle = textTheme.bodyMedium?.copyWith(
      color: PlantPalColors.mint,
    );

    Widget banner(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PlantPalColors.forest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

    if (_userId == null) {
      return banner(Text(greeting, style: greetingStyle));
    }

    return banner(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userProfile,
            builder: (context, snapshot) {
              final data = snapshot.data?.data();

              final name = [data?['displayName'], data?['username']]
                  .map((value) => (value ?? '').toString().trim())
                  .firstWhere((value) => value.isNotEmpty, orElse: () => '');

              return Text(
                name.isEmpty ? greeting : '$greeting, $name',
                style: greetingStyle,
              );
            },
          ),

          const SizedBox(height: 4),

          StreamBuilder<List<MyPlant>>(
            stream: _summaryPlants,
            builder: (context, snapshot) {
              final plants = snapshot.data;

              if (plants == null) {
                return const SizedBox(height: 20);
              }

              return Text(plantSummary(plants), style: summaryStyle);
            },
          ),
        ],
      ),
    );
  }

  // Display the three newest Community posts.
  Widget _buildRecentPosts(BuildContext context) {
    if (_recentPosts == null) {
      return const Text('Sign in to see community posts.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _recentPosts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Community posts error: ${snapshot.error}');

          return const Text('Could not load community posts.');
        }

        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final posts = snapshot.data!.docs.take(3).toList();

        if (posts.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            color: _cardColor(context),
            elevation: 1,
            shape: _cardShape(context),
            child: ListTile(
              iconColor: _accent(context),
              leading: const Icon(Icons.forum_outlined),
              title: Text(
                'No posts yet',
                style: TextStyle(color: _textColor(context)),
              ),
              subtitle: Text(
                'Be the first to share in Community.',
                style: TextStyle(color: _secondaryText(context)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => HomeTabs.goTo(context, HomeTabs.community),
            ),
          );
        }

        return Column(
          children: [
            for (final post in posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RecentPostTile(
                  data: post.data(),
                  onTap: () => HomeTabs.goTo(context, HomeTabs.community),
                ),
              ),
          ],
        );
      },
    );
  }

  // Display the user's saved plants.
  Widget _buildSavedPlants(BuildContext context) {
    if (_myPlants == null) {
      return const Text('Sign in to see your saved plants.');
    }

    return StreamBuilder<List<MyPlant>>(
      stream: _myPlants,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('My Plants error: ${snapshot.error}');

          return const Text('Could not load your plants.');
        }

        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final plants = snapshot.data!;

        if (plants.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            color: _cardColor(context),
            elevation: 1,
            shape: _cardShape(context),
            child: ListTile(
              iconColor: _accent(context),
              leading: const Icon(Icons.local_florist_outlined),
              title: Text(
                'No saved plants yet',
                style: TextStyle(color: _textColor(context)),
              ),
              subtitle: Text(
                'Search for a plant to add it.',
                style: TextStyle(color: _secondaryText(context)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => HomeTabs.goTo(context, HomeTabs.search),
            ),
          );
        }

        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: plants.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => MyPlantCard(
              plant: plants[index],
              compact: true,
              onTap: () => openMyPlantDetails(context, plants[index]),
            ),
          ),
        );
      },
    );
  }

  // Display watering reminders.
  Widget _buildReminders(BuildContext context) {
    final userId = _userId;

    if (userId == null) {
      return const Text('Sign in to get watering reminders.');
    }

    return StreamBuilder<List<MyPlant>>(
      stream: _reminderPlants,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Reminders error: ${snapshot.error}');

          return const Text('Could not load your reminders.');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Keep the existing watering reminder widget.
        return WateringRemindersCard(userId: userId, plants: snapshot.data!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = _background(context);
    final cardColor = _cardColor(context);
    final textColor = _textColor(context);
    final accent = _accent(context);

    return Theme(
      data: _screenTheme(Theme.of(context)),
      child: ColoredBox(
        color: background,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGreeting(context),

            const SizedBox(height: 16),

            // Watering reminders section.
            Card(
              margin: EdgeInsets.zero,
              color: cardColor,
              elevation: 1,
              shape: _cardShape(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminders',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildReminders(context),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Saved plants heading.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved plants',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: textColor, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: accent),
                  onPressed: widget.onViewAllPlants,
                  child: const Text('View all'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            _buildSavedPlants(context),

            const SizedBox(height: 24),

            // Community heading.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Community',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: textColor, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: accent),
                  onPressed: () => HomeTabs.goTo(context, HomeTabs.community),
                  child: const Text('See all'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            _buildRecentPosts(context),
          ],
        ),
      ),
    );
  }
}

// Compact preview of a Community post.
class _RecentPostTile extends StatefulWidget {
  const _RecentPostTile({required this.data, this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  @override
  State<_RecentPostTile> createState() => _RecentPostTileState();
}

class _RecentPostTileState extends State<_RecentPostTile> {
  // Look up the post author's username.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _author =
      (widget.data['userId'] ?? '').toString().isEmpty
      ? null
      : DatabaseService().getUserStream(widget.data['userId'].toString());

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final title = (data['title'] ?? '').toString();

    final description = (data['description'] ?? '').toString();

    final imageUrl = (data['imageUrl'] ?? '').toString();

    final accent = _accent(context);

    // Placeholder when a post has no picture.
    final placeholder = SizedBox(
      width: 48,
      height: 48,
      child: Icon(Icons.forum_outlined, color: accent),
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _author,
      builder: (context, snapshot) {
        final username = (snapshot.data?.data()?['username'] ?? '')
            .toString()
            .trim();

        final author = username.isNotEmpty ? '@$username' : 'PlantPal User';

        return _buildTile(
          title: title,
          description: description,
          imageUrl: imageUrl,
          author: author,
          placeholder: placeholder,
        );
      },
    );
  }

  Widget _buildTile({
    required String title,
    required String description,
    required String imageUrl,
    required String author,
    required Widget placeholder,
  }) {
    final cardColor = _cardColor(context);
    final textColor = _textColor(context);
    final secondaryText = _secondaryText(context);
    final accent = _accent(context);

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      elevation: 1,
      shape: _cardShape(context),
      child: ListTile(
        onTap: widget.onTap,
        iconColor: accent,

        leading: imageUrl.isEmpty
            ? placeholder
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                ),
              ),

        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),

        subtitle: Text(
          [if (description.isNotEmpty) description, 'by $author'].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: secondaryText),
        ),

        isThreeLine: description.isNotEmpty,

        trailing: Icon(Icons.chevron_right, color: accent),
      ),
    );
  }
}
