import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:oasis/features/messages/data/services/giphy_service.dart';
import 'package:oasis/features/messages/data/services/klipy_service.dart';
import 'package:oasis/features/messages/core/chat_api_config.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GiphyPickerSheet extends StatefulWidget {
  final Function(String url, bool isSticker) onSelected;
  final bool useKlipy;

  const GiphyPickerSheet({
    super.key,
    required this.onSelected,
    this.useKlipy = false,
  });

  @override
  State<GiphyPickerSheet> createState() => _GiphyPickerSheetState();
}

class _GiphyPickerSheetState extends State<GiphyPickerSheet> {
  final GiphyService _giphyService = GiphyService();
  final KlipyService _klipyService = KlipyService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isStickers = false;
  String _selectedCategory = 'Trending';
  List<dynamic> _results = [];
  List<String> _categories = [];
  bool _isLoading = false;
  String? _error;
  
  Timer? _searchDebounce;

  bool get _isUsingKlipy => widget.useKlipy || ChatApiConfig.giphyApiKey.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // Load categories (Giphy only for now, or standard list)
    final catResult = await _giphyService.getCategories(isSticker: _isStickers);
    if (catResult.isSuccess) {
      _categories = catResult.data ?? [];
    }

    // Load trending or search results
    await _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final query = _searchController.text.trim();
    
    if (_isUsingKlipy) {
      KlipyResult<List<KlipyMedia>> result;
      if (query.isNotEmpty) {
        result = await _klipyService.search(query);
      } else {
        result = await _klipyService.getTrending();
      }

      if (!mounted) return;
      setState(() {
        if (result.isSuccess) {
          _results = result.data ?? [];
        } else {
          _error = result.error;
        }
        _isLoading = false;
      });
    } else {
      GiphyResult<List<GiphyMedia>> result;
      if (query.isNotEmpty) {
        result = await _giphyService.search(query, isSticker: _isStickers);
      } else if (_selectedCategory != 'Trending') {
        result = await _giphyService.search(_selectedCategory, isSticker: _isStickers);
      } else {
        result = await _giphyService.getTrending(isSticker: _isStickers);
      }

      if (!mounted) return;
      setState(() {
        if (result.isSuccess) {
          _results = result.data ?? [];
        } else {
          _error = result.error;
        }
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData();
    });
  }

  void _toggleType(bool isStickers) {
    if (_isStickers == isStickers) return;
    if (_isUsingKlipy) return; // Klipy doesn't support stickers in current service impl
    
    HapticUtils.lightImpact();
    setState(() {
      _isStickers = isStickers;
      _results = [];
    });
    _fetchData();
  }

  void _selectCategory(String category) {
    if (_selectedCategory == category) return;
    HapticUtils.selectionClick();
    setState(() {
      _selectedCategory = category;
      _searchController.clear();
      _results = [];
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Container(
      height: MediaQuery.of(context).size.height * (isDesktop ? 0.8 : 0.75),
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark 
            ? colorScheme.surface.withValues(alpha: 0.8)
            : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header & Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  _isUsingKlipy ? 'Klipy' : (_isStickers ? 'Stickers' : 'GIFs'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (!_isUsingKlipy) _buildToggle(),
              ],
            ),
          ),

          // Thin Minimal Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isUsingKlipy ? 'Search Klipy...' : 'Search Giphy...',
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  prefixIcon: Icon(FluentIcons.search_20_regular, size: 18, color: colorScheme.onSurfaceVariant),
                  suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _fetchData();
                          },
                        ) 
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),

          // Category Chips
          const SizedBox(height: 8),
          _buildCategoryChips(),

          // Results Grid
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
            label: 'GIFs',
            isSelected: !_isStickers,
            onTap: () => _toggleType(false),
          ),
          _ToggleItem(
            label: 'Stickers',
            isSelected: _isStickers,
            onTap: () => _toggleType(true),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => _selectCategory(category),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : null,
              ),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.transparent,
              side: BorderSide(
                color: isSelected 
                    ? Colors.transparent 
                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!),
            TextButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.emoji_sad_24_regular, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No results found'),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      crossAxisCount: ResponsiveLayout.isDesktop(context) ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final media = _results[index];
        return GestureDetector(
          onTap: () {
            HapticUtils.lightImpact();
            widget.onSelected(media.url, _isStickers);
            Navigator.pop(context);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: media.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) {
                      return const AspectRatio(
                        aspectRatio: 1.0,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

