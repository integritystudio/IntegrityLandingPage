import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'tracking.dart';

// =============================================================================
// Analytics Event Types
// =============================================================================

/// Supported analytics event types.
///
/// Using an enum prevents typos and enables IDE autocomplete.
enum AnalyticsEvent {
  pageView('page_view'),
  ctaClick('cta_click'),
  formSubmission('form_submission'),
  pricingTierView('pricing_tier_view'),
  scrollDepth('scroll_depth'),
  featureInteraction('feature_interaction'),
  pricingToggle('pricing_toggle'),
  externalLinkClick('external_link_click'),
  demoRequest('demo_request'),
  leadMagnetDownload('lead_magnet_download'),
  blogPostClick('blog_post_click');

  final String name;
  const AnalyticsEvent(this.name);
}

// =============================================================================
// Analytics Service (GA4)
// =============================================================================

/// Analytics service using JavaScript interop for GA4.
///
/// Key design decisions:
/// - Initializes ONLY after user consent (GDPR compliance)
/// - Scripts loaded dynamically, not in index.html
/// - No Firebase SDK dependency (smaller bundle)
///
/// Usage:
/// ```dart
/// await AnalyticsService.initialize();
/// AnalyticsService.trackPageView('landing');
/// ```
class AnalyticsService {
  AnalyticsService._();

  static bool _initialized = false;
  static bool _enabled = true;

  /// Whether analytics is ready to track events.
  static bool get isReady => _initialized && _enabled;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initialize GA4 analytics after user consent.
  ///
  /// Injects GTM script dynamically (not loaded in index.html for GDPR).
  static Future<void> initialize() async {
    if (_initialized || !kIsWeb) return;

    try {
      // Inject GTM script after consent
      TrackingWeb.injectGTM();
      _initialized = true;
      _log('Analytics initialized - GTM injected');
    } catch (e, stackTrace) {
      _log('Failed to initialize analytics: $e');
      await ErrorTrackingService.captureException(
        e,
        stackTrace: stackTrace,
        context: 'AnalyticsService.initialize',
      );
    }
  }

  /// Disable analytics (consent revocation).
  static void disable() {
    _enabled = false;
    _log('Analytics disabled');
  }

  /// Enable analytics (re-consent).
  static void enable() {
    _enabled = true;
    _log('Analytics enabled');
  }

  // ---------------------------------------------------------------------------
  // Page & Navigation Tracking
  // ---------------------------------------------------------------------------

  /// Track page view with optional referral source.
  static void trackPageView(String pageName, {String? ref}) {
    _track(AnalyticsEvent.pageView, {
      'page_title': pageName,
      'page_location': pageName,
      if (ref != null) 'page_referrer': ref,
    });
  }

  /// Track scroll depth (fires at 25%, 50%, 75%, 100%).
  static void trackScrollDepth(int percentage) {
    if (percentage % 25 != 0) return;

    _track(AnalyticsEvent.scrollDepth, {
      'percentage': percentage,
    });
  }

  // ---------------------------------------------------------------------------
  // User Interaction Tracking
  // ---------------------------------------------------------------------------

  /// Track CTA button click.
  static void trackCTAClick({
    required String buttonName,
    required String location,
    String? ctaType,
  }) {
    _track(AnalyticsEvent.ctaClick, {
      'button_name': buttonName,
      'location': location,
      if (ctaType != null) 'cta_type': ctaType,
    });
  }

  /// Track feature card interaction.
  static void trackFeatureInteraction(String featureName) {
    _track(AnalyticsEvent.featureInteraction, {
      'feature_name': featureName,
    });
  }

  /// Track external link click.
  static void trackExternalLink(String url) {
    _track(AnalyticsEvent.externalLinkClick, {
      'url': url,
    });
  }

  // ---------------------------------------------------------------------------
  // Conversion Tracking
  // ---------------------------------------------------------------------------

