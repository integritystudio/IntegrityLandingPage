import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:integrity_studio_ai/pages/signup_page.dart';
import 'package:integrity_studio_ai/services/auth0_config.dart';
import 'package:integrity_studio_ai/services/auth0_service.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/form_fields.dart';
import 'package:integrity_studio_ai/widgets/common/gradient_page_shell.dart';
import '../helpers/fake_auth0_browser.dart';
import '../helpers/test_helpers.dart';

/// SignupPage contract: collects the email (and, for enterprise, the company),
/// validates it and the terms box locally, then hands off to Auth0's sign-up
/// screen with the tier and company carried as a SignupIntent. No password is
/// entered on this site.
void main() {
  late FakeAuth0Browser browser;

  setUp(() {
    browser = FakeAuth0Browser();
    Auth0Service.setForTesting(browser: browser);
  });

  tearDown(Auth0Service.resetForTesting);

  group('SignupPage', () {
    void setLargeViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Widget buildSignupPage({String tier = 'starter', VoidCallback? onBack}) {
      return MaterialApp(
        theme: testTheme,
        home: SignupPage(tier: tier, onBack: onBack),
      );
    }

    group('widget structure', () {
      testWidgets('renders SignupPage', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders Scaffold', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders GradientPageShell', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientPageShell), findsOneWidget);
      });
    });

    group('form fields', () {
      testWidgets('renders FormTextField widgets', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Email only: the password is set on Auth0's sign-up screen.
        expect(find.byType(FormTextField), findsOneWidget);
      });

      testWidgets('renders Checkbox for terms agreement', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('renders GradientButton for submit', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientButton), findsOneWidget);
      });
    });

    group('tier display', () {
      testWidgets('renders with starter tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'starter'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with growth tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'growth'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with enterprise tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('form interaction', () {
      testWidgets('can enter text in the email field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
        await tester.pump();

        expect(find.text('user@example.com'), findsOneWidget);
      });

      testWidgets('can toggle terms checkbox', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        final checkbox = find.byType(Checkbox);
        expect(checkbox, findsOneWidget);

        // Get initial state
        final initialCheckbox = tester.widget<Checkbox>(checkbox);
        expect(initialCheckbox.value, isFalse);

        // Tap to toggle
        await tester.tap(checkbox);
        await tester.pump();

        // Check new state
        final updatedCheckbox = tester.widget<Checkbox>(checkbox);
        expect(updatedCheckbox.value, isTrue);
      });
    });

    group('navigation', () {
      testWidgets('onBack callback is called when provided', (tester) async {
        setLargeViewport(tester);
        var backCalled = false;

        await tester.pumpWidget(buildSignupPage(onBack: () => backCalled = true));
        await tester.pump();

        // Find and tap the back button (first IconButton)
        final iconButtons = find.byType(IconButton);
        expect(iconButtons, findsWidgets);

        await tester.tap(iconButtons.first);
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    group('responsive design', () {
      testWidgets('renders on mobile viewport', (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders on tablet viewport', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('form validation', () {
      testWidgets('submit button exists', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientButton), findsOneWidget);
      });

      testWidgets('tapping submit without filling form shows validation', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Tap submit button
        final submitButton = find.byType(GradientButton);
        await tester.tap(submitButton);
        await tester.pump();

        // Form should still be visible (validation prevents submission)
        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('widget disposal', () {
      testWidgets('disposes without error', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Replace with different widget to trigger dispose
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const Scaffold(body: Text('Replaced')),
          ),
        );
        await tester.pump();

        expect(find.byType(SignupPage), findsNothing);
      });
    });

    group('tier-specific form fields', () {
      testWidgets('shows no password field on any tier', (tester) async {
        setLargeViewport(tester);
        for (final tier in SignupTiers.all) {
          await tester.pumpWidget(buildSignupPage(tier: tier));
          await tester.pump();

          expect(find.textContaining('Password'), findsNothing, reason: tier);
          final obscured = tester
              .widgetList<EditableText>(find.byType(EditableText))
              .any((et) => et.obscureText);
          expect(obscured, isFalse, reason: tier);
        }
      });

      testWidgets('non-enterprise does not show company field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: SignupTiers.starter));
        await tester.pump();

        expect(find.text('Company Name'), findsNothing);
      });

      testWidgets('enterprise shows the company field alongside email', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: SignupTiers.enterprise));
        await tester.pump();

        expect(find.text('Company Name'), findsOneWidget);
        expect(find.byType(FormTextField), findsNWidgets(2));
      });
    });

    group('button text', () {
      testWidgets('non-enterprise shows Start Free Trial', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: SignupTiers.starter));
        await tester.pump();

        expect(find.text('Start Free Trial'), findsOneWidget);
      });

      testWidgets('enterprise shows Create Account', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: SignupTiers.enterprise));
        await tester.pump();

        expect(find.text('Create Account'), findsOneWidget);
      });
    });

    group('validation', () {
      Future<void> submit(WidgetTester tester, {String email = '', bool agree = false}) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();
        if (email.isNotEmpty) {
          await tester.enterText(find.byType(TextFormField).first, email);
        }
        if (agree) await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.byType(GradientButton));
        await tester.pump();
      }

      testWidgets('an empty email is refused before leaving the site', (tester) async {
        await submit(tester, agree: true);

        expect(find.text('Please enter your email'), findsOneWidget);
        expect(browser.navigations, isEmpty);
      });

      testWidgets('a malformed email is refused', (tester) async {
        await submit(tester, email: 'not-an-email', agree: true);

        expect(find.text('Please enter a valid email'), findsOneWidget);
        expect(browser.navigations, isEmpty);
      });

      testWidgets('the terms must be agreed to', (tester) async {
        await submit(tester, email: 'user@example.com');

        expect(
          find.text('Please agree to the Terms of Service and Privacy Policy'),
          findsOneWidget,
        );
        expect(browser.navigations, isEmpty);
      });
    });

    group('submission', () {
      Future<void> fillAndSubmit(
        WidgetTester tester, {
        required String tier,
        String? company,
      }) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: tier));
        await tester.pump();
        await tester.enterText(find.byType(TextFormField).at(0), ' user@example.com ');
        if (company != null) {
          await tester.enterText(find.byType(TextFormField).at(1), company);
        }
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.byType(GradientButton));
        await tester.pump();
      }

      SignupIntent? storedIntent() => SignupIntent.tryDecode(
          browser.stores[BrowserStore.session]!['auth0_signup_intent']);

      testWidgets('opens the Auth0 sign-up screen with the email pre-filled', (tester) async {
        await fillAndSubmit(tester, tier: SignupTiers.starter);

        final url = browser.lastNavigation!;
        expect(url.host, Auth0Config.domain);
        expect(url.path, '/authorize');
        expect(url.queryParameters['screen_hint'], 'signup');
        expect(url.queryParameters['login_hint'], 'user@example.com');
      });

      testWidgets('carries the tier across the redirect, with no org name', (tester) async {
        await fillAndSubmit(tester, tier: SignupTiers.growth);

        expect(storedIntent()?.tier, SignupTiers.growth);
        expect(storedIntent()?.orgName, isNull);
      });

      testWidgets('enterprise carries the company as the org name', (tester) async {
        await fillAndSubmit(tester, tier: SignupTiers.enterprise, company: ' Acme Corp ');

        expect(storedIntent()?.tier, SignupTiers.enterprise);
        expect(storedIntent()?.orgName, 'Acme Corp');
      });

      testWidgets('enterprise without a company leaves the name to the receiver', (tester) async {
        await fillAndSubmit(tester, tier: SignupTiers.enterprise);

        expect(storedIntent()?.orgName, isNull);
      });

      testWidgets('disables the button once the redirect has started', (tester) async {
        await fillAndSubmit(tester, tier: SignupTiers.starter);

        final button = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(button.onPressed, isNull);
        expect(find.text('Redirecting...'), findsOneWidget);
      });
    });
  });
}
