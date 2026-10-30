import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../services/database_service.dart';
import '../widgets/watering.dart';
import 'home_screen.dart';
import 'plant_details_screen.dart';
import '../widgets/plant_care_guide.dart';

import 'analysis_plant_details_screen.dart';

/// Plants from search open the Perenual care page; plants saved from a photo
/// analysis (no Perenual id) open the analysis details page.
void openMyPlantDetails(BuildContext context, MyPlant plant) {
  if (plant.perenualId != null) {
    openPlantDetailsPage(
      context,
      plant.toSearchResult(),
      collapseCare: true,
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => AnalysisPlantDetailsScreen(
        plant: plant,
      ),
    ),
  );
}

/// One-line summary, e.g. "4 plants · 1 needs water today".
/// Used on My Plants and the Dashboard.
String plantSummary(List<MyPlant> plants) {
  if (plants.isEmpty) return 'No plants saved yet';
  final count = '${plants.length} plant${plants.length == 1 ? '' : 's'}';
  // due today or overdue; plants with no schedule don't count
  final due = plants.where((p) => (p.daysUntilWatering() ?? 1) <= 0).length;
  if (due == 0) return '$count · nothing to water today';
  return '$count · $due need${due == 1 ? 's' : ''} water today';
}

/// My Plants tab: the user's saved plants, live from Firestore.
class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  final String? _userId = currentUserId();
  late final Stream<List<MyPlant>>? _plants =
      _userId == null ? null : DatabaseService().getMyPlants(_userId);

  /// Asks before removing a plant.
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
        plantId: plant.id,
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

    // States: signed out, error, loading, empty, or the list.
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
                      // First row is the title and summary.
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Plants',
                              style:
                                  Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plantSummary(plants),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        );
                      }
                      final plant = plants[index - 1];
                      return MyPlantCard(
                        plant: plant,
                        onTap: () => openMyPlantDetails(context, plant),
                        onRemove: () =>
                            _confirmRemove(userId, plant),
                        onWatered: () => markPlantWatered(
                          context,
                          userId: userId,
                          plant: plant,
                        ),
                        onEditSchedule: () => editWateringSchedule(
                          context,
                          userId: userId,
                          plant: plant,
                        ),
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
    this.onWatered,
    this.onEditSchedule,
  });

  final MyPlant plant;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onWatered;
  final VoidCallback? onEditSchedule;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final daysUntilWatering = plant.daysUntilWatering();
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
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                PlantThumbnailWithFallback(
                  url: plant.imageUrl,
                  scientificName: plant.scientificName,
                  commonName: plant.commonName,
                  size: compact ? 40 : 72,
                ),
                SizedBox(width: compact ? 12 : 16),
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
                          _CardDetail(
                            icon: Icons.place_outlined,
                            text: plant.location!,
                          ),
                        ],
                        if (plant.wateringSummary != null) ...[
                          const SizedBox(height: 4),
                          _CardDetail(
                            icon: Icons.water_drop_outlined,
                            text: plant.wateringSummary!,
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Divider(height: 16),
                        // Watering status, "Watered" button, and schedule.
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              wateringStatus(plant),
                              style: daysUntilWatering != null &&
                                      daysUntilWatering <= 0
                                  ? textTheme.bodyMedium?.copyWith(
                                      color: colors.error,
                                      fontWeight: FontWeight.bold,
                                    )
                                  : textTheme.bodyMedium,
                            ),
                            if (onWatered != null && daysUntilWatering != null)
                              TextButton.icon(
                                onPressed: onWatered,
                                icon: const Icon(
                                  Icons.water_drop_outlined,
                                  size: 18,
                                ),
                                label: const Text('Watered'),
                              ),
                            if (onEditSchedule != null)
                              TextButton(
                                onPressed: onEditSchedule,
                                child: Text(
                                  plant.waterEveryDays == null
                                      ? 'Set schedule'
                                      : 'Every ${plant.waterEveryDays} days',
                                ),
                              ),
                          ],
                        ),
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

/// Small icon + text line on a plant card (location, watering needs).
class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // muted icon, text cut off with "..." if too long
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Centered icon and text for the signed-out, error and empty states.
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
