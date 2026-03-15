/// Blog content configuration.
///
/// Contains blog post models and content for the blog listing page.
/// Blog content is loaded from content.yaml at runtime.
library;

import '../../services/content_loader.dart';

/// A single blog post entry.
class BlogPost {
  final String title;
  final String subtitle;
  final String description;
  final String date;
  final String readTime;
  final String category;
  final String url;
  final bool isSeries;
  final bool isInternal;
  final List<SeriesArticle> seriesArticles;
  final List<String> stats;

  const BlogPost({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.date,
    required this.readTime,
    required this.category,
    required this.url,
    this.isSeries = false,
    this.isInternal = false,
    this.seriesArticles = const [],
    this.stats = const [],
  });

  /// Create a BlogPost from a YAML map.
  factory BlogPost.fromMap(Map<String, dynamic> map) {
    final seriesArticlesData = map['series_articles'] as List?;
    final statsData = map['stats'] as List?;

    return BlogPost(
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      description: map['description'] as String? ?? '',
      date: map['date'] as String? ?? '',
      readTime: map['read_time'] as String? ?? '',
      category: map['category'] as String? ?? '',
      url: map['url'] as String? ?? '',
      isSeries: map['is_series'] as bool? ?? false,
      isInternal: map['is_internal'] as bool? ?? false,
      seriesArticles: seriesArticlesData
              ?.map((e) => SeriesArticle.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      stats: statsData?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

/// An article within a blog series.
class SeriesArticle {
  final String title;
  final String description;
  final String url;

  const SeriesArticle({
    required this.title,
    required this.description,
    required this.url,
  });

  /// Create a SeriesArticle from a YAML map.
  factory SeriesArticle.fromMap(Map<String, dynamic> map) {
    return SeriesArticle(
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      url: map['url'] as String? ?? '',
    );
  }
}

/// Blog content provider.
///
/// Loads blog posts from content.yaml via [ContentLoader].
abstract final class BlogContent {
  /// Page title from YAML.
  static String get pageTitle => ContentLoader.blogPageTitle;

  /// Page subtitle from YAML.
  static String get pageSubtitle => ContentLoader.blogPageSubtitle;

  /// All blog posts, ordered by date (newest first).
  ///
  /// Loaded from content.yaml at runtime.
  static List<BlogPost> get posts =>
      ContentLoader.blogPosts.map((map) => BlogPost.fromMap(map)).toList();
}
