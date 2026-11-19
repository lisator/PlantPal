import 'package:flutter/material.dart';

import '../models/my_plant.dart';
import '../models/perenual_models.dart';
import '../services/database_service.dart';
import '../services/perenual_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/health_history.dart';
import '../widgets/plant_care_guide.dart';
import '../widgets/plant_photo_editor.dart';
import '../widgets/watering.dart';

import 'home_screen.dart';
import 'plant_analysis_screen.dart';

// Shared PlantPal theme, preserving light and dark mode.
ThemeData _screenTheme(ThemeData base) {
  final isDark = base.brightness == Brightness.dark;
  final accent = isDark ? PlantPalColors.darkAccent : PlantPalColors.forest;

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: PlantPalColors.forest,
      brightness: base.brightness,
    ),
    scaffoldBackgroundColor: isDark
        ? PlantPalColors.darkBackground
        : PlantPalColors.lightBackground,
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF3A5444) : PlantPalColors.mint,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PlantPalColors.forest,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent),
      ),
    ),
  );
}

// Open the details page for a Perenual plant.
void openPlantDetailsPage(
  BuildContext context,
  PlantSearchResult plant, {
  bool collapseCare = false,
  bool fromMyPlants = false,
  MyPlant? savedPlant,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PlantDetailsScreen(
        plantId: plant.id,
        preview: plant,
        collapseCare: collapseCare,
        fromMyPlants: fromMyPlants,
        savedPlant: savedPlant,
      ),
    ),
  );
}

class PlantDetailsScreen extends StatefulWidget {
  const PlantDetailsScreen({
    super.key,
    required this.plantId,
    this.preview,
    this.collapseCare = false,
    this.fromMyPlants = false,
    this.savedPlant,
  });

  final int plantId;
  final PlantSearchResult? preview;
  final bool collapseCare;
  final bool fromMyPlants;
  final MyPlant? savedPlant;

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

