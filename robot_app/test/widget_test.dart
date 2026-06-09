import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_app/main.dart';

void main() {
  testWidgets('shows pad controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PadPage()));

    expect(find.text('192.168.4.1:1234'), findsOneWidget);
  });
}
