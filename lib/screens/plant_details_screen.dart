import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../models/perenual_models.dart';
import '../services/database_service.dart';
import '../services/perenual_service.dart';
import '../widgets/reusable_widgets.dart';
import 'home_screen.dart';

void openPlantDetailsPage(BuildContext context, PlantSearchResult plant) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PlantDetailsScreen(plantId: plant.id, preview: plant),
    ),
  );
}

/// Care details for a Perenual species. [preview] (from the search results)
/// is shown in the header while the full details load.
class PlantDetailsScreen extends StatefulWidget {
  const PlantDetailsScreen({super.key, required this.plantId, this.preview});

  final int plantId;
  final PlantSearchResult? preview;

  @override
  State<PlantDetailsScreen> createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  late Future<PlantDetails> _details;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final preview = widget.preview;
    // Skip the API call for species the free plan can't return; it would
    // just be refused and still count against the daily limit.
    if (preview != null && !preview.hasFullDetails) {
      _details = Future.value(PlantDetails.basic(preview));
    } else {
      _details = PerenualService.instance.getPlantDetails(widget.plantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plant care')),
      body: FutureBuilder<PlantDetails>(
        future: _details,
        builder: (context, snapshot) {
          final details = snapshot.data;
          final preview = widget.preview;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _PlantHeader(
                    name: details?.commonName ?? preview?.commonName ?? '',
                    scientificName:
                        details?.scientificName ?? preview?.scientificName ?? '',
                    imageUrl: details?.imageUrl ?? preview?.thumbnailUrl,
                    family: details?.family,
                  ),
                  const SizedBox(height: 24),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _ErrorPanel(
                      message: snapshot.error is PerenualException
                          ? (snapshot.error as PerenualException).message
                          : 'Could not load care details.',
                      onRetry: () => setState(_load),
                    )
                  else if (details != null) ...[
                    _MyPlantButton(details: details),
                    const SizedBox(height: 20),
                    _CareDetails(details: details),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlantHeader extends StatelessWidget {
  const _PlantHeader({
    required this.name,
    required this.scientificName,
    this.imageUrl,
    this.family,
  });

  final String name;
  final String scientificName;
  final String? imageUrl;
  final String? family;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: textTheme.headlineSmall),
        if (scientificName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            scientificName,
            style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        if (family != null) ...[
          const SizedBox(height: 4),
          Text('Family: $family', style: textTheme.bodySmall),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side-by-side on wide screens, stacked on phones.
          if (constraints.maxWidth >= 480) {
            return Row(
              children: [
                PlantThumbnail(url: imageUrl, size: 140),
                const SizedBox(width: 20),
                Expanded(child: info),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlantThumbnail(
                url: imageUrl,
                size: constraints.maxWidth,
                height: 200,
              ),
              const SizedBox(height: 16),
              info,
            ],
          );
        },
      ),
    );
  }
}

class _CareDetails extends StatelessWidget {
  const _CareDetails({required this.details});

  final PlantDetails details;

  String? _watering() {
    final parts = [
      if (details.watering != null) details.watering!,
      if (details.wateringBenchmark != null) details.wateringBenchmark!.toLowerCase(),
    ];
    final summary = parts.isEmpty ? null : parts.join(' - ');
    final guide = details.careGuide['watering'];
    if (summary == null) return guide;
    return guide == null ? summary : '$summary\n\n$guide';
  }

  String? _sunlight() {
    final summary = details.sunlight.isEmpty ? null : details.sunlight.join(', ');
    final guide = details.careGuide['sunlight'];
    if (summary == null) return guide;
    return guide == null ? summary : '$summary\n\n$guide';
  }

  String? _toxicity() {
    final pets = details.poisonousToPets;
    final humans = details.poisonousToHumans;
    if (pets == null && humans == null) return null;
    return [
      if (pets != null) pets ? 'Toxic to pets' : 'Not known to be toxic to pets',
      if (humans != null)
        humans ? 'Toxic to humans' : 'Not known to be toxic to humans',
    ].join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final facts = <(IconData, String, String?)>[
      (Icons.water_drop_outlined, 'Water', _watering()),
      (Icons.wb_sunny_outlined, 'Light', _sunlight()),
      (Icons.grass, 'Soil', details.soil.isEmpty ? null : details.soil.join(', ')),
      (Icons.content_cut, 'Pruning', details.careGuide['pruning']),
      (Icons.thermostat_outlined, 'Hardiness', details.hardiness),
      (Icons.pets_outlined, 'Pet safety', _toxicity()),
    ].where((fact) => fact.$3 != null).toList();

    final tags = [
      if (details.indoor == true) 'Indoor',
      if (details.careLevel != null) 'Care: ${details.careLevel}',
      if (details.maintenance != null) 'Maintenance: ${details.maintenance}',
      if (details.growthRate != null) 'Growth: ${details.growthRate}',
      if (details.cycle != null) details.cycle!,
      if (details.type != null) details.type!,
      if (details.droughtTolerant == true) 'Drought tolerant',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in tags) Chip(label: Text(tag))],
          ),
          const SizedBox(height: 20),
        ],
        if (details.description != null) ...[
          Text('About', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(details.description!),
          const SizedBox(height: 24),
        ],
        Text('Care guide', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        if (facts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              details.isLimited
                  ? 'Care details for this plant are not included in our '
                      'current Perenual plan. You can still add it to My Plants.'
                  : 'Detailed care information is not available for this plant.',
            ),
          )
        else
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            PlantCareFact(
              icon: facts[i].$1,
              title: facts[i].$2,
              description: facts[i].$3!,
            ),
          ],
        const SizedBox(height: 16),
        Text(
          'Plant data from Perenual',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// "Add to My Plants" / "In My Plants" toggle for the details page.
class _MyPlantButton extends StatefulWidget {
  const _MyPlantButton({required this.details});

  final PlantDetails details;

  @override
  State<_MyPlantButton> createState() => _MyPlantButtonState();
}

class _MyPlantButtonState extends State<_MyPlantButton> {
  final String? _userId = currentUserId();
  late final Stream<bool>? _isSaved = _userId == null
      ? null
      : DatabaseService().isInMyPlants(
          userId: _userId,
          perenualId: widget.details.id,
        );
  bool _isBusy = false;

  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _add() async {
    final input = await showDialog<({String nickname, String location})>(
      context: context,
      builder: (context) => _AddPlantDialog(plantName: widget.details.commonName),
    );
    if (input == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await DatabaseService().addMyPlant(
        userId: _userId!,
        plant: MyPlant.fromDetails(
          widget.details,
          nickname: input.nickname,
          location: input.location,
        ),
      );
      if (!mounted) return;
      _showMessage(
        'Added to My Plants',
        action: SnackBarAction(
          label: 'View',
          onPressed: () => HomeTabs.goTo(context, HomeTabs.myPlants),
        ),
      );
    } catch (e) {
      debugPrint('My Plants error: $e');
      if (mounted) _showMessage('Could not add plant. Try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _isBusy = true);
    try {
      await DatabaseService().removeMyPlant(
        userId: _userId!,
        perenualId: widget.details.id,
      );
      if (mounted) _showMessage('Removed from My Plants');
    } catch (e) {
      debugPrint('My Plants error: $e');
      if (mounted) _showMessage('Could not remove plant. Try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaved == null) {
      return const Text('Sign in to add plants to My Plants.');
    }

    return StreamBuilder<bool>(
      stream: _isSaved,
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;
        final isLoading = _isBusy || !snapshot.hasData;

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (isSaved) ...[
              OutlinedButton.icon(
                onPressed: isLoading ? null : _remove,
                icon: const Icon(Icons.check),
                label: const Text('In My Plants - Remove'),
              ),
              TextButton(
                onPressed: () => HomeTabs.goTo(context, HomeTabs.myPlants),
                child: const Text('View My Plants'),
              ),
            ] else
              FilledButton.icon(
                onPressed: isLoading ? null : _add,
                icon: const Icon(Icons.add),
                label: const Text('Add to My Plants'),
              ),
          ],
        );
      },
    );
  }
}

class _AddPlantDialog extends StatefulWidget {
  const _AddPlantDialog({required this.plantName});

  final String plantName;

  @override
  State<_AddPlantDialog> createState() => _AddPlantDialogState();
}

class _AddPlantDialogState extends State<_AddPlantDialog> {
  final _nickname = TextEditingController();
  final _location = TextEditingController();

  @override
  void dispose() {
    _nickname.dispose();
    _location.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, (nickname: _nickname.text, location: _location.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.plantName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nickname,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nickname (optional)',
              hintText: 'e.g. Monty',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              hintText: 'e.g. Living room',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// Rounded plant image with a leaf icon fallback for missing or broken images.
class PlantThumbnail extends StatelessWidget {
  const PlantThumbnail({super.key, this.url, required this.size, this.height});

  final String? url;
  final double size;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      color: colors.primaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.local_florist, color: colors.onPrimaryContainer),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: height ?? size,
        child: url == null
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}
