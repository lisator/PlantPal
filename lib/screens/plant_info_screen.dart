import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/perenual_models.dart';
import '../services/perenual_service.dart';
import 'plant_details_screen.dart';
import '../widgets/plant_care_guide.dart';

// PlantPal colors, same palette as the community screen.
const Color _forest = Color(0xFF315F43);
const Color _sage = Color(0xFF83AD8A);
const Color _pale = Color(0xFFF6F8F2);
const Color _mint = Color(0xFFE0EBDD);
const Color _ink = Color(0xFF24372A);

// Rounded card with a mint border and soft shadow, like the community posts.
const RoundedRectangleBorder _cardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(20)),
  side: BorderSide(color: _mint),
);
final Color _cardShadow = _forest.withValues(alpha: 0.12);

// Forest buttons, spinners, and text fields instead of Flutter's default
// purple, like the community screen's own theme.
ThemeData _screenTheme(ThemeData base) => base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _forest,
        primary: _forest,
      ),
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
        style: OutlinedButton.styleFrom(foregroundColor: _forest),
      ),
    );

/// Plant Search tab: searches Perenual and lists matching plants.
class PlantSearch extends StatefulWidget {
  const PlantSearch({super.key});

  @override
  State<PlantSearch> createState() => _PlantSearchState();
}

class _PlantSearchState extends State<PlantSearch> {
  // Quick-search chips shown before the first search.
  static const List<String> _suggestions = [
    'Monstera',
    'Pothos',
    'Snake plant',
    'Peace lily',
    'Fern',
    'Aloe',
  ];

  // Recent searches are saved on this device, newest first.
  static const String _recentSearchesKey = 'recentSearches';
  static const int _maxRecentSearches = 6;

  final PerenualService _api = PerenualService.instance;
  final TextEditingController _controller = TextEditingController();

  // Current search and its results (Perenual returns them in pages).
  String _activeQuery = '';
  List<PlantSearchResult> _results = [];
  int _page = 1;
  bool _hasMore = false;
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Ignores responses from searches that were replaced by a newer one.
  int _requestId = 0;

  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Searches only run on Enter / the search button, never while typing,
  // to save Perenual's 100 requests/day.
  void _onQueryChanged(String value) {
    if (value.trim().isNotEmpty) return;
    _requestId++;
    setState(() {
      _activeQuery = '';
      _results = [];
      _error = null;
      _isLoading = false;
    });
  }

