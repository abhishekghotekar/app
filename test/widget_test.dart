// Basic smoke test for the CVAI app.

import 'package:flutter_test/flutter_test.dart';

import 'package:cvai/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CvaiApp(loggedIn: false));
    expect(find.text('CVAI'), findsWidgets);
  });
}
