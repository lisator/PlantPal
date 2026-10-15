import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import 'plant_details_screen.dart';

void openMyPlantDetails(BuildContext context, MyPlant plant) {
  openPlantDetailsPage(context, plant.toSearchResult());
}

class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  final String? _userId = currentUserId();
  late final Stream<List<MyPlant>>? _plants =
      _userId == null ? null : DatabaseService().getMyPlants(_userId);

  Future<void> _confirmRemove(String userId, MyPlant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove plant?'),
        content: Text('Remove ${plant.displayName} from My Plants?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await DatabaseService().removeMyPlant(
        userId: userId,
        perenualId: plant.perenualId,
      );
    } catch (e) {
      debugPrint('My Plants error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove plant. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: userId == null
            ? const MyPlantsMessage(
                icon: Icons.lock_outline,
                title: 'Sign in to see your plants',
                message: 'My Plants is saved to your PlantPal account.',
              )
            : StreamBuilder<List<MyPlant>>(
                stream: _plants,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('My Plants error: ${snapshot.error}');
                    return const MyPlantsMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Could not load your plants',
                      message: 'Check your connection and try again.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final plants = snapshot.data!;
                  if (plants.isEmpty) {
                    return MyPlantsMessage(
                      icon: Icons.local_florist_outlined,
                      title: 'No plants yet',
                      message: 'Search for a plant and tap "Add to My Plants" '
                          'to keep its care info here.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            HomeTabs.goTo(context, HomeTabs.search),
                        icon: const Icon(Icons.search),
                        label: const Text('Search plants'),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: plants.length + 1,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: index == 0 ? 16 : 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Plants',
                              style:
                                  Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text('${plants.length} saved'),
                          ],
                        );
                      }
                      final plant = plants[index - 1];
                      return MyPlantCard(
                        plant: plant,
                        onTap: () => openMyPlantDetails(context, plant),
                        onRemove: () =>
                            _confirmRemove(userId, plant),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// Card for a saved plant. [compact] is the small version used on the dashboard.
class MyPlantCard extends StatelessWidget {
  const MyPlantCard({
    super.key,
    required this.plant,
    this.compact = false,
    this.onTap,
    this.onRemove,
  });

  final MyPlant plant;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle =
        plant.nickname != null ? plant.commonName : plant.scientificName;

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
                PlantThumbnail(url: plant.imageUrl, size: compact ? 40 : 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        plant.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      if (!compact) ...[
                        if (plant.location != null) ...[
                          const SizedBox(height: 8),
                          Text('Location: ${plant.location}'),
                        ],
                        if (plant.wateringSummary != null) ...[
                          const SizedBox(height: 4),
                          Text('Water: ${plant.wateringSummary}'),
                        ],
                      ],
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove from My Plants',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  )
                else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyPlantsMessage extends StatelessWidget {
  const MyPlantsMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
