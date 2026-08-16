import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/docs/doc_components.dart' show DocTable, kDocBulletChar;
import '../widgets/navigation/doc_page_scaffold.dart';
import '../widgets/sections/page_hero_section.dart';

/// Legal page type enum.
enum LegalPageType { privacy, terms, cookies, accessibility }

/// Legal page displaying Privacy Policy, Terms of Service, Cookies Policy,
/// or Accessibility Statement.
///
/// Copy lives in [LegalContent]; this page only renders it with:
/// - Responsive layout
/// - Proper heading hierarchy
/// - Section organization
/// - Back navigation
class LegalPage extends StatelessWidget {
  final LegalPageType type;
  final VoidCallback? onBack;

  const LegalPage({
    super.key,
    required this.type,
    this.onBack,
  });

  /// Factory constructor for Privacy Policy page.
  factory LegalPage.privacy({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.privacy,
        onBack: onBack,
      );

  /// Factory constructor for Terms of Service page.
  factory LegalPage.terms({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.terms,
        onBack: onBack,
      );

  /// Factory constructor for Cookies Policy page.
  factory LegalPage.cookies({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.cookies,
        onBack: onBack,
      );

  /// Factory constructor for Accessibility Statement page.
  factory LegalPage.accessibility({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.accessibility,
        onBack: onBack,
      );

  LegalDocContent get _doc => switch (type) {
        LegalPageType.privacy => LegalContent.privacy,
        LegalPageType.terms => LegalContent.terms,
        LegalPageType.cookies => LegalContent.cookies,
        LegalPageType.accessibility => LegalContent.accessibility,
      };

  IconData get _icon => switch (type) {
        LegalPageType.privacy => LucideIcons.shield,
        LegalPageType.terms => LucideIcons.fileText,
        LegalPageType.cookies => LucideIcons.cookie,
        LegalPageType.accessibility => LucideIcons.accessibility,
      };

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final doc = _doc;

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: CustomScrollView(
        slivers: [
          DocPageAppBar(title: doc.title, onBack: onBack),

          // Hero Section
          SliverToBoxAdapter(
            child: PageHeroSection(
              isMobile: isMobile,
              accentColor: AppColors.blue400,
              badgeIcon: _icon,
              badgeText: doc.badge,
              headline: doc.title,
              subheadline: doc.subtitle,
              subheadlineMaxWidth: 600,
              mobileHeadlineFontSize: 32,
              extraContent: Text(
                'Last updated: ${doc.lastUpdated}',
                style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in doc.sections)
                      _LegalSection(
                        title: section.title,
                        content: section.content,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Footer spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxxl),
          ),
        ],
      ),
    );
  }
}

/// A legal section with title and content.
class _LegalSection extends StatelessWidget {
  final String title;
  final String content;

  const _LegalSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headingSM.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _MarkdownText(content: content),
        ],
      ),
    );
  }
}

/// Simple markdown-like text rendering: bullets, full-line bold, inline bold,
/// and pipe tables (rendered via [DocTable]).
class _MarkdownText extends StatelessWidget {
  final String content;

  const _MarkdownText({required this.content});

  static final RegExp _boldPattern = RegExp(r'\*\*(.+?)\*\*');

  /// Matches a table separator row such as `|----|:---:|`.
  static final RegExp _tableSeparator = RegExp(r'^[-:\s|]+$');
  static final TextStyle _bodyStyle = AppTypography.bodyMD.copyWith(
    color: AppColors.gray300,
    height: 1.6,
  );
  static final TextStyle _boldSpanStyle = _bodyStyle.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );
  static final TextStyle _boldLineStyle = AppTypography.bodyMD.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );
  static final TextStyle _bulletStyle = AppTypography.bodyMD.copyWith(
    color: AppColors.blue400,
  );

  @override
  Widget build(BuildContext context) {
    final lines = content.trim().split('\n');
    final widgets = <Widget>[];

    var i = 0;
    while (i < lines.length) {
      final trimmed = lines[i].trim();
      if (trimmed.startsWith('|')) {
        // Pipe table: consume the whole block of consecutive `|` lines
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildTable(tableLines),
          ),
        );
        continue;
      }
      i++;
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.md));
      } else if (trimmed.startsWith('- ')) {
        // Bullet point
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$kDocBulletChar ', style: _bulletStyle),
                Expanded(
                  child: _parseInlineFormatting(trimmed.substring(2)),
                ),
              ],
            ),
          ),
        );
      } else if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
        // Bold heading-like line
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              trimmed.replaceAll('**', ''),
              style: _boldLineStyle,
            ),
          ),
        );
      } else {
        // Regular paragraph
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _parseInlineFormatting(trimmed),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Renders [text] with inline `**bold**` spans over the body style.
  Widget _parseInlineFormatting(String text) {
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in _boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(text: match.group(1), style: _boldSpanStyle));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(TextSpan(children: spans), style: _bodyStyle);
  }

  /// Renders a block of markdown pipe-table lines as a [DocTable].
  /// The first row is the header; separator rows (`|---|`) are dropped.
  Widget _buildTable(List<String> tableLines) {
    final parsed = [
      for (final line in tableLines)
        if (!_tableSeparator.hasMatch(line)) _splitTableRow(line),
    ];
    if (parsed.isEmpty) return const SizedBox.shrink();

    return DocTable(headers: parsed.first, rows: parsed.sublist(1));
  }

  List<String> _splitTableRow(String line) {
    final parts = line.split('|');
    // A well-formed row `| a | b |` splits into ['', ' a ', ' b ', ''].
    return [
      for (final part in parts.sublist(1, parts.length - 1)) part.trim(),
    ];
  }
}
