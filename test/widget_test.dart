// KazeGarage widget test

import 'package:flutter_test/flutter_test.dart';
import 'package:kaze_garage/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const KazeGarageApp());
    await tester.pumpAndSettle();
    // App should show loading or main screen
    expect(find.text('KazeGarage'), findsOneWidget);
  });
}
