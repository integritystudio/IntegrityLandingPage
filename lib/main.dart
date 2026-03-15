import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart' hide ContentLoader;

import 'app.dart';
import 'services/content_loader.dart';
import 'services/tracking.dart';

// =============================================================================
// Configuration Constants
// =============================================================================

/// Sentry configuration loaded from compile-time environment variables.
///
/// Build with:
/// ```bash
/// flutter build web \
///   --dart-define=SENTRY_DSN=your-dsn \
///   --dart-define=ENVIRONMENT=production \
///   --dart-define=APP_VERSION=2.0.0 \
///   --dart-define=LANGTRACE_API_KEY=your-langtrace-api-key
/// ```
abstract final class SentryConfig {
  /// Sentry DSN (Data Source Name) for error reporting.
  static const dsn = String.fromEnvironment('SENTRY_DSN');

  /// Current environment (development, staging, production).
  static const environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// App version for release tracking.
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '2.0.0',
  );

  /// Whether Sentry is configured (DSN is provided).
  static bool get isConfigured => dsn.isNotEmpty;

  /// Percentage of transactions to sample for performance monitoring.
  static const tracesSampleRate = 0.2;

  /// Percentage of transactions to profile.
  static const profilesSampleRate = 0.2;
}

/// Langtrace configuration for Claude Code subscription-based API key.
///
/// Langtrace provides observability for LLM applications.
/// Configure via compile-time environment variable:
/// ```bash
/// flutter build web --dart-define=LANGTRACE_API_KEY=your-api-key
/// ```
abstract final class LantraceConfig {
  /// Langtrace API key for LLM observability.
  static const apiKey = String.fromEnvironment('LANGTRACE_API_KEY');

  /// Whether Langtrace is configured (API key is provided).
  static bool get isConfigured => apiKey.isNotEmpty;
}

// =============================================================================
// Application Entry Point
// =============================================================================

/// Application entry point.
///
/// Initializes:
/// 1. Flutter bindings
/// 2. GTM Consent Mode v2 (default denied state)
/// 3. Sentry error tracking (if configured)
/// 4. The main application widget
Future<void> main() async {
  // Use path-based URLs (e.g., /eu-ai-act) instead of hash-based (e.g., /#/eu-ai-act)
  // This must be called before runApp() for deep linking to work
  usePathUrlStrategy();

  // Initialize Marionette for AI agent testing in debug mode.
  // Guard: if a binding already exists (e.g. IntegrationTestWidgetsFlutterBinding
  // from flutter drive), skip MarionetteBinding to avoid a duplicate-binding crash.
  if (kDebugMode) {
    try {
      MarionetteBinding.ensureInitialized();
    } on Object {
      // Binding already initialized (integration test environment)
    }
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  // Enable semantics tree for accessibility and E2E testing
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // Load content from YAML before app starts
  try {
    await ContentLoader.load();
  } on ContentLoadException catch (e, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: e,
      stack: stackTrace,
      library: 'content_loader',
      context: ErrorDescription('loading content.yaml at app startup'),
    ));
    rethrow;
  }

  // Initialize GTM Consent Mode with default denied state (GDPR requirement)
  // This MUST happen before GTM loads to ensure proper consent handling
  if (kIsWeb) {
    TrackingWeb.initializeConsentMode();
  }

  if (SentryConfig.isConfigured) {
    await _initializeWithSentry();
  } else {
    _runAppWithoutSentry();
  }
}

/// Initialize app with Sentry error tracking.
Future<void> _initializeWithSentry() async {
  await SentryFlutter.init(
    (options) {
      // Core configuration
      options.dsn = SentryConfig.dsn;
      options.environment = SentryConfig.environment;
      options.release = 'integrity-studio@${SentryConfig.appVersion}';

      // Performance monitoring
      options.tracesSampleRate = SentryConfig.tracesSampleRate;
      options.profilesSampleRate = SentryConfig.profilesSampleRate;
      options.enableAutoPerformanceTracing = true;

      // Error capture enhancements
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
      options.reportSilentFlutterErrors = true;

      // Debug breadcrumbs
      options.maxBreadcrumbs = 100;
    },
    appRunner: () => runApp(const IntegrityStudioApp()),
  );
}

/// Run app without Sentry (for development without DSN).
void _runAppWithoutSentry() {
  runApp(const IntegrityStudioApp());
}
