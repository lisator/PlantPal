import 'package:flutter/material.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // Community menu will be added later.
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add Post button
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Add Post screen will be connected next.
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Post'),
              ),
            ),

            const SizedBox(height: 20),

            // Empty feed message
            const Icon(
              Icons.local_florist,
              size: 70,
            ),

            const SizedBox(height: 15),

            const Text(
              'Your feed is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Follow some plant friends to see their posts!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: () {
                // Find Plant Friends will be added later.
              },
              child: const Text('Find Plant Friends'),
            ),
          ],
        ),
      ),
    );
  }
}