import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests for Cloudflare Pages _redirects configuration.
///
/// Validates routing rules to prevent regressions where directory paths
/// (e.g., /blog) incorrectly redirect to / instead of their intended target.
///
/// Root cause (fixed in 0c1b161): A rewrite rule `/blog /index.html 200`
/// caused Cloudflare's pretty-URL normalization to 308 redirect /blog to /
/// (root). The fix is to 301 redirect /blog to /blog/, letting CF serve
/// blog/index.html directly.
void main() {
  late String redirectsContent;
  late List<_RedirectRule> rules;

  setUpAll(() {
    final file = File('web/_redirects');
    if (!file.existsSync()) {
      fail('web/_redirects not found');
    }
    redirectsContent = file.readAsStringSync();
    rules = _parseRedirectRules(redirectsContent);
  });

  group('_redirects file structure', () {
    test('file exists and is non-empty', () {
      expect(redirectsContent.isNotEmpty, isTrue);
    });

    test('has SPA fallback as last rule', () {
      final lastRule = rules.last;
      expect(lastRule.source, equals('/*'));
      expect(lastRule.target, equals('/index.html'));
      expect(lastRule.status, equals(200));
    });

    test('all rules have valid status codes', () {
      const validStatuses = {200, 301, 302, 308};
      for (final rule in rules) {
        expect(
          validStatuses.contains(rule.status),
          isTrue,
          reason: 'Rule "${rule.source}" has invalid status ${rule.status}',
        );
      }
    });
  });

  group('blog routing rules', () {
    test('/blog redirects to /blog/ (not /index.html)', () {
      final blogRule = rules.firstWhere(
        (r) => r.source == '/blog',
        orElse: () => fail('/blog rule not found in _redirects'),
      );
      expect(
        blogRule.target,
        equals('/blog/'),
        reason: '/blog must redirect to /blog/ to avoid CF pretty-URL '
            'normalization redirecting to /',
      );
      expect(
        blogRule.status,
        anyOf(equals(301), equals(302)),
        reason: '/blog should use a redirect status (301 or 302), '
            'not a 200 rewrite',
      );
    });

    test('/blog does not rewrite to root index.html', () {
      final blogRule = rules.firstWhere((r) => r.source == '/blog');
      expect(
        blogRule.target,
        isNot(equals('/index.html')),
        reason: 'Rewriting /blog to /index.html causes CF pretty-URL '
            'normalization to 308 redirect to /',
      );
    });

    test('blog article HTML rules exist', () {
      final articleRule = rules.where(
        (r) => r.source.startsWith('/blog/') && r.source.contains('.html'),
      );
      expect(
        articleRule.isNotEmpty,
        isTrue,
        reason: 'Blog article HTML serving rules should exist',
      );
    });
  });

  group('blog/index.html exists', () {
    test('web/blog/index.html is present', () {
      final file = File('web/blog/index.html');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'blog/index.html must exist so CF serves the SPA at /blog/',
      );
    });

    test('web/blog/index.html contains base href="/"', () {
      final content = File('web/blog/index.html').readAsStringSync();
      expect(
        content.contains('<base href="/">'),
        isTrue,
        reason: 'blog/index.html must have base href="/" for asset resolution',
      );
    });

    test('web/blog/index.html contains Flutter bootstrap', () {
      final content = File('web/blog/index.html').readAsStringSync();
      expect(
        content.contains('flutter_bootstrap.js'),
        isTrue,
        reason: 'blog/index.html must be a Flutter SPA entry point',
      );
    });
  });

  group('directory path safety', () {
    test('no directory paths rewrite to /index.html with 200', () {
      // Directories that exist on disk — rewriting these to /index.html
      // causes CF pretty-URL normalization to 308 redirect to /
      const knownDirs = ['/blog', '/docs', '/icons', '/images', '/internship'];

      for (final dir in knownDirs) {
        final dirRules = rules.where((r) => r.source == dir);
        for (final rule in dirRules) {
          final isUnsafeRewrite =
              rule.target == '/index.html' && rule.status == 200;
          expect(
            isUnsafeRewrite,
            isFalse,
            reason: 'Rule "$dir /index.html 200" causes CF pretty-URL '
                'normalization to 308 redirect to /. '
                'Use a redirect to $dir/ instead.',
          );
        }
      }
    });
  });
}

/// Parsed redirect rule from _redirects file.
class _RedirectRule {
  final String source;
  final String target;
  final int status;

  const _RedirectRule(this.source, this.target, this.status);
}

/// Parse _redirects file into structured rules, skipping comments/blanks.
List<_RedirectRule> _parseRedirectRules(String content) {
  final rules = <_RedirectRule>[];
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final status = int.tryParse(parts[2]);
      if (status != null) {
        rules.add(_RedirectRule(parts[0], parts[1], status));
      }
    }
  }
  return rules;
}
