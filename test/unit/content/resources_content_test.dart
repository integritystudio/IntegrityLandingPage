import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {

  group('ResourcesContent', () {
    group('current content', () {
      test('has required fields', () {
        final content = AppContent.resources;

        expect(content.sectionId, equals('resources'));
        expect(content.title, isNotEmpty);
        expect(content.subtitle, isNotEmpty);
        expect(content.blogCtaText, isNotEmpty);
        expect(content.blogCtaUrl, isNotEmpty);
        expect(content.docsCtaText, isNotEmpty);
        expect(content.docsCtaUrl, isNotEmpty);
      });

      test('has 4 documentation categories', () {
        final content = AppContent.resources;

        expect(content.documentation.length, equals(4));
      });

      test('documentation categories cover key areas', () {
        final content = AppContent.resources;
        final titles = content.documentation.map((d) => d.title).toList();

        expect(titles, contains('Getting Started'));
        expect(titles, contains('API Reference'));
        expect(titles, contains('Compliance Guides'));
        expect(titles, contains('Integrations'));
      });

      test('each documentation category has required fields', () {
        final content = AppContent.resources;

        for (final doc in content.documentation) {
          expect(doc.icon, isNotNull);
          expect(doc.title, isNotEmpty);
          expect(doc.description, isNotEmpty);
          expect(doc.url, isNotEmpty);
          expect(doc.popularTopics, isNotEmpty);
          expect(doc.popularTopics.length, greaterThanOrEqualTo(3));
        }
      });

      test('has 3 featured blog posts', () {
        final content = AppContent.resources;

        // TODO: Update to 5 when missing blog HTML files are created:
        // - web/blog/eu-ai-act-engineering-guide.html
        // - web/blog/ai-agent-observability-guide.html
        expect(content.featuredPosts.length, equals(3));
      });

      test('each blog post has required fields', () {
        final content = AppContent.resources;

        for (final post in content.featuredPosts) {
          expect(post.title, isNotEmpty);
          expect(post.excerpt, isNotEmpty);
          expect(post.category, isNotEmpty);
          expect(post.publishDate, isNotEmpty);
          expect(post.readTime, isNotEmpty);
          expect(post.slug, isNotEmpty);
        }
      });

      test('blog posts cover content pillars', () {
        final content = AppContent.resources;
        final categories =
            content.featuredPosts.map((p) => p.category.toLowerCase()).toSet();

        // TODO: Re-enable when eu-ai-act-engineering-guide.html is created
        // expect(categories, contains('compliance'));
        expect(categories, contains('cost optimization'));
        expect(categories, contains('best practices'));
      });

    });

    group('DocCategoryContent', () {
      test('creates with all required fields', () {
        const doc = DocCategoryContent(
          icon: LucideIcons.bookOpen,
          title: 'Test Docs',
          description: 'Test description',
          url: '/docs/test',
          popularTopics: ['Topic 1', 'Topic 2'],
        );

        expect(doc.icon, equals(LucideIcons.bookOpen));
        expect(doc.title, equals('Test Docs'));
        expect(doc.description, equals('Test description'));
        expect(doc.url, equals('/docs/test'));
        expect(doc.popularTopics.length, equals(2));
      });
    });

    group('BlogPostPreviewContent', () {
      test('creates with all required fields', () {
        const post = BlogPostPreviewContent(
          title: 'Test Post',
          excerpt: 'Test excerpt',
          category: 'Test Category',
          publishDate: '2024-12-15',
          readTime: '5 min read',
          slug: 'test-post',
          featuredImageAsset: 'assets/test.png',
          author: 'Test Author',
        );

        expect(post.title, equals('Test Post'));
        expect(post.excerpt, equals('Test excerpt'));
        expect(post.category, equals('Test Category'));
        expect(post.publishDate, equals('2024-12-15'));
        expect(post.readTime, equals('5 min read'));
        expect(post.slug, equals('test-post'));
        expect(post.featuredImageAsset, equals('assets/test.png'));
        expect(post.author, equals('Test Author'));
      });

      test('optional fields default to null', () {
        const post = BlogPostPreviewContent(
          title: 'Test',
          excerpt: 'Excerpt',
          category: 'Cat',
          publishDate: '2024-01-01',
          readTime: '3 min',
          slug: 'test',
        );

        expect(post.featuredImageAsset, isNull);
        expect(post.author, isNull);
      });
    });

    group('LeadMagnetContent', () {
      test('creates with all required fields', () {
        const magnet = LeadMagnetContent(
          icon: LucideIcons.fileText,
          title: 'Test Guide',
          description: 'Test description',
          format: 'PDF',
          ctaText: 'Download',
          url: '/resources/test',
          requiresEmail: true,
        );

        expect(magnet.icon, equals(LucideIcons.fileText));
        expect(magnet.title, equals('Test Guide'));
        expect(magnet.format, equals('PDF'));
        expect(magnet.requiresEmail, isTrue);
      });

      test('requiresEmail defaults to true', () {
        const magnet = LeadMagnetContent(
          icon: LucideIcons.file,
          title: 'Default',
          description: 'Desc',
          format: 'PDF',
          ctaText: 'Get',
          url: '/test',
        );

        expect(magnet.requiresEmail, isTrue);
      });
    });

    group('ResourcesContent constructor', () {
      test('creates with all required fields', () {
        const content = ResourcesContent(
          sectionId: 'test-resources',
          title: 'Test Resources',
          subtitle: 'Test Subtitle',
          documentation: [],
          featuredPosts: [],
          leadMagnets: [],
          blogCtaText: 'View Blog',
          blogCtaUrl: '/blog',
          docsCtaText: 'View Docs',
          docsCtaUrl: '/docs',
        );

        expect(content.sectionId, equals('test-resources'));
        expect(content.title, equals('Test Resources'));
        expect(content.documentation, isEmpty);
        expect(content.featuredPosts, isEmpty);
        expect(content.leadMagnets, isEmpty);
      });
    });

    group('content quality', () {
      test('getting started mentions 5 minutes setup', () {
        final content = AppContent.resources;
        final gettingStarted = content.documentation.firstWhere(
          (d) => d.title.toLowerCase().contains('getting started'),
        );

        expect(
          gettingStarted.description.toLowerCase(),
          contains('5 minutes'),
        );
      });

      test('compliance guides mentions EU AI Act', () {
        final content = AppContent.resources;
        final compliance = content.documentation.firstWhere(
          (d) => d.title.toLowerCase().contains('compliance'),
        );

        expect(
          compliance.popularTopics.any((t) => t.contains('EU AI Act')),
          isTrue,
        );
      });

      test('blog posts have authors', () {
        final content = AppContent.resources;

        for (final post in content.featuredPosts) {
          expect(post.author, isNotNull);
        }
      });
    });
  });
}
