import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';

/// A widget that wraps its child and applies a grayscale filter
/// when the digital wellbeing intentional limit is reached.
/// This acts as a "dopamine detox" by removing color stimulation.
class GrayscaleDetox extends StatelessWidget {
  final Widget child;
  final bool isEnabled;

  const GrayscaleDetox({super.key, required this.child, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return child;

    return Consumer<DigitalWellbeingService>(
      builder: (context, wellbeing, _) {
        if (!wellbeing.isLimitReached) return child;

        // Grayscale matrix for ColorFiltered
        // This converts everything to B/W with 100% saturation removal
        const double grey = 0.2126;
        const double green = 0.7152;
        const double blue = 0.0722;

        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            grey,
            green,
            blue,
            0,
            0,
            grey,
            green,
            blue,
            0,
            0,
            grey,
            green,
            blue,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: child,
        );
      },
    );
  }
}
