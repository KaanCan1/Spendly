import 'package:flutter_test/flutter_test.dart';

import 'package:spendly/main.dart';

void main() {
  testWidgets('Login screen shows Spendly branding', (WidgetTester tester) async {
    await tester.pumpWidget(const SpendlyApp());
    await tester.pump();
    // AuthGate times out /me after 5s; advance past that.
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Spendly'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
