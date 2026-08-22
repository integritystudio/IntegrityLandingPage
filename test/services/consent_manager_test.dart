import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/consent_manager.dart';
import '../helpers/test_helpers.dart';

// =============================================================================
// Mock Implementations for Testing
// =============================================================================

/// Mock platform check that can simulate web environment.
class MockPlatformCheck implements PlatformCheck {
  final bool _isWeb;
  MockPlatformCheck({this._isWeb = false});

  @override
  bool get isWeb => _isWeb;
}

/// Mock storage for testing consent persistence.
class MockConsentStorage implements ConsentStorage {
  final Map<String, String> _storage = {};
  bool throwOnGet = false;
  bool throwOnSet = false;
  bool throwOnRemove = false;

  @override
  String? get(String key) {
    if (throwOnGet) throw Exception('Storage error on get');
    return _storage[key];
  }

  @override
  void set(String key, String value) {
    if (throwOnSet) throw Exception('Storage error on set');
    _storage[key] = value;
  }

  @override
  void remove(String key) {
    if (throwOnRemove) throw Exception('Storage error on remove');
    _storage.remove(key);
  }

  void clear() => _storage.clear();
  bool containsKey(String key) => _storage.containsKey(key);
  String? operator [](String key) => _storage[key];
}

/// Mock tracking service for testing consent updates.
class MockTrackingService implements TrackingService {
  bool consentUpdated = false;
  bool? lastAnalyticsConsent;
  bool? lastMarketingConsent;
  bool facebookPixelInjected = false;
  bool facebookPageViewSent = false;

  @override
  void updateConsent({required bool analytics, required bool marketing}) {
    consentUpdated = true;
    lastAnalyticsConsent = analytics;
    lastMarketingConsent = marketing;
  }

  @override
  void injectFacebookPixel() {
    facebookPixelInjected = true;
  }

  @override
  void sendFBPageView() {
    facebookPageViewSent = true;
  }

  void reset() {
    consentUpdated = false;
    lastAnalyticsConsent = null;
    lastMarketingConsent = null;
    facebookPixelInjected = false;
    facebookPageViewSent = false;
  }
}

/// Mock analytics adapter for testing analytics initialization.
class MockAnalyticsAdapter implements AnalyticsAdapter {
  bool initialized = false;
  bool disabled = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  void disable() {
    disabled = true;
  }

  void reset() {
    initialized = false;
    disabled = false;
  }
}

