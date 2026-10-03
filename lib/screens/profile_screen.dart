import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // Profile menu will be added later.
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile picture
            const CircleAvatar(
              radius: 55,
              child: Icon(
                Icons.person,
                size: 60,
              ),
            ),

            const SizedBox(height: 12),

            // Username
            const Text(
              'Plant Friend',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Plant lover 🌱',
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _ProfileStat(
                  number: '12',
                  label: 'Posts',
                ),
                _ProfileStat(
                  number: '248',
                  label: 'Followers',
                ),
                _ProfileStat(
                  number: '186',
                  label: 'Following',
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Profile options
            const Divider(),

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Username'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Edit username later.
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Change email later.
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Change password later.
              },
            ),

            const Divider(),

            const SizedBox(height: 15),

            OutlinedButton(
              onPressed: () {
                // Logout will be connected to Firebase later.
              },
              child: const Text('Log Out'),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String number;
  final String label;

  const _ProfileStat({
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}