import 'package:flutter/material.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:intl/intl.dart';

class ActivityGraph extends StatelessWidget {
  final List<Post> posts;

  const ActivityGraph({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    // Calculate daily post frequencies for the last year
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final endDate = today;
    final startDate = today.subtract(const Duration(days: 364));
    final adjustedStartDate = startDate.subtract(
      Duration(days: startDate.weekday % 7),
    );

    final Map<DateTime, int> dailyCounts = {};
    for (var post in posts) {
      final postDate = DateTime(
        post.timestamp.year,
        post.timestamp.month,
        post.timestamp.day,
      );
      if (postDate.isAfter(
            adjustedStartDate.subtract(const Duration(days: 1)),
          ) &&
          postDate.isBefore(endDate.add(const Duration(days: 1)))) {
        dailyCounts[postDate] = (dailyCounts[postDate] ?? 0) + 1;
      }
    }

    final totalContributions = dailyCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalContributions contributions in the last year',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Contribution settings',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 20, right: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 13), // skip Sun
                                _buildDayLabel('Mon'),
                                const SizedBox(height: 13), // skip Tue
                                _buildDayLabel('Wed'),
                                const SizedBox(height: 13), // skip Thu
                                _buildDayLabel('Fri'),
                              ],
                            ),
                          ),
                          _buildContributionGrid(
                            context,
                            adjustedStartDate,
                            endDate,
                            dailyCounts,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Learn how we count contributions',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Less',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildLegendSquare(context, 0),
                            const SizedBox(width: 2),
                            _buildLegendSquare(context, 1),
                            const SizedBox(width: 2),
                            _buildLegendSquare(context, 2),
                            const SizedBox(width: 2),
                            _buildLegendSquare(context, 3),
                            const SizedBox(width: 2),
                            _buildLegendSquare(context, 4),
                            const SizedBox(width: 4),
                            Text(
                              'More',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 16),
              _buildYearSelector(context),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildYearSelector(BuildContext context) {
    return Column(
      children: [
        _buildYearButton(context, '2026', isSelected: true),
        const SizedBox(height: 8),
        _buildYearButton(context, '2025', isSelected: false),
        const SizedBox(height: 8),
        _buildYearButton(context, '2024', isSelected: false),
      ],
    );
  }

  Widget _buildYearButton(
    BuildContext context,
    String year, {
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 80,
      height: 32,
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        year,
        style: TextStyle(
          color: isSelected
              ? colorScheme.onPrimary
              : colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDayLabel(String label) {
    return SizedBox(
      height: 10,
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

  Widget _buildContributionGrid(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
    Map<DateTime, int> dailyCounts,
  ) {
    final List<List<DateTime?>> weeks = [];
    DateTime current = startDate;

    while (current.isBefore(endDate.add(const Duration(days: 1)))) {
      final List<DateTime?> week = List.generate(7, (index) {
        final DateTime day = current.add(Duration(days: index));
        if (day.isAfter(endDate)) return null;
        return day;
      });
      weeks.add(week);
      current = current.add(const Duration(days: 7));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: _buildMonthLabels(weeks)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: weeks.map((week) {
            return Column(
              children: week.map((day) {
                if (day == null) {
                  return const SizedBox(width: 13, height: 13);
                }
                final count = dailyCounts[day] ?? 0;
                return _buildContributionSquare(context, day, count);
              }).toList(),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildMonthLabels(List<List<DateTime?>> weeks) {
    return weeks.asMap().entries.map((entry) {
      final week = entry.value;
      final firstDay = week.firstWhere((d) => d != null, orElse: () => null);

      if (firstDay != null && firstDay.day <= 7) {
        return SizedBox(
          width: 13,
          height: 15,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 40,
                child: Text(
                  DateFormat('MMM').format(firstDay),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox(width: 13, height: 15);
    }).toList();
  }

  Widget _buildContributionSquare(
    BuildContext context,
    DateTime date,
    int count,
  ) {
    final color = _getContributionColor(context, count);
    return Tooltip(
      message: '${DateFormat('MMM d, y').format(date)}: $count contributions',
      child: Container(
        width: 11,
        height: 11,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildLegendSquare(BuildContext context, int level) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: _getContributionColor(context, level, isLegend: true),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getContributionColor(
    BuildContext context,
    int count, {
    bool isLegend = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (count == 0) {
      return isDark ? const Color(0xFF161B22) : const Color(0xFFEBEDF0);
    }

    if (isDark) {
      if (count == 1 || (isLegend && count == 1)) {
        return const Color(0xFF0E4429);
      }
      if (count == 2 || (isLegend && count == 2)) {
        return const Color(0xFF006D32);
      }
      if (count == 3 || (isLegend && count == 3)) {
        return const Color(0xFF26A641);
      }
      return const Color(0xFF39D353);
    } else {
      if (count == 1 || (isLegend && count == 1)) {
        return const Color(0xFF9BE9A8);
      }
      if (count == 2 || (isLegend && count == 2)) {
        return const Color(0xFF40C463);
      }
      if (count == 3 || (isLegend && count == 3)) {
        return const Color(0xFF30A14E);
      }
      return const Color(0xFF216E39);
    }
  }
}
