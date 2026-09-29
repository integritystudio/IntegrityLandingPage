import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:integrity_studio_ai/pages/auth_page.dart';
import 'package:integrity_studio_ai/services/auth0_config.dart';
import 'package:integrity_studio_ai/services/auth0_service.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/form_fields.dart';

import '../helpers/fake_auth0_browser.dart';
import '../helpers/test_helpers.dart';

/// AuthPage contract: no credentials are entered on this site. The one action
/// sends the browser to Auth0 Universal Login; the link goes to signup.
void main() {
  late FakeAuth0Browser browser;

  setUp(() {
    setUpOverflowErrorSuppression();
    initializeTestContent();
    browser = FakeAuth0Browser();
    Auth0Service.setForTesting(browser: browser);
  });

  tearDown(() {
    Auth0Service.resetForTesting();
    tearDownOverflowErrorSuppression();
  });

  Future<void> pumpAuthPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    bool mobile = false,
  }) async {
    mobile ? setMobileSize(tester) : setDesktopSize(tester);
    await tester.pumpWidget(MaterialApp.router(
      theme: testTheme,
      routerConfig: GoRouter(
        initialLocation: Routes.login,
        routes: [
          GoRoute(
            path: Routes.login,
            builder: (_, _) => AuthPage(onBack: onBack),
          ),
          GoRoute(
            path: Routes.signup,
            builder: (_, _) => const Scaffold(body: Text('signup_page')),
          ),
        ],
      ),
    ));
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  Finder continueButton() => find.widgetWithText(GradientButton, 'Continue to Sign In');

  testWidgets('shows no credential fields: the password is entered on Auth0', (tester) async {
    await pumpAuthPage(tester);

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(FormTextField), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(continueButton(), findsOneWidget);
  });

  testWidgets('Continue sends the browser to Auth0 login, not sign-up', (tester) async {
    await pumpAuthPage(tester);

    await tester.tap(continueButton());
    await tester.pump();

    final url = browser.lastNavigation!;
    expect(url.host, Auth0Config.domain);
    expect(url.path, '/authorize');
    expect(url.queryParameters, isNot(contains('screen_hint')));
  });

  testWidgets('Continue is disabled once the redirect has started', (tester) async {
    await pumpAuthPage(tester);

    await tester.tap(continueButton());
    await tester.pump();

    // While loading the button shows a spinner in place of its text.
    final button = tester.widget<GradientButton>(find.byType(GradientButton));
    expect(button.onPressed, isNull);
    expect(button.isLoading, isTrue);
    expect(browser.navigations, hasLength(1));
  });

  testWidgets('the sign-up link goes to the signup page', (tester) async {
    await pumpAuthPage(tester);

    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    expect(find.text('signup_page'), findsOneWidget);
  });

  testWidgets('back button triggers onBack when provided', (tester) async {
    var backCalled = false;
    await pumpAuthPage(tester, onBack: () => backCalled = true);

    await tester.tap(find.byIcon(Icons.arrow_back));

    expect(backCalled, isTrue);
  });

  testWidgets('no back button when onBack is null', (tester) async {
    await pumpAuthPage(tester);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('renders on a mobile viewport', (tester) async {
    await pumpAuthPage(tester, mobile: true);

    expect(continueButton(), findsOneWidget);
  });
}
