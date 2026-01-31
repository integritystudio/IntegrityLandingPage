import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/security_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the SecurityPage widget
  Future<void> pumpSecurityPage(
    WidgetTester tester, {
    VoidCallback? onBack,
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
        home: SecurityPage(onBack: onBack),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('SecurityPage', () {
    group('page structure', () {
      testPageStructure(pumpSecurityPage);

      testWidgets('renders page title in app bar', (tester) async {
        await pumpSecurityPage(tester);

        expect(find.text(SecurityContent.pageTitle), findsWidgets);
      });

      testWidgets('renders Back to Home text button', (tester) async {
        await pumpSecurityPage(tester);

        expect(find.text('Back to Home'), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallbacks(pumpSecurityPage);
    });

    group('hero section', () {
      testWidgets('renders security badge', (tester) async {
        await pumpSecurityPage(tester);

        expect(find.text(SecurityContent.badge), findsOneWidget);
      });

      testWidgets('renders shield check icon in badge', (tester) async {
        await pumpSecurityPage(tester);

        expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      });

      testWidgets('renders subtitle', (tester) async {
        await pumpSecurityPage(tester);

        expect(find.text(SecurityContent.subtitle), findsOneWidget);
      });
    });

    group('security content cards', () {
      testWidgets('renders commitment section with lock icon', (tester) async {
        await pumpSecurityPage(tester);

        expect(find.text(SecurityContent.commitmentTitle), findsOneWidget);
        expect(find.byIcon(LucideIcons.lock), findsOneWidget);
      });

      testWidgets('renders authentication section', (tester) async {
        await pumpSecurityPage(tester);

        // Scroll to find the section
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();

        expect(find.text(SecurityContent.authTitle), findsOneWidget);
      });

      testWidgets('renders data protection section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();

        expect(find.text(SecurityContent.dataProtectionTitle), findsOneWidget);
      });

      testWidgets('renders access control section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pump();

        expect(find.text(SecurityContent.accessControlTitle), findsOneWidget);
      });

      testWidgets('renders enterprise identity section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1000));
        await tester.pump();

        expect(
            find.text(SecurityContent.enterpriseIdentityTitle), findsOneWidget);
      });

      testWidgets('renders compliance section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1500));
        await tester.pump();

        expect(find.text(SecurityContent.complianceTitle), findsOneWidget);
      });

      testWidgets('renders API security section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2500));
        await tester.pump();

        expect(find.text(SecurityContent.apiSecurityTitle), findsOneWidget);
      });

      testWidgets('renders best practices section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3000));
        await tester.pump();

        expect(find.text(SecurityContent.bestPracticesTitle), findsOneWidget);
      });

      testWidgets('renders reporting section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4000));
        await tester.pump();

        expect(find.text(SecurityContent.reportingTitle), findsOneWidget);
      });
    });

    group('stats cards', () {
      testWidgets('renders security stats', (tester) async {
        await pumpSecurityPage(tester);

        // First stat
        expect(find.text(SecurityContent.stats[0].value), findsOneWidget);
        expect(find.text(SecurityContent.stats[0].label), findsOneWidget);
      });

      testWidgets('renders all stat values', (tester) async {
        await pumpSecurityPage(tester);

        for (final stat in SecurityContent.stats) {
          expect(find.text(stat.value), findsOneWidget);
        }
      });
    });

    group('checklist items', () {
      testWidgets('renders auth feature items', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();

        // Check for first auth feature
        expect(find.text(SecurityContent.authFeatures[0].title), findsOneWidget);
      });

      testWidgets('renders check icons for checklist items', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();

        // Multiple check icons for checklist items
        expect(find.byIcon(LucideIcons.check), findsWidgets);
      });
    });

    group('alerts', () {
      testWidgets('renders warning alert with secrets warning', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pump();

        expect(find.text(SecurityContent.secretsWarning), findsOneWidget);
      });

      testWidgets('renders danger alert with vulnerability warning',
          (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4500));
        await tester.pump();

        expect(
            find.text(SecurityContent.vulnerabilityWarning), findsOneWidget);
      });
    });

    group('contact box', () {
      testWidgets('renders security contact section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4500));
        await tester.pump();

        expect(find.text('Security Contact'), findsOneWidget);
      });

      testWidgets('renders security email', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4500));
        await tester.pump();

        expect(
            find.textContaining(SecurityContent.securityEmail), findsOneWidget);
      });

      testWidgets('renders response time text', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4500));
        await tester.pump();

        expect(find.text(SecurityContent.responseTime), findsOneWidget);
      });
    });

    group('footer', () {
      test('SecurityContent has lastUpdated defined', () {
        expect(SecurityContent.lastUpdated, isNotEmpty);
        expect(SecurityContent.lastUpdated, contains('Last Updated'));
      });

      test('CompanyInfo has name defined', () {
        expect(CompanyInfo.name, isNotEmpty);
        expect(CompanyInfo.name, equals('Integrity Studio'));
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<SecurityPage>(
        pumpSecurityPage,
        expectedTitle: SecurityContent.pageTitle,
      );
    });

    group('section icons', () {
      testWidgets('renders correct icons for each section', (tester) async {
        await pumpSecurityPage(tester);

        // Icons visible in initial view
        expect(find.byIcon(LucideIcons.lock), findsOneWidget);
        expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);

        // Scroll to see more icons
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();

        expect(find.byIcon(LucideIcons.user), findsOneWidget);
      });

      testWidgets('renders database icon for data protection', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump();

        expect(find.byIcon(LucideIcons.database), findsOneWidget);
      });

      testWidgets('renders key icon for access control', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pump();

        expect(find.byIcon(LucideIcons.key), findsOneWidget);
      });
    });

    group('sub-sections', () {
      testWidgets('renders encryption sub-section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump();

        expect(find.text('Encryption'), findsOneWidget);
      });

      testWidgets('renders database security sub-section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -650));
        await tester.pump();

        expect(find.text('Database Security'), findsOneWidget);
      });

      testWidgets('renders development practices sub-section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3200));
        await tester.pump();

        expect(find.text('Development Practices'), findsOneWidget);
      });

      testWidgets('renders operational security sub-section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3300));
        await tester.pump();

        expect(find.text('Operational Security'), findsOneWidget);
      });

      testWidgets('renders for users sub-section', (tester) async {
        await pumpSecurityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3400));
        await tester.pump();

        expect(find.text('For Users'), findsOneWidget);
      });
    });
  });
}
