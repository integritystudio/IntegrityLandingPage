import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/legal_page.dart';
import 'package:integrity_studio_ai/widgets/docs/doc_components.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  group('LegalPageType', () {
    test('has all required values', () {
      expect(LegalPageType.values, contains(LegalPageType.privacy));
      expect(LegalPageType.values, contains(LegalPageType.terms));
      expect(LegalPageType.values, contains(LegalPageType.cookies));
      expect(LegalPageType.values, contains(LegalPageType.accessibility));
    });

    test('has exactly 4 values', () {
      expect(LegalPageType.values.length, equals(4));
    });
  });

  group('LegalPage', () {
    Future<void> pumpLegalPage(
      WidgetTester tester,
      LegalPageType type, {
      VoidCallback? onBack,
    }) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: testTheme,
          home: LegalPage(
            type: type,
            onBack: onBack,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    /// [PagePumpFunction] for the shared helpers. Goes through the
    /// [LegalPage.privacy] factory so they also cover its onBack wiring.
    Future<void> pumpPrivacyPage(
      WidgetTester tester, {
      VoidCallback? onBack,
      VoidCallback? onShowCookieSettings,
      bool mobile = false,
    }) async {
      if (mobile) {
        setMobileSize(tester);
      } else {
        setDesktopSize(tester);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: testTheme,
          home: LegalPage.privacy(onBack: onBack),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    group('factory constructors', () {
      testWidgets('LegalPage.privacy creates privacy page', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: LegalPage.privacy(),
          ),
        );
        await tester.pump();

        expect(find.text('Privacy Policy'), findsWidgets);
      });

      testWidgets('LegalPage.terms creates terms page', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: LegalPage.terms(),
          ),
        );
        await tester.pump();

        expect(find.text('Terms of Service'), findsWidgets);
      });

      testWidgets('LegalPage.cookies creates cookies page', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: LegalPage.cookies(),
          ),
        );
        await tester.pump();

        expect(find.text('Cookie Policy'), findsWidgets);
      });

      testWidgets('LegalPage.accessibility creates accessibility page',
          (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: LegalPage.accessibility(),
          ),
        );
        await tester.pump();

        expect(find.text('Accessibility Statement'), findsWidgets);
      });
    });

    group('layout', () {
      testPageStructure(
        (tester) => pumpLegalPage(tester, LegalPageType.privacy),
      );
    });

    group('app bar', () {
      testWidgets('has Back to Home text button', (tester) async {
        await pumpLegalPage(tester, LegalPageType.privacy);
        expect(find.text(CTAText.backToHome), findsOneWidget);
      });

      testBackButtonCallbacks(pumpPrivacyPage);
    });

    group('privacy policy page', () {
      testWidgets('displays Privacy Policy title', (tester) async {
        await pumpLegalPage(tester, LegalPageType.privacy);
        expect(find.text('Privacy Policy'), findsWidgets);
      });

      testWidgets('displays Your Privacy Matters badge', (tester) async {
        await pumpLegalPage(tester, LegalPageType.privacy);
        expect(find.text('Your Privacy Matters'), findsOneWidget);
      });

      testWidgets('displays shield icon', (tester) async {
        await pumpLegalPage(tester, LegalPageType.privacy);
        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });

      testWidgets('displays last updated date', (tester) async {
        await pumpLegalPage(tester, LegalPageType.privacy);
        expect(find.textContaining('Last updated'), findsOneWidget);
      });

      testWidgets('displays privacy content sections', (tester) async {
        await pumpLegalPage(tester, LegalPageType.privacy);

        // Scroll to reveal content
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();

        expect(find.textContaining('What Data Do We Collect'), findsOneWidget);
      });
    });

    group('terms of service page', () {
      testWidgets('displays Terms of Service title', (tester) async {
        await pumpLegalPage(tester, LegalPageType.terms);
        expect(find.text('Terms of Service'), findsWidgets);
      });

      testWidgets('displays Legal Agreement badge', (tester) async {
        await pumpLegalPage(tester, LegalPageType.terms);
        expect(find.text('Legal Agreement'), findsOneWidget);
      });

      testWidgets('displays file text icon', (tester) async {
        await pumpLegalPage(tester, LegalPageType.terms);
        expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
      });

      testWidgets('displays terms content sections', (tester) async {
        await pumpLegalPage(tester, LegalPageType.terms);

        // Scroll to reveal content
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();

        expect(find.textContaining('Agreement to Terms'), findsOneWidget);
      });
    });

    group('cookie policy page', () {
      testWidgets('displays Cookie Policy title', (tester) async {
        await pumpLegalPage(tester, LegalPageType.cookies);
        expect(find.text('Cookie Policy'), findsWidgets);
      });

      testWidgets('displays Cookie Information badge', (tester) async {
        await pumpLegalPage(tester, LegalPageType.cookies);
        expect(find.text('Cookie Information'), findsOneWidget);
      });

      testWidgets('displays cookie icon', (tester) async {
        await pumpLegalPage(tester, LegalPageType.cookies);
        expect(find.byIcon(LucideIcons.cookie), findsOneWidget);
      });

      testWidgets('displays cookie content sections', (tester) async {
        await pumpLegalPage(tester, LegalPageType.cookies);

        // Scroll to reveal content
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();

        expect(find.textContaining('Introduction'), findsOneWidget);
      });

      testWidgets('renders the cookie category table as a DocTable',
          (tester) async {
        await pumpLegalPage(tester, LegalPageType.cookies);

        expect(find.byType(DocTable), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Essential'), findsOneWidget);
        // No raw markdown pipe rows leak into the rendered text
        expect(find.textContaining('| Category'), findsNothing);
      });
    });

    group('accessibility statement page', () {
      testWidgets('displays Accessibility Statement title', (tester) async {
        await pumpLegalPage(tester, LegalPageType.accessibility);
        expect(find.text('Accessibility Statement'), findsWidgets);
      });

      testWidgets('displays Inclusive Design badge', (tester) async {
        await pumpLegalPage(tester, LegalPageType.accessibility);
        expect(find.text('Inclusive Design'), findsOneWidget);
      });

      testWidgets('displays accessibility icon', (tester) async {
        await pumpLegalPage(tester, LegalPageType.accessibility);
        expect(find.byIcon(LucideIcons.accessibility), findsOneWidget);
      });

      testWidgets('displays accessibility content sections', (tester) async {
        await pumpLegalPage(tester, LegalPageType.accessibility);

        // Scroll to reveal content
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();

        expect(find.textContaining('Commitment to Accessibility'), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<LegalPage>(pumpPrivacyPage, includeTablet: true);
    });

    group('all page types render without error', () {
      for (final type in LegalPageType.values) {
        testWidgets('$type page renders successfully', (tester) async {
          await pumpLegalPage(tester, type);
          expect(find.byType(LegalPage), findsOneWidget);
        });
      }
    });
  });
}
