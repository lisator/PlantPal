import 'package:flutter/material.dart';

class MyPlantsScreen extends StatelessWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('My Plants'),
        SizedBox(height: 16),
        Text('Plant 1'),
        Text('Plant 2'),
        Text('Plant 3'),
      ],
    );
  }
}
