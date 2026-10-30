import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../services/database_service.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/watering.dart';

import 'community_screen.dart';
import 'my_plants_screen.dart';
import 'plant_analysis_screen.dart';
import 'plant_info_screen.dart';
import 'profile_screen.dart';

/// Bottom tab indexes in HomeScreen, plus a way for pushed pages
/// (e.g. plant details) to jump to a tab.
class HomeTabs {
  static const int dashboard = 0;
  static const int myPlants = 1;
  static const int upload = 2;
  static const int search = 3;
  static const int community = 4;

  /// HomeScreen listens to this and switches tabs when it changes.
  static final ValueNotifier<int> selected = ValueNotifier(dashboard);

  /// Closes any pages pushed on top of HomeScreen and shows [tab].
  static void goTo(BuildContext context, int tab) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    selected.value = tab;
  }
}

/// The signed-in user's id, or null if signed out or Firebase isn't set up
/// (e.g. Linux desktop).
String? currentUserId() {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance.currentUser?.uid;
}

/// Main app shell: app bar, drawer, and the bottom tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
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

  // Pages pushed on top (e.g. plant details) switch tabs via HomeTabs.goTo.
  void _onTabRequested() {
    if (HomeTabs.selected.value != _selectedIndex || _showProfile) {
      _selectBottomTab(HomeTabs.selected.value);
    }
  }

  // Order must match HomeTabs and the bottom nav items below.
  List<Widget> get _screens => [
        DashboardScreen(
          onViewAllPlants: () => _selectBottomTab(HomeTabs.myPlants),
        ),
        const MyPlantsScreen(),
        const UploadScreen(),
        const PlantSearch(),
        const CommunityScreen(),
      ];

  // Opened from the drawer; shows in place of the current tab.
  void _openProfile() {
    setState(() {
      _showProfile = true;
    });
  }

  // Also updates HomeTabs so it stays in sync with the bottom nav.
  void _selectBottomTab(int index) {
    HomeTabs.selected.value = index;
    setState(() {
      _selectedIndex = index;
      _showProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlantPal'),
        centerTitle: true,
      ),

      drawer: AppDrawer(
        onProfileTap: _openProfile,
      ),

      body: _showProfile
          ? const ProfileScreen(
              insideHome: true,
            )
          : _screens[_selectedIndex],

      bottomNavigationBar:
          BottomNavigationBar(
        currentIndex:
            _selectedIndex,
        type:
            BottomNavigationBarType.fixed,

        onTap: _selectBottomTab,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: 'My Plants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Plant Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}

/// Dashboard tab: watering reminders and a row of saved plants.
class DashboardScreen
    extends StatefulWidget {
      final VoidCallback onViewAllPlants;
  const DashboardScreen({
    super.key,
    required this.onViewAllPlants,
  });

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  final String? _userId = currentUserId();
  // Each StreamBuilder below gets its own stream.
  late final Stream<List<MyPlant>>? _myPlants =
      _userId == null
          ? null
          : DatabaseService().getMyPlants(_userId);
  late final Stream<List<MyPlant>>? _reminderPlants =
      _userId == null
          ? null
          : DatabaseService().getMyPlants(_userId);
  // saved plants for the summary line under the greeting
  late final Stream<List<MyPlant>>? _summaryPlants =
      _userId == null
          ? null
          : DatabaseService().getMyPlants(_userId);
  // the user's firestore doc (users/{uid}), used for their name in the greeting
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>?
      _userProfile = _userId == null
          ? null
          : DatabaseService().getUserStream(_userId);
  // community posts, newest first (only the first 3 are shown)
  late final Stream<QuerySnapshot<Map<String, dynamic>>>?
      _recentPosts = _userId == null
          ? null
          : DatabaseService().getPosts();

  /// "Good morning, Name" and a one-line summary of the user's plants.
  Widget _buildGreeting(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // morning before 12, afternoon before 6pm, evening after
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    // signed out: just the greeting, no name or summary
    if (_userId == null) {
      return Text(greeting, style: textTheme.headlineSmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userProfile,
          builder: (context, snapshot) {
            // Display name, then username, then no name.
            final data = snapshot.data?.data();
            final name = [data?['displayName'], data?['username']]
                .map((value) => (value ?? '').toString().trim())
                .firstWhere(
                  (value) => value.isNotEmpty,
                  orElse: () => '',
                );
            return Text(
              name.isEmpty ? greeting : '$greeting, $name',
              style: textTheme.headlineSmall,
            );
          },
        ),
        const SizedBox(height: 4),
        StreamBuilder<List<MyPlant>>(
          stream: _summaryPlants,
          builder: (context, snapshot) {
            // keeps the space while loading so the page doesn't jump
            final plants = snapshot.data;
            if (plants == null) {
              return const SizedBox(height: 20);
            }
            return Text(
              plantSummary(plants),
              style: textTheme.bodyMedium,
            );
          },
        ),
      ],
    );
  }

  /// The 3 newest community posts; tapping one opens the Community tab.
  Widget _buildRecentPosts(BuildContext context) {
    if (_recentPosts == null) {
      return const Text(
        'Sign in to see community posts.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _recentPosts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Community posts error: ${snapshot.error}');
          return const Text(
            'Could not load community posts.',
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // only show the 3 newest posts
        final posts = snapshot.data!.docs.take(3).toList();
        if (posts.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('No posts yet'),
              subtitle: const Text('Be the first to share in Community.'),
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

  /// Saved plants row, or a shortcut to Search if there are none.
  Widget _buildSavedPlants(BuildContext context) {
    if (_myPlants == null) {
      return const Text(
        'Sign in to see your saved plants.',
      );
    }

    return StreamBuilder<List<MyPlant>>(
      stream: _myPlants,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('My Plants error: ${snapshot.error}');
          return const Text(
            'Could not load your plants.',
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final plants = snapshot.data!;
        if (plants.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.local_florist_outlined,
              ),
              title: const Text(
                'No saved plants yet',
              ),
              subtitle: const Text(
                'Search for a plant to add it.',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () => HomeTabs.goTo(
                context,
                HomeTabs.search,
              ),
            ),
          );
        }

        return SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            itemCount: plants.length,
            separatorBuilder:
                (context, index) =>
                    const SizedBox(
              width: 12,
            ),
            itemBuilder:
                (context, index) =>
                    MyPlantCard(
              plant: plants[index],
              compact: true,
              onTap: () =>
                  openMyPlantDetails(
                context,
                plants[index],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Watering reminders built from the user's saved plants.
  Widget _buildReminders(BuildContext context) {
    final userId = _userId;
    if (userId == null) {
      return const Text(
        'Sign in to get watering reminders.',
      );
    }

    return StreamBuilder<List<MyPlant>>(
      stream: _reminderPlants,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Reminders error: ${snapshot.error}');
          return const Text(
            'Could not load your reminders.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        return WateringRemindersCard(
          userId: userId,
          plants: snapshot.data!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGreeting(context),

        const SizedBox(
          height: 16,
        ),

        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reminders',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                _buildReminders(context),
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 20,
        ),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saved plants',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            TextButton(
              onPressed:
                  widget.onViewAllPlants,
              child:
                  const Text('View all'),
            ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        _buildSavedPlants(context),

        const SizedBox(
          height: 24,
        ),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Community',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            TextButton(
              onPressed: () => HomeTabs.goTo(
                context,
                HomeTabs.community,
              ),
              child:
                  const Text('See all'),
            ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        _buildRecentPosts(context),
      ],
    );
  }
}

/// Compact preview of one community post for the dashboard.
class _RecentPostTile extends StatefulWidget {
  const _RecentPostTile({
    required this.data,
    this.onTap,
  });

  // the post's firestore fields (title, description, imageUrl, userId)
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  @override
  State<_RecentPostTile> createState() => _RecentPostTileState();
}

class _RecentPostTileState extends State<_RecentPostTile> {
  // the poster's user doc, only used for their username
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _author =
      (widget.data['userId'] ?? '').toString().isEmpty
          ? null
          : DatabaseService()
              .getUserStream(widget.data['userId'].toString());

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final title = (data['title'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    // shown when a post has no image or the image fails to load
    const placeholder = SizedBox(
      width: 48,
      height: 48,
      child: Icon(Icons.forum_outlined),
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _author,
      builder: (context, snapshot) {
        // username only, never the real name or email
        final username =
            (snapshot.data?.data()?['username'] ?? '').toString().trim();
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
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: widget.onTap,
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
        ),
        subtitle: Text(
          [
            if (description.isNotEmpty) description,
            'by $author',
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: description.isNotEmpty,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}