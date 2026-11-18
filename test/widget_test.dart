// Basic smoke test for the CVAI app.

import 'package:flutter_test/flutter_test.dart';

import 'package:cvai/main.dart';
import 'package:cvai/screens/dashboard/home_screen.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CvaiApp(loggedIn: true));
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