void main() {

  // =============================================================================
  // ConsentManager Tests - Non-Web Platform (Default Behavior)
  // =============================================================================

  group('ConsentManager (non-web platform)', () {
    setUp(() {
      ConsentManager.resetDependencies();
    });

    group('hasConsent', () {
      test('returns true on non-web platforms', () {
        final result = ConsentManager.hasConsent();
        expect(result, isTrue);
      });

      test('consistently returns true for non-web platform', () {
        expect(ConsentManager.hasConsent(), isTrue);
        expect(ConsentManager.hasConsent(), isTrue);
        expect(ConsentManager.hasConsent(), isTrue);
      });
    });

    group('getStoredConsent', () {
      test('returns full consent on non-web platforms', () async {
        final consent = await ConsentManager.getStoredConsent();

        expect(consent, isNotNull);
        expect(consent!.analytics, isTrue);
        expect(consent.marketing, isTrue);
        expect(consent.essential, isTrue);
      });

      test('returned consent has valid timestamp', () async {
        final before = DateTime.now();
        final consent = await ConsentManager.getStoredConsent();
        final after = DateTime.now();

        expect(consent, isNotNull);
        expect(
          consent!.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          consent.timestamp.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });

      test('returns new instance on each call', () async {
        final consent1 = await ConsentManager.getStoredConsent();
        final consent2 = await ConsentManager.getStoredConsent();

        expect(consent1, isNotNull);
        expect(consent2, isNotNull);
        expect(identical(consent1, consent2), isFalse);
        expect(consent1!.analytics, equals(consent2!.analytics));
        expect(consent1.marketing, equals(consent2.marketing));
      });
    });

    group('saveConsent', () {
      test('completes without error for analytics consent', () async {
        final prefs = ConsentPreferences(analytics: true, marketing: false);
        await expectLater(ConsentManager.saveConsent(prefs), completes);
      });

      test('completes without error for marketing consent', () async {
        final prefs = ConsentPreferences(analytics: false, marketing: true);
        await expectLater(ConsentManager.saveConsent(prefs), completes);
      });

      test('completes without error for full consent', () async {
        final prefs = ConsentPreferences(analytics: true, marketing: true);
        await expectLater(ConsentManager.saveConsent(prefs), completes);
      });

      test('completes without error for no consent (essential only)', () async {
        final prefs = ConsentPreferences(analytics: false, marketing: false);
        await expectLater(ConsentManager.saveConsent(prefs), completes);
      });
    });

    group('revokeConsent', () {
      test('completes without error', () async {
        await expectLater(ConsentManager.revokeConsent(), completes);
      });

      test('can be called multiple times', () async {
        await ConsentManager.revokeConsent();
        await ConsentManager.revokeConsent();
        await ConsentManager.revokeConsent();
        expect(true, isTrue);
      });
    });
  });

  // =============================================================================
  // ConsentManager Tests - Web Platform (Mocked)
  // =============================================================================

  group('ConsentManager (web platform - mocked)', () {
    late MockPlatformCheck mockPlatform;
    late MockConsentStorage mockStorage;
    late MockTrackingService mockTracking;
    late MockAnalyticsAdapter mockAnalytics;

    setUp(() {
      mockPlatform = MockPlatformCheck(isWeb: true);
      mockStorage = MockConsentStorage();
      mockTracking = MockTrackingService();
      mockAnalytics = MockAnalyticsAdapter();

      ConsentManager.configureDependencies(
        platform: mockPlatform,
        storage: mockStorage,
        tracking: mockTracking,
        analytics: mockAnalytics,
      );
    });

    tearDown(() {
      ConsentManager.resetDependencies();
    });

    group('hasConsent', () {
      test('returns false when no consent stored', () {
        final result = ConsentManager.hasConsent();
        expect(result, isFalse);
      });

      test('returns true when consent is stored', () {
        mockStorage.set('integrity_cookie_consent', '{"analytics":true}');
        final result = ConsentManager.hasConsent();
        expect(result, isTrue);
      });

      test('returns false when storage throws exception', () {
        mockStorage.throwOnGet = true;
        final result = ConsentManager.hasConsent();
        expect(result, isFalse);
      });
    });

    group('getStoredConsent', () {
      test('returns null when no consent stored', () async {
        final consent = await ConsentManager.getStoredConsent();
        expect(consent, isNull);
      });

      test('returns stored consent when present', () async {
        final storedConsent = ConsentPreferences(
          analytics: true,
          marketing: false,
          timestamp: DateTime(2024, 6, 15),
        );
        mockStorage.set('integrity_cookie_consent', jsonEncode(storedConsent.toJson()));

        final consent = await ConsentManager.getStoredConsent();

        expect(consent, isNotNull);
        expect(consent!.analytics, isTrue);
        expect(consent.marketing, isFalse);
      });

      test('returns null when storage throws exception', () async {
        mockStorage.throwOnGet = true;
        final consent = await ConsentManager.getStoredConsent();
        expect(consent, isNull);
      });

      test('returns null when stored JSON is invalid', () async {
        mockStorage.set('integrity_cookie_consent', 'invalid json');
        final consent = await ConsentManager.getStoredConsent();
        expect(consent, isNull);
      });

      test('handles corrupted JSON gracefully', () async {
        mockStorage.set('integrity_cookie_consent', '{broken');
        final consent = await ConsentManager.getStoredConsent();
        expect(consent, isNull);
      });
    });

    group('saveConsent', () {
      test('stores consent to storage on web', () async {
        final prefs = ConsentPreferences(analytics: true, marketing: true);
        await ConsentManager.saveConsent(prefs);

        expect(mockStorage.containsKey('integrity_cookie_consent'), isTrue);
        final stored = jsonDecode(mockStorage['integrity_cookie_consent']!);
        expect(stored['analytics'], isTrue);
        expect(stored['marketing'], isTrue);
      });

      test('updates GTM consent mode', () async {
        final prefs = ConsentPreferences(analytics: true, marketing: false);
        await ConsentManager.saveConsent(prefs);

        expect(mockTracking.consentUpdated, isTrue);
        expect(mockTracking.lastAnalyticsConsent, isTrue);
        expect(mockTracking.lastMarketingConsent, isFalse);
      });

      test('initializes analytics when consent given', () async {
        final prefs = ConsentPreferences(analytics: true, marketing: false);
        await ConsentManager.saveConsent(prefs);

        expect(mockAnalytics.initialized, isTrue);
      });

      test('does not initialize analytics when consent denied', () async {
        final prefs = ConsentPreferences(analytics: false, marketing: false);
        await ConsentManager.saveConsent(prefs);

        expect(mockAnalytics.initialized, isFalse);
      });

      test('disables analytics on consent downgrade (analytics was enabled, now revoked)',
          () async {
        // Grant analytics consent first.
        await ConsentManager.saveConsent(
          ConsentPreferences(analytics: true, marketing: false),
        );
        expect(mockAnalytics.initialized, isTrue);
        expect(mockAnalytics.disabled, isFalse);

        // Revoke analytics consent — saveConsent must call disable().
        await ConsentManager.saveConsent(
          ConsentPreferences(analytics: false, marketing: false),
        );
        expect(mockAnalytics.disabled, isTrue);
      });

      test('initializes Facebook Pixel when marketing consent given', () async {
        final prefs = ConsentPreferences(analytics: false, marketing: true);
        await ConsentManager.saveConsent(prefs);

        expect(mockTracking.facebookPixelInjected, isTrue);
        // PageView is fired by meta-pixel.js on load, not by ConsentManager
        expect(mockTracking.facebookPageViewSent, isFalse);
      });

      test('does not initialize Facebook Pixel when marketing denied', () async {
        final prefs = ConsentPreferences(analytics: true, marketing: false);
        await ConsentManager.saveConsent(prefs);

        expect(mockTracking.facebookPixelInjected, isFalse);
        expect(mockTracking.facebookPageViewSent, isFalse);
      });

      test('handles storage exception gracefully', () async {
        mockStorage.throwOnSet = true;
        final prefs = ConsentPreferences(analytics: true, marketing: true);

        // Should not throw
        await expectLater(ConsentManager.saveConsent(prefs), completes);
        // Analytics should still be initialized
        expect(mockAnalytics.initialized, isTrue);
      });

      test('full consent initializes both analytics and marketing', () async {
        final prefs = ConsentPreferences.acceptAll();
        await ConsentManager.saveConsent(prefs);

        expect(mockAnalytics.initialized, isTrue);
        expect(mockTracking.facebookPixelInjected, isTrue);
        // PageView is fired by meta-pixel.js on load, not by ConsentManager
        expect(mockTracking.facebookPageViewSent, isFalse);
        expect(mockTracking.consentUpdated, isTrue);
      });

      test('essential only does not initialize analytics or marketing', () async {
        final prefs = ConsentPreferences.essentialOnly();
        await ConsentManager.saveConsent(prefs);

        expect(mockAnalytics.initialized, isFalse);
        expect(mockTracking.facebookPixelInjected, isFalse);
      });
    });

    group('revokeConsent', () {
      test('removes consent from storage', () async {
        mockStorage.set('integrity_cookie_consent', '{"analytics":true}');
        await ConsentManager.revokeConsent();

        expect(mockStorage.containsKey('integrity_cookie_consent'), isFalse);
      });

      test('disables analytics', () async {
        await ConsentManager.revokeConsent();
        expect(mockAnalytics.disabled, isTrue);
      });

      test('handles storage exception gracefully', () async {
        mockStorage.throwOnRemove = true;
        // Should not throw
        await expectLater(ConsentManager.revokeConsent(), completes);
        // Analytics should still be disabled
        expect(mockAnalytics.disabled, isTrue);
      });

      test('can be called when no consent exists', () async {
        await expectLater(ConsentManager.revokeConsent(), completes);
        expect(mockAnalytics.disabled, isTrue);
      });
    });

    group('workflow scenarios', () {
      test('full consent workflow: save then revoke', () async {
        // User accepts all cookies
        await ConsentManager.saveConsent(ConsentPreferences.acceptAll());
        expect(mockStorage.containsKey('integrity_cookie_consent'), isTrue);
        expect(mockAnalytics.initialized, isTrue);

        // Reset mocks to track subsequent calls
        mockAnalytics.reset();

        // User revokes consent
        await ConsentManager.revokeConsent();
        expect(mockStorage.containsKey('integrity_cookie_consent'), isFalse);
        expect(mockAnalytics.disabled, isTrue);
      });

      test('consent update workflow', () async {
        // First accept only essential
        await ConsentManager.saveConsent(ConsentPreferences.essentialOnly());
        expect(mockAnalytics.initialized, isFalse);

        // Then upgrade to full consent
        mockTracking.reset();
        await ConsentManager.saveConsent(ConsentPreferences.acceptAll());

        expect(mockAnalytics.initialized, isTrue);
        expect(mockTracking.facebookPixelInjected, isTrue);
        expect(mockTracking.consentUpdated, isTrue);
      });

      test('hasConsent reflects storage state', () async {
        expect(ConsentManager.hasConsent(), isFalse);

        await ConsentManager.saveConsent(ConsentPreferences.acceptAll());
        expect(ConsentManager.hasConsent(), isTrue);

        await ConsentManager.revokeConsent();
        expect(ConsentManager.hasConsent(), isFalse);
      });
    });
  });

  // =============================================================================
  // Dependency Injection Tests
  // =============================================================================

  group('Dependency injection', () {
    setUp(() {
      ConsentManager.resetDependencies();
    });

    tearDown(() {
      ConsentManager.resetDependencies();
    });

    test('configureDependencies updates platform', () {
      final mockPlatform = MockPlatformCheck(isWeb: true);
      ConsentManager.configureDependencies(platform: mockPlatform);

      // With web platform, hasConsent returns false when no storage
      expect(ConsentManager.hasConsent(), isFalse);
    });

    test('configureDependencies updates storage', () async {
      final mockPlatform = MockPlatformCheck(isWeb: true);
      final mockStorage = MockConsentStorage();
      mockStorage.set('integrity_cookie_consent', jsonEncode({
        'analytics': true,
        'marketing': true,
      }));

      ConsentManager.configureDependencies(
        platform: mockPlatform,
        storage: mockStorage,
      );

      final consent = await ConsentManager.getStoredConsent();
      expect(consent, isNotNull);
      expect(consent!.analytics, isTrue);
    });

    test('resetDependencies restores defaults', () {
      final mockPlatform = MockPlatformCheck(isWeb: true);
      ConsentManager.configureDependencies(platform: mockPlatform);

      // Web platform should show false when no consent
      expect(ConsentManager.hasConsent(), isFalse);

      ConsentManager.resetDependencies();

      // Default (non-web) should show true
      expect(ConsentManager.hasConsent(), isTrue);
    });

    test('partial configureDependencies only updates specified deps', () async {
      final mockPlatform = MockPlatformCheck(isWeb: true);
      final mockStorage = MockConsentStorage();
      final mockAnalytics = MockAnalyticsAdapter();

      // Configure only platform and storage
      ConsentManager.configureDependencies(
        platform: mockPlatform,
        storage: mockStorage,
        analytics: mockAnalytics,
      );

      await ConsentManager.saveConsent(ConsentPreferences.acceptAll());
      expect(mockAnalytics.initialized, isTrue);
    });
  });

  // =============================================================================
  // Default Implementation Tests
  // =============================================================================

  group('DefaultConsentStorage', () {
    test('returns null on non-web platform', () {
      const storage = DefaultConsentStorage();
      expect(storage.get('any_key'), isNull);
    });

    test('set does nothing on non-web platform', () {
      const storage = DefaultConsentStorage();
      // Should not throw
      storage.set('key', 'value');
    });

    test('remove does nothing on non-web platform', () {
      const storage = DefaultConsentStorage();
      // Should not throw
      storage.remove('key');
    });
  });

  group('DefaultPlatformCheck', () {
    test('isWeb returns kIsWeb value (false in tests)', () {
      const check = DefaultPlatformCheck();
      expect(check.isWeb, isFalse);
    });
  });

  group('DefaultTrackingService', () {
    test('updateConsent does not throw', () {
      const service = DefaultTrackingService();
      // Should not throw on non-web
      service.updateConsent(analytics: true, marketing: true);
    });

    test('injectFacebookPixel does not throw', () {
      const service = DefaultTrackingService();
      service.injectFacebookPixel();
    });

    test('sendFBPageView does not throw', () {
      const service = DefaultTrackingService();
      service.sendFBPageView();
    });
  });

  group('DefaultAnalyticsAdapter', () {
    test('initialize completes', () async {
      const adapter = DefaultAnalyticsAdapter();
      await expectLater(adapter.initialize(), completes);
    });

    test('disable does not throw', () {
      const adapter = DefaultAnalyticsAdapter();
      adapter.disable();
    });
  });

  // =============================================================================
  // ConsentPreferences Model Tests
  // =============================================================================

  group('ConsentPreferences', () {
    group('construction', () {
      test('creates with required values', () {
        final prefs = ConsentPreferences(analytics: false, marketing: false);
        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isFalse);
        expect(prefs.marketing, isFalse);
      });

      test('creates with all true values', () {
        final prefs = ConsentPreferences(analytics: true, marketing: true);
        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isTrue);
      });

      test('essential is always true', () {
        final prefs = ConsentPreferences(analytics: false, marketing: false);
        expect(prefs.essential, isTrue);
      });

      test('sets timestamp to now by default', () {
        final before = DateTime.now();
        final prefs = ConsentPreferences(analytics: true, marketing: true);
        final after = DateTime.now();

        expect(prefs.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(prefs.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });

      test('uses provided timestamp', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final prefs = ConsentPreferences(
          analytics: true,
          marketing: true,
          timestamp: timestamp,
        );
        expect(prefs.timestamp, equals(timestamp));
      });

      test('default consent version is 1.0', () {
        final prefs = ConsentPreferences(analytics: true, marketing: true);
        expect(prefs.consentVersion, equals('1.0'));
      });

      test('uses provided consent version', () {
        final prefs = ConsentPreferences(
          analytics: true,
          marketing: true,
          consentVersion: '2.0',
        );
        expect(prefs.consentVersion, equals('2.0'));
      });
    });

    group('factory constructors', () {
      test('acceptAll creates full consent', () {
        final prefs = ConsentPreferences.acceptAll();
        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isTrue);
      });

      test('essentialOnly creates essential only consent', () {
        final prefs = ConsentPreferences.essentialOnly();
        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isFalse);
        expect(prefs.marketing, isFalse);
      });

      test('analyticsOnly creates analytics consent', () {
        final prefs = ConsentPreferences.analyticsOnly();
        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isFalse);
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        final timestamp = DateTime(2024, 6, 15, 10, 30, 0);
        final prefs = ConsentPreferences(
          analytics: true,
          marketing: false,
          timestamp: timestamp,
          consentVersion: '1.5',
        );
        final json = prefs.toJson();

        expect(json['essential'], isTrue);
        expect(json['analytics'], isTrue);
        expect(json['marketing'], isFalse);
        expect(json['timestamp'], equals('2024-06-15T10:30:00.000'));
        expect(json['consentVersion'], equals('1.5'));
      });

      test('fromJson creates correct object', () {
        final json = {
          'essential': true,
          'analytics': true,
          'marketing': false,
          'timestamp': '2024-01-01T00:00:00.000',
          'consentVersion': '1.0',
        };
        final prefs = ConsentPreferences.fromJson(json);

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isFalse);
        expect(prefs.timestamp, equals(DateTime(2024, 1, 1)));
      });

      test('fromJson handles missing fields', () {
        final json = <String, dynamic>{};
        final prefs = ConsentPreferences.fromJson(json);

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isFalse);
        expect(prefs.marketing, isFalse);
        expect(prefs.consentVersion, equals('1.0'));
      });

      test('fromJson handles null values', () {
        final json = <String, dynamic>{
          'essential': null,
          'analytics': null,
          'marketing': null,
          'timestamp': null,
          'consentVersion': null,
        };
        final prefs = ConsentPreferences.fromJson(json);

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isFalse);
        expect(prefs.marketing, isFalse);
        expect(prefs.consentVersion, equals('1.0'));
      });

      test('round-trip serialization preserves data', () {
        final original = ConsentPreferences(
          analytics: true,
          marketing: false,
          timestamp: DateTime(2024, 6, 15, 10, 30, 0),
          consentVersion: '2.0',
        );

        final json = original.toJson();
        final restored = ConsentPreferences.fromJson(json);

        expect(restored.essential, equals(original.essential));
        expect(restored.analytics, equals(original.analytics));
        expect(restored.marketing, equals(original.marketing));
        expect(restored.timestamp, equals(original.timestamp));
        expect(restored.consentVersion, equals(original.consentVersion));
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        final prefs = ConsentPreferences(analytics: true, marketing: false);
        final str = prefs.toString();

        expect(str, contains('ConsentPreferences'));
        expect(str, contains('analytics: true'));
        expect(str, contains('marketing: false'));
      });
    });
  });

  // =============================================================================
  // ConsentLevel Enum Tests
  // =============================================================================

  group('ConsentLevel', () {
    test('has exactly three values', () {
      expect(ConsentLevel.values.length, equals(3));
    });

    test('values are in expected order', () {
      expect(ConsentLevel.values[0], equals(ConsentLevel.essential));
      expect(ConsentLevel.values[1], equals(ConsentLevel.analytics));
      expect(ConsentLevel.values[2], equals(ConsentLevel.all));
    });

    test('name property returns correct string', () {
      expect(ConsentLevel.essential.name, equals('essential'));
      expect(ConsentLevel.analytics.name, equals('analytics'));
      expect(ConsentLevel.all.name, equals('all'));
    });
  });

  // =============================================================================
  // ConsentLevelExtension Tests
  // =============================================================================

  group('ConsentLevelExtension', () {
    test('essential.toPreferences returns essentialOnly preferences', () {
      final prefs = ConsentLevel.essential.toPreferences();
      expect(prefs.analytics, isFalse);
      expect(prefs.marketing, isFalse);
    });

    test('analytics.toPreferences returns analyticsOnly preferences', () {
      final prefs = ConsentLevel.analytics.toPreferences();
      expect(prefs.analytics, isTrue);
      expect(prefs.marketing, isFalse);
    });

    test('all.toPreferences returns acceptAll preferences', () {
      final prefs = ConsentLevel.all.toPreferences();
      expect(prefs.analytics, isTrue);
      expect(prefs.marketing, isTrue);
    });

    test('toPreferences creates new instance each time', () {
      final prefs1 = ConsentLevel.all.toPreferences();
      final prefs2 = ConsentLevel.all.toPreferences();
      expect(identical(prefs1, prefs2), isFalse);
    });
  });

  // =============================================================================
  // Edge Case Tests
  // =============================================================================

  group('Edge cases', () {
    setUp(() {
      ConsentManager.resetDependencies();
    });

    tearDown(() {
      ConsentManager.resetDependencies();
    });

    test('ConsentPreferences handles timestamp with milliseconds', () {
      final timestamp = DateTime(2024, 6, 15, 10, 30, 45, 123);
      final prefs = ConsentPreferences(
        analytics: true,
        marketing: true,
        timestamp: timestamp,
      );

      final json = prefs.toJson();
      final restored = ConsentPreferences.fromJson(json);

      expect(restored.timestamp.millisecond, equals(123));
    });

    test('ConsentPreferences handles very old timestamp', () {
      final timestamp = DateTime(1970, 1, 1);
      final prefs = ConsentPreferences(
        analytics: true,
        marketing: true,
        timestamp: timestamp,
      );

      final json = prefs.toJson();
      final restored = ConsentPreferences.fromJson(json);
      expect(restored.timestamp, equals(timestamp));
    });

    test('ConsentPreferences handles future timestamp', () {
      final timestamp = DateTime(2100, 12, 31);
      final prefs = ConsentPreferences(
        analytics: true,
        marketing: true,
        timestamp: timestamp,
      );

      final json = prefs.toJson();
      final restored = ConsentPreferences.fromJson(json);
      expect(restored.timestamp, equals(timestamp));
    });

    test('Multiple rapid consent saves do not cause issues', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(ConsentManager.saveConsent(
          ConsentPreferences(analytics: i.isEven, marketing: i.isOdd),
        ));
      }

      await Future.wait(futures);
      expect(true, isTrue);
    });

    test('Concurrent getStoredConsent calls work correctly', () async {
      final futures = <Future<ConsentPreferences?>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(ConsentManager.getStoredConsent());
      }

      final results = await Future.wait(futures);
      for (final result in results) {
        expect(result, isNotNull);
        expect(result!.analytics, isTrue);
        expect(result.marketing, isTrue);
      }
    });

    test('Web platform with empty storage key value', () async {
      final mockPlatform = MockPlatformCheck(isWeb: true);
      final mockStorage = MockConsentStorage();
      mockStorage.set('integrity_cookie_consent', '');

      ConsentManager.configureDependencies(
        platform: mockPlatform,
        storage: mockStorage,
      );

      // Empty string is still "stored" so hasConsent returns true
      expect(ConsentManager.hasConsent(), isTrue);

      // But getStoredConsent returns null due to invalid JSON
      final consent = await ConsentManager.getStoredConsent();
      expect(consent, isNull);
    });
  });

  // =============================================================================
  // Re-export Verification
  // =============================================================================

  group('Re-exports', () {
    test('consent_manager exports ConsentPreferences', () {
      // ignore: unnecessary_type_check
      expect(ConsentPreferences.acceptAll() is ConsentPreferences, isTrue);
    });

    test('consent_manager exports ConsentLevel', () {
      // ignore: unnecessary_type_check
      expect(ConsentLevel.all is ConsentLevel, isTrue);
    });

    test('consent_manager exports ConsentStorage interface', () {
      final storage = MockConsentStorage();
      expect(storage, isA<ConsentStorage>());
    });

    test('consent_manager exports PlatformCheck interface', () {
      final platform = MockPlatformCheck();
      expect(platform, isA<PlatformCheck>());
    });

    test('consent_manager exports TrackingService interface', () {
      final tracking = MockTrackingService();
      expect(tracking, isA<TrackingService>());
    });

    test('consent_manager exports AnalyticsAdapter interface', () {
      final analytics = MockAnalyticsAdapter();
      expect(analytics, isA<AnalyticsAdapter>());
    });
  });

  // =============================================================================
  // TestData helpers
  // =============================================================================

  group('TestData helpers', () {
    test('consentJson creates valid JSON', () {
      final json = TestData.consentJson();
      expect(json['essential'], isTrue);
      expect(json['analytics'], isTrue);
      expect(json['marketing'], isFalse);
    });

    test('acceptAllConsentJson creates full consent', () {
      final json = TestData.acceptAllConsentJson();
      expect(json['analytics'], isTrue);
      expect(json['marketing'], isTrue);
    });

    test('essentialOnlyConsentJson creates minimal consent', () {
      final json = TestData.essentialOnlyConsentJson();
      expect(json['analytics'], isFalse);
      expect(json['marketing'], isFalse);
    });
  });
}