  /// Track form submission.
  static void trackFormSubmission({
    required String formType,
    required bool success,
    String? errorMessage,
  }) {
    _track(AnalyticsEvent.formSubmission, {
      'form_type': formType,
      'success': success,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  /// Track pricing tier view.
  static void trackPricingView(String tier) {
    _track(AnalyticsEvent.pricingTierView, {
      'tier': tier,
    });
  }

  /// Track pricing toggle (annual/monthly).
  static void trackPricingToggle({required bool isAnnual}) {
    _track(AnalyticsEvent.pricingToggle, {
      'billing_period': isAnnual ? 'annual' : 'monthly',
    });
  }

  /// Track demo request.
  static void trackDemoRequest() {
    _track(AnalyticsEvent.demoRequest, {});
  }

  /// Track lead magnet download.
  static void trackLeadMagnetDownload(String resourceName) {
    _track(AnalyticsEvent.leadMagnetDownload, {
      'resource_name': resourceName,
    });
  }

  /// Track blog post click.
  static void trackBlogPostClick(String postSlug) {
    _track(AnalyticsEvent.blogPostClick, {
      'post_slug': postSlug,
    });
  }

  /// Track custom event (for A/B testing and custom analytics).
  static void trackEvent({
    required String eventName,
    Map<String, dynamic> parameters = const {},
  }) {
    if (!isReady) return;

    _sendEvent(eventName, parameters);
    _log('$eventName: $parameters');
  }

  // ---------------------------------------------------------------------------
  // Internal Methods
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Test Spy (only available in tests via @visibleForTesting)
  // ---------------------------------------------------------------------------

  /// Call log for verifying analytics calls in tests.
  /// Each entry is `{event: AnalyticsEvent, params: Map}`.
  @visibleForTesting
  static List<({AnalyticsEvent event, Map<String, dynamic> params})>? callLog;

  /// Enable the call log spy for testing. Returns the log list.
  @visibleForTesting
  static List<({AnalyticsEvent event, Map<String, dynamic> params})>
      enableCallLog() {
    callLog = [];
    return callLog!;
  }

  /// Disable the call log and reset analytics state for testing.
  @visibleForTesting
  static void resetForTesting() {
    callLog = null;
    _initialized = false;
    _enabled = true;
  }

  /// Core tracking method with guard clause.
  static void _track(AnalyticsEvent event, Map<String, dynamic> params) {
    // Record to call log if spy is active (test mode)
    callLog?.add((event: event, params: Map<String, dynamic>.from(params)));

    if (!isReady) return;

    _sendEvent(event.name, params);
    _log('${event.name}: $params');
  }

  /// Send event to analytics platform via GTM/gtag.
  static void _sendEvent(String eventName, Map<String, dynamic> parameters) {
    if (!kIsWeb) return;

    TrackingWeb.sendEvent(eventName, parameters);
  }

  /// Debug logging (only in debug mode).
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('Analytics: $message');
    }
  }
}

// =============================================================================
// Error Tracking Service (Sentry)
// =============================================================================

/// Severity levels for error tracking messages.
///
/// Maps to Sentry's level system for consistent categorization.
enum ErrorSeverity {
  debug(SentryLevel.debug),
  info(SentryLevel.info),
  warning(SentryLevel.warning),
  error(SentryLevel.error),
  fatal(SentryLevel.fatal);

  final SentryLevel sentryLevel;
  const ErrorSeverity(this.sentryLevel);
}

/// Error tracking service using Sentry.
///
/// Provides a clean API for:
/// - Exception capture with context
/// - Message logging with severity levels
/// - Breadcrumbs for debugging trails
/// - User identification for error correlation
/// - Performance transactions
///
/// Usage:
/// ```dart
/// // Capture an exception
/// try {
///   await riskyOperation();
/// } catch (e, stackTrace) {
///   await ErrorTrackingService.captureException(
///     e,
///     stackTrace: stackTrace,
///     context: 'UserProfile.loadData',
///   );
/// }
///
/// // Add breadcrumb for context
/// ErrorTrackingService.addBreadcrumb(
///   message: 'User clicked submit',
///   category: 'ui.click',
/// );
/// ```
class ErrorTrackingService {
  ErrorTrackingService._();

  // ---------------------------------------------------------------------------
  // Exception Capture
  // ---------------------------------------------------------------------------

