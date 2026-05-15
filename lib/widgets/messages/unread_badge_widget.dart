import 'package:flutter/material.dart';

class UnreadBadgeWidget extends StatelessWidget {
  final int count;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const UnreadBadgeWidget({
    super.key,
    required this.count,
    this.size = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedOpacity(
      opacity: count > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor ?? colorScheme.error,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Center(
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: TextStyle(
              color: textColor ?? colorScheme.onError,
              fontSize: size * 0.6,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
