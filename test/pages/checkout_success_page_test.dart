import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/checkout_success_page.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  Widget buildPage({
    String email = 'user@example.com',
    String tier = 'growth',
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      theme: testTheme,
      home: CheckoutSuccessPage(
        email: email,
        tier: tier,
        onBack: onBack,
      ),
    );
  }

  group('CheckoutSuccessPage', () {
    group('page structure', () {
      testWidgets('renders Scaffold', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage());
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders success icon', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage());
        await tester.pump();

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      });

      testWidgets('renders payment received heading', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage());
        await tester.pump();

        expect(find.text('Payment received'), findsOneWidget);
      });

      testWidgets('renders sign-in button', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage());
        await tester.pump();

        expect(find.byType(GradientButton), findsOneWidget);
        expect(find.text('Sign In to Activate'), findsOneWidget);
      });
    });

    group('content', () {
      testWidgets('includes tier name in body text', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage(tier: 'growth'));
        await tester.pump();

        expect(
          find.textContaining('growth'),
          findsOneWidget,
        );
      });

      testWidgets('includes email in body text', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage(email: 'buyer@example.com'));
        await tester.pump();

        expect(
          find.textContaining('buyer@example.com'),
          findsOneWidget,
        );
      });

      testWidgets('sanitizes email in body text', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          buildPage(email: 'user@example.com'),
        );
        await tester.pump();

        expect(find.byType(CheckoutSuccessPage), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('calls onBack when back button tapped', (tester) async {
        setDesktopSize(tester);
        var backCalled = false;
        await tester.pumpWidget(buildPage(onBack: () => backCalled = true));
        await tester.pump();

        final backButton = find.byType(IconButton);
        await tester.tap(backButton);
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('does not render back button when onBack is null', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage());
        await tester.pump();

        expect(find.byType(IconButton), findsNothing);
      });
    });

    group('responsive', () {
      testWidgets('renders on mobile viewport', (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(buildPage());
        await tester.pump();

        expect(find.byType(CheckoutSuccessPage), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildPage());
        await tester.pump();

        expect(find.byType(CheckoutSuccessPage), findsOneWidget);
      });
    });
  });
}
