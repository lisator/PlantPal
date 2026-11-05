import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../models/perenual_models.dart';
import '../services/perenual_service.dart';
import '../widgets/plant_care_guide.dart';
import 'home_screen.dart';
import '../widgets/health_history.dart';

// PlantPal colors, same palette as the community screen. Used for the app
// bar, header, plant info, and care guide; Health History keeps its own look.
const Color _forest = Color(0xFF315F43);
const Color _pale = Color(0xFFF6F8F2);
const Color _mint = Color(0xFFE0EBDD);
const Color _ink = Color(0xFF24372A);

// Forest icons, buttons, spinners, and care guide accents instead of
// Flutter's default purple.
ThemeData _screenTheme(ThemeData base) => base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _forest,
        primary: _forest,
        outlineVariant: _mint,
      ),
      dividerTheme: const DividerThemeData(color: _mint),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _forest),
      ),
    );

class AnalysisPlantDetailsScreen extends StatelessWidget {
  const AnalysisPlantDetailsScreen({
    super.key,
    required this.plant,
  });

  final MyPlant plant;

  @override
  Widget build(BuildContext context) {
    final userId = currentUserId();

    return Scaffold(
      backgroundColor: _pale,
      appBar: AppBar(
        title: const Text(
          'Plant care',
          style: TextStyle(
            color: _forest,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _pale,
        surfaceTintColor: _pale,
        foregroundColor: _forest,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // header, plant info, and care guide in PlantPal colors
              Theme(
                data: _screenTheme(Theme.of(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PlantHeader(plant: plant),

                    const SizedBox(height: 24),

                    _PlantInformation(plant: plant),

                    const SizedBox(height: 28),

                    _AnalysisCareGuide(plant: plant),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              if (userId == null)
                const Text(
                  'Sign in to view plant health history.',
                )
              else
                HealthHistory(
                  userId: userId,
                  plantId: plant.id,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlantHeader extends StatelessWidget {
  const _PlantHeader({
    required this.plant,
  });

  final MyPlant plant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      // white card with a mint border, like the community posts
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _mint),
        boxShadow: [
          BoxShadow(
            color: _forest.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plant.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                plant.imageUrl!,
                width: double.infinity,
                height: 230,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    height: 230,
                    color: colors.primaryContainer,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_florist,
                      size: 60,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          Text(
            plant.displayName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
          ),

          if (plant.nickname != null) ...[
            const SizedBox(height: 4),
            Text(
              plant.commonName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],

          if (plant.scientificName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plant.scientificName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlantInformation extends StatelessWidget {
  const _PlantInformation({
    required this.plant,
  });

  final MyPlant plant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Plant',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _ink,
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

/// Care info for a plant identified by plant analysis. These plants have no
/// Perenual ID, so Perenual is searched by the identified name first, then
/// Wikipedia fills in whatever Perenual doesn't have.
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
    // Both start now, side by side: Perenual by the identified name, and
    // Wikipedia for whatever Perenual turns out not to have.
    _perenual = PerenualService.instance
        .findByName(
          scientificName: widget.plant.scientificName,
          commonName: widget.plant.commonName,
        )
        .catchError((Object e) {
      debugPrint('Perenual lookup for analysis plant failed: $e');
      return null;
    });
    _wikipedia = loadWikipediaFor(
      scientificName: widget.plant.scientificName,
      commonName: widget.plant.commonName,
    );
  }

  /// Names only, for plants Perenual doesn't have, so Wikipedia can still
  /// be searched.
  PlantDetails get _namesOnly => PlantDetails.basic(PlantSearchResult(
        id: -1,
        commonName: widget.plant.commonName,
        scientificName: widget.plant.scientificName,
      ));


  /// Where the care info comes from, when it isn't simply this plant's
  /// Perenual entry.
  String? _note(PlantDetails? found) {
    if (found == null) {
      return 'This plant isn\'t in our plant database (Perenual), so care '
          'info comes from Wikipedia.';
    }
    final identified = widget.plant.scientificName.toLowerCase();
    if (!found.scientificName.toLowerCase().startsWith(identified) &&
        !identified.startsWith(found.scientificName.toLowerCase())) {
      return 'Showing care info for ${found.commonName} '
          '(${found.scientificName}), the closest match in our plant database.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlantDetails?>(
      future: _perenual,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final found = snapshot.data;
        return PlantCareGuide(
          details: found ?? _namesOnly,
          wikipedia: _wikipedia,
          note: _note(found),
          // only opened from my plants, so start collapsed
          collapsible: true,
        );
      },
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
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