import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/models/consent_preferences.dart';

void main() {
  group('ConsentPreferences', () {
    group('constructor', () {
      test('creates with required parameters', () {
        final prefs = ConsentPreferences(
          analytics: true,
          marketing: false,
        );

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isFalse);
        expect(prefs.consentVersion, equals('1.0'));
        expect(prefs.timestamp, isNotNull);
      });

      test('essential is always true', () {
        final prefs = ConsentPreferences(
          analytics: false,
          marketing: false,
        );

        expect(prefs.essential, isTrue);
      });

      test('uses provided timestamp', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30);
        final prefs = ConsentPreferences(
          analytics: true,
          marketing: true,
          timestamp: timestamp,
        );

        expect(prefs.timestamp, equals(timestamp));
      });

      test('uses provided consent version', () {
        final prefs = ConsentPreferences(
          analytics: true,
          marketing: true,
          consentVersion: '2.0',
        );

        expect(prefs.consentVersion, equals('2.0'));
      });

      test('sets timestamp to now by default', () {
        final before = DateTime.now();
        final prefs = ConsentPreferences(analytics: true, marketing: true);
        final after = DateTime.now();

        expect(
          prefs.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          prefs.timestamp.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });
    });

    group('factory constructors', () {
      test('acceptAll sets both analytics and marketing to true', () {
        final prefs = ConsentPreferences.acceptAll();

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isTrue);
      });

      test('essentialOnly sets analytics and marketing to false', () {
        final prefs = ConsentPreferences.essentialOnly();

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isFalse);
        expect(prefs.marketing, isFalse);
      });

      test('analyticsOnly sets analytics true and marketing false', () {
        final prefs = ConsentPreferences.analyticsOnly();

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isFalse);
      });
    });

    group('JSON serialization', () {
      test('toJson serializes all fields', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30);
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
        expect(json['timestamp'], equals(timestamp.toIso8601String()));
        expect(json['consentVersion'], equals('1.5'));
      });

      test('fromJson creates correct preferences', () {
        final json = {
          'essential': true,
          'analytics': true,
          'marketing': false,
          'timestamp': '2024-01-15T10:30:00.000',
          'consentVersion': '1.5',
        };

        final prefs = ConsentPreferences.fromJson(json);

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isTrue);
        expect(prefs.marketing, isFalse);
        expect(prefs.timestamp, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(prefs.consentVersion, equals('1.5'));
      });

      test('fromJson handles missing keys with defaults', () {
        final json = <String, dynamic>{};

        final prefs = ConsentPreferences.fromJson(json);

        expect(prefs.essential, isTrue);
        expect(prefs.analytics, isFalse);
        expect(prefs.marketing, isFalse);
        expect(prefs.consentVersion, equals('1.0'));
      });

      test('fromJson handles null values with defaults', () {
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

      test('round-trip serialization preserves exact timestamp', () {
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
      test('returns readable string representation', () {
        final prefs = ConsentPreferences(
          analytics: true,
          marketing: false,
        );

        final str = prefs.toString();

        expect(str, contains('analytics: true'));
        expect(str, contains('marketing: false'));
        expect(str, contains('timestamp:'));
      });
    });
  });

  group('ConsentLevel', () {
    test('essential level creates essentialOnly preferences', () {
      final prefs = ConsentLevel.essential.toPreferences();

      expect(prefs.analytics, isFalse);
      expect(prefs.marketing, isFalse);
    });

    test('analytics level creates analyticsOnly preferences', () {
      final prefs = ConsentLevel.analytics.toPreferences();

      expect(prefs.analytics, isTrue);
      expect(prefs.marketing, isFalse);
    });

    test('all level creates acceptAll preferences', () {
      final prefs = ConsentLevel.all.toPreferences();

      expect(prefs.analytics, isTrue);
      expect(prefs.marketing, isTrue);
    });

    test('toPreferences creates a new instance each time', () {
      final prefs1 = ConsentLevel.all.toPreferences();
      final prefs2 = ConsentLevel.all.toPreferences();

      expect(identical(prefs1, prefs2), isFalse);
    });
  });
}
