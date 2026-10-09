import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import 'plant_care_screen.dart';

class PlantSearch extends StatefulWidget {
  const PlantSearch({super.key});

  @override
  State<PlantSearch> createState() => _PlantSearchState();
}

class _PlantSearchState extends State<PlantSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final results = plantCatalog.where((plant) {
      return plant.name.toLowerCase().contains(normalizedQuery) ||
          plant.species.toLowerCase().contains(normalizedQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Plant Search', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search by plant name',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No plants found.')),
          )
        else
          for (final plant in results) ...[
            PlantCard(
              plant: plant,
              onTap: () => openPlantCarePage(context, plant),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
