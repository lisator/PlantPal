import 'package:flutter/material.dart';

import '../models/perenual_models.dart';
import '../services/perenual_service.dart';
import 'plant_details_screen.dart';
import '../widgets/plant_care_guide.dart';

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

  final PerenualService _api = PerenualService.instance;
  final TextEditingController _controller = TextEditingController();

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

  void _searchNow(String value) {
    final query = value.trim();
    if (query.isNotEmpty) _search(query);
  }

  Future<void> _search(String query) async {
    if (query == _activeQuery && _error == null && !_isLoading) return;

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
    return Align(
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
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
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
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchNow(_controller.text),
                        ),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.clear),
                                onPressed: _clear,
                              ),
                        border: const OutlineInputBorder(),
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
    );
  }

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
          onPressed: () => _search(_activeQuery),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    if (_activeQuery.isEmpty) {
      return _SearchMessage(
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
                label: Text(suggestion),
                onPressed: () => _useSuggestion(suggestion),
              ),
          ],
        ),
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
                    onPressed: _loadMore,
                    child: const Text('Load more'),
                  ),
          );
        }
        final plant = _results[index - 1];
        return PlantSearchResultCard(
          plant: plant,
          onTap: () => openPlantDetailsPage(context, plant),
        );
      },
    );
  }
}

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PlantThumbnailWithFallback(
                url: plant.thumbnailUrl,
                scientificName: plant.scientificName,
                commonName: plant.commonName,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plant.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
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
                      Text(
                        'Basic info only',
                        style: textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
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
