import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/legal_page.dart';
import 'package:lucide_icons/lucide_icons.dart';
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

      testWidgets('factory constructors accept onBack callback', (tester) async {
        var backCalled = false;
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: LegalPage.privacy(onBack: () => backCalled = true),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(backCalled, isTrue);
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

      testWidgets('back button triggers onBack callback', (tester) async {
        var backCalled = false;
        await pumpLegalPage(
          tester,
          LegalPageType.privacy,
          onBack: () => backCalled = true,
        );

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('Back to Home button triggers onBack callback',
          (tester) async {
        var backCalled = false;
        await pumpLegalPage(
          tester,
          LegalPageType.privacy,
          onBack: () => backCalled = true,
        );

        await tester.tap(find.text(CTAText.backToHome));
        await tester.pump();

        expect(backCalled, isTrue);
      });
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
      testWidgets('renders on mobile viewport', (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const LegalPage(type: LegalPageType.privacy),
          ),
        );
        await tester.pump();

        expect(find.byType(LegalPage), findsOneWidget);
      });

      testWidgets('renders on tablet viewport', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const LegalPage(type: LegalPageType.privacy),
          ),
        );
        await tester.pump();

        expect(find.byType(LegalPage), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const LegalPage(type: LegalPageType.privacy),
          ),
        );
        await tester.pump();

        expect(find.byType(LegalPage), findsOneWidget);
      });
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
