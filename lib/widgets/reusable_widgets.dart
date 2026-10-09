import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback? onProfileTap;

  const AppDrawer({
    super.key,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 112, 221, 116),
            ),
            child: Text(
              'PlantPal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(
              Icons.account_circle,
            ),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);

              if (onProfileTap != null) {
                onProfileTap!();
              }
            },
          ),

          ListTile(
            leading: const Icon(
              Icons.message,
            ),
            title: const Text('Messages'),
            onTap: () {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Messages will be added later.',
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(
              Icons.settings,
            ),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Settings will be added later.',
                  ),
                ),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(
              Icons.logout,
            ),
            title: const Text('Log Out'),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const LoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.message,
    this.isChecked = false,
    this.onChanged,
  });

  final String message;
  final bool isChecked;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.local_florist,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ),

            Checkbox(
              value: isChecked,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class PlantCard extends StatelessWidget {
  const PlantCard({
    super.key,
    required this.plant,
    this.compact = false,
    this.onTap,
  });

  final Plant plant;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 248 : null,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.local_florist,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Text(
                        plant.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),

                      Text(
                        plant.species,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),

                      if (!compact) ...[
                        const SizedBox(
                          height: 10,
                        ),

                        if (plant.location != null)
                          Text(
                            'Location: ${plant.location}',
                          ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          plant.wateringNote,
                        ),
                      ],
                    ],
                  ),
                ),

                if (onTap != null) ...[
                  const SizedBox(
                    width: 8,
                  ),
                  const Icon(
                    Icons.chevron_right,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlantCareFact extends StatelessWidget {
  const PlantCareFact({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall,
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
