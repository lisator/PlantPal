import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../models/perenual_models.dart';
import '../services/database_service.dart';
import '../services/perenual_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/health_history.dart';
import '../widgets/plant_care_guide.dart';
import '../widgets/plant_photo_editor.dart';
import 'home_screen.dart';
import 'plant_analysis_screen.dart';

class AnalysisPlantDetailsScreen extends StatelessWidget {
  const AnalysisPlantDetailsScreen({super.key, required this.plant});

  final MyPlant plant;

  @override
  Widget build(BuildContext context) {
    final userId = currentUserId();
    final background = PlantPalColors.background(context);
    final textColor = PlantPalColors.text(context);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Plant care',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StreamBuilder<List<MyPlant>>(
                stream: userId == null
                    ? null
                    : DatabaseService().getMyPlants(userId),
                builder: (context, snapshot) {
                  final savedPlants = snapshot.data;
                  final currentPlant = savedPlants == null
                      ? plant
                      : savedPlants
                                .where((p) => p.id == plant.id)
                                .firstOrNull ??
                            plant;

                  return _PlantHeader(plant: currentPlant);
                },
              ),
              const SizedBox(height: 24),
              _PlantInformation(plant: plant),
              const SizedBox(height: 28),
              _AnalysisCareGuide(plant: plant),
              const SizedBox(height: 28),
              if (userId == null)
                Text(
                  'Sign in to view plant health history.',
                  style: TextStyle(
                    color: PlantPalColors.secondaryText(context),
                  ),
                )
              else
                HealthHistory(
                  userId: userId,
                  plantId: plant.id,
                  onRunAnalysis: () async {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: const Text('New Health Analysis'),
                          ),
                          body: UploadScreen(targetPlant: plant),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Header displaying the plant picture and names.
class _PlantHeader extends StatelessWidget {
  const _PlantHeader({required this.plant});

  final MyPlant plant;

  @override
  Widget build(BuildContext context) {
    final cardColor = PlantPalColors.card(context);
    final textColor = PlantPalColors.text(context);
    final secondary = PlantPalColors.secondaryText(context);
    final borderColor = PlantPalColors.border(context);
    final accent = PlantPalColors.accent(context);
    final softColor = PlantPalColors.softBackground(context);
    final isDark = PlantPalColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plant.imageUrl != null && plant.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                plant.imageUrl!,
                width: double.infinity,
                height: 230,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 230,
                    color: softColor,
                    alignment: Alignment.center,
                    child: Icon(Icons.local_florist, size: 60, color: accent),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => changePlantPhoto(context, plant),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Edit Photo'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plant.displayName,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: textColor, fontWeight: FontWeight.w700),
          ),
          if (plant.nickname != null) ...[
            const SizedBox(height: 4),
            Text(
              plant.commonName,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: secondary),
            ),
          ],
          if (plant.scientificName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plant.scientificName,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: secondary, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

// Location, watering schedule, and date added.
class _PlantInformation extends StatelessWidget {
  const _PlantInformation({required this.plant});

  final MyPlant plant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Plant',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: PlantPalColors.text(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (plant.location != null)
          _InfoRow(
            icon: Icons.location_on_outlined,
            title: 'Location',
            value: plant.location!,
          ),
        _InfoRow(
          icon: Icons.water_drop_outlined,
          title: 'Watering',
          value: plant.waterEveryDays == null
              ? 'No watering schedule'
              : 'Every ${plant.waterEveryDays} days',
        ),
        if (plant.addedAt != null)
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            title: 'Added',
            value: _formatDate(plant.addedAt!),
          ),
      ],
    );
  }
}

// Look up care information using Perenual and Wikipedia.
// The original lookup and fallback behavior is preserved.
class _AnalysisCareGuide extends StatefulWidget {
  const _AnalysisCareGuide({required this.plant});

  final MyPlant plant;

  @override
  State<_AnalysisCareGuide> createState() => _AnalysisCareGuideState();
}

class _AnalysisCareGuideState extends State<_AnalysisCareGuide> {
  late final Future<PlantDetails?> _perenual;
  late final Future<WikipediaExtras> _wikipedia;

  @override
  void initState() {
    super.initState();

    _perenual = PerenualService.instance
        .findByName(
          scientificName: widget.plant.scientificName,
          commonName: widget.plant.commonName,
        )
        .catchError((Object error) {
          debugPrint('Perenual lookup for analysis plant failed: $error');
          return null;
        });

    _wikipedia = loadWikipediaFor(
      scientificName: widget.plant.scientificName,
      commonName: widget.plant.commonName,
    );
  }

  /// Names only, for plants Perenual doesn't have, so Wikipedia can still
  /// be searched.
  // not marked limited, so no "not in our perenual plan" note shows
  PlantDetails get _namesOnly => PlantDetails(
    id: -1,
    commonName: widget.plant.commonName,
    scientificName: widget.plant.scientificName,
  );

  /// Where the care info comes from, when it's another plant's Perenual
  /// entry. Plants Perenual doesn't have get no note.
  String? _note(PlantDetails? found) {
    if (found == null) return null;
    final identified = widget.plant.scientificName.toLowerCase();
    final foundName = found.scientificName.toLowerCase();

    if (!foundName.startsWith(identified) &&
        !identified.startsWith(foundName)) {
      return 'Showing care info for ${found.commonName} '
          '(${found.scientificName}), the closest match '
          'in our plant database.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlantDetails?>(
      future: _perenual,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: PlantPalColors.accent(context),
              ),
            ),
          );
        }

        final found = snapshot.data;

        return PlantCareGuide(
          details: found ?? _namesOnly,
          wikipedia: _wikipedia,
          note: _note(found),
          collapsible: true,
        );
      },
    );
  }
}

// Theme-aware information row.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textColor = PlantPalColors.text(context);
    final secondary = PlantPalColors.secondaryText(context);
    final accent = PlantPalColors.accent(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[date.month - 1]} '
      '${date.day}, ${date.year}';
}
