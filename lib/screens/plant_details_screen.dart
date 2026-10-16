import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/my_plant.dart';
import '../models/perenual_models.dart';
import '../services/database_service.dart';
import '../services/perenual_service.dart';
import '../services/wikipedia_service.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/watering.dart';
import 'home_screen.dart';

void openPlantDetailsPage(BuildContext context, PlantSearchResult plant) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PlantDetailsScreen(plantId: plant.id, preview: plant),
    ),
  );
}

/// Perenual details, plus what Wikipedia filled in where Perenual had nothing.
typedef _PlantPage = ({
  PlantDetails details,
  WikipediaSummary? wiki,
  Map<CareTopic, String> careExcerpts,
});

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
  late Future<_PlantPage> _page;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _page = _loadPage();
  }

  Future<_PlantPage> _loadPage() async {
    final preview = widget.preview;
    // Skip the API call for species the free plan can't return; it would
    // just be refused and still count against the daily limit.
    final details = preview != null && !preview.hasFullDetails
        ? PlantDetails.basic(preview)
        : await PerenualService.instance.getPlantDetails(widget.plantId);
    return _addWikipedia(details);
  }

  /// Fills in a missing description or image from Wikipedia, plus care
  /// excerpts for any of Water/Light/Soil that Perenual has nothing for.
  Future<_PlantPage> _addWikipedia(PlantDetails details) async {
    final missingCare = CareTopic.values
        .where((topic) => _perenualCare(details, topic) == null)
        .toList();
    if (details.description != null &&
        details.imageUrl != null &&
        missingCare.isEmpty) {
      return (details: details, wiki: null, careExcerpts: const <CareTopic, String>{});
    }

    final wiki = await WikipediaService.instance.findPlant(
      scientificName: details.scientificName,
      commonName: details.commonName,
    );
    if (wiki == null) {
      return (details: details, wiki: null, careExcerpts: const <CareTopic, String>{});
    }
    final careExcerpts = missingCare.isEmpty
        ? const <CareTopic, String>{}
        : await WikipediaService.instance.careExcerpts(wiki);
    return (
      details: details.copyWith(
        description: details.description ?? wiki.extract,
        imageUrl: details.imageUrl ?? wiki.imageUrl,
        wikipediaUrl: wiki.pageUrl,
      ),
      wiki: wiki,
      careExcerpts: careExcerpts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plant care')),
      body: FutureBuilder<_PlantPage>(
        future: _page,
        builder: (context, snapshot) {
          final page = snapshot.data;
          final details = page?.details;
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
                  else if (page != null) ...[
                    _MyPlantButton(
                      details: page.details,
                      wateringReference: _wateringReference(page),
                    ),
                    const SizedBox(height: 20),
                    _CareDetails(
                      details: page.details,
                      wiki: page.wiki,
                      careExcerpts: page.careExcerpts,
                    ),
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

/// Perenual's text for a care topic, or null when Perenual has nothing.
String? _perenualCare(PlantDetails details, CareTopic topic) {
  String? withGuide(String? summary, String? guide) {
    if (summary == null) return guide;
    return guide == null ? summary : '$summary\n\n$guide';
  }

  switch (topic) {
    case CareTopic.water:
      final parts = [
        if (details.watering != null) details.watering!,
        if (details.wateringBenchmark != null)
          details.wateringBenchmark!.toLowerCase(),
      ];
      return withGuide(
        parts.isEmpty ? null : parts.join(' - '),
        details.careGuide['watering'],
      );
    case CareTopic.light:
      return withGuide(
        details.sunlight.isEmpty ? null : details.sunlight.join(', '),
        details.careGuide['sunlight'],
      );
    case CareTopic.soil:
      return details.soil.isEmpty ? null : details.soil.join(', ');
  }
}

/// Watering guidance shown while choosing a schedule: Perenual's text, else
/// the Wikipedia excerpt. It's only a reference; the user picks the number.
({String source, String text})? _wateringReference(_PlantPage page) {
  final perenual = _perenualCare(page.details, CareTopic.water);
  if (perenual != null) return (source: 'Perenual', text: perenual);
  final wiki = page.careExcerpts[CareTopic.water];
  return wiki == null ? null : (source: 'Wikipedia', text: wiki);
}

class _CareDetails extends StatelessWidget {
  const _CareDetails({
    required this.details,
    required this.wiki,
    required this.careExcerpts,
  });

  final PlantDetails details;
  final WikipediaSummary? wiki;
  final Map<CareTopic, String> careExcerpts;

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

  /// Perenual's field when it has one, then a quoted Wikipedia excerpt, then
  /// a "not available" note. Wikipedia text is never turned into a value.
  Widget _careSection(CareTopic topic, IconData icon, String title) {
    final perenual = _perenualCare(details, topic);
    if (perenual != null) {
      return PlantCareFact(icon: icon, title: title, description: perenual);
    }
    final excerpt = careExcerpts[topic];
    if (excerpt != null && wiki != null) {
      return _WikipediaCareFact(
        icon: icon,
        title: title,
        excerpt: excerpt,
        article: wiki!,
      );
    }
    return PlantCareFact(
      icon: icon,
      title: title,
      description: 'Details not available yet.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final otherFacts = <(IconData, String, String?)>[
      (Icons.content_cut, 'Pruning', details.careGuide['pruning']),
      (Icons.thermostat_outlined, 'Hardiness', details.hardiness),
      (Icons.pets_outlined, 'Pet safety', _toxicity()),
    ].where((fact) => fact.$3 != null);

    final rows = [
      _careSection(CareTopic.water, Icons.water_drop_outlined, 'Water'),
      _careSection(CareTopic.light, Icons.wb_sunny_outlined, 'Light'),
      _careSection(CareTopic.soil, Icons.grass, 'Soil'),
      for (final fact in otherFacts)
        PlantCareFact(icon: fact.$1, title: fact.$2, description: fact.$3!),
    ];

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
        if (details.isLimited)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Care details for this plant are not included in our current '
              'Perenual plan. You can still add it to My Plants.',
              style: textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          rows[i],
        ],
        const SizedBox(height: 16),
        Text(
          details.wikipediaUrl == null
              ? 'Plant data from Perenual'
              : 'Plant data from Perenual. Additional text and images from '
                  'Wikipedia (CC BY-SA): ${details.wikipediaUrl}',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A care section quoted from Wikipedia: the article's own words, labeled and
/// linked, since care values can't be reliably pulled out of prose.
class _WikipediaCareFact extends StatelessWidget {
  const _WikipediaCareFact({
    required this.icon,
    required this.title,
    required this.excerpt,
    required this.article,
  });

  final IconData icon;
  final String title;
  final String excerpt;
  final WikipediaSummary article;

  Future<void> _openArticle(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(article.pageUrl),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Wikipedia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Excerpt from Wikipedia',
                  style: textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: colors.outlineVariant, width: 3),
                    ),
                  ),
                  child: Text(
                    excerpt,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openArticle(context),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Read more on Wikipedia'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PlantThumbnail(url: article.thumbnailUrl, size: 56),
        ],
      ),
    );
  }
}

/// "Add to My Plants" / "In My Plants" toggle for the details page.
class _MyPlantButton extends StatefulWidget {
  const _MyPlantButton({required this.details, this.wateringReference});

  final PlantDetails details;
  final ({String source, String text})? wateringReference;

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
    final input = await showDialog<
        ({String nickname, String location, int? waterEveryDays})>(
      context: context,
      builder: (context) => _AddPlantDialog(
        plantName: widget.details.commonName,
        suggestedWaterEveryDays: suggestedWaterEveryDays(
          benchmark: widget.details.wateringBenchmark,
          watering: widget.details.watering,
        ),
        wateringReference: widget.wateringReference,
      ),
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
          waterEveryDays: input.waterEveryDays,
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
  const _AddPlantDialog({
    required this.plantName,
    this.suggestedWaterEveryDays,
    this.wateringReference,
  });

  final String plantName;
  final int? suggestedWaterEveryDays;
  final ({String source, String text})? wateringReference;

  @override
  State<_AddPlantDialog> createState() => _AddPlantDialogState();
}

class _AddPlantDialogState extends State<_AddPlantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _location = TextEditingController();
  late final _waterEveryDays = TextEditingController(
    text: '${widget.suggestedWaterEveryDays ?? ''}',
  );

  @override
  void dispose() {
    _nickname.dispose();
    _location.dispose();
    _waterEveryDays.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      nickname: _nickname.text,
      location: _location.text,
      waterEveryDays: parseWaterEveryDays(_waterEveryDays.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reference = widget.wateringReference;

    return AlertDialog(
      title: Text('Add ${widget.plantName}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  hintText: 'e.g. Living room',
                ),
              ),
              const SizedBox(height: 12),
              WaterEveryDaysField(
                controller: _waterEveryDays,
                onSubmitted: _submit,
                helperText: widget.suggestedWaterEveryDays != null
                    ? 'Suggested from Perenual. Adjust it for your home.'
                    : 'Perenual has no schedule for this plant. Leave blank '
                        'to set one later from My Plants.',
              ),
              if (reference != null &&
                  widget.suggestedWaterEveryDays == null) ...[
                const SizedBox(height: 12),
                Text('${reference.source} says:', style: textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(
                  reference.text,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
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

/// [PlantThumbnail] that looks up a Wikipedia image when [url] is missing.
class PlantThumbnailWithFallback extends StatefulWidget {
  const PlantThumbnailWithFallback({
    super.key,
    this.url,
    required this.scientificName,
    required this.commonName,
    required this.size,
  });

  final String? url;
  final String scientificName;
  final String commonName;
  final double size;

  @override
  State<PlantThumbnailWithFallback> createState() =>
      _PlantThumbnailWithFallbackState();
}

class _PlantThumbnailWithFallbackState extends State<PlantThumbnailWithFallback> {
  Future<WikipediaSummary?>? _wiki;

  @override
  void initState() {
    super.initState();
    if (widget.url == null) {
      _wiki = WikipediaService.instance.findPlant(
        scientificName: widget.scientificName,
        commonName: widget.commonName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_wiki == null) return PlantThumbnail(url: widget.url, size: widget.size);
    return FutureBuilder<WikipediaSummary?>(
      future: _wiki,
      builder: (context, snapshot) => PlantThumbnail(
        url: snapshot.data?.thumbnailUrl,
        size: widget.size,
      ),
    );
  }
}
