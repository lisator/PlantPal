import 'package:flutter/material.dart';

class PlantSearch extends StatelessWidget {
  const PlantSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Plant Search'),
        SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Search for a plant',
            border: OutlineInputBorder(),
          ),
          child: TextField(),
        ),
      ],
    );
  }
}
