import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/plant_care_guide.dart';
import '../widgets/plant_photo_editor.dart';
import '../widgets/watering.dart';
import 'analysis_plant_details_screen.dart';
import 'home_screen.dart';
import 'plant_details_screen.dart';

const Color _forest = PlantPalColors.forest;

RoundedRectangleBorder _cardShape(BuildContext context) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: BorderSide(color: PlantPalColors.border(context)),
  );
}

// Keep the app's current light or dark mode.
ThemeData _screenTheme(ThemeData base) {
  final isDark = base.brightness == Brightness.dark;
  final accent = isDark ? PlantPalColors.darkAccent : PlantPalColors.forest;

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _forest,
      brightness: base.brightness,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _forest,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: accent),
    ),
  );
}

// Search plants use Perenual details; analyzed plants use analysis details.
void openMyPlantDetails(BuildContext context, MyPlant plant) {
  if (plant.perenualId != null) {
    openPlantDetailsPage(
      context,
      plant.toSearchResult(),
      collapseCare: true,
      fromMyPlants: true,
      savedPlant: plant,
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => AnalysisPlantDetailsScreen(plant: plant),
    ),
  );
}

// Used by My Plants and the dashboard.
String plantSummary(List<MyPlant> plants) {
  if (plants.isEmpty) return 'No plants saved yet';

  final count = '${plants.length} plant${plants.length == 1 ? '' : 's'}';
  final due = plants
      .where((plant) => (plant.daysUntilWatering() ?? 1) <= 0)
      .length;

  if (due == 0) return '$count · nothing to water today';
  return '$count · $due need${due == 1 ? 's' : ''} water today';
}

class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  final String? _userId = currentUserId();

  late final Stream<List<MyPlant>>? _plants = _userId == null
      ? null
      : DatabaseService().getMyPlants(_userId);

  Future<void> _confirmRemove(String userId, MyPlant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove plant?'),
        content: Text('Remove ${plant.displayName} from My Plants?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await DatabaseService().removeMyPlant(userId: userId, plantId: plant.id);
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

    return Theme(
      data: _screenTheme(Theme.of(context)),
      child: ColoredBox(
        color: PlantPalColors.background(context),
        child: Align(
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
                          message:
                              'Search for a plant and tap '
                              '"Add to My Plants" to keep its care info here.',
                          action: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _forest,
                              foregroundColor: Colors.white,
                            ),
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
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Plants',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: PlantPalColors.text(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plantSummary(plants),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: PlantPalColors.secondaryText(
                                          context,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 8),

                                const WateringColorGuide(showOnTrack: true),
                              ],
                            );
                          }

                          final plant = plants[index - 1];
                          return MyPlantCard(
                            plant: plant,
                            onTap: () => openMyPlantDetails(context, plant),
                            onRemove: () => _confirmRemove(userId, plant),
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
        ),
      ),
    );
  }
}

// Reusable card also shown in compact form on the dashboard.
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
    final daysUntilWatering = plant.daysUntilWatering();
    final subtitle = plant.nickname != null
        ? plant.commonName
        : plant.scientificName;

    final cardColor = PlantPalColors.card(context);
    final textColor = PlantPalColors.text(context);
    final secondaryText = PlantPalColors.secondaryText(context);
    final accent = PlantPalColors.accent(context);
    final border = PlantPalColors.border(context);
    final isDark = PlantPalColors.isDark(context);

    return SizedBox(
      width: compact ? 248 : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
        shape: _cardShape(context),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlantThumbnailWithFallback(
                      url: plant.imageUrl,
                      scientificName: plant.scientificName,
                      commonName: plant.commonName,
                      size: compact ? 40 : 72,
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: 'Change plant photo',
                        icon: const Icon(Icons.camera_alt_outlined, size: 20),
                        color: accent,
                        onPressed: () => changePlantPhoto(context, plant),
                      ),
                  ],
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
                        style: textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: secondaryText,
                          ),
                        ),
                      const SizedBox(height: 6),
                      _LatestHealthStatus(plantId: plant.id),
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
                        Divider(height: 16, color: border),
                        const SizedBox(height: 4),
                        LayoutBuilder(
                          builder: (context, available) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: available.maxWidth,
                                  ),
                                  child: _WateringBadge(
                                    text: wateringStatus(plant),
                                    daysUntilWatering: daysUntilWatering,
                                  ),
                                ),
                                if (onWatered != null &&
                                    daysUntilWatering != null)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: accent,
                                    ),
                                    onPressed: onWatered,
                                    icon: const Icon(
                                      Icons.water_drop_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Watered'),
                                  ),
                                if (onEditSchedule != null)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: accent,
                                    ),
                                    onPressed: onEditSchedule,
                                    child: Text(
                                      plant.waterEveryDays == null
                                          ? 'Set schedule'
                                          : 'Every ${plant.waterEveryDays} days',
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove from My Plants',
                    color: accent,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  )
                else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Watering indicator with responsive text and a colored border.
class _WateringBadge extends StatelessWidget {
  const _WateringBadge({required this.text, required this.daysUntilWatering});

  final String text;
  final int? daysUntilWatering;

  @override
  Widget build(BuildContext context) {
    final days = daysUntilWatering;
    final due = days != null && days <= 0;
    final color = wateringColor(days);
    final background = color == null
        ? PlantPalColors.softBackground(context)
        : color.withValues(alpha: 0.12);
    final foreground = PlantPalColors.text(context);
    final borderColor = color ?? PlantPalColors.border(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: due ? 1.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop, size: 14, color: color ?? foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestHealthStatus extends StatefulWidget {
  const _LatestHealthStatus({required this.plantId});

  final String plantId;

  @override
  State<_LatestHealthStatus> createState() => _LatestHealthStatusState();
}

class _LatestHealthStatusState extends State<_LatestHealthStatus> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _analysis;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _LatestHealthStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plantId != widget.plantId) _subscribe();
  }

  void _subscribe() {
    final userId = currentUserId();
    _analysis = userId == null
        ? null
        : DatabaseService().getLatestPlantAnalysis(
            userId: userId,
            plantId: widget.plantId,
          );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _analysis,
      builder: (context, snapshot) {
        String label = 'Not analyzed';
        IconData icon = Icons.help_outline;
        Color color = PlantPalColors.secondaryText(context);

        if (snapshot.hasError) {
          label = 'Health unavailable';
        } else if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final status =
              (snapshot.data!.docs.first.data()['healthStatus'] ?? '')
                  .toString()
                  .trim();

          if (status.toLowerCase() == 'healthy') {
            label = 'Healthy';
            icon = Icons.check_circle_outline;
            color = const Color(0xFF3B7D44);
          } else if (status.isNotEmpty) {
            label = status;
            icon = Icons.warning_amber_rounded;
            color = Colors.orange.shade800;
          }
        } else if (!snapshot.hasData && _analysis != null) {
          label = 'Checking health...';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final secondaryText = PlantPalColors.secondaryText(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: secondaryText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: secondaryText),
          ),
        ),
      ],
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
    final textColor = PlantPalColors.text(context);
    final secondaryText = PlantPalColors.secondaryText(context);
    final accent = PlantPalColors.accent(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: accent),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
