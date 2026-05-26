import 'package:fluent_ui/fluent_ui.dart';

/// A control that lets the user navigate through a collection of pages using
/// a series of glyphs (pips).
///
/// ![PipsPager example](https://learn.microsoft.com/en-us/windows/apps/design/controls/images/pips-pager-horizontal.png)
///
/// {@tool snippet}
/// This example shows a basic pips pager:
///
/// ```dart
/// PipsPager(
///   numberOfPages: 5,
///   selectedPageIndex: _currentIndex,
///   onPageIndexChanged: (index) {
///     setState(() => _currentIndex = index);
///   },
/// )
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [Pagination], for navigating through large collections of pages
///  * <https://learn.microsoft.com/en-us/windows/apps/design/controls/pips-pager>
class PipsPager extends StatelessWidget {
  /// Creates a pips pager.
  const PipsPager({
    required this.numberOfPages, super.key,
    this.selectedPageIndex = 0,
    this.onPageIndexChanged,
    this.orientation = Axis.horizontal,
    this.visibleNumber = 5,
  }) : assert(numberOfPages >= 0),
       assert(selectedPageIndex >= 0),
       assert(visibleNumber > 0);

  /// The number of pages in the collection.
  final int numberOfPages;

  /// The index of the currently selected page.
  final int selectedPageIndex;

  /// Called when the selected page index changes.
  final ValueChanged<int>? onPageIndexChanged;

  /// The orientation of the pips pager.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis orientation;

  /// The number of pips that are visible at a time.
  ///
  /// Defaults to 5.
  final int visibleNumber;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasFluentTheme(context));
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      child: Flex(
        direction: orientation,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(numberOfPages, (index) {
          final isSelected = index == selectedPageIndex;

          return HoverButton(
            onPressed: onPageIndexChanged != null
                ? () => onPageIndexChanged!(index)
                : null,
            builder: (context, states) {
              return Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedContainer(
                  duration: theme.fasterAnimationDuration,
                  curve: theme.animationCurve,
                  width: isSelected ? 12 : 6,
                  height: orientation == Axis.horizontal
                      ? 6
                      : (isSelected ? 12 : 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.accentColor.defaultBrushFor(theme.brightness)
                        : theme.resources.textFillColorSecondary.withValues(
                            alpha: states.isHovered ? 0.6 : 0.4,
                          ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
