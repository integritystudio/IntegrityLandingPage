import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/oauth_callback_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the OAuthCallbackPage widget with larger viewport
  Future<void> pumpOAuthCallbackPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
    String? code,
    String? state,
    String? error,
    String? errorDescription,
    bool mobile = false,
  }) async {
    clearOverflowExceptions(tester);

    if (mobile) {
      setMobileSize(tester);
    } else {
      setScreenSize(tester, TestScreenSizes.desktopLarge);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: OAuthCallbackPage(
          onBack: onBack,
          onShowCookieSettings: onShowCookieSettings,
          code: code,
          state: state,
          error: error,
          errorDescription: errorDescription,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    clearOverflowExceptions(tester);
  }

  /// Helper to scroll and clear overflow exceptions
  Future<void> scrollDown(WidgetTester tester, double offset) async {
    await tester.drag(find.byType(CustomScrollView), Offset(0, -offset));
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  group('OAuthCallbackPage', () {
    group('page structure', () {
      testWidgets('renders company name in app bar', (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(find.text(CompanyInfo.name), findsOneWidget);
      });

      testWidgets('renders shield icon in app bar', (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });

      testWidgets('renders back arrow in app bar', (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      });
    });

    group('success state', () {
      testWidgets('renders success icon when code is provided', (tester) async {
        await pumpOAuthCallbackPage(tester, code: 'test_auth_code');

        expect(find.byIcon(LucideIcons.checkCircle2), findsOneWidget);
      });

      testWidgets('renders Authentication Successful heading', (tester) async {
        await pumpOAuthCallbackPage(tester, code: 'test_auth_code');

        expect(find.text('Authentication Successful'), findsOneWidget);
      });

      testWidgets('renders success message', (tester) async {
        await pumpOAuthCallbackPage(tester, code: 'test_auth_code');

        expect(
          find.textContaining('Google account has been connected'),
          findsOneWidget,
        );
      });

      testWidgets('renders Back to Home button', (tester) async {
        await pumpOAuthCallbackPage(tester, code: 'test_auth_code');

        expect(find.text('Back to Home'), findsOneWidget);
      });

      testWidgets('renders Go to Dashboard button', (tester) async {
        await pumpOAuthCallbackPage(tester, code: 'test_auth_code');

        expect(find.text('Go to Dashboard'), findsOneWidget);
      });
    });

    group('error state', () {
      testWidgets('renders error icon when error is provided', (tester) async {
        await pumpOAuthCallbackPage(tester, error: 'access_denied');

        expect(find.byIcon(LucideIcons.xCircle), findsOneWidget);
      });

      testWidgets('renders Authentication Failed heading', (tester) async {
        await pumpOAuthCallbackPage(tester, error: 'access_denied');

        expect(find.text('Authentication Failed'), findsOneWidget);
      });

      testWidgets('renders error description when provided', (tester) async {
        await pumpOAuthCallbackPage(
          tester,
          error: 'access_denied',
          errorDescription: 'User denied access',
        );

        expect(find.text('User denied access'), findsOneWidget);
      });

      testWidgets('renders error code', (tester) async {
        await pumpOAuthCallbackPage(tester, error: 'access_denied');

        expect(find.textContaining('access_denied'), findsOneWidget);
      });

      testWidgets('renders Try Again button', (tester) async {
        await pumpOAuthCallbackPage(tester, error: 'access_denied');

        expect(find.text('Try Again'), findsOneWidget);
      });
    });

    group('processing state', () {
      testWidgets('renders loading indicator when no code or error',
          (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders Processing Authentication heading', (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(find.text('Processing Authentication'), findsOneWidget);
      });

      testWidgets('renders processing message', (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(
          find.textContaining('Please wait'),
          findsOneWidget,
        );
      });
    });

    group('navigation', () {
      testWidgets('calls onBack when back button is pressed', (tester) async {
        var backCalled = false;
        await pumpOAuthCallbackPage(
          tester,
          onBack: () => backCalled = true,
          code: 'test_code',
        );

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('renders navigation links on desktop', (tester) async {
        await pumpOAuthCallbackPage(tester, mobile: false);

        expect(find.text('Features'), findsWidgets);
        expect(find.text('Pricing'), findsWidgets);
      });

      testWidgets('renders popup menu on mobile', (tester) async {
        await pumpOAuthCallbackPage(tester, mobile: true);

        expect(find.byIcon(LucideIcons.menu), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testWidgets('desktop renders correctly', (tester) async {
        await pumpOAuthCallbackPage(tester, mobile: false);

        expect(find.byType(OAuthCallbackPage), findsOneWidget);
      });

      testWidgets('mobile renders correctly', (tester) async {
        await pumpOAuthCallbackPage(tester, mobile: true);

        expect(find.byType(OAuthCallbackPage), findsOneWidget);
      });

      testWidgets('tablet viewport renders correctly', (tester) async {
        setTabletSize(tester);
        clearOverflowExceptions(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const OAuthCallbackPage(),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(OAuthCallbackPage), findsOneWidget);
      });
    });

    group('footer section', () {
      testWidgets('includes FooterSection widget when scrolled into view',
          (tester) async {
        await pumpOAuthCallbackPage(tester, code: 'test_code');

        await scrollDown(tester, 800);

        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('page structure includes footer in slivers', (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(find.byType(OAuthCallbackPage), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('back button has tooltip', (tester) async {
        await pumpOAuthCallbackPage(tester);

        final iconButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, LucideIcons.arrowLeft),
        );
        expect(iconButton.tooltip, equals('Back'));
      });

      testWidgets('text content is selectable', (tester) async {
        await pumpOAuthCallbackPage(tester);

        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });
  });
}
