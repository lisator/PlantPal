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

  List<Widget> get _screens => [
        DashboardScreen(
          onViewAllPlants: () => _selectBottomTab(HomeTabs.myPlants),
        ),
        const MyPlantsScreen(),
        const UploadScreen(),
        const PlantSearch(),
        const CommunityScreen(),
      ];

  void _openProfile() {
    setState(() {
      _showProfile = true;
    });
  }

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
  late final Stream<List<MyPlant>>? _myPlants =
      _userId == null
          ? null
          : DatabaseService().getMyPlants(_userId);
  late final Stream<List<MyPlant>>? _reminderPlants =
      _userId == null
          ? null
          : DatabaseService().getMyPlants(_userId);

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
      ],
    );
  }
}