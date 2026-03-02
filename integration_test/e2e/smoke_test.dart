import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke test — widget renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('smoke')));
    expect(find.text('smoke'), findsOneWidget);
  });
}
