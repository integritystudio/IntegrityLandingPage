import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/pages/compliance_page.dart';
import 'package:integrity_studio_ai/pages/docs_index_page.dart';
import 'package:integrity_studio_ai/pages/help_center_page.dart';
import 'package:integrity_studio_ai/pages/pricing_page.dart';
import 'package:integrity_studio_ai/pages/request_failure_page.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/navigation/shared_app_bar.dart';

import '../helpers/test_content.dart';
import '../helpers/test_helpers.dart';

/// Every link to the contact page reads `urls.internal.contact` (7e1f3c2). Production's
/// value is the old literal, so each row runs with the value swapped: a call site that
/// still hard-codes '/contact' lands nowhere near the destination below.
void main() {
  const testContactUrl = '/test-contact';
  const destination = 'contact destination';
  const scrollStep = 300.0;

  final sites = <({String name, Widget page, Finder link})>[
    (name: "compliance's Contact Us", page: const CompliancePage(), link: find.text('Contact Us')),
    // The enterprise tier card says Contact Sales too; the page's own CTA is the GradientButton.
    (
      name: "pricing's Contact Sales",
      page: const PricingPage(),
      link: find.widgetWithText(GradientButton, 'Contact Sales'),
    ),
    (name: "the help center's Contact Support", page: const HelpCenterPage(), link: find.text('Contact Support')),
    (name: "request-failure's Try Again", page: const RequestFailurePage(), link: find.text('Try Again')),
    (name: "the docs index's Support quick link", page: const DocsIndexPage(), link: find.text('Support')),
    (
      name: "the sub-page app bar's Contact",
      page: Scaffold(body: CustomScrollView(slivers: [SharedAppBar.subPage()])),
      link: find.text('Contact'),
    ),
  ];

  for (final site in sites) {
    testWidgets('${site.name} goes to urls.internal.contact', (tester) async {
      withContent(await realContentWith('contact: "/contact"', 'contact: "$testContactUrl"'));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => site.page),
          GoRoute(path: testContactUrl, builder: (_, _) => const Scaffold(body: Text(destination))),
        ],
      );
      setDesktopSize(tester);
      clearOverflowExceptions(tester);
      await tester.pumpWidget(MaterialApp.router(theme: testTheme, routerConfig: router));
      await tester.pump();

      // Builds a lazily built link, then jumps to it; the pump lays out the jump.
      await tester.scrollUntilVisible(site.link, scrollStep, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(site.link);
      await tester.pump();
      await tester.pump();
      clearOverflowExceptions(tester);

      expect(find.text(destination), findsOneWidget);
    });
  }
}
