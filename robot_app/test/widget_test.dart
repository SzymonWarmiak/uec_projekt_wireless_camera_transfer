import 'package:flutter_test/flutter_test.dart';
import 'package:robot_app/main.dart';

void main() {
  testWidgets('shows pad controls', (WidgetTester tester) async {
    await tester.pumpWidget(const RobotPadApp());

    expect(find.text('Basys Cam Pad'), findsOneWidget);
    expect(find.text('Start wideo'), findsOneWidget);
    expect(find.text('Stop wideo'), findsOneWidget);
    expect(find.text('Maska: 0x0  (0000)'), findsOneWidget);
  });
}
