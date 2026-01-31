import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/resources_section.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ResourcesSection', () {
    group('widget structure', () {
      testWidgets('renders section title', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        expect(find.text(AppContent.resources.title), findsOneWidget);
      });

      testWidgets('renders section subtitle', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        expect(find.text(AppContent.resources.subtitle), findsOneWidget);
      });

      testWidgets('renders all 4 documentation category titles', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        for (final doc in AppContent.resources.documentation) {
          expect(find.text(doc.title), findsOneWidget);
        }
      });

      testWidgets('renders blog post titles', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        for (final post in AppContent.resources.featuredPosts) {
          expect(find.text(post.title), findsOneWidget);
        }
      });

      testWidgets('renders blog CTA', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        expect(find.text(AppContent.resources.blogCtaText), findsOneWidget);
      });

      testWidgets('renders docs CTA', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        expect(find.text(AppContent.resources.docsCtaText), findsOneWidget);
      });
    });

    group('blog posts', () {
      testWidgets('renders blog post categories', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        for (final post in AppContent.resources.featuredPosts) {
          expect(find.text(post.category), findsWidgets);
        }
      });

      testWidgets('renders blog post read times', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        for (final post in AppContent.resources.featuredPosts) {
          expect(find.text(post.readTime), findsWidgets);
        }
      });
    });

    group('accessibility', () {
      testWidgets('documentation categories are accessible', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        final semanticsHandle = tester.ensureSemantics();
        await tester.pumpWidget(testableSection(const ResourcesSection()));
        await tester.pumpAndSettle();

        expect(find.text('Getting Started'), findsOneWidget);
        expect(find.text('API Reference'), findsOneWidget);

        semanticsHandle.dispose();
      });
    });
  });
}
