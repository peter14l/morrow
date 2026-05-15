import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonContainer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const SkeletonContainer._({
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  const SkeletonContainer.square({
    required double size,
    BorderRadius? borderRadius,
  }) : this._(width: size, height: size, borderRadius: borderRadius);

  const SkeletonContainer.rounded({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) : this._(
         width: width,
         height: height,
         borderRadius:
             borderRadius ?? const BorderRadius.all(Radius.circular(12)),
       );

  const SkeletonContainer.circular({required double size})
    : this._(width: size, height: size, shape: BoxShape.circle);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.light
        ? Colors.grey[300]!
        : Colors.grey[800]!;
    final highlightColor = theme.brightness == Brightness.light
        ? Colors.grey[100]!
        : Colors.grey[700]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: shape == BoxShape.rectangle
              ? (borderRadius ?? BorderRadius.circular(8))
              : null,
          shape: shape,
        ),
      ),
    );
  }
}
