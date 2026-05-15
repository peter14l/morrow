import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/widgets/dotted_border_painter.dart';

void main() {
  group('DottedBorder Tests', () {
    testWidgets('DottedBorder renders child', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DottedBorder(child: Text('Hello World'))),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('DottedBorder applies borderRadius', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DottedBorder(
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      final dottedBorder = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(DottedBorder),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = dottedBorder.painter as DottedBorderPainter;
      expect(painter.borderRadius, BorderRadius.circular(10));
    });
  });
}
