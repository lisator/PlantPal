import 'package:flutter/material.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Community'),
        SizedBox(height: 16),
        Text('Post 1'),
        Text('Post 2'),
        Text('Post 3'),
      ],
    );
  }
}
