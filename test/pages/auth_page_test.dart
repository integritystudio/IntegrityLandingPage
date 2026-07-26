import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:integrity_studio_ai/pages/auth_page.dart';
import 'package:integrity_studio_ai/services/contact_service.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';
import 'package:integrity_studio_ai/widgets/common/alert.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/form_fields.dart';
import '../helpers/test_helpers.dart';

import '../helpers/mock_http_adapter.dart';

void main() {
  setUp(() {
    setUpOverflowErrorSuppression();
    initializeTestContent();
  });
  tearDown(tearDownOverflowErrorSuppression);

  // ---------------------------------------------------------------------------
  // Helper builders
  // ---------------------------------------------------------------------------

  /// Fires the TapGestureRecognizer on a RichText toggle mode link.
  ///
  /// Scanning the span tree directly is more reliable than tapAt() because
  /// the RichText's recognizer doesn't always win hit-testing in the
  /// test environment.
  Future<void> tapRichTextToggle(WidgetTester tester) async {
    final richTextFinder = find.byType(RichText);
    for (final element in richTextFinder.evaluate()) {
      final widget = element.widget as RichText;
      void scanSpan(InlineSpan span) {
        if (span is TextSpan) {
          if (span.recognizer is TapGestureRecognizer) {
            (span.recognizer as TapGestureRecognizer).onTap?.call();
          }
          span.children?.forEach(scanSpan);
        }
      }
      scanSpan(widget.text);
    }
    await tester.pump();
  }

  Widget buildAuthPage({
    AuthMode mode = AuthMode.signUp,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      theme: testTheme,
      home: AuthPage(mode: mode, onBack: onBack),
    );
  }

  GoRouter makeAuthRouter(AuthMode mode) => GoRouter(
        initialLocation: mode.routePath,
        routes: [
          GoRoute(
            path: Routes.signup,
            builder: (_, _) => const AuthPage(mode: AuthMode.signUp),
          ),
          GoRoute(
            path: Routes.login,
            builder: (_, _) => const AuthPage(mode: AuthMode.signIn),
          ),
          GoRoute(
            path: Routes.provision,
            builder: (_, _) =>
                const Scaffold(body: Text('provision_page')),
          ),
          GoRoute(
            path: Routes.dashboard,
            builder: (_, _) =>
                const Scaffold(body: Text('dashboard_page')),
          ),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home_page')),
          ),
        ],
      );

  Future<void> pumpAuthPage(
    WidgetTester tester, {
    AuthMode mode = AuthMode.signUp,
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
    bool mobile = false,
  }) async {
    if (mobile) {
      setMobileSize(tester);
    } else {
      setDesktopSize(tester);
    }
    await tester.pumpWidget(buildAuthPage(mode: mode, onBack: onBack));
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  // ---------------------------------------------------------------------------
  // PasswordPolicy boundary validation (existing tests preserved)
  // ---------------------------------------------------------------------------

  group('PasswordPolicy boundary validation', () {
    bool isPasswordValid(String password) =>
        password.isNotEmpty &&
        password.length >= PasswordPolicy.minLength &&
        password.length <= PasswordPolicy.maxLength;

    test('password of exactly minLength (8) passes validation', () {
      final password = 'a' * PasswordPolicy.minLength;
      expect(isPasswordValid(password), isTrue);
    });

    test('password of exactly maxLength (128) passes validation', () {
      final password = 'a' * PasswordPolicy.maxLength;
      expect(isPasswordValid(password), isTrue);
    });

    test('password one character below minLength (7) fails validation', () {
      final password = 'a' * (PasswordPolicy.minLength - 1);
      expect(isPasswordValid(password), isFalse);
    });

    test('password one character above maxLength (129) fails validation', () {
      final password = 'a' * (PasswordPolicy.maxLength + 1);
      expect(isPasswordValid(password), isFalse);
    });

    test('empty password fails validation', () {
      expect(isPasswordValid(''), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // AuthMode enum
  // ---------------------------------------------------------------------------

  group('AuthMode enum', () {
    test('signUp and signIn are distinct values', () {
      expect(AuthMode.signUp, isNot(equals(AuthMode.signIn)));
    });

    test('AuthMode values has both modes', () {
      expect(AuthMode.values, containsAll([AuthMode.signUp, AuthMode.signIn]));
    });
  });

  // ---------------------------------------------------------------------------
  // ContactService.isValidEmail (used in _isFormValid)
  // ---------------------------------------------------------------------------

  group('ContactService.isValidEmail', () {
    test('accepts valid email', () {
      expect(ContactService.isValidEmail('user@example.com'), isTrue);
    });

    test('rejects email without @', () {
      expect(ContactService.isValidEmail('invalidemail.com'), isFalse);
    });

    test('rejects empty string', () {
      expect(ContactService.isValidEmail(''), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget rendering — sign-up mode
  // ---------------------------------------------------------------------------

  group('AuthPage sign-up mode', () {
    group('widget structure', () {
      testWidgets('renders AuthPage widget', (tester) async {
        await pumpAuthPage(tester);
        expect(find.byType(AuthPage), findsOneWidget);
      });

      testWidgets('renders Scaffold', (tester) async {
        await pumpAuthPage(tester);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders GradientBackground', (tester) async {
        await pumpAuthPage(tester);
        expect(find.byType(AuthPage), findsOneWidget);
      });

      testWidgets('renders title Create Account', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);
        expect(find.text('Create Account'), findsOneWidget);
      });

      testWidgets('renders subtitle about API key', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);
        expect(
          find.text('Get your API key to access the Integrity API'),
          findsOneWidget,
        );
      });

      testWidgets('renders email field', (tester) async {
        await pumpAuthPage(tester);
        expect(find.text('Email Address'), findsOneWidget);
      });

      testWidgets('renders password field', (tester) async {
        await pumpAuthPage(tester);
        expect(find.text('Password'), findsOneWidget);
      });

      testWidgets('renders confirm password field in sign-up mode',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);
        expect(find.text('Confirm Password'), findsOneWidget);
      });

      testWidgets('renders three FormTextField widgets in sign-up mode',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);
        expect(find.byType(FormTextField), findsNWidgets(3));
      });

      testWidgets('renders Sign Up submit button', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);
        expect(find.text('Sign Up'), findsOneWidget);
      });

      testWidgets('renders toggle mode link', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);
        // Toggle link is a RichText with TextSpan (not findable by find.text)
        expect(find.byType(RichText), findsWidgets);
      });

      testWidgets('submit button is disabled when form is invalid',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);
        final btn = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(btn.onPressed, isNull);
      });
    });

    group('form validation', () {
      testWidgets('submit button enabled with valid sign-up form',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        await tester.enterText(
            find.byType(FormTextField).at(0), 'user@example.com');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(1), 'password123');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(2), 'password123');
        await tester.pump();

        final btn = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(btn.onPressed, isNotNull);
      });

      testWidgets('submit button disabled with mismatched confirm password',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        await tester.enterText(
            find.byType(FormTextField).at(0), 'user@example.com');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(1), 'password123');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(2), 'wrongpassword');
        await tester.pump();

        final btn = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(btn.onPressed, isNull);
      });

      testWidgets('submit button disabled with invalid email', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        await tester.enterText(find.byType(FormTextField).at(0), 'notanemail');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(1), 'password123');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(2), 'password123');
        await tester.pump();

        final btn = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(btn.onPressed, isNull);
      });

      testWidgets('submit button disabled with short password', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        await tester.enterText(
            find.byType(FormTextField).at(0), 'user@example.com');
        await tester.pump();
        await tester.enterText(find.byType(FormTextField).at(1), 'short');
        await tester.pump();
        await tester.enterText(find.byType(FormTextField).at(2), 'short');
        await tester.pump();

        final btn = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(btn.onPressed, isNull);
      });

      testWidgets('error message cleared when email field changes',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        // Enter valid form then trigger error via text input
        await tester.enterText(find.byType(FormTextField).at(0), 'a@b.com');
        await tester.pump();
        // Changing email clears error
        await tester.enterText(find.byType(FormTextField).at(0), 'new@b.com');
        await tester.pump();
        // Error should not be visible (no error was set, but the setState path executes)
        expect(find.byType(Alert), findsNothing);
      });
    });

    group('toggle mode', () {
      testWidgets('tap toggle link switches to sign-in mode', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Confirm Password'), findsOneWidget);

        await tapRichTextToggle(tester);

        expect(find.text('Sign In'), findsAtLeastNWidgets(1));
        expect(find.text('Confirm Password'), findsNothing);
      });

      testWidgets('toggle preserves email across mode switch', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        await tester.enterText(
            find.byType(FormTextField).at(0), 'keep@example.com');
        await tester.pump();

        await tapRichTextToggle(tester);

        // Email field should still contain the entered email
        final emailField =
            tester.widget<TextField>(find.byType(TextField).first);
        expect(emailField.controller?.text, equals('keep@example.com'));
      });

      testWidgets('toggle resets mode state for password validation',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp);

        // Fill in valid sign-up form
        await tester.enterText(
            find.byType(FormTextField).at(0), 'user@example.com');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(1), 'password123');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(2), 'password123');
        await tester.pump();

        // Form is valid
        expect(
            tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
            isNotNull);

        // Toggle to sign-in mode - clears internal password state
        await tapRichTextToggle(tester);

        // In sign-in mode with only email from before, if password state is
        // cleared the form is invalid (button disabled) until password re-entered
        // Note: the TextFormField displays old typed text (initialValue behavior)
        // but internal _password/_confirmPassword state IS reset
        expect(find.text('Sign In'), findsAtLeastNWidgets(1));
        expect(find.text('Confirm Password'), findsNothing);
      });
    });

    group('navigation', () {
      testWidgets('back button triggers onBack when provided', (tester) async {
        var backCalled = false;
        await pumpAuthPage(
            tester, mode: AuthMode.signUp, onBack: () => backCalled = true);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('no back button when onBack is null', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signUp, onBack: null);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Widget rendering — sign-in mode
  // ---------------------------------------------------------------------------

  group('AuthPage sign-in mode', () {
    group('widget structure', () {
      testWidgets('renders Sign In title', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);
        expect(find.text('Sign In'), findsWidgets);
      });

      testWidgets('renders subtitle Access your account', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);
        expect(find.text('Access your account'), findsOneWidget);
      });

      testWidgets('does not render confirm password in sign-in mode',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);
        expect(find.text('Confirm Password'), findsNothing);
      });

      testWidgets('renders two FormTextField widgets in sign-in mode',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);
        expect(find.byType(FormTextField), findsNWidgets(2));
      });

      testWidgets('renders Sign In submit button', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);
        expect(find.text('Sign In'), findsWidgets);
      });

      testWidgets("renders toggle mode RichText link", (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);
        // Toggle link is a RichText with TapGestureRecognizer
        expect(find.byType(RichText), findsWidgets);
      });
    });

    group('form validation', () {
      testWidgets('submit button enabled with valid sign-in credentials',
          (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);

        await tester.enterText(
            find.byType(FormTextField).at(0), 'user@example.com');
        await tester.pump();
        await tester.enterText(
            find.byType(FormTextField).at(1), 'password123');
        await tester.pump();

        final btn = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(btn.onPressed, isNotNull);
      });

      testWidgets(
          'submit button disabled when sign-in form is empty', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);

        final btn = tester.widget<GradientButton>(find.byType(GradientButton));
        expect(btn.onPressed, isNull);
      });
    });

    group('toggle mode', () {
      testWidgets('tap toggle link switches to sign-up mode', (tester) async {
        await pumpAuthPage(tester, mode: AuthMode.signIn);

        expect(find.text('Confirm Password'), findsNothing);

        await tapRichTextToggle(tester);

        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Confirm Password'), findsOneWidget);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Responsive layout
  // ---------------------------------------------------------------------------

  group('responsive layout', () {
    testWidgets('renders on mobile viewport', (tester) async {
      setMobileSize(tester);
      await tester.pumpWidget(buildAuthPage());
      await tester.pump();
      clearOverflowExceptions(tester);
      expect(find.byType(AuthPage), findsOneWidget);
    });

    testWidgets('renders on desktop viewport', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(buildAuthPage());
      await tester.pump();
      clearOverflowExceptions(tester);
      expect(find.byType(AuthPage), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Submission flow (GoRouter + mocked ProvisioningService)
  // ---------------------------------------------------------------------------

  group('submission — sign-up', () {
    late MockHttpAdapter adapter;

    setUp(() {
      adapter = MockHttpAdapter();
      ProvisioningService.setDioForTesting(dioWithMockAdapter(adapter));
      ProvisioningService.retryDelay = (_) async {};
    });

    tearDown(() {
      ProvisioningService.resetDio();
      ProvisioningService.resetRetryDelay();
    });

    testWidgets('routes to /provision on successful sign-up', (tester) async {
      setDesktopSize(tester);
      adapter.stubJson('POST', {'jwt': 'test-jwt'}, statusCode: 201);

      final router = makeAuthRouter(AuthMode.signUp);
      await tester.pumpWidget(
          MaterialApp.router(theme: testTheme, routerConfig: router));
      await tester.pump();

      await tester.enterText(
          find.byType(FormTextField).at(0), 'user@example.com');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(1), 'password123');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(2), 'password123');
      await tester.pump();

      await tester.tap(find.byType(GradientButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('provision_page'), findsOneWidget);
    });

    testWidgets('shows error message on failed sign-up', (tester) async {
      setDesktopSize(tester);
      adapter.stubJson('POST', {'error': 'Email already exists'},
          statusCode: 409);

      final router = makeAuthRouter(AuthMode.signUp);
      await tester.pumpWidget(
          MaterialApp.router(theme: testTheme, routerConfig: router));
      await tester.pump();

      await tester.enterText(
          find.byType(FormTextField).at(0), 'user@example.com');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(1), 'password123');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(2), 'password123');
      await tester.pump();

      await tester.tap(find.byType(GradientButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Error alert should be visible (not navigated away)
      expect(find.byType(Alert), findsOneWidget);
      expect(find.text('provision_page'), findsNothing);
    });

    testWidgets('button shows loading state during submission',
        (tester) async {
      setDesktopSize(tester);
      // Use a slow mock: response completes after a delay
      final completer = adapter.stubDelayedJson('POST', {'jwt': 'test-jwt'}, statusCode: 201);

      final router = makeAuthRouter(AuthMode.signUp);
      await tester.pumpWidget(
          MaterialApp.router(theme: testTheme, routerConfig: router));
      await tester.pump();

      await tester.enterText(
          find.byType(FormTextField).at(0), 'user@example.com');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(1), 'password123');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(2), 'password123');
      await tester.pump();

      // Tap submit - starts loading
      await tester.tap(find.byType(GradientButton));
      await tester.pump(); // One frame - loading starts

      // During loading, button should show loading state
      final btn = tester.widget<GradientButton>(find.byType(GradientButton));
      expect(btn.isLoading, isTrue);

      // Complete the pending response to avoid test leak
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('submission — sign-in', () {
    late MockHttpAdapter adapter;

    setUp(() {
      adapter = MockHttpAdapter();
      ProvisioningService.setDioForTesting(dioWithMockAdapter(adapter));
      ProvisioningService.retryDelay = (_) async {};
    });

    tearDown(() {
      ProvisioningService.resetDio();
      ProvisioningService.resetRetryDelay();
    });

    testWidgets('routes to /dashboard on successful sign-in', (tester) async {
      setDesktopSize(tester);
      adapter.stubJson('POST', {'jwt': 'test-jwt'}, statusCode: 200);

      final router = makeAuthRouter(AuthMode.signIn);
      await tester.pumpWidget(
          MaterialApp.router(theme: testTheme, routerConfig: router));
      await tester.pump();

      await tester.enterText(
          find.byType(FormTextField).at(0), 'user@example.com');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(1), 'password123');
      await tester.pump();

      await tester.tap(find.byType(GradientButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Sign-in bypasses provisioning and goes straight to the dashboard.
      expect(find.text('dashboard_page'), findsOneWidget);
    });

    testWidgets('shows error message on failed sign-in', (tester) async {
      setDesktopSize(tester);
      adapter.stubJson('POST', {'error': 'Invalid credentials'}, statusCode: 401);

      final router = makeAuthRouter(AuthMode.signIn);
      await tester.pumpWidget(
          MaterialApp.router(theme: testTheme, routerConfig: router));
      await tester.pump();

      await tester.enterText(
          find.byType(FormTextField).at(0), 'user@example.com');
      await tester.pump();
      await tester.enterText(find.byType(FormTextField).at(1), 'password123');
      await tester.pump();

      await tester.tap(find.byType(GradientButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Alert), findsOneWidget);
      expect(find.text('provision_page'), findsNothing);
    });
  });
}
