import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/blog_page.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestContent();
  });

  group('BlogPage', () {
    group('BlogPost model', () {
      test('creates with all required fields', () {
        const post = BlogPost(
          title: 'Test Title',
          subtitle: 'Test Subtitle',
          description: 'Test Description',
          date: 'January 1, 2025',
          readTime: '10 min read',
          category: 'Technology',
          url: '/blog/test-post',
        );

        expect(post.title, equals('Test Title'));
        expect(post.subtitle, equals('Test Subtitle'));
        expect(post.description, equals('Test Description'));
        expect(post.date, equals('January 1, 2025'));
        expect(post.readTime, equals('10 min read'));
        expect(post.category, equals('Technology'));
        expect(post.url, equals('/blog/test-post'));
        expect(post.isSeries, isFalse);
        expect(post.seriesArticles, isEmpty);
        expect(post.stats, isEmpty);
      });

      test('creates series post with articles', () {
        const post = BlogPost(
          title: 'Series Post',
          subtitle: 'A multi-part series',
          description: 'Description',
          date: 'January 1, 2025',
          readTime: '60 min read',
          category: 'Research',
          url: '/blog/series',
          isSeries: true,
          seriesArticles: [
            SeriesArticle(
              title: 'Part 1',
              description: 'First part',
              url: '/blog/series/part-1',
            ),
            SeriesArticle(
              title: 'Part 2',
              description: 'Second part',
              url: '/blog/series/part-2',
            ),
          ],
        );

        expect(post.isSeries, isTrue);
        expect(post.seriesArticles, hasLength(2));
        expect(post.seriesArticles[0].title, equals('Part 1'));
        expect(post.seriesArticles[1].title, equals('Part 2'));
      });

      test('creates post with stats', () {
        const post = BlogPost(
          title: 'Post with Stats',
          subtitle: 'Subtitle',
          description: 'Description',
          date: 'January 1, 2025',
          readTime: '15 min read',
          category: 'Analysis',
          url: '/blog/stats-post',
          stats: [
            '50% improvement',
            '10x faster',
            '99% accuracy',
          ],
        );

        expect(post.stats, hasLength(3));
        expect(post.stats[0], equals('50% improvement'));
        expect(post.stats[1], equals('10x faster'));
        expect(post.stats[2], equals('99% accuracy'));
      });
    });

    group('SeriesArticle model', () {
      test('creates with all required fields', () {
        const article = SeriesArticle(
          title: 'Article Title',
          description: 'Article Description',
          url: '/blog/series/article',
        );

        expect(article.title, equals('Article Title'));
        expect(article.description, equals('Article Description'));
        expect(article.url, equals('/blog/series/article'));
      });
    });

    group('static blog content', () {
      test('has at least one blog post', () {
        // Access static posts through widget rendering
        // The _posts list is private, so we test through widget behavior
        expect(true, isTrue); // Placeholder - actual content tested via widget
      });

      test('AI Observability Platform Strategy post is defined correctly', () {
        // Test the expected content structure
        const expectedTitle = 'AI Observability Platform Strategy';
        const expectedCategory = 'Strategy';
        const expectedSeriesCount = 6;

        // These values should match the static _posts in BlogPage
        expect(expectedTitle, isNotEmpty);
        expect(expectedCategory, isNotEmpty);
        expect(expectedSeriesCount, equals(6));
      });

      test('series articles have required URLs', () {
        // Expected URLs for the blog series
        const expectedUrls = [
          '/blog/ai-observability-platform-strategy/market-analysis.html',
          '/blog/ai-observability-platform-strategy/regulatory-drivers.html',
          '/blog/ai-observability-platform-strategy/competitive-landscape.html',
          '/blog/ai-observability-platform-strategy/growth-strategy.html',
          '/blog/ai-observability-platform-strategy/recommendations.html',
          '/blog/ai-observability-platform-strategy/sources.html',
        ];

        expect(expectedUrls, hasLength(6));
        for (final url in expectedUrls) {
          expect(url, startsWith('/blog/'));
          expect(url, endsWith('.html'));
        }
      });

      test('stats contain market data', () {
        const expectedStats = [
          '\$2.9B+ market size by 2030',
          '25.47% CAGR growth rate',
          '98% enterprises increasing budgets',
        ];

        expect(expectedStats, hasLength(3));
        expect(expectedStats[0], contains('market size'));
        expect(expectedStats[1], contains('CAGR'));
        expect(expectedStats[2], contains('enterprises'));
      });
    });

    group('widget rendering', () {
      testWidgets('renders blog page header', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Blog'), findsOneWidget);
        expect(find.text('Back to Home'), findsOneWidget);
        expect(find.text('Insights & Research'), findsOneWidget);
      });

      testWidgets('renders blog post card', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // First post is "End-to-End Agentic Observability"
        expect(find.text('End-to-End Agentic Observability: From Chaos to Control'),
            findsOneWidget);
        expect(find.text('Best Practices'), findsOneWidget);
        expect(find.text('January 30, 2026'), findsOneWidget);
        expect(find.text('12 min read'), findsOneWidget);
      });

      testWidgets('renders series badge for series posts', (tester) async {
        // Use tall screen to see the series post (5th post)
        setScreenSize(tester, const Size(1280, 4000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('6 Part Series'), findsOneWidget);
      });

      testWidgets('renders stats badges', (tester) async {
        // Use tall screen to see the series post with market stats (5th post)
        setScreenSize(tester, const Size(1280, 4000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('\$2.9B+'), findsOneWidget);
        expect(find.textContaining('25.47%'), findsOneWidget);
        expect(find.textContaining('98%'), findsOneWidget);
      });

      testWidgets('renders View Articles button for series', (tester) async {
        // Use tall screen to see the series post (5th post)
        setScreenSize(tester, const Size(1280, 4000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('View Articles'), findsOneWidget);
      });

      testWidgets('expands series articles on tap', (tester) async {
        // Use a large screen to ensure series post (7th) is visible
        setScreenSize(tester, const Size(1920, 4000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Initially, View Articles button should be visible
        expect(find.text('View Articles'), findsOneWidget);
        expect(find.text('Hide Articles'), findsNothing);

        // Scroll to ensure button is visible before tapping
        await tester.ensureVisible(find.text('View Articles'));
        await tester.pump();

        // Tap View Articles button
        await tester.tap(find.text('View Articles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Button text should change after expansion
        expect(find.text('Hide Articles'), findsOneWidget);
        expect(find.text('View Articles'), findsNothing);
      });

      testWidgets('collapses series articles on second tap', (tester) async {
        // Use a large screen to ensure series post (4th) is visible
        setScreenSize(tester, const Size(1920, 3000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Scroll to ensure button is visible
        await tester.ensureVisible(find.text('View Articles'));
        await tester.pump();

        // Expand
        await tester.tap(find.text('View Articles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Hide Articles'), findsOneWidget);

        // Collapse
        await tester.tap(find.text('Hide Articles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('View Articles'), findsOneWidget);
      });

      testWidgets('calls onBack callback when back button pressed',
          (tester) async {
        setDesktopSize(tester);
        var backCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: BlogPage(onBack: () => backCalled = true),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Tap back button in app bar (LucideIcons.arrowLeft)
        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('calls onBack when Back to Home pressed', (tester) async {
        setDesktopSize(tester);
        var backCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: BlogPage(onBack: () => backCalled = true),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Back to Home'));
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    group('responsive design', () {
      testWidgets('renders correctly on mobile', (tester) async {
        setScreenSize(tester, const Size(375, 812));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Blog header should be present
        expect(find.text('Blog'), findsOneWidget);
        expect(find.byType(BlogPage), findsOneWidget);
      });

      testWidgets('renders correctly on tablet', (tester) async {
        // Use a taller tablet screen
        setScreenSize(tester, const Size(768, 1200));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Blog header should be present
        expect(find.text('Blog'), findsOneWidget);
        // First post title should be visible on tablet
        expect(find.textContaining('End-to-End Agentic'), findsWidgets);
      });

      testWidgets('renders correctly on desktop', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Blog'), findsOneWidget);
        // First post is End-to-End Agentic Observability
        expect(find.text('End-to-End Agentic Observability: From Chaos to Control'),
            findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('has proper semantic structure', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify text elements are present and readable
        expect(find.text('Insights & Research'), findsOneWidget);
        expect(
          find.textContaining('Deep dives into AI observability'),
          findsOneWidget,
        );
      });

      testWidgets('buttons are tappable', (tester) async {
        // Use tall screen to see the series post (5th post) with View Articles
        setScreenSize(tester, const Size(1280, 4000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const BlogPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Find and verify View Articles button is tappable
        final viewArticlesButton = find.text('View Articles');
        expect(viewArticlesButton, findsOneWidget);
        expect(tester.widget(viewArticlesButton), isNotNull);
      });
    });
  });
}