  /// Capture an exception with optional context.
  ///
  /// [exception] The error or exception to capture.
  /// [stackTrace] Optional stack trace for better debugging.
  /// [context] Location identifier (e.g., 'PaymentForm.submit').
  /// [extra] Additional key-value data for debugging.
  static Future<void> captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    _log('Exception: $exception');

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) => _configureScope(
        scope,
        context: context,
        extra: extra,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message Capture
  // ---------------------------------------------------------------------------

  /// Capture a message for non-exception issues.
  ///
  /// Use for logging important events that aren't exceptions:
  /// - Unexpected states
  /// - Validation failures
  /// - API response anomalies
  static Future<void> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.info,
    Map<String, dynamic>? extra,
  }) async {
    _log('Message [$severity]: $message');

    await Sentry.captureMessage(
      message,
      level: severity.sentryLevel,
      withScope: (scope) => _configureScope(scope, extra: extra),
    );
  }

  // ---------------------------------------------------------------------------
  // Breadcrumbs
  // ---------------------------------------------------------------------------

  /// Add a breadcrumb for debugging context.
  ///
  /// Breadcrumbs create a trail of events leading up to an error.
  /// Categories help filter in the Sentry dashboard:
  /// - 'navigation' - Route changes
  /// - 'ui.click' - User interactions
  /// - 'http' - API calls
  /// - 'console' - Log messages
  static void addBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Add a navigation breadcrumb.
  static void addNavigationBreadcrumb({
    required String from,
    required String to,
  }) {
    addBreadcrumb(
      message: 'Navigated from $from to $to',
      category: 'navigation',
      data: {'from': from, 'to': to},
    );
  }

  /// Add a user action breadcrumb.
  static void addUserActionBreadcrumb({
    required String action,
    String? target,
  }) {
    addBreadcrumb(
      message: action,
      category: 'ui.click',
      data: {'target': target},
    );
  }

  // ---------------------------------------------------------------------------
  // User Context
  // ---------------------------------------------------------------------------

  /// Set user context for error correlation.
  ///
  /// All subsequent errors will include this user information,
  /// helping identify issues affecting specific users.
  static void setUser({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic>? data,
  }) {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: data,
      ));
    });
  }

  /// Clear user context (e.g., on logout).
  static void clearUser() {
    Sentry.configureScope((scope) => scope.setUser(null));
  }

  // ---------------------------------------------------------------------------
  // Performance Monitoring
  // ---------------------------------------------------------------------------

  /// Start a performance transaction.
  ///
  /// Returns a transaction that must be finished when the operation completes.
  ///
  /// ```dart
  /// final transaction = ErrorTrackingService.startTransaction(
  ///   name: 'loadUserProfile',
  ///   operation: 'http.client',
  /// );
  /// try {
  ///   await loadProfile();
  ///   transaction.status = const SpanStatus.ok();
  /// } catch (e) {
  ///   transaction.status = const SpanStatus.internalError();
  ///   rethrow;
  /// } finally {
  ///   await transaction.finish();
  /// }
  /// ```
  static ISentrySpan startTransaction({
    required String name,
    required String operation,
  }) {
    return Sentry.startTransaction(name, operation, bindToScope: true);
  }

  // ---------------------------------------------------------------------------
  // Tags & Context
  // ---------------------------------------------------------------------------

  /// Set a global tag that appears on all events.
  static void setTag(String key, String value) {
    Sentry.configureScope((scope) => scope.setTag(key, value));
  }

  /// Set multiple global tags.
  static void setTags(Map<String, String> tags) {
    Sentry.configureScope((scope) {
      for (final entry in tags.entries) {
        scope.setTag(entry.key, entry.value);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Internal Methods
  // ---------------------------------------------------------------------------

  /// Configure scope with context and extra data.
  static void _configureScope(
    Scope scope, {
    String? context,
    Map<String, dynamic>? extra,
  }) {
    if (context != null) {
      scope.setContexts('app_context', {'location': context});
    }
    if (extra != null) {
      scope.setContexts('extra_data', extra);
    }
  }

  /// Debug logging (only in debug mode).
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('ErrorTracking: $message');
    }
  }
}

// =============================================================================
// Facebook Pixel Service
// =============================================================================

/// Facebook Pixel tracking service.
///
/// Follows same pattern as AnalyticsService for consistency.
/// Initializes ONLY after marketing consent.
class FacebookPixelService {
  FacebookPixelService._();

  static bool _initialized = false;
  static bool _enabled = true;

  static bool get isReady => _initialized && _enabled;

  /// Initialize Facebook Pixel after marketing consent.
  static Future<void> initialize() async {
    if (_initialized || !kIsWeb) return;

    try {
      TrackingWeb.injectFacebookPixel();
      _initialized = true;
      _log('Facebook Pixel initialized');
    } catch (e, stackTrace) {
      _log('Failed to initialize Facebook Pixel: $e');
      await ErrorTrackingService.captureException(
        e,
        stackTrace: stackTrace,
        context: 'FacebookPixelService.initialize',
      );
    }
  }

  /// Disable tracking.
  static void disable() {
    _enabled = false;
  }

  /// Enable tracking.
  static void enable() {
    _enabled = true;
  }

  /// Track page view.
  static void trackPageView() {
    if (!isReady) return;
    TrackingWeb.sendFBPageView();
  }

  /// Track lead (form submission).
  static void trackLead({String? email}) {
    if (!isReady) return;
    TrackingWeb.sendFBEvent('Lead', email != null ? {'email': email} : null);
    _log('Lead event sent');
  }

  /// Track contact form submission.
  static void trackContact({String? email, String? name}) {
    if (!isReady) return;
    final params = <String, dynamic>{};
    if (email != null) params['email'] = email;
    if (name != null) params['content_name'] = name;
    TrackingWeb.sendFBEvent('Contact', params.isNotEmpty ? params : null);
    _log('Contact event sent');
  }

  /// Track view content.
  static void trackViewContent(String contentType) {
    if (!isReady) return;
    TrackingWeb.sendFBEvent('ViewContent', {'content_type': contentType});
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('FacebookPixel: $message');
    }
  }
}
