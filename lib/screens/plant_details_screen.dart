import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../models/perenual_models.dart';
import '../services/database_service.dart';
import '../services/perenual_service.dart';
import '../widgets/plant_care_guide.dart';
import '../widgets/watering.dart';
import 'home_screen.dart';
import '../widgets/health_history.dart';

// PlantPal colors, same palette as the community screen.
const Color _forest = Color(0xFF315F43);
const Color _pale = Color(0xFFF6F8F2);
const Color _mint = Color(0xFFE0EBDD);
const Color _ink = Color(0xFF24372A);

// Forest buttons, icons, spinners, and care guide accents instead of
// Flutter's default purple. Only wraps this page, so the analysis pages that
// also show the care guide keep their own look.
ThemeData _screenTheme(ThemeData base) => base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _forest,
        primary: _forest,
        outlineVariant: _mint,
      ),
      scaffoldBackgroundColor: _pale,
      dividerTheme: const DividerThemeData(color: _mint),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _forest),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _forest,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _forest,
          side: const BorderSide(color: _forest),
        ),
      ),
    );

/// Opens the care page for a Perenual plant (from search or My Plants).
// collapseCare: true when opened from my plants (sections start collapsed)
void openPlantDetailsPage(
  BuildContext context,
  PlantSearchResult plant, {
  bool collapseCare = false,
  bool fromMyPlants = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PlantDetailsScreen(
        plantId: plant.id,
        preview: plant,
        collapseCare: collapseCare,
        fromMyPlants: fromMyPlants,
      ),
    ),
  );
}

/// Care details for a Perenual species. [preview] (from the search results)
/// is shown in the header while the full details load.
///
/// Perenual is loaded first and shown as soon as it arrives. Wikipedia
/// (which can take several seconds when Gemini is involved) then fills in
/// whatever Perenual is missing, without holding up the rest of the page.
class PlantDetailsScreen extends StatefulWidget {
  const PlantDetailsScreen({
    super.key,
    required this.plantId,
    this.preview,
    this.collapseCare = false,
    this.fromMyPlants = false,
  });

  final int plantId;
  final PlantSearchResult? preview;

  // collapse about and care guide (my plants and search), or show everything
  final bool collapseCare;

  // true when opened from my plants: shows the plant's health history
  // (search also collapses care info, but isn't a saved plant)
  final bool fromMyPlants;

  @override
  State<PlantDetailsScreen> createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  late Future<PlantDetails> _details;
  late Future<WikipediaExtras> _wikipedia;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _details = _loadDetails();
    final preview = widget.preview;
    // When the plant's name is already known (from the search results),
    // Wikipedia is looked up at the same time as Perenual, not after it.
    _wikipedia = preview != null
        ? loadWikipediaFor(
            scientificName: preview.scientificName,
            commonName: preview.commonName,
          )
        : _details.then(loadWikipediaExtras,
            onError: (_) => noWikipediaExtras);
  }

  Future<PlantDetails> _loadDetails() async {
    final preview = widget.preview;
    // Skip the API call for species the free plan can't return; it would
    // just be refused and still count against the daily limit.
    if (preview != null && !preview.hasFullDetails) {
      return PlantDetails.basic(preview);
    }
    return PerenualService.instance.getPlantDetails(widget.plantId);
  }

  // Header shows right away; below it is a spinner, an error, or the care info.
  @override
  Widget build(BuildContext context) {
    // health history keeps the app's default look, not this page's colors
    final healthHistoryTheme = Theme.of(context);

    return Theme(
      data: _screenTheme(Theme.of(context)),
      child: Scaffold(
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
                  FutureBuilder<WikipediaExtras>(
                    future: _wikipedia,
                    // Uses Wikipedia's photo if Perenual has none.
                    builder: (context, wiki) => _PlantHeader(
                      name: details?.commonName ?? preview?.commonName ?? '',
                      scientificName: details?.scientificName ??
                          preview?.scientificName ??
                          '',
                      imageUrl: details?.imageUrl ??
                          preview?.thumbnailUrl ??
                          wiki.data?.article?.imageUrl,
                      family: details?.family,
                    ),
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
                    FutureBuilder<WikipediaExtras>(
                      future: _wikipedia,
                      builder: (context, wiki) => _MyPlantButton(
                        details: details,
                        wateringReference:
                            wateringReference(details, wiki.data),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PlantCareGuide(
                      details: details,
                      wikipedia: _wikipedia,
                      collapsible: widget.collapseCare,
                    ),

                    if (widget.fromMyPlants && currentUserId() != null) ...[
                      const SizedBox(height: 28),

                      Theme(
                        data: healthHistoryTheme,
                        child: HealthHistory(
                          userId: currentUserId()!,
                          plantId: '${details.id}',
                        ),
                      ),
                    ]
                  ],
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Photo, name, scientific name and family at the top of the page.
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

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: textTheme.headlineSmall?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
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

  /// Asks for nickname, location and watering schedule, then saves to Firestore.
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

  /// Removes this plant from My Plants.
  Future<void> _remove() async {
    setState(() => _isBusy = true);
    try {
      await DatabaseService().removeMyPlant(
        userId: _userId!,
        plantId:'${widget.details.id}',
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

    // Follows Firestore, so the button updates if the plant is added elsewhere.
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

/// Form shown before saving: nickname, location, and days between watering.
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

  // Returns the form values to _add().
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
              // No Perenual schedule: show Wikipedia's watering advice instead.
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

/// Error message with a "Try again" button.
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
