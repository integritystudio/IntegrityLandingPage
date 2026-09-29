import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/compliance_page.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';
import '../helpers/test_content.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);

  testWidgets('describes the Contact Us link with copy from content.yaml', (tester) async {
    // Placeholder values that differ from the production copy, so a hard-coded
    // string on the page cannot pass.
    ContentLoader.loadFromString(contentLoaderTestYaml);
    addTearDown(initializeTestContent);
    setDesktopSize(tester);

    await tester.pumpApp(const CompliancePage());

    expect(find.text('Compliance Contact Link Description', skipOffstage: false), findsOneWidget);
  });
}
