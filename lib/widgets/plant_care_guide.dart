import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/perenual_models.dart';
import '../services/wikipedia_service.dart';
import 'reusable_widgets.dart';

/// What Wikipedia adds to a plant's Perenual data: the article (for a
/// description, image and link) and care excerpts for the topics Perenual
/// has nothing for.
typedef WikipediaExtras = ({
  WikipediaSummary? article,
  Map<CareTopic, CareExcerpt> care,
});

const WikipediaExtras noWikipediaExtras = (article: null, care: {});

/// Perenual's text for a care topic, or null when Perenual has nothing.
String? perenualCare(PlantDetails details, CareTopic topic) {
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

/// Perenual comes first; Wikipedia is only looked up for what Perenual is
/// missing (a description, an image, or Water/Light/Soil). Never throws.
Future<WikipediaExtras> loadWikipediaExtras(PlantDetails details) async {
  final missingCare = CareTopic.values
      .where((topic) => perenualCare(details, topic) == null)
      .toList();
  if (details.description != null &&
      details.imageUrl != null &&
      missingCare.isEmpty) {
    return noWikipediaExtras;
  }

  return loadWikipediaFor(
    scientificName: details.scientificName,
    commonName: details.commonName,
    withCare: missingCare.isNotEmpty,
  );
}

/// Looks up a plant's Wikipedia article and care excerpts by name. Screens
/// that already know the plant's name call this at the same time as
/// Perenual, instead of waiting for Perenual first; [PlantCareGuide] still
/// shows Perenual's info first for each topic. Never throws.
Future<WikipediaExtras> loadWikipediaFor({
  required String scientificName,
  required String commonName,
  bool withCare = true,
}) async {
  final article = await WikipediaService.instance.findPlant(
    scientificName: scientificName,
    commonName: commonName,
  );
  if (article == null || !withCare) {
    return (article: article, care: const <CareTopic, CareExcerpt>{});
  }
  final care = await WikipediaService.instance.plantCare(
    article,
    scientificName: scientificName,
  );
  return (article: article, care: care);
}

/// Watering guidance shown while choosing a schedule: Perenual's text, else
/// the Wikipedia excerpt. It's only a reference; the user picks the number.
({String source, String text})? wateringReference(
  PlantDetails details,
  WikipediaExtras? extras,
) {
  final perenual = perenualCare(details, CareTopic.water);
  if (perenual != null) return (source: 'Perenual', text: perenual);
  final wiki = extras?.care[CareTopic.water];
  return wiki == null ? null : (source: 'Wikipedia', text: wiki.text);
}

/// The "About" and "Care guide" sections for a plant, shared by the plant
/// details page and the page for plants saved from plant analysis.
///
/// Perenual's data shows right away. Topics Perenual doesn't cover show a
/// small spinner until [wikipedia] finishes, so a slow Wikipedia/Gemini
/// lookup never holds up the rest of the page.
class PlantCareGuide extends StatelessWidget {
  const PlantCareGuide({
    super.key,
    required this.details,
    required this.wikipedia,
    this.note,
    this.collapsible = false,
  });

  final PlantDetails details;
  final Future<WikipediaExtras> wikipedia;

  // true on my plants pages: about and care guide start collapsed
  final bool collapsible;

  /// Shown under "Care guide", e.g. where the care info comes from. Defaults
  /// to a note for plants outside the free Perenual plan.
  final String? note;

  String? _toxicity() {
    final pets = details.poisonousToPets;
    final humans = details.poisonousToHumans;
    if (pets == null && humans == null) return null;
    return [
      if (pets != null)
        pets ? 'Toxic to pets' : 'Not known to be toxic to pets',
      if (humans != null)
        humans ? 'Toxic to humans' : 'Not known to be toxic to humans',
    ].join('. ');
  }

  /// Perenual's field when it has one, then a quoted Wikipedia excerpt, then
  /// a "not available" note. Wikipedia text is never turned into a value.
  Widget _careRow(
    CareTopic topic,
    IconData icon,
    String title,
    AsyncSnapshot<WikipediaExtras> wiki,
  ) {
    final perenual = perenualCare(details, topic);
    if (perenual != null) {
      return PlantCareFact(icon: icon, title: title, description: perenual);
    }
    if (wiki.connectionState != ConnectionState.done) {
      return _LoadingCareRow(icon: icon, title: title);
    }
    final excerpt = wiki.data?.care[topic];
    if (excerpt != null) {
      return WikipediaCareFact(icon: icon, title: title, excerpt: excerpt);
    }
    return PlantCareFact(
      icon: icon,
      title: title,
      description: 'Details not available yet.',
    );
  }

  /// Wikipedia sometimes gives two topics the same sentence, e.g. one
  /// sentence about both light and water. That excerpt is shown once, titled
  /// with every topic it covers ("Water & Light"), instead of repeating it.
  /// Perenual rows are never combined.
  static List<Widget> _combineDuplicateExcerpts(List<Widget> careRows) {
    // Each Wikipedia excerpt group sits where its first topic was, with that
    // topic's icon. Other rows are kept as they are.
    final groups =
        <({IconData icon, List<String> titles, CareExcerpt excerpt})>[];
    final combined = <Object>[];
    for (final row in careRows) {
      if (row is! WikipediaCareFact) {
        combined.add(row);
        continue;
      }
      final index = groups.indexWhere(
        (group) => _sameExcerpt(group.excerpt.text, row.excerpt.text),
      );
      if (index == -1) {
        groups.add((icon: row.icon, titles: [row.title], excerpt: row.excerpt));
        combined.add(groups.length - 1);
        continue;
      }
      final group = groups[index];
      groups[index] = (
        icon: group.icon,
        titles: [...group.titles, row.title],
        // keep the longer excerpt when one contains the other
        excerpt: row.excerpt.text.length > group.excerpt.text.length
            ? row.excerpt
            : group.excerpt,
      );
    }

    String joinTitles(List<String> titles) => titles.length == 1
        ? titles.single
        : '${titles.sublist(0, titles.length - 1).join(', ')} & ${titles.last}';

    return [
      for (final item in combined)
        if (item is int)
          WikipediaCareFact(
            icon: groups[item].icon,
            title: joinTitles(groups[item].titles),
            excerpt: groups[item].excerpt,
          )
        else
          item as Widget,
    ];
  }

  /// True when two excerpts are the same text, or one contains the other,
  /// ignoring case, spacing and quote styles.
  static bool _sameExcerpt(String a, String b) {
    String normalize(String text) => text
        .toLowerCase()
        .replaceAll(RegExp('[‘’]'), "'")
        .replaceAll(RegExp('[“”]'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final first = normalize(a);
    final second = normalize(b);
    return first.contains(second) || second.contains(first);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final otherFacts = <(IconData, String, String?)>[
      (Icons.content_cut, 'Pruning', details.careGuide['pruning']),
      (Icons.thermostat_outlined, 'Hardiness', details.hardiness),
      (Icons.pets_outlined, 'Pet safety', _toxicity()),
    ].where((fact) => fact.$3 != null);

    final tags = [
      if (details.indoor == true) 'Indoor',
      if (details.careLevel != null) 'Care: ${details.careLevel}',
      if (details.maintenance != null) 'Maintenance: ${details.maintenance}',
      if (details.growthRate != null) 'Growth: ${details.growthRate}',
      if (details.cycle != null) details.cycle!,
      if (details.type != null) details.type!,
      if (details.droughtTolerant == true) 'Drought tolerant',
    ];

    return FutureBuilder<WikipediaExtras>(
      future: wikipedia,
      builder: (context, wiki) {
        final article = wiki.data?.article;
        final description = details.description ?? article?.extract;
        final rows = [
          ..._combineDuplicateExcerpts([
            _careRow(CareTopic.water, Icons.water_drop_outlined, 'Water', wiki),
            _careRow(CareTopic.light, Icons.wb_sunny_outlined, 'Light', wiki),
            _careRow(CareTopic.soil, Icons.grass, 'Soil', wiki),
          ]),
          for (final fact in otherFacts)
            PlantCareFact(icon: fact.$1, title: fact.$2, description: fact.$3!),
        ];

        // care guide body: optional source note, then the care rows
        final careContent = <Widget>[
          if (note != null || details.isLimited)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                note ??
                    'Care details for this plant are not included in our '
                        'current Perenual plan, so Wikipedia is used instead.',
                style: textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
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
            if (collapsible) ...[
              // tap a heading to open/close it
              if (description != null)
                _CollapsibleSection(
                  title: 'About',
                  children: [Text(description)],
                ),
              _CollapsibleSection(
                title: 'Care guide',
                subtitle: 'Water, light, soil and more',
                children: careContent,
              ),
            ] else ...[
              if (description != null) ...[
                Text('About', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 24),
              ],
              Text('Care guide', style: textTheme.titleLarge),
              ...careContent,
            ],
            const SizedBox(height: 16),
            Text(
              article == null
                  ? 'Plant data from Perenual'
                  : 'Plant data from Perenual. Additional text and images from '
                        'Wikipedia (CC BY-SA): ${article.pageUrl}',
              style: textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

/// Section heading that expands to show [children]. Starts collapsed.
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      subtitle: subtitle == null ? null : Text(subtitle!),
      // no extra padding or borders, so it lines up with the rest of the page
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      shape: const Border(),
      collapsedShape: const Border(),
      children: children,
    );
  }
}

/// A care row whose text is still loading.
class _LoadingCareRow extends StatelessWidget {
  const _LoadingCareRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 12),
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }
}

/// A care section quoted from Wikipedia: the article's own words, labeled and
/// linked, since care values can't be reliably pulled out of prose.
class WikipediaCareFact extends StatelessWidget {
  const WikipediaCareFact({
    super.key,
    required this.icon,
    required this.title,
    required this.excerpt,
  });

  final IconData icon;
  final String title;
  final CareExcerpt excerpt;

  WikipediaSummary get article => excerpt.article;

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
                  excerpt.sourceLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
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
                    excerpt.text,
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
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

class _PlantThumbnailWithFallbackState
    extends State<PlantThumbnailWithFallback> {
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
    if (_wiki == null)
      return PlantThumbnail(url: widget.url, size: widget.size);
    return FutureBuilder<WikipediaSummary?>(
      future: _wiki,
      builder: (context, snapshot) =>
          PlantThumbnail(url: snapshot.data?.thumbnailUrl, size: widget.size),
    );
  }
}
