import 'package:flutter_test/flutter_test.dart';
import 'package:elcora_dely/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DeliverApp());

    // Advance time to allow animations to complete
    await tester.pump(const Duration(seconds: 3));

    // Verify that the splash screen shows the app title.
    // Note: The text might be found even if not fully visible, but we check its presence.
    expect(find.text('El Corazon Dely'), findsOneWidget);
  });
}
