import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/perenual_models.dart';
import '../services/database_service.dart';
import '../services/perenual_service.dart';
import '../theme/plantpal_colors.dart';
import '../widgets/plant_care_guide.dart';
import 'plant_details_screen.dart';

class PlantSearch extends StatefulWidget {
  const PlantSearch({super.key});

  @override
  State<PlantSearch> createState() => _PlantSearchState();
}

class _PlantSearchState extends State<PlantSearch> {
  static const List<String> _suggestions = [
    'Monstera',
    'Pothos',
    'Snake plant',
    'Peace lily',
    'Fern',
    'Aloe',
  ];

  // Recent searches are saved to the user's account, newest first.
  static const int _maxRecentSearches = 6;

  final PerenualService _api = PerenualService.instance;
  final TextEditingController _controller = TextEditingController();

  String _activeQuery = '';
  List<PlantSearchResult> _results = [];

  int _page = 1;
  int _total = 0;
  int _requestId = 0;

  bool _hasMore = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  String? _error;

  // PlantPal theme colors for light and dark mode.
  Color get _background => PlantPalColors.background(context);
  Color get _card => PlantPalColors.card(context);
  Color get _text => PlantPalColors.text(context);
  Color get _secondary => PlantPalColors.secondaryText(context);
  Color get _accent => PlantPalColors.accent(context);
  Color get _border => PlantPalColors.border(context);
  Color get _soft => PlantPalColors.softBackground(context);

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

  // Clear the search when the input is empty.
  void _onQueryChanged(String value) {
    if (value.trim().isNotEmpty) return;

    _requestId++;

    setState(() {
      _activeQuery = '';
      _results = [];
      _error = null;
      _isLoading = false;
      _hasMore = false;
      _total = 0;
    });
  }

  void _searchNow(String value) {
    final query = value.trim();

    if (query.isNotEmpty) {
      _search(query);
    }
  }

  // Load previous searches saved on this device.
  Future<void> _loadRecentSearches() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final saved = await DatabaseService().getRecentSearches(userId);
      if (!mounted) return;
      // keep anything searched while this was loading
      setState(() {
        _recentSearches = [
          ..._recentSearches,
          ...saved.where(
            (s) => !_recentSearches.any(
              (r) => r.toLowerCase() == s.toLowerCase(),
            ),
          ),
        ].take(_maxRecentSearches).toList();
      });
    } catch (e) {
      debugPrint('Recent searches error: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await DatabaseService().setRecentSearches(
        userId: userId,
        queries: List.of(_recentSearches),
      );
    } catch (e) {
      debugPrint('Recent searches error: $e');
    }
  }

  // Move the search to the front and remove duplicates.
  void _addRecentSearch(String query) {
    setState(() {
      _recentSearches = [
        query,
        ..._recentSearches.where((s) => s.toLowerCase() != query.toLowerCase()),
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

  // Search for plants using the Perenual API.
  Future<void> _search(String query) async {
    if (query == _activeQuery && _error == null && !_isLoading) {
      return;
    }

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

      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Load more results without repeating earlier ones.
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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _useSuggestion(String suggestion) {
    _controller.text = suggestion;
    _searchNow(suggestion);
  }

  void _clear() {
    _controller.clear();
    _onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: _text, fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 16),

                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        return TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(color: _text),
                          cursorColor: _accent,
                          decoration: InputDecoration(
                            labelText: 'Search by plant name',
                            hintText: 'e.g. monstera, pothos, fern',
                            helperText: 'Press Enter to search',
                            labelStyle: TextStyle(color: _secondary),
                            hintStyle: TextStyle(color: _secondary),
                            helperStyle: TextStyle(color: _secondary),

                            prefixIcon: IconButton(
                              tooltip: 'Search',
                              color: _accent,
                              icon: const Icon(Icons.search),
                              onPressed: () => _searchNow(_controller.text),
                            ),

                            suffixIcon: value.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    color: _accent,
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clear,
                                  ),

                            filled: true,
                            fillColor: _card,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: _border),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: _accent, width: 2),
                            ),
                          ),
                          onChanged: _onQueryChanged,
                          onSubmitted: _searchNow,
                        );
                      },
                    ),
                  ],
                ),
              ),

              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Display an error if the search fails.
    if (_error != null) {
      return _SearchMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: _error!,
        action: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: PlantPalColors.forest,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _search(_activeQuery),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    // Display suggestions and recent searches.
    if (_activeQuery.isEmpty) {
      final message = _SearchMessage(
        icon: Icons.local_florist_outlined,
        title: 'Find a plant',
        message:
            'Search thousands of species to see watering, '
            'sunlight, and soil needs.',
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                backgroundColor: _soft,
                side: BorderSide(color: _border),
                labelStyle: TextStyle(color: _text),
                label: Text(suggestion),
                onPressed: () => _useSuggestion(suggestion),
              ),
          ],
        ),
      );

      if (_recentSearches.isEmpty) {
        return message;
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recently searched',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: _text, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                child: const Text('Clear'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final recent in _recentSearches)
                InputChip(
                  backgroundColor: _card,
                  side: BorderSide(color: _border),
                  shape: const StadiumBorder(),

                  // Theme-aware text color fixes the conflict.
                  labelStyle: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w500,
                  ),

                  avatar: Icon(Icons.history, size: 18, color: _accent),
                  label: Text(recent),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  deleteIconColor: _accent,
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

    // No search results found.
    if (_results.isEmpty) {
      return _SearchMessage(
        icon: Icons.search_off,
        title: 'No plants found',
        message:
            'No results for "$_activeQuery". '
            'Try a common or scientific name.',
      );
    }

    // Display search results.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _results.length + 2,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            '$_total result${_total == 1 ? '' : 's'} '
            'for "$_activeQuery"',
            style: TextStyle(color: _secondary, fontSize: 13),
          );
        }

        if (index == _results.length + 1) {
          if (!_hasMore) {
            return const SizedBox.shrink();
          }

          return Center(
            child: _isLoadingMore
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: BorderSide(color: _border),
                    ),
                    onPressed: _loadMore,
                    child: const Text('Load more'),
                  ),
          );
        }

        final plant = _results[index - 1];

        return PlantSearchResultCard(
          plant: plant,
          onTap: () => openPlantDetailsPage(context, plant, collapseCare: true),
        );
      },
    );
  }
}

// Card used to display a plant from search results.
class PlantSearchResultCard extends StatelessWidget {
  const PlantSearchResultCard({super.key, required this.plant, this.onTap});

  final PlantSearchResult plant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = PlantPalColors.text(context);
    final secondary = PlantPalColors.secondaryText(context);
    final accent = PlantPalColors.accent(context);

    return Card(
      margin: EdgeInsets.zero,
      color: PlantPalColors.card(context),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: PlantPalColors.border(context)),
      ),
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
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (plant.scientificName.isNotEmpty)
                      Text(
                        plant.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    if (plant.otherNames.isNotEmpty)
                      Text(
                        'Also: '
                        '${plant.otherNames.take(3).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondary),
                      ),

                    if (!plant.hasFullDetails)
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: PlantPalColors.softBackground(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Basic info only',
                          style: TextStyle(fontSize: 11, color: text),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

// Message displayed before searching or when no results are found.
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
            Icon(icon, size: 48, color: PlantPalColors.accent(context)),

            const SizedBox(height: 12),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PlantPalColors.text(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: PlantPalColors.secondaryText(context)),
            ),

            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
