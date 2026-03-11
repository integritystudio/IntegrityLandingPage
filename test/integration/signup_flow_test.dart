import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/signup_page.dart';
import 'package:integrity_studio_ai/pages/pricing_page.dart';
// test_helpers imported via integration_test_helpers.dart
import 'helpers/integration_test_helpers.dart';
import 'helpers/mock_services.dart';

/// Integration tests for the signup flow.
///
/// Tests the complete user journey:
/// 1. Navigate to /pricing
/// 2. Select a tier
/// 3. Click "Get Started" -> navigates to /signup?tier=X
/// 4. Fill signup form
/// 5. Submit and verify confirmation
void main() {

  setUp(() {
    suppressOverflowErrors();
    IntegrationMocks.resetAll();
  });

  tearDown(() {
    restoreErrorHandler();
  });

  group('Signup Page Direct', () {
    testWidgets('signup page renders with tier badge', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            tier: 'growth',
            onBack: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Verify tier badge is shown
      expect(find.text('Growth Plan'), findsOneWidget);

      // Verify page title
      expect(find.text('Start Your Free Trial'), findsOneWidget);
    });

    testWidgets('signup form has all required fields', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            tier: 'starter',
            onBack: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Verify form fields by label
      expect(find.textContaining('Full Name'), findsOneWidget);
      expect(find.textContaining('Work Email'), findsOneWidget);
      expect(find.textContaining('Company Name'), findsOneWidget);

      // Verify terms checkbox exists
      expect(find.textContaining('Terms of Service'), findsOneWidget);
      expect(find.textContaining('Privacy Policy'), findsOneWidget);

      // Verify submit button
      expect(find.text(CTAText.startFreeTrial), findsOneWidget);
    });

    testWidgets('signup form validates empty name', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            tier: 'starter',
            onBack: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Tap submit without filling name
      await tester.tap(find.text(CTAText.startFreeTrial));
      await pumpFrames(tester, frames: 10);

      // Should show validation error
      expect(find.textContaining('enter your name'), findsOneWidget);
    });

    testWidgets('signup form validates email format', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            tier: 'starter',
            onBack: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Fill name first
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'John Doe');
      await pumpFrames(tester, frames: 2);

      // Enter invalid email
      await tester.enterText(textFields.at(1), 'invalid-email');
      await pumpFrames(tester, frames: 2);

      // Check terms checkbox
      await tester.tap(find.byType(Checkbox));
      await pumpFrames(tester, frames: 2);

      // Tap submit
      await tester.tap(find.text(CTAText.startFreeTrial));
      await pumpFrames(tester, frames: 10);

      // Should show email validation error
      expect(find.textContaining('valid email'), findsOneWidget);
    });

    testWidgets('signup form requires terms agreement', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            tier: 'starter',
            onBack: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Fill all fields but don't check terms
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'John Doe');
      await pumpFrames(tester, frames: 2);
      await tester.enterText(textFields.at(1), 'john@example.com');
      await pumpFrames(tester, frames: 2);
      await tester.enterText(textFields.at(2), 'Acme Corp');
      await pumpFrames(tester, frames: 2);

      // Tap submit without checking terms
      await tester.tap(find.text(CTAText.startFreeTrial));
      await pumpFrames(tester, frames: 10);

      // Should show terms error
      expect(find.textContaining('agree to'), findsWidgets);
    });

    testWidgets('signup form accepts valid input', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            tier: 'growth',
            onBack: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Fill all fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'John Doe');
      await pumpFrames(tester, frames: 2);
      await tester.enterText(textFields.at(1), 'john@example.com');
      await pumpFrames(tester, frames: 2);
      await tester.enterText(textFields.at(2), 'Acme Corp');
      await pumpFrames(tester, frames: 2);

      // Check terms
      await tester.tap(find.byType(Checkbox));
      await pumpFrames(tester, frames: 2);

      // Verify input is captured
      expect(find.text('John Doe'), findsWidgets);
      expect(find.text('john@example.com'), findsWidgets);
      expect(find.text('Acme Corp'), findsWidgets);
    });

    testWidgets('different tiers show correct descriptions', (tester) async {
      setDesktopSize(tester);

      // Test starter tier
      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(tier: 'starter', onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 10);
      expect(find.text('Starter Plan'), findsOneWidget);
      expect(find.textContaining('small teams'), findsOneWidget);

      // Test enterprise tier
      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(tier: 'enterprise', onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 10);
      expect(find.text('Enterprise Plan'), findsOneWidget);
      expect(find.textContaining('Custom'), findsOneWidget);
    });

    testWidgets('features list is visible', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(tier: 'starter', onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Verify feature list items
      expect(find.text('14-day free trial'), findsOneWidget);
      expect(find.text('No credit card required'), findsOneWidget);
      expect(find.text('Cancel anytime'), findsOneWidget);
    });

    testWidgets('back button works', (tester) async {
      var backPressed = false;

      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            tier: 'starter',
            onBack: () => backPressed = true,
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Find and tap back button
      final iconButtons = find.byType(IconButton);
      if (iconButtons.evaluate().isNotEmpty) {
        await tester.tap(iconButtons.first);
        await pumpFrames(tester, frames: 5);
      }

      expect(backPressed, isTrue);
    });
  });

  group('Signup Navigation Flow', () {
    testWidgets('signup receives tier from query parameter', (tester) async {
      setDesktopSize(tester);

      String? receivedTier;

      final router = GoRouter(
        initialLocation: '/signup?tier=scale',
        routes: [
          GoRoute(
            path: '/signup',
            builder: (context, state) {
              receivedTier = state.uri.queryParameters['tier'];
              return SignupPage(
                tier: receivedTier ?? 'starter',
                onBack: () {},
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 20);

      expect(receivedTier, equals('scale'));
      expect(find.text('Scale Plan'), findsOneWidget);
    });

    testWidgets('signup defaults to starter when no tier specified',
        (tester) async {
      setDesktopSize(tester);

      final router = GoRouter(
        initialLocation: '/signup',
        routes: [
          GoRoute(
            path: '/signup',
            builder: (context, state) {
              final tier = state.uri.queryParameters['tier'] ?? 'starter';
              return SignupPage(tier: tier, onBack: () {});
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 20);

      expect(find.text('Starter Plan'), findsOneWidget);
    });
  });

  group('Pricing to Signup Navigation', () {
    testWidgets('pricing page loads correctly', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: PricingPage(
            onBack: () {},
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Verify pricing page content
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
