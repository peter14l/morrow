import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/services/search_service.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';
import 'package:oasis/widgets/desktop_header.dart';
import 'package:oasis/widgets/wellbeing/lockout_overlay.dart';
import 'package:oasis/widgets/custom_snackbar.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/widgets/wellbeing/grayscale_detox.dart';

class SearchScreen extends StatefulWidget {
  final bool isPanel;
  const SearchScreen({super.key, this.isPanel = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with material.SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  late material.TabController _tabController;
  Timer? _debounceTimer;
  Timer? _throttleTimer;
  bool _isThrottled = false;

  List<Map<String, dynamic>> _userResults = [];
  List<Post> _postResults = [];
  bool _isLoading = false;
  String _query = '';

  // Filter states
  String _selectedFilter = 'all'; // all, users, posts
  String _sortBy = 'relevance'; // relevance, recent, popular
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _tabController = material.TabController(length: 2, vsync: this);
  }

  Future<void> _performSearch() async {
    if (_query.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final users = await _searchService.searchUsers(_query);
      final posts = await _searchService.searchPosts(_query);

      if (mounted) {
        setState(() {
          _userResults = users;
          _postResults = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, e);
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);

    if (!_isThrottled) {
      _performSearch();
      _isThrottled = true;
      _throttleTimer = Timer(const Duration(seconds: 2), () {
        _isThrottled = false;
      });
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _onSearchSubmitted(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final useFluent = themeProvider.useFluentUI;
    final usePanelLayout = widget.isPanel;

    if (useFluent && isDesktop && !usePanelLayout) {
      return material.Material(
        color: material.Colors.transparent,
        child: _buildFluentSearch(context, themeProvider),
      );
    }

    if (usePanelLayout) {
      // Panel layout - simplified for narrow sliding panel
      return material.Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: material.AppBar(
          backgroundColor: colorScheme.surface,
          automaticallyImplyLeading: false,
          elevation: 0,
          toolbarHeight: 60,
          title: _buildSearchBox(colorScheme, isM3E, isPanel: true),
          actions: [
            if (_query.isNotEmpty)
              material.IconButton(
                icon: const material.Icon(material.Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
            const material.SizedBox(width: 4),
          ],
        ),
        body: _buildPanelLayout(isM3E),
      );
    }

    return GrayscaleDetox(
      child: AdaptiveScaffold(
        title: const Text('Search'),
        actions: isDesktop ? [
          material.IconButton.filledTonal(
            icon: material.Icon(
              _showFilters ? material.Icons.filter_list_off : material.Icons.filter_list,
              size: 20,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
          ),
        ] : null,
        appBar: !isDesktop ? material.AppBar(
          backgroundColor: colorScheme.surface,
          automaticallyImplyLeading: true,
          elevation: 0,
          toolbarHeight: 80,
          title: _buildSearchBox(colorScheme, isM3E),
          actions: [
            if (_query.isNotEmpty)
              material.IconButton(
                icon: const material.Icon(material.Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
            const SizedBox(width: 8),
          ],
          bottom: material.PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const material.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: material.TabBar(
                controller: _tabController,
                indicator: const material.BoxDecoration(),
                dividerColor: material.Colors.transparent,
                labelPadding: const material.EdgeInsets.symmetric(horizontal: 4),
                tabs: [
                  _buildTab('People', 0, isM3E),
                  _buildTab('Posts', 1, isM3E),
                ],
              ),
            ),
          ),
        ) : null,
        header: isDesktop ? _buildNewDesktopHeader(theme, colorScheme, isM3E) : null,
        body: Stack(
          children: [
            isDesktop ? _buildDesktopLayout(isM3E) : _buildMobileLayout(isM3E),
            const LockoutOverlay(pageName: 'Search'),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(material.ColorScheme colorScheme, bool isM3E, {bool isPanel = false}) {
    return Container(
      height: isPanel ? 40 : 52,
      decoration: material.BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(isM3E ? (isPanel ? 12 : 16) : (isPanel ? 20 : 26)),
        border: Border.all(
          color: material.Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: material.TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
        decoration: material.InputDecoration(
          hintText: 'Search...',
          border: material.InputBorder.none,
          hintStyle: material.TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: isPanel ? 14 : null,
          ),
          prefixIcon: material.Icon(
            material.Icons.search,
            color: colorScheme.onSurfaceVariant,
            size: isPanel ? 20 : 24,
          ),
          contentPadding: material.EdgeInsets.symmetric(
            horizontal: isPanel ? 12 : 16,
            vertical: isPanel ? 10 : 14,
          ),
        ),
        style: material.Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
          fontSize: isPanel ? 14 : null,
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildFluentSearch(BuildContext context, ThemeProvider themeProvider) {
    return fluent.ScaffoldPage.scrollable(
      header: fluent.PageHeader(
        title: const Text('Search'),
        commandBar: fluent.CommandBar(
          mainAxisAlignment: material.MainAxisAlignment.end,
          primaryItems: [
            fluent.CommandBarButton(
              icon: material.Icon(_showFilters ? material.Icons.filter_list_off : material.Icons.filter_list, size: 18),
              label: Text(_showFilters ? 'Hide Filters' : 'Show Filters'),
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const material.EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: fluent.TextBox(
            controller: _searchController,
            placeholder: 'Search for anything on Oasis...',
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
            prefix: const Padding(
              padding: material.EdgeInsets.only(left: 12.0),
              child: material.Icon(material.Icons.search, size: 20),
            ),
            suffix: _query.isNotEmpty ? fluent.IconButton(
              icon: const material.Icon(material.Icons.clear, size: 16),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ) : null,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showFilters)
              Container(
                width: 250,
                padding: const material.EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    fluent.RadioGroup<String>(
                      groupValue: _selectedFilter,
                      onChanged: (v) { if(v != null) setState(() => _selectedFilter = v); },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fluent.RadioButton<String>(
                            value: 'all',
                            content: const Text('All'),
                          ),
                          const SizedBox(height: 12),
                          fluent.RadioButton<String>(
                            value: 'users',
                            content: const Text('Users'),
                          ),
                          const SizedBox(height: 12),
                          fluent.RadioButton<String>(
                            value: 'posts',
                            content: const Text('Posts'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading 
                ? const Center(child: fluent.ProgressRing())
                : _query.isEmpty
                  ? _buildSearchSuggestions(themeProvider.isM3EEnabled)
                  : _buildDesktopResults(themeProvider.isM3EEnabled),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewDesktopHeader(
    material.ThemeData theme,
    material.ColorScheme colorScheme,
    bool isM3E,
  ) {
    return Column(
      children: [
        DesktopHeader(
          title: 'Search',
          subtitle: 'Discover people, posts, and moments',
          actions: [
            material.IconButton.filledTonal(
              icon: material.Icon(
                _showFilters ? material.Icons.filter_list_off : material.Icons.filter_list,
                size: 20,
              ),
              onPressed: () => setState(() => _showFilters = !_showFilters),
              tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
              style: material.IconButton.styleFrom(
                backgroundColor: _showFilters
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: _showFilters
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                shape: material.RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isM3E ? 12 : 20),
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const material.EdgeInsets.fromLTRB(40, 0, 40, 24),
          child: MaxWidthContainer(
            maxWidth: 1000,
            child: Container(
              height: 64,
              decoration: material.BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(isM3E ? 16 : 32),
                border: material.Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: material.TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: _onSearchSubmitted,
                decoration: material.InputDecoration(
                  hintText: 'Search for anything on Oasis...',
                  border: material.InputBorder.none,
                  hintStyle: material.TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const material.Icon(material.Icons.search, size: 28),
                  suffixIcon: _query.isNotEmpty
                      ? material.IconButton(
                          icon: const material.Icon(material.Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const material.EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
        ),
        const material.Divider(height: 1),
      ],
    );
  }

  void _showPanelFilters(BuildContext context, bool isM3E) {
    material.showModalBottomSheet(
      context: context,
      backgroundColor: material.Theme.of(context).colorScheme.surface,
      shape: material.RoundedRectangleBorder(
        borderRadius: material.BorderRadius.vertical(
          top: Radius.circular(isM3E ? 48 : 24),
        ),
      ),
      builder: (context) => Container(
        padding: const material.EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            material.Text(
              'Sort Results',
              style: material.Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                letterSpacing: isM3E ? -0.5 : 0,
              ),
            ),
            const SizedBox(height: 24),
            _buildSortOption('Relevance', 'relevance', material.Icons.star_outline),
            _buildSortOption('Recent', 'recent', material.Icons.access_time),
            _buildSortOption('Popular', 'popular', material.Icons.trending_up),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index, bool isM3E) {
    return material.ListenableBuilder(
      listenable: _tabController,
      builder: (context, child) {
        final isSelected = _tabController.index == index;
        final theme = material.Theme.of(context);
        return Container(
          width: double.infinity,
          height: 44,
          alignment: Alignment.center,
          decoration: material.BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(isM3E ? 12 : 12),
          ),
          child: material.Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? material.Colors.white
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected
                  ? (isM3E ? FontWeight.w900 : FontWeight.bold)
                  : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(bool isM3E) {
    return Row(
      children: [
        // Filters Sidebar
        if (_showFilters)
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: material.Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: _buildFiltersSidebar(isM3E),
          ),
        // Main Content
        Expanded(
          child: _isLoading
              ? const Center(child: material.CircularProgressIndicator())
              : _query.isEmpty
              ? _buildSearchSuggestions(isM3E)
              : _buildDesktopResults(isM3E),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isM3E) {
    return _isLoading
        ? const Center(child: material.CircularProgressIndicator())
        : _query.isEmpty
        ? _buildSearchSuggestions(isM3E)
        : material.TabBarView(
            controller: _tabController,
            children: [_buildUserList(isM3E), _buildPostList()],
          );
  }

  Widget _buildPanelLayout(bool isM3E) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _isLoading
        ? const Center(child: material.CircularProgressIndicator())
        : _query.isEmpty
        ? Center(
            child: Padding(
              padding: const material.EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  material.Icon(
                    material.Icons.search,
                    size: 48,
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for people and posts',
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter keywords to find users and posts',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : Column(
            children: [
              // Simple tab bar
              Padding(
                padding: const material.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: _buildPanelTab('People', 0, isM3E)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPanelTab('Posts', 1, isM3E)),
                  ],
                ),
              ),
              // Results
              Expanded(
                child: material.TabBarView(
                  controller: _tabController,
                  children: [_buildPanelUserList(isM3E), _buildPanelPostList()],
                ),
              ),
            ],
          );
  }

  Widget _buildPanelTab(String label, int index, bool isM3E) {
    return material.ListenableBuilder(
      listenable: _tabController,
      builder: (context, child) {
        final isSelected = _tabController.index == index;
        final theme = material.Theme.of(context);
        return material.GestureDetector(
          onTap: () => _tabController.animateTo(index),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: material.BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
              borderRadius: BorderRadius.circular(isM3E ? 10 : 10),
            ),
            child: material.Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? material.Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelUserList(bool isM3E) {
    if (_userResults.isEmpty) {
      return Center(
        child: material.Text(
          'No users found',
          style: material.Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: material.Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const material.EdgeInsets.symmetric(horizontal: 8),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return material.ListTile(
          contentPadding: const material.EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          dense: true,
          leading: material.CircleAvatar(
            radius: 18,
            backgroundImage: user['avatar_url'] != null
                ? CachedNetworkImageProvider(user['avatar_url'])
                : null,
            child: user['avatar_url'] == null
                ? Text(user['username'][0].toUpperCase())
                : null,
          ),
          title: Text(
            user['full_name'] ?? user['username'],
            style: material.Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '@${user['username']}',
            style: material.Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            context.push('/profile/${user['id']}');
          },
        );
      },
    );
  }

  Widget _buildPanelPostList() {
    if (_postResults.isEmpty) {
      return Center(
        child: material.Text(
          'No posts found',
          style: material.Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: material.Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const material.EdgeInsets.symmetric(horizontal: 8),
      itemCount: _postResults.length,
      itemBuilder: (context, index) {
        final post = _postResults[index];
        return _buildPanelPostCard(post);
      },
    );
  }

  Widget _buildPanelPostCard(Post post) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const material.EdgeInsets.only(bottom: 8),
      padding: const material.EdgeInsets.all(12),
      decoration: material.BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            children: [
              material.CircleAvatar(
                radius: 14,
                backgroundImage: post.userAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(post.userAvatar)
                    : null,
                child: post.userAvatar.isEmpty
                    ? Text(
                        post.username[0].toUpperCase(),
                        style: const material.TextStyle(fontSize: 10),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post.username,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Content
          Text(
            post.content ?? '',
            style: theme.textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersSidebar(bool isM3E) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const material.EdgeInsets.all(16),
      children: [
        Text(
          'Filters',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        // Filter by Type
        Text(
          'Type',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildFilterChip('All', 'all'),
        _buildFilterChip('Users', 'users'),
        _buildFilterChip('Posts', 'posts'),
        const SizedBox(height: 24),

        // Sort By
        Text(
          'Sort By',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildSortOption('Relevance', 'relevance', material.Icons.star_outline),
        _buildSortOption('Recent', 'recent', material.Icons.access_time),
        _buildSortOption('Popular', 'popular', material.Icons.trending_up),
        const SizedBox(height: 24),

        // Quick Stats
        if (_userResults.isNotEmpty || _postResults.isNotEmpty) ...[
          Container(
            padding: const material.EdgeInsets.all(16),
            decoration: material.BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Users:', style: theme.textTheme.bodyMedium),
                    Text(
                      '${_userResults.length}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Posts:', style: theme.textTheme.bodyMedium),
                    Text(
                      '${_postResults.length}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const material.EdgeInsets.only(bottom: 8),
      child: material.FilterChip(
        label: SizedBox(width: double.infinity, child: Text(label)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
      ),
    );
  }

  Widget _buildSortOption(String label, String value, material.IconData icon) {
    final isSelected = _sortBy == value;
    final theme = material.Theme.of(context);

    return Padding(
      padding: const material.EdgeInsets.only(bottom: 8),
      child: material.InkWell(
        onTap: () => setState(() => _sortBy = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const material.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: material.BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              material.Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopResults(bool isM3E) {
    if (_selectedFilter == 'users' || _selectedFilter == 'all') {
      if (_selectedFilter == 'users') {
        return _buildUserList(isM3E);
      }
      // Show both
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_userResults.isNotEmpty) ...[
              Padding(
                padding: const material.EdgeInsets.all(16),
                child: Text(
                  'People',
                  style: material.Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 200, child: _buildUserList(isM3E)),
            ],
            if (_postResults.isNotEmpty) ...[
              Padding(
                padding: const material.EdgeInsets.all(16),
                child: Text(
                  'Posts',
                  style: material.Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                  ),
                ),
              ),
              _buildPostList(),
            ],
            if (_userResults.isEmpty && _postResults.isEmpty)
              _buildEmptyState('No results found'),
          ],
        ),
      );
    } else {
      return _buildPostList();
    }
  }

  Widget _buildSearchSuggestions(bool isM3E) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: MaxWidthContainer(
        maxWidth: 600,
        child: SingleChildScrollView(
          child: Padding(
            padding: const material.EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                material.Icon(
                  material.Icons.search,
                  size: 80,
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Search for people and posts',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter keywords to find users, posts, and more',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Search Tips
                Container(
                  padding: const material.EdgeInsets.all(20),
                  decoration: material.BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Tips',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchTip(
                        material.Icons.person_outline,
                        'Find users by name or username',
                      ),
                      _buildSearchTip(
                        material.Icons.article_outlined,
                        'Discover posts by keywords',
                      ),
                      _buildSearchTip(material.Icons.tag, 'Search using hashtags'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTip(material.IconData icon, String text) {
    final theme = material.Theme.of(context);
    return Padding(
      padding: const material.EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          material.Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildUserList(bool isM3E) {
    if (_userResults.isEmpty) {
      return _buildEmptyState('No users found');
    }

    final isDesktop = ResponsiveLayout.isDesktop(context);
    final usePanelLayout = widget.isPanel;

    if (isDesktop && !usePanelLayout) {
      return MaxWidthContainer(
        maxWidth: ResponsiveLayout.maxContentWidth,
        child: material.GridView.builder(
          padding: const material.EdgeInsets.all(16),
          gridDelegate: material.SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ResponsiveLayout.getGridColumns(
              context,
              mobile: 1,
              tablet: 2,
              desktop: 3,
            ),
            childAspectRatio: 3.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _userResults.length,
          itemBuilder: (context, index) {
            final user = _userResults[index];
            return _buildUserCard(user, isM3E);
          },
        ),
      );
    }

    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return material.ListTile(
          contentPadding: const material.EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          dense: true,
          leading: material.CircleAvatar(
            radius: 18,
            backgroundImage: user['avatar_url'] != null
                ? CachedNetworkImageProvider(user['avatar_url'])
                : null,
            child: user['avatar_url'] == null
                ? Text(user['username'][0].toUpperCase())
                : null,
          ),
          title: Text(
            user['full_name'] ?? user['username'],
            style: material.Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '@${user['username']}',
            style: material.Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            context.push('/profile/${user['id']}');
          },
        );
      },
    );
  }

  Widget _buildPostList() {
    if (_postResults.isEmpty) {
      return _buildEmptyState('No posts found');
    }

    final postList = ListView.builder(
      padding: const material.EdgeInsets.all(16),
      itemCount: _postResults.length,
      itemBuilder: (context, index) {
        final post = _postResults[index];
        return PostCard(post: post);
      },
    );

    return (ResponsiveLayout.isDesktop(context) && !widget.isPanel)
        ? MaxWidthContainer(
            maxWidth: ResponsiveLayout.maxFeedWidth,
            child: postList,
          )
        : postList;
  }

  Widget _buildEmptyState(String message) {
    final theme = material.Theme.of(context);
    return Center(
      child: Padding(
        padding: const material.EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            material.Icon(
              material.Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isM3E) {
    final theme = material.Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: material.BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: material.InkWell(
            onTap: () => context.push('/profile/${user['id']}'),
            borderRadius: BorderRadius.circular(isM3E ? 24 : 12),
            child: Padding(
              padding: const material.EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isM3E ? 3 : 0),
                    decoration: material.BoxDecoration(
                      shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: isM3E ? BorderRadius.circular(14) : null,
                      border: isM3E
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: isM3E
                          ? BorderRadius.circular(11)
                          : BorderRadius.circular(28),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: user['avatar_url'] != null
                            ? CachedNetworkImage(
                                imageUrl: user['avatar_url'],
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Text(
                                    user['username'][0].toUpperCase(),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: material.MainAxisAlignment.center,
                      children: [
                        Text(
                          user['full_name'] ?? user['username'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isM3E
                                ? FontWeight.w900
                                : FontWeight.bold,
                            letterSpacing: isM3E ? -0.5 : 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${user['username']}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  material.Icon(
                    material.Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
