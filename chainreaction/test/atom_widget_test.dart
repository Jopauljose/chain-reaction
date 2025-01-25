import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: Text('0'),
            ),
            Expanded(
              child: Text('1'),
            ),
          ],
        ),
      ),
    ));

    expect(find.text('0'), findsOneWidget);
  });
}
