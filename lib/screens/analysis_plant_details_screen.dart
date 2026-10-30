import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../models/perenual_models.dart';
import '../services/database_service.dart';
import '../services/perenual_service.dart';
import '../widgets/plant_care_guide.dart';
import 'home_screen.dart';

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
      appBar: AppBar(
        title: const Text('Plant care'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PlantHeader(plant: plant),

              const SizedBox(height: 24),

              _PlantInformation(plant: plant),

              const SizedBox(height: 28),

              _AnalysisCareGuide(plant: plant),

              const SizedBox(height: 28),

              Text(
                'Health History',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 6),

              Text(
                'Saved plant analyses appear here so you can track '
                'changes in your plant\'s health over time.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),

              const SizedBox(height: 16),

              if (userId == null)
                const Text(
                  'Sign in to view plant health history.',
                )
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: DatabaseService().getPlantAnalyses(
                    userId: userId,
                    plantId: plant.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const _MessageCard(
                        message: 'Could not load health history.',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final analyses = snapshot.data!.docs;

                    if (analyses.isEmpty) {
                      return const _MessageCard(
                        message:
                            'No health analyses have been saved for this plant yet.',
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < analyses.length; i++) ...[
                          _AnalysisCard(
                            data: analyses[i].data(),
                            isLatest: i == 0,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
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
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
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
            style: Theme.of(context).textTheme.headlineMedium,
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
          style: Theme.of(context).textTheme.headlineSmall,
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

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.data,
    required this.isLatest,
  });

  final Map<String, dynamic> data;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final status =
        data['healthStatus']?.toString() ?? 'Unknown';

    final confidence =
        (data['confidence'] as num?)?.toDouble();

    final timestamp =
        data['analyzedAt'] as Timestamp?;

    final issues =
        (data['issues'] as List?)
                ?.whereType<Map>()
                .map(
                  (item) =>
                      Map<String, dynamic>.from(item),
                )
                .toList() ??
            [];

    final care =
        (data['recommendedCare'] as List?)
                ?.map(
                  (item) => item.toString(),
                )
                .toList() ??
            [];

    final imageUrl =
        data['imageUrl'] as String?;

    final healthy =
        status == 'Healthy';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLatest) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F3DF),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Text(
                  'Latest Analysis',
                  style: TextStyle(
                    color: Color(0xFF315D3A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (timestamp != null)
              Text(
                _formatDate(timestamp.toDate()),
                style:
                    Theme.of(context).textTheme.titleMedium,
              ),

            if (imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 155,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      height: 155,
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.local_florist,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: healthy
                    ? const Color(0xFFE4F3DF)
                    : const Color(0xFFFFEDBC),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    healthy
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: healthy
                        ? const Color(0xFF3B7D44)
                        : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (confidence != null) ...[
              const SizedBox(height: 10),
              Text(
                'Identification confidence: '
                '${(confidence * 100).toStringAsFixed(1)}%',
              ),
            ],

            if (issues.isNotEmpty) ...[
              const SizedBox(height: 14),

              Text(
                'Detected Issues',
                style:
                    Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              for (final issue in issues)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue['name']?.toString() ??
                              'Unknown issue',
                        ),
                      ),
                      if (issue['probability'] is num)
                        Text(
                          '${(((issue['probability'] as num).toDouble()) * 100).toStringAsFixed(1)}%',
                        ),
                    ],
                  ),
                ),
            ],

            if (care.isNotEmpty) ...[
              const SizedBox(height: 14),

              Text(
                'Suggested Treatment',
                style:
                    Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              for (final item in care)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Color(0xFF4F7C56),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
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