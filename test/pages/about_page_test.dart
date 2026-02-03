import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:integrity_studio_ai/pages/about_page.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  group('AboutPage', () {
    Future<void> pumpAboutPage(
      WidgetTester tester, {
      VoidCallback? onBack,
      VoidCallback? onShowCookieSettings,
      bool setSize = true,
    }) async {
      clearOverflowExceptions(tester);
      if (setSize) setDesktopSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: testTheme,
          home: AboutPage(
            onBack: onBack,
            onShowCookieSettings: onShowCookieSettings,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      clearOverflowExceptions(tester);
    }

    group('constructor', () {
      testWidgets('creates with default parameters', (tester) async {
        await pumpAboutPage(tester);
        expect(find.byType(AboutPage), findsOneWidget);
      });

      testWidgets('creates with onBack callback', (tester) async {
        await pumpAboutPage(tester, onBack: () {});
        expect(find.byType(AboutPage), findsOneWidget);
      });

      testWidgets('creates with onShowCookieSettings callback', (tester) async {
        await pumpAboutPage(tester, onShowCookieSettings: () {});
        expect(find.byType(AboutPage), findsOneWidget);
      });
    });

    group('layout', () {
      testPageStructure(pumpAboutPage);

      testWidgets('renders SelectionArea for text selection', (tester) async {
        await pumpAboutPage(tester);
        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });

    group('app bar', () {
      testWidgets('displays company name', (tester) async {
        await pumpAboutPage(tester);
        expect(find.text(CompanyInfo.name), findsOneWidget);
      });

      testWidgets('has back arrow button', (tester) async {
        await pumpAboutPage(tester);
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      });

      testWidgets('back button triggers onBack callback', (tester) async {
        var backCalled = false;
        await pumpAboutPage(tester, onBack: () => backCalled = true);

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    group('hero section', () {
      testWidgets('displays headline text', (tester) async {
        await pumpAboutPage(tester);
        expect(find.textContaining('Building Trust'), findsOneWidget);
      });

      testWidgets('displays Schedule Demo button', (tester) async {
        await pumpAboutPage(tester);
        expect(find.byType(GradientButton), findsWidgets);
      });

      testWidgets('displays anchor points', (tester) async {
        await pumpAboutPage(tester);
        expect(find.byIcon(LucideIcons.check), findsWidgets);
      });
    });

    group('stats section', () {
      testWidgets('displays By the Numbers heading', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to reveal stats section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump();
        await tester.pump();

        expect(find.text('By the Numbers'), findsOneWidget);
      });
    });

    group('mission and vision section', () {
      testWidgets('displays Our Mission heading', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to reveal section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
        await tester.pump();
        await tester.pump();

        expect(find.text('Our Mission'), findsOneWidget);
      });

      testWidgets('displays Our Vision heading', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to reveal section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
        await tester.pump();
        await tester.pump();

        expect(find.text('Our Vision'), findsOneWidget);
      });
    });

    group('story section', () {
      testWidgets('displays Our Story heading', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to reveal section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
        await tester.pump();
        await tester.pump();

        expect(find.text('Our Story'), findsOneWidget);
      });

      testWidgets('displays story step numbers', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to reveal section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
        await tester.pump();
        await tester.pump();

        expect(find.text('01'), findsOneWidget);
        expect(find.text('02'), findsOneWidget);
        expect(find.text('03'), findsOneWidget);
      });
    });

    group('values section', () {
      testWidgets('displays Our Values heading', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to reveal section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
        await tester.pump();
        await tester.pump();

        expect(find.text('Our Values'), findsOneWidget);
      });
    });

    group('team section', () {
      testWidgets('displays Meet the Team heading', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to reveal section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -3500));
        await tester.pump();
        await tester.pump();

        expect(find.text('Meet the Team'), findsOneWidget);
      });
    });

    group('footer section', () {
      testWidgets('renders FooterSection', (tester) async {
        await pumpAboutPage(tester);

        // Scroll to bottom
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump();

        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('passes onShowCookieSettings to footer', (tester) async {
        await pumpAboutPage(
          tester,
          onShowCookieSettings: () {},
        );

        // Scroll to bottom to render footer
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump();

        expect(find.byType(FooterSection), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testWidgets('renders on mobile viewport', (tester) async {
        setMobileSize(tester);
        await pumpAboutPage(tester, setSize: false);
        expect(find.byType(AboutPage), findsOneWidget);
      });

      testWidgets('renders on tablet viewport', (tester) async {
        setTabletSize(tester);
        await pumpAboutPage(tester, setSize: false);
        expect(find.byType(AboutPage), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        setDesktopSize(tester);
        await pumpAboutPage(tester, setSize: false);
        expect(find.byType(AboutPage), findsOneWidget);
      });
    });
  });
}
