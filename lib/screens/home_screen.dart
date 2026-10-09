import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/reusable_widgets.dart';

import 'community_screen.dart';
import 'my_plants_screen.dart';
import 'plant_analysis_screen.dart';
import 'plant_info_screen.dart';
import 'plant_care_screen.dart';
import 'community_screen.dart';
import '../models/models.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  bool _showProfile = false;

  List<Widget> get _screens => [
        DashboardScreen(
          onViewAllPlants: () => _selectBottomTab(1), // Switches to the 'My Plants' tab
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

  void _showMyPlants() {
    setState(() {
      _selectedIndex = 1;
      _showProfile = false;
    });
  }

  void _selectBottomTab(int index) {
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
            icon: Icon(
              Icons.home,
            ),
            label: 'Dashboard',
          ),

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
  final List<Map<String, dynamic>> _reminders = [
    {
      'message': 'Water your monstera today!',
      'checked': false,
    },
    {
      'message': 'Check the basil soil moisture.',
      'checked': true,
    },
  ];

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

                for (
                  int i = 0;
                  i < _reminders.length;
                  i++
                )
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: ReminderCard(
                      message:
                          _reminders[i]['message'],
                      isChecked:
                          _reminders[i]['checked'],
                      onChanged: (value) {
                        setState(() {
                          _reminders[i]
                                  ['checked'] =
                              value ?? false;
                        });
                      },
                    ),
                  ),
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

        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            itemCount:
                savedPlants.length,
            separatorBuilder:
                (context, index) =>
                    const SizedBox(
              width: 12,
            ),
            itemBuilder:
                (context, index) =>
                    PlantCard(
              plant:
                  savedPlants[index],
              compact: true,
              onTap: () =>
                  openPlantCarePage(
                context,
                savedPlants[index],
              ),
            ),
          ),
        ),
      ],
    );
  }
}