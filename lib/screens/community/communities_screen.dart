import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/providers/community_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/models/community.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // Filter states
  bool _showPrivateOnly = false;
  bool _showJoinedOnly = false;
  bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCommunities();
    });
  }

  void _loadCommunities() {
    final userId = _authService.currentUser?.id;
    if (userId != null) {
      final provider = context.read<CommunityProvider>();
      provider.loadAllCommunities();
      provider.loadUserCommunities(userId);
    }
  }

  void _showSearchDialog() {
    showSearch(context: context, delegate: CommunitySearchDelegate());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isDesktop) {
      return Scaffold(
        body: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Communities',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, size: 24),
                    onPressed: () => _showSearchDialog(),
                    tooltip: 'Search Communities',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      _showSidebar ? Icons.menu_open : Icons.menu,
                      size: 24,
                    ),
                    onPressed: () =>
                        setState(() => _showSidebar = !_showSidebar),
                    tooltip: _showSidebar ? 'Hide Sidebar' : 'Show Sidebar',
                    style: IconButton.styleFrom(
                      backgroundColor: _showSidebar
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: _showSidebar
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Consumer<CommunityProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.allCommunities.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null) {
                    return Center(child: Text('Error: ${provider.error}'));
                  }

                  return _buildDesktopLayout(provider);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/communities/create'),
          icon: const Icon(Icons.add),
          label: const Text('Create Community'),
        ),
      );
    }

    // Mobile layout
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Communities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Communities'),
          ],
        ),
      ),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allCommunities.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCommunitiesGrid(provider.allCommunities),
              _buildCommunitiesGrid(provider.userCommunities),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout(CommunityProvider provider) {
    List<Community> communitiesToShow;
    if (_showJoinedOnly) {
      communitiesToShow = provider.userCommunities;
    } else if (_showPrivateOnly) {
      communitiesToShow = provider.allCommunities
          .where((c) => c.isPrivate)
          .toList();
    } else {
      communitiesToShow = provider.allCommunities;
    }

    return Row(
      children: [
        if (_showSidebar)
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: _buildSidebar(provider),
          ),
        Expanded(child: _buildCommunitiesGrid(communitiesToShow)),
      ],
    );
  }

  Widget _buildCommunitiesGrid(List<Community> communities) {
    if (communities.isEmpty) {
      return _buildEmptyState();
    }

    // Masonry Grid View
    return MasonryGridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: ResponsiveLayout.getGridColumns(
        context,
        mobile: 1,
        tablet: 2,
        desktop: 3,
      ),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: communities.length,
      itemBuilder: (context, index) {
        return _buildCommunityCard(communities[index], index);
      },
    );
  }

  Widget _buildSidebar(CommunityProvider provider) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Browse',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildSidebarOption(
          'Discover',
          Icons.explore_outlined,
          _tabController.index == 0,
          () => _tabController.animateTo(0),
        ),
        _buildSidebarOption(
          'My Communities',
          Icons.groups_outlined,
          _tabController.index == 1,
          () => _tabController.animateTo(1),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Filters',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Private Only'),
          value: _showPrivateOnly,
          onChanged: (value) => setState(() => _showPrivateOnly = value),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          title: const Text('Joined Only'),
          value: _showJoinedOnly,
          onChanged: (value) => setState(() => _showJoinedOnly = value),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildSidebarOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No communities found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCard(Community community, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Varying height for masonry effect based on description length or index
    // Using index to simulate some variance if descriptions are uniform

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: InkWell(
        onTap: () => context.push('/community/${community.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Image with Glass Overlay
            Container(
              height:
                  120 +
                  (index % 3) *
                      20.0, // Mild height variation for visual interest
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    // Simple distinct colors based on index to differentiate cards visually
                    HSLColor.fromAHSL(
                      1,
                      (index * 137.5) % 360,
                      0.6,
                      0.6,
                    ).toColor(),
                    HSLColor.fromAHSL(
                      1,
                      (index * 137.5 + 40) % 360,
                      0.5,
                      0.5,
                    ).toColor(),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  if (community.isPrivate)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          backgroundBlendMode: BlendMode.darken,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Private',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black54, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Text(
                        community.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat(
                        Icons.people,
                        '${community.membersCount}',
                        colorScheme,
                      ),
                      _buildMiniStat(
                        Icons.article,
                        '${community.postsCount}',
                        colorScheme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, ColorScheme colors) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class CommunitySearchDelegate extends SearchDelegate<Community?> {
  final CommunityProvider _communityProvider = CommunityProvider();

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Search communities...'));
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Community>>(
      future: _communityProvider.searchCommunities(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No communities found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final community = snapshot.data![index];
            return ListTile(
              title: Text(community.name),
              subtitle: Text(community.description),
              onTap: () {
                close(context, community);
                context.push('/community/${community.id}');
              },
            );
          },
        );
      },
    );
  }
}
