import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests for Content Security Policy configuration in web/index.html.
///
/// Validates that CSP directives are properly configured for security
/// monitoring and compliance.
void main() {
  late String indexHtml;

  setUpAll(() {
    final file = File('web/index.html');
    if (!file.existsSync()) {
      fail('web/index.html not found');
    }
    indexHtml = file.readAsStringSync();
  });

  group('CSP Configuration', () {
    test('has Content-Security-Policy meta tag', () {
      expect(
        indexHtml.contains('http-equiv="Content-Security-Policy"'),
        isTrue,
        reason: 'CSP meta tag should be present',
      );
    });

    test('has report-uri directive for CSP violation reporting', () {
      expect(
        indexHtml.contains('report-uri'),
        isTrue,
        reason: 'CSP should have report-uri directive for violation reporting',
      );
    });

    test('report-uri points to Sentry security endpoint', () {
      // Sentry security endpoint format: https://*.ingest.sentry.io/api/PROJECT_ID/security/
      // sentry_key is a 32-character hex string (public DSN key)
      final reportUriPattern = RegExp(
        r'report-uri\s+https://[a-z0-9]+\.ingest\.(us\.)?sentry\.io/api/\d+/security/\?sentry_key=[a-f0-9]{32}',
      );
      expect(
        reportUriPattern.hasMatch(indexHtml),
        isTrue,
        reason: 'report-uri should point to Sentry security endpoint with 32-char hex key',
      );
    });

    test('connect-src allows CSP report endpoint domain', () {
      // Verify the domain in report-uri is whitelisted in connect-src
      // This ensures browsers can actually send CSP violation reports
      expect(
        indexHtml.contains('connect-src') &&
            indexHtml.contains('https://*.ingest.sentry.io'),
        isTrue,
        reason: 'connect-src must whitelist Sentry ingest domain for reports to be sent',
      );
    });

    test('connect-src includes Sentry ingest domain', () {
      expect(
        indexHtml.contains('https://*.ingest.sentry.io'),
        isTrue,
        reason: 'connect-src should allow Sentry ingest for error reporting',
      );
    });

    test('has strict base-uri directive', () {
      expect(
        indexHtml.contains("base-uri 'self'"),
        isTrue,
        reason: 'base-uri should be restricted to self',
      );
    });

    test('has strict object-src directive', () {
      expect(
        indexHtml.contains("object-src 'none'"),
        isTrue,
        reason: 'object-src should be none to prevent plugin-based attacks',
      );
    });

    test('has form-action directive', () {
      expect(
        indexHtml.contains("form-action 'self'"),
        isTrue,
        reason: 'form-action should be restricted to self',
      );
    });

    test('has upgrade-insecure-requests directive', () {
      expect(
        indexHtml.contains('upgrade-insecure-requests'),
        isTrue,
        reason: 'Should upgrade HTTP requests to HTTPS',
      );
    });

    test('does not have unsafe-eval in script-src', () {
      // wasm-unsafe-eval is acceptable for Flutter WebAssembly
      // but full unsafe-eval should not be present
      final scriptSrc = RegExp(r"script-src[^;]+").firstMatch(indexHtml);
      expect(scriptSrc, isNotNull, reason: 'script-src directive should exist');

      final scriptSrcContent = scriptSrc!.group(0)!;
      // Check for unsafe-eval but not wasm-unsafe-eval
      final hasUnsafeEval = scriptSrcContent.contains("'unsafe-eval'") &&
          !scriptSrcContent.contains("'wasm-unsafe-eval'");
      expect(
        hasUnsafeEval,
        isFalse,
        reason: 'script-src should not have unsafe-eval (wasm-unsafe-eval is acceptable)',
      );
    });
  });

  group('CSP Security Directives', () {
    test('script-src does not allow inline scripts', () {
      // Find the script-src line directly in the HTML
      // The CSP spans multiple lines, each directive on its own line
      final scriptSrcMatch = RegExp(
        r'script-src\s+([^\n;]+)',
        multiLine: true,
      ).firstMatch(indexHtml);
      expect(scriptSrcMatch, isNotNull, reason: 'script-src directive should exist');

      final scriptSrcContent = scriptSrcMatch!.group(1)!;
      expect(
        scriptSrcContent.contains("'unsafe-inline'"),
        isFalse,
        reason: 'script-src should not allow unsafe-inline',
      );
    });

    test('frame-src restricts frame origins', () {
      expect(
        indexHtml.contains('frame-src'),
        isTrue,
        reason: 'frame-src should be defined to restrict iframe sources',
      );
    });

    test('font-src restricts font origins', () {
      expect(
        indexHtml.contains('font-src'),
        isTrue,
        reason: 'font-src should be defined to restrict font sources',
      );
    });
  });
}
