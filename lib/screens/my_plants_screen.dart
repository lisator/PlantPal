import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import 'plant_care_screen.dart';

class MyPlantsScreen extends StatelessWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Plants', style: Theme.of(context).textTheme.headlineSmall),
            Text('${savedPlants.length} saved'),
          ],
        ),
        const SizedBox(height: 16),
        for (final plant in savedPlants) ...[
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
