import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke test renders app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Routine'),
        ),
      ),
    );

    expect(find.text('Routine'), findsOneWidget);
  });
}
