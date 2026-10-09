import 'package:flutter/material.dart';
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