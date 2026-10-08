import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/reusable_widgets.dart';

void openPlantCarePage(BuildContext context, Plant plant) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PlantCareScreen(plant: plant),
    ),
  );
}

class PlantCareScreen extends StatelessWidget {
  const PlantCareScreen({super.key, required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Plant care')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.local_florist,
                    size: 30,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  plant.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  plant.species,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                Text(plant.description),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Care guide', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          PlantCareFact(
            icon: Icons.wb_sunny_outlined,
            title: 'Light',
            description: plant.light,
          ),
          const Divider(height: 1),
          PlantCareFact(
            icon: Icons.water_drop_outlined,
            title: 'Water',
            description: plant.wateringNote,
          ),
          const Divider(height: 1),
          PlantCareFact(
            icon: Icons.air,
            title: 'Humidity',
            description: plant.humidity,
          ),
          const Divider(height: 1),
          PlantCareFact(
            icon: Icons.grass,
            title: 'Soil',
            description: plant.soil,
          ),
          const Divider(height: 1),
          PlantCareFact(
            icon: Icons.pets_outlined,
            title: 'Pet safety',
            description: plant.petSafety,
          ),
        ],
      ),
    );
  }
}
