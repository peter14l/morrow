import 'package:flutter/material.dart';
import 'package:oasis/features/circles/presentation/screens/circles_list_screen.dart';

/// The Spaces hub hosts Circles & Communities.
class SpacesScreen extends StatelessWidget {
  final int initialIndex;
  const SpacesScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return const CirclesListScreen();
  }
}
