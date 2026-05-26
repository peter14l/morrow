import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/circles/presentation/widgets/circles/circle_list_card.dart';

class CirclesListScreen extends StatefulWidget {
  const CirclesListScreen({super.key});

  @override
  State<CirclesListScreen> createState() => _CirclesListScreenState();
}

class _CirclesListScreenState extends State<CirclesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final profile = context.read<ProfileProvider>();
    final userId = profile.currentProfile?.id;
    if (userId != null) {
      await context.read<CircleProvider>().loadCircles(userId);
    }
  }

  Future<void> _deleteCircle(BuildContext context, String circleId) async {
    try {
      await context.read<CircleProvider>().deleteCircle(circleId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Circle deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting circle: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final circles = context.watch<CircleProvider>();
    final profile = context.watch<ProfileProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return PopScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App Bar ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 40 : 20,
                    isDesktop ? 40 : 20,
                    isDesktop ? 40 : 20,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Circles',
                              style:
                                  (isDesktop
                                          ? theme.textTheme.headlineLarge
                                          : theme.textTheme.headlineMedium)
                                      ?.copyWith(
                                        fontWeight: isM3E
                                            ? FontWeight.w900
                                            : FontWeight.w900,
                                        letterSpacing: isM3E ? -1.5 : -1,
                                      ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your private commitment groups',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Create circle button
                      _PrimaryButton(
                        label: isDesktop ? 'Create New Circle' : 'New Circle',
                        icon: FluentIcons.add_circle_24_regular,
                        isM3E: isM3E,
                        onTap: () => context.pushNamed('create_circle'),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ── Content ────────────────────────────────────────────────────
              if (circles.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (circles.circles.isEmpty)
                SliverFillRemaining(
                  child: _EmptyCirclesState(
                    isM3E: isM3E,
                    onCreateTap: () => context.pushNamed('create_circle'),
                  ),
                )
              else if (isDesktop)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: circles.circles.length,
                    itemBuilder: (context, i) {
                      final circle = circles.circles[i];
                      return CircleListCard(
                        circle: circle,
                        isDesktop: true,
                        onTap: () => context.pushNamed(
                          'circle_detail',
                          pathParameters: {'circleId': circle.id},
                        ),
                        onDelete: () => _deleteCircle(context, circle.id),
                        currentUserId: profile.currentProfile?.id,
                      );
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: circles.circles.length,
                    itemBuilder: (context, i) {
                      final circle = circles.circles[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CircleListCard(
                          circle: circle,
                          onTap: () => context.pushNamed(
                            'circle_detail',
                            pathParameters: {'circleId': circle.id},
                          ),
                          onDelete: () => _deleteCircle(context, circle.id),
                          currentUserId: profile.currentProfile?.id,
                        ),
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isM3E;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isM3E = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isM3E ? 12 : 14),
        ),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: isM3E ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyCirclesState extends StatelessWidget {
  final VoidCallback onCreateTap;
  final bool isM3E;
  const _EmptyCirclesState({required this.onCreateTap, this.isM3E = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(24) : null,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              FluentIcons.people_team_24_regular,
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No circles yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a circle with close friends\nand start building shared commitments.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            onTap: onCreateTap,
            icon: FluentIcons.add_circle_24_regular,
            label: 'Create a Circle',
            isM3E: isM3E,
          ),
        ],
      ),
    );
  }
}