    // Load Wikipedia information alongside Perenual.
    _wikipedia = preview != null
        ? loadWikipediaFor(
            scientificName: preview.scientificName,
            commonName: preview.commonName,
          )
        : _details.then(loadWikipediaExtras, onError: (_) => noWikipediaExtras);
  }

  Future<PlantDetails> _loadDetails() async {
    final preview = widget.preview;

    // Avoid unsupported API calls for basic-only plants.
    if (preview != null && !preview.hasFullDetails) {
      return PlantDetails.basic(preview);
    }

    return PerenualService.instance.getPlantDetails(widget.plantId);
  }

  @override
  Widget build(BuildContext context) {
    final healthHistoryTheme = Theme.of(context);
    final background = PlantPalColors.background(context);
    final textColor = PlantPalColors.text(context);
    final userId = currentUserId();

    return Theme(
      data: _screenTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: Text(
            'Plant care',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: background,
          foregroundColor: textColor,
          surfaceTintColor: Colors.transparent,
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
                    // Plant picture and basic information.
                    FutureBuilder<WikipediaExtras>(
                      future: _wikipedia,
                      builder: (context, wiki) {
                        final savedPlant = widget.savedPlant;

                        return StreamBuilder<List<MyPlant>>(
                          stream: savedPlant != null && userId != null
                              ? DatabaseService().getMyPlants(userId)
                              : null,
                          builder: (context, savedSnapshot) {
                            final plants = savedSnapshot.data;

                            final currentPlant =
                                savedPlant == null || plants == null
                                ? savedPlant
                                : plants
                                          .where((p) => p.id == savedPlant.id)
                                          .firstOrNull ??
                                      savedPlant;

                            return _PlantHeader(
                              name:
                                  currentPlant?.displayName ??
                                  details?.commonName ??
                                  preview?.commonName ??
                                  '',
                              scientificName:
                                  details?.scientificName ??
                                  preview?.scientificName ??
                                  '',
                              imageUrl:
                                  currentPlant?.imageUrl ??
                                  details?.imageUrl ??
                                  preview?.thumbnailUrl ??
                                  wiki.data?.article?.imageUrl,
                              family: details?.family,
                              onEditPhoto: currentPlant == null
                                  ? null
                                  : () =>
                                        changePlantPhoto(context, currentPlant),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Loading Perenual details.
                    if (snapshot.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    // Error while loading care details.
                    else if (snapshot.hasError)
                      _ErrorPanel(
                        message: snapshot.error is PerenualException
                            ? (snapshot.error as PerenualException).message
                            : 'Could not load care details.',
                        onRetry: () => setState(_load),
                      )
                    // Display full plant details.
                    else if (details != null) ...[
                      FutureBuilder<WikipediaExtras>(
                        future: _wikipedia,
                        builder: (context, wiki) {
                          return _MyPlantButton(
                            details: details,
                            wateringReference: wateringReference(
                              details,
                              wiki.data,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Plant care information.
                      PlantCareGuide(
                        details: details,
                        wikipedia: _wikipedia,
                        collapsible: widget.collapseCare,
                      ),

                      // Health History for saved plants.
                      if (widget.fromMyPlants && userId != null) ...[
                        const SizedBox(height: 28),
                        Theme(
                          data: healthHistoryTheme,
                          child: HealthHistory(
                            userId: userId,
                            plantId: widget.savedPlant?.id ?? '${details.id}',
                            onRunAnalysis: widget.savedPlant == null
                                ? null
                                : () async {
                                    await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (context) => Scaffold(
                                          appBar: AppBar(
                                            title: const Text(
                                              'New Health Analysis',
                                            ),
                                          ),
                                          body: UploadScreen(
                                            targetPlant: widget.savedPlant,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ],
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

// Plant picture, common name, scientific name, and family.
class _PlantHeader extends StatelessWidget {
  const _PlantHeader({
    required this.name,
    required this.scientificName,
    this.imageUrl,
    this.family,
    this.onEditPhoto,
  });

  final String name;
  final String scientificName;
  final String? imageUrl;
  final String? family;
  final VoidCallback? onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final cardColor = PlantPalColors.card(context);
    final textColor = PlantPalColors.text(context);
    final secondaryColor = PlantPalColors.secondaryText(context);
    final borderColor = PlantPalColors.border(context);

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: textTheme.headlineSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),

        if (scientificName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            scientificName,
            style: textTheme.bodyMedium?.copyWith(
              color: secondaryColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        if (family != null && family!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Family: $family',
            style: textTheme.bodySmall?.copyWith(color: secondaryColor),
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: PlantPalColors.isDark(context) ? 0.18 : 0.06,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wider screens: picture beside plant information.
          if (constraints.maxWidth >= 480) {
            return Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlantThumbnail(url: imageUrl, size: 140),
                    if (onEditPhoto != null)
                      TextButton.icon(
                        onPressed: onEditPhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Edit Photo'),
                      ),
                  ],
                ),

                const SizedBox(width: 20),

                Expanded(child: info),
              ],
            );
          }

          // Smaller phones: picture above plant information.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlantThumbnail(
                url: imageUrl,
                size: constraints.maxWidth,
                height: 200,
              ),

              if (onEditPhoto != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEditPhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Edit Photo'),
                  ),
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

// Add or remove a plant from My Plants.
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

  // Ask for nickname, location, and watering schedule.
  Future<void> _add() async {
    final input =
        await showDialog<
          ({String nickname, String location, int? waterEveryDays})
        >(
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

    setState(() {
      _isBusy = true;
    });

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

      if (mounted) {
        _showMessage('Could not add plant. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  // Remove plant from saved collection.
  Future<void> _remove() async {
    setState(() {
      _isBusy = true;
    });

    try {
      await DatabaseService().removeMyPlant(
        userId: _userId!,
        plantId: '${widget.details.id}',
      );

      if (mounted) {
        _showMessage('Removed from My Plants');
      }
    } catch (e) {
      debugPrint('My Plants error: $e');

      if (mounted) {
        _showMessage('Could not remove plant. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaved == null) {
      return Text(
        'Sign in to add plants to My Plants.',
        style: TextStyle(color: PlantPalColors.text(context)),
      );
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

// Dialog for adding a plant to My Plants.
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

    final cardColor = PlantPalColors.card(context);
    final textColor = PlantPalColors.text(context);
    final secondary = PlantPalColors.secondaryText(context);
    final accent = PlantPalColors.accent(context);
    final softColor = PlantPalColors.softBackground(context);

    return AlertDialog(
      backgroundColor: cardColor,
      title: Text(
        'Add ${widget.plantName}',
        style: TextStyle(color: textColor),
      ),
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
                style: TextStyle(color: textColor),
                cursorColor: accent,
                decoration: InputDecoration(
                  labelText: 'Nickname (optional)',
                  hintText: 'e.g. Monty',
                  filled: true,
                  fillColor: softColor,
                  labelStyle: TextStyle(color: secondary),
                  hintStyle: TextStyle(color: secondary),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _location,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: textColor),
                cursorColor: accent,
                decoration: InputDecoration(
                  labelText: 'Location (optional)',
                  hintText: 'e.g. Living room',
                  filled: true,
                  fillColor: softColor,
                  labelStyle: TextStyle(color: secondary),
                  hintStyle: TextStyle(color: secondary),
                ),
              ),

              const SizedBox(height: 12),

              WaterEveryDaysField(
                controller: _waterEveryDays,
                onSubmitted: _submit,
                helperText: widget.suggestedWaterEveryDays != null
                    ? 'Suggested from Perenual. '
                          'Adjust it for your home.'
                    : 'Perenual has no schedule for '
                          'this plant. Leave blank to '
                          'set one later from My Plants.',
              ),

              // Show Wikipedia watering advice if Perenual
              // does not provide a suggested schedule.
              if (reference != null &&
                  widget.suggestedWaterEveryDays == null) ...[
                const SizedBox(height: 12),
                Text(
                  '${reference.source} says:',
                  style: textTheme.labelSmall?.copyWith(color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  reference.text,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontStyle: FontStyle.italic,
                  ),
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
          style: FilledButton.styleFrom(
            backgroundColor: PlantPalColors.forest,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Error panel for a failed Perenual request.
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
            color: PlantPalColors.accent(context),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: PlantPalColors.text(context)),
          ),
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
