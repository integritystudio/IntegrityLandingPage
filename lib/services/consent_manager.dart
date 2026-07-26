import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/consent_preferences.dart';
import 'analytics.dart';
import 'tracking.dart';

// Re-export for backward compatibility
export '../models/consent_preferences.dart';

/// Storage abstraction for consent data.
///
/// This interface allows for dependency injection in tests while using
/// platform-specific storage (localStorage on web) in production.
abstract class ConsentStorage {
  String? get(String key);
  void set(String key, String value);
  void remove(String key);
}

/// Default storage implementation using TrackingWeb.
///
/// On web: Uses localStorage via TrackingWeb.
/// On other platforms: Returns null (no storage needed).
class DefaultConsentStorage implements ConsentStorage {
  const DefaultConsentStorage();

  @override
  String? get(String key) {
    if (!kIsWeb) return null;
    return TrackingWeb.getFromStorage(key);
  }

  @override
  void set(String key, String value) {
    if (!kIsWeb) return;
    TrackingWeb.setToStorage(key, value);
  }

  @override
  void remove(String key) {
    if (!kIsWeb) return;
    TrackingWeb.removeFromStorage(key);
  }
}

/// Platform check abstraction for testing.
///
/// Allows overriding the kIsWeb check in tests.
abstract class PlatformCheck {
  bool get isWeb;
}

/// Default platform check using kIsWeb constant.
class DefaultPlatformCheck implements PlatformCheck {
  const DefaultPlatformCheck();

  @override
  bool get isWeb => kIsWeb;
}

/// Tracking service abstraction for testing.
abstract class TrackingService {
  void updateConsent({required bool analytics, required bool marketing});
  void injectFacebookPixel();
  void sendFBPageView();
}

/// Default tracking implementation using TrackingWeb.
class DefaultTrackingService implements TrackingService {
  const DefaultTrackingService();

  @override
  void updateConsent({required bool analytics, required bool marketing}) {
    TrackingWeb.updateConsent(analytics: analytics, marketing: marketing);
  }

  @override
  void injectFacebookPixel() {
    TrackingWeb.injectFacebookPixel();
  }

  @override
  void sendFBPageView() {
    TrackingWeb.sendFBPageView();
  }
}

/// Analytics service abstraction for testing.
abstract class AnalyticsAdapter {
  Future<void> initialize();
  void disable();
}

/// Default analytics implementation using AnalyticsService.
class DefaultAnalyticsAdapter implements AnalyticsAdapter {
  const DefaultAnalyticsAdapter();

  @override
  Future<void> initialize() => AnalyticsService.initialize();

  @override
  void disable() => AnalyticsService.disable();
}

/// GDPR-compliant consent management
///
/// This service manages user consent for cookies and analytics.
/// Analytics are ONLY initialized AFTER explicit user consent.
///
/// Usage:
/// 1. Check if consent exists: ConsentManager.hasConsent()
/// 2. Show cookie banner if no consent
/// 3. Save consent: await ConsentManager.saveConsent(prefs)
/// 4. Analytics auto-initialize based on consent preferences
class ConsentManager {
  ConsentManager._();

  static const String _storageKey = 'integrity_cookie_consent';

  // Dependency injection for testing
  static PlatformCheck _platform = const DefaultPlatformCheck();
  static ConsentStorage _storage = const DefaultConsentStorage();
  static TrackingService _tracking = const DefaultTrackingService();
  static AnalyticsAdapter _analytics = const DefaultAnalyticsAdapter();

  /// Configure dependencies for testing.
  ///
  /// This method allows injecting mock implementations in tests.
  @visibleForTesting
  static void configureDependencies({
    PlatformCheck? platform,
    ConsentStorage? storage,
    TrackingService? tracking,
    AnalyticsAdapter? analytics,
  }) {
    if (platform != null) _platform = platform;
    if (storage != null) _storage = storage;
    if (tracking != null) _tracking = tracking;
    if (analytics != null) _analytics = analytics;
  }

  /// Reset dependencies to defaults.
  @visibleForTesting
  static void resetDependencies() {
    _platform = const DefaultPlatformCheck();
    _storage = const DefaultConsentStorage();
    _tracking = const DefaultTrackingService();
    _analytics = const DefaultAnalyticsAdapter();
  }

  /// Check if user has already given consent (any level)
  static bool hasConsent() {
    if (!_platform.isWeb) return true; // Non-web platforms don't need consent banner

    try {
      // Access localStorage via dart:html on web
      final stored = _storage.get(_storageKey);
      return stored != null;
    } catch (e) {
      return false;
    }
  }

  /// Get stored consent preferences
  static Future<ConsentPreferences?> getStoredConsent() async {
    if (!_platform.isWeb) {
      return ConsentPreferences(
        analytics: true,
        marketing: true,
      );
    }

    try {
      final stored = _storage.get(_storageKey);
      if (stored == null) return null;
      return ConsentPreferences.fromJson(jsonDecode(stored));
    } catch (e) {
      return null;
    }
  }

  /// Save consent and initialize services accordingly
  static Future<void> saveConsent(ConsentPreferences prefs) async {
    if (_platform.isWeb) {
      try {
        _storage.set(_storageKey, jsonEncode(prefs.toJson()));
      } catch (e) {
        // Storage might be unavailable in private browsing
        debugPrint('Failed to save consent to storage: $e');
      }

      // Update GTM Consent Mode with user's choices
      _tracking.updateConsent(
        analytics: prefs.analytics,
        marketing: prefs.marketing,
      );
    }

    // Initialize analytics if consent was given; disable if consent was revoked
    // (handles the downgrade case where analytics was previously enabled).
    if (prefs.analytics) {
      await _analytics.initialize();
    } else {
      _analytics.disable();
    }

    if (prefs.marketing) {
      await _initializeMarketing();
    }
  }

  /// Revoke all consent (for "Manage Preferences" -> "Reject All")
  static Future<void> revokeConsent() async {
    if (_platform.isWeb) {
      try {
        _storage.remove(_storageKey);
      } catch (e) {
        debugPrint('Failed to remove consent from storage: $e');
      }
    }

    // Note: We can't truly "uninitialize" analytics scripts that are already loaded
    // But we can stop tracking new events
    _analytics.disable();
  }

  /// Initialize Facebook Pixel (only after marketing consent)
  static Future<void> _initializeMarketing() async {
    if (!_platform.isWeb) return;

    // Inject Facebook Pixel script. meta-pixel.js fires its own initial
    // PageView on load — no extra sendFBPageView() call needed.
    _tracking.injectFacebookPixel();
    if (kDebugMode) {
      debugPrint('Marketing tracking initialized with consent');
    }
  }
}
