// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Maximum time (ms) to wait for consent update before firing tags.
const int consentWaitForUpdateMs = 500;

/// GTM Container ID from Doppler (integrity-studio/prd)
/// Updated to new container (integritystudio.ai-v2) on 2025-12-28
const String gtmContainerId = 'GTM-NLLQ5ZM3';

/// GA4 Measurement ID from Doppler (integrity-studio/prd)
const String ga4MeasurementId = 'G-J7TL7PQH7S';

// =============================================================================
// JS Interop Bindings
// =============================================================================

@JS('gtag')
external void _gtag(JSString command, [JSAny? arg1, JSAny? arg2]);

@JS('fbq')
external void _fbq(JSString command, [JSAny? arg1, JSAny? arg2]);

@JS('dataLayer')
external JSArray<JSAny>? get _dataLayer;

@JS('dataLayer')
external set _dataLayer(JSArray<JSAny>? value);

/// Push to dataLayer using JS interop
@JS('dataLayer.push')
external void _dataLayerPush(JSAny data);

// =============================================================================
// GTM Tracking Service
// =============================================================================

/// Web-specific GTM and Analytics implementation.
///
/// Handles:
/// - GTM script injection (after consent)
/// - Consent Mode v2 initialization
/// - gtag event sending
/// - localStorage for consent persistence
class TrackingWeb {
  TrackingWeb._();

  static bool _gtmInjected = false;
  static bool _fbPixelInjected = false;

  // ---------------------------------------------------------------------------
  // Consent Mode v2
  // ---------------------------------------------------------------------------

  /// Initialize Consent Mode with default denied state.
  /// This MUST be called before GTM loads (in index.html or early init).
  static void initializeConsentMode() {
    // Initialize dataLayer if not exists
    _dataLayer ??= <JSAny>[].toJS;

    // Set default consent state (denied until user consents)
    _gtag(
      'consent'.toJS,
      'default'.toJS,
      <String, dynamic>{
        'ad_storage': 'denied',
        'ad_user_data': 'denied',
        'ad_personalization': 'denied',
        'analytics_storage': 'denied',
        'functionality_storage': 'granted', // Essential cookies
        'personalization_storage': 'denied',
        'security_storage': 'granted', // Essential for security
        'wait_for_update': consentWaitForUpdateMs,
      }.jsify(),
    );
  }

  /// Update consent state after user makes a choice.
  static void updateConsent({
    required bool analytics,
    required bool marketing,
  }) {
    _gtag(
      'consent'.toJS,
      'update'.toJS,
      <String, dynamic>{
        'ad_storage': marketing ? 'granted' : 'denied',
        'ad_user_data': marketing ? 'granted' : 'denied',
        'ad_personalization': marketing ? 'granted' : 'denied',
        'analytics_storage': analytics ? 'granted' : 'denied',
        'personalization_storage': analytics ? 'granted' : 'denied',
      }.jsify(),
    );
  }

  // ---------------------------------------------------------------------------
  // GTM Injection
  // ---------------------------------------------------------------------------

  /// Inject GTM script after user consent.
  static void injectGTM() {
    if (_gtmInjected) return;

    final head = web.document.head;
    if (head == null) return;

    // Create GTM script
    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..async = true
      ..src =
          'https://www.googletagmanager.com/gtm.js?id=$gtmContainerId';

    // Initialize dataLayer with GTM start event
    _dataLayer ??= <JSAny>[].toJS;
    _pushToDataLayer({
      'gtm.start': DateTime.now().millisecondsSinceEpoch,
      'event': 'gtm.js',
    });

    head.appendChild(script);
    _gtmInjected = true;
  }

  /// Push event to dataLayer.
  static void _pushToDataLayer(Map<String, dynamic> data) {
    _dataLayer ??= <JSAny>[].toJS;
    final jsData = data.jsify();
    if (jsData != null) {
      _dataLayerPush(jsData);
    }
  }

  // ---------------------------------------------------------------------------
  // GA4 Event Tracking
  // ---------------------------------------------------------------------------

  /// Send event to GA4 via gtag.
  static void sendEvent(String eventName, Map<String, dynamic> parameters) {
    if (!_gtmInjected) return;

    _gtag(
      'event'.toJS,
      eventName.toJS,
      parameters.jsify(),
    );
  }

  /// Send page view to GA4.
  static void sendPageView(String pagePath, String pageTitle) {
    sendEvent('page_view', {
      'page_path': pagePath,
      'page_title': pageTitle,
    });
  }

  // ---------------------------------------------------------------------------
  // Facebook Pixel
  // ---------------------------------------------------------------------------

  /// Inject the Facebook Pixel script after marketing consent.
  ///
  /// Dynamically appends web/js/meta-pixel.js to the document head. The script initialises
  /// the fbq stub, loads the SDK from Facebook's CDN, and fires the initial
  /// fbq('init') + fbq('track', 'PageView') — no additional sendFBPageView()
  /// call is needed after this.
  static void injectFacebookPixel() {
    if (_fbPixelInjected) return;
    _fbPixelInjected = true;

    final head = web.document.head;
    if (head == null) return;

    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..src = 'js/meta-pixel.js';
    head.appendChild(script);
  }

  /// Track Facebook Pixel event.
  static void sendFBEvent(String eventName, [Map<String, dynamic>? parameters]) {
    if (!_fbPixelInjected) return;

    if (parameters != null) {
      _fbq('track'.toJS, eventName.toJS, parameters.jsify());
    } else {
      _fbq('track'.toJS, eventName.toJS);
    }
  }

  /// Track Facebook Pixel page view.
  static void sendFBPageView() {
    sendFBEvent('PageView');
  }

  // ---------------------------------------------------------------------------
  // localStorage
  // ---------------------------------------------------------------------------

  /// Get value from localStorage.
  static String? getFromStorage(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  /// Set value in localStorage.
  static void setToStorage(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (e) {
      // Storage might be unavailable in private browsing
    }
  }

  /// Remove value from localStorage.
  static void removeFromStorage(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (e) {
      // Ignore errors
    }
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Check if GTM is injected.
  static bool get isGTMInjected => _gtmInjected;

  /// Check if Facebook Pixel is injected.
  static bool get isFBPixelInjected => _fbPixelInjected;
}