  // Called by Enter, the search icon, and the suggestion chips.
  void _searchNow(String value) {
    final query = value.trim();
    if (query.isNotEmpty) _search(query);
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_recentSearchesKey) ?? [];
      if (!mounted) return;
      setState(() => _recentSearches = saved);
    } catch (e) {
      debugPrint('Recent searches error: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
    } catch (e) {
      debugPrint('Recent searches error: $e');
    }
  }

  // Moves [query] to the front, dropping any older copy (ignoring case).
  void _addRecentSearch(String query) {
    setState(() {
      _recentSearches = [
        query,
        ..._recentSearches
            .where((s) => s.toLowerCase() != query.toLowerCase()),
      ].take(_maxRecentSearches).toList();
    });
    _saveRecentSearches();
  }

  void _removeRecentSearch(String query) {
    setState(() => _recentSearches.remove(query));
    _saveRecentSearches();
  }

  void _clearRecentSearches() {
    setState(() => _recentSearches = []);
    _saveRecentSearches();
  }

  /// Runs a new search, replacing the current results.
  Future<void> _search(String query) async {
    // Skip if this exact search is already showing.
    if (query == _activeQuery && _error == null && !_isLoading) return;

    _addRecentSearch(query);
    final requestId = ++_requestId;
    setState(() {
      _activeQuery = query;
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final page = await _api.searchPlants(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = page.results;
        _page = page.currentPage;
        _hasMore = page.hasMore;
        _total = page.total;
      });
    } on PerenualException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Adds the next page of results to the list.
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final requestId = _requestId;
    setState(() => _isLoadingMore = true);

    try {
      final page = await _api.searchPlants(_activeQuery, page: _page + 1);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = [..._results, ...page.results];
        _page = page.currentPage;
        _hasMore = page.hasMore;
      });
    } on PerenualException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Fills the search box with a chip's text and searches it.
  void _useSuggestion(String suggestion) {
    _controller.text = suggestion;
    _searchNow(suggestion);
  }

  // The X button: empties the box and goes back to the suggestions.
  void _clear() {
    _controller.clear();
    _onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _screenTheme(Theme.of(context)),
      child: ColoredBox(
      color: _pale,
      child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plant Search',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // Rebuilds as you type so the clear button shows/hides.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Search by plant name',
                        hintText: 'e.g. monstera, pothos, fern',
                        helperText: 'Press Enter to search',
                        prefixIcon: IconButton(
                          tooltip: 'Search',
                          color: _forest,
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchNow(_controller.text),
                        ),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                color: _forest,
                                icon: const Icon(Icons.clear),
                                onPressed: _clear,
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        floatingLabelStyle:
                            const TextStyle(color: _forest),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: BorderSide(color: _mint),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: BorderSide(color: _mint),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide:
                              BorderSide(color: _forest, width: 2),
                        ),
                      ),
                      onChanged: _onQueryChanged,
                      onSubmitted: _searchNow,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// Area below the search box: loading, error, suggestions, no results,
  /// or the results list.
  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _SearchMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: _error!,
        action: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _forest,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _search(_activeQuery),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    if (_activeQuery.isEmpty) {
      final message = _SearchMessage(
        icon: Icons.local_florist_outlined,
        title: 'Find a plant',
        message: 'Search thousands of species to see watering, sunlight, '
            'and soil needs.',
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                backgroundColor: _mint,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: const TextStyle(color: _forest),
                label: Text(suggestion),
                onPressed: () => _useSuggestion(suggestion),
              ),
          ],
        ),
      );
      if (_recentSearches.isEmpty) return message;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recently searched',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final recent in _recentSearches)
                InputChip(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _mint),
                  shape: const StadiumBorder(),
                  labelStyle: const TextStyle(color: _forest),
                  avatar: const Icon(Icons.history, size: 18, color: _forest),
                  label: Text(recent),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  deleteIconColor: _forest,
                  deleteButtonTooltipMessage: 'Remove from recent',
                  onPressed: () => _useSuggestion(recent),
                  onDeleted: () => _removeRecentSearch(recent),
                ),
            ],
          ),
          message,
        ],
      );
    }

    if (_results.isEmpty) {
      return _SearchMessage(
        icon: Icons.search_off,
        title: 'No plants found',
        message: 'No results for "$_activeQuery". '
            'Try a common name like "fern" or a scientific name.',
      );
    }

    // Rows: result count, then the plants, then "Load more".
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _results.length + 2,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            '$_total result${_total == 1 ? '' : 's'} for "$_activeQuery"',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        if (index == _results.length + 1) {
          if (!_hasMore) return const SizedBox.shrink();
          return Center(
            child: _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _forest,
                      side: const BorderSide(color: _sage),
                    ),
                    onPressed: _loadMore,
                    child: const Text('Load more'),
                  ),
          );
        }
        final plant = _results[index - 1];
        return PlantSearchResultCard(
          plant: plant,
          // care info starts collapsed, same as from My Plants
          onTap: () => openPlantDetailsPage(
            context,
            plant,
            collapseCare: true,
          ),
        );
      },
    );
  }
}

/// One search result: photo, names, and a "Basic info only" label for
/// plants outside Perenual's free plan.
class PlantSearchResultCard extends StatelessWidget {
  const PlantSearchResultCard({
    super.key,
    required this.plant,
    this.onTap,
  });

  final PlantSearchResult plant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shadowColor: _cardShadow,
      shape: _cardShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PlantThumbnailWithFallback(
                url: plant.thumbnailUrl,
                scientificName: plant.scientificName,
                commonName: plant.commonName,
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plant.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (plant.scientificName.isNotEmpty)
                      Text(
                        plant.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    if (plant.otherNames.isNotEmpty)
                      Text(
                        'Also: ${plant.otherNames.take(3).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    if (!plant.hasFullDetails)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _mint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Basic info only',
                          style: textTheme.labelSmall?.copyWith(
                            color: _forest,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _forest),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered icon and text for the empty, error and no-results states.
class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
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
            Icon(icon, size: 48, color: _forest),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: _ink),
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
