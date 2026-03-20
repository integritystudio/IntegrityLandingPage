import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';

void main() {
  group('CompanyInfo', () {
    test('has non-empty company name', () {
      expect(CompanyInfo.name, isNotEmpty);
    });

    test('has non-empty tagline', () {
      expect(CompanyInfo.tagline, isNotEmpty);
    });

    test('has valid email format', () {
      expect(CompanyInfo.email, contains('@'));
      expect(CompanyInfo.email, contains('.'));
    });

    test('has copyright with year', () {
      expect(CompanyInfo.copyright, contains('©'));
      expect(CompanyInfo.copyright, contains('${DateTime.now().year}'));
    });

    test('has location info', () {
      expect(CompanyInfo.locationCity, isNotEmpty);
      expect(CompanyInfo.locationRegion, isNotEmpty);
    });

    test('has phone number', () {
      expect(CompanyInfo.phone, isNotEmpty);
    });
  });

  group('ExternalUrls', () {
    test('calendly URL points to integritystudio/demo', () {
      expect(ExternalUrls.calendlyDemo,
          equals('https://calendly.com/integritystudio/demo'));
    });

    test('calendly URL is a valid calendly.com link', () {
      expect(ExternalUrls.calendlyDemo, startsWith('https://calendly.com/'));
    });
  });

  group('PlatformMetrics', () {
    test('setupTime matches content.yaml value', () {
      expect(PlatformMetrics.setupTime, equals('15 min'));
    });

    test('setupTimeLabel matches content.yaml value', () {
      expect(PlatformMetrics.setupTimeLabel, equals('Average'));
    });

    test('uptime matches content.yaml value', () {
      expect(PlatformMetrics.uptime, equals('99.9%'));
    });

    test('all metrics are non-empty', () {
      expect(PlatformMetrics.uptime, isNotEmpty);
      expect(PlatformMetrics.uptimeSla, isNotEmpty);
      expect(PlatformMetrics.tracesProcessed, isNotEmpty);
      expect(PlatformMetrics.tracesProcessedPeriod, isNotEmpty);
      expect(PlatformMetrics.aiTeams, isNotEmpty);
      expect(PlatformMetrics.setupTime, isNotEmpty);
      expect(PlatformMetrics.setupTimeLabel, isNotEmpty);
    });
  });

  group('CTAText', () {
    test('primary CTAs are non-empty', () {
      expect(CTAText.startFreeTrial, isNotEmpty);
      expect(CTAText.getStarted, isNotEmpty);
      expect(CTAText.scheduledDemo, isNotEmpty);
      expect(CTAText.requestDemo, isNotEmpty);
      expect(CTAText.contactSales, isNotEmpty);
      expect(CTAText.learnMore, isNotEmpty);
    });

    test('navigation CTAs are non-empty', () {
      expect(CTAText.backToHome, isNotEmpty);
      expect(CTAText.viewAll, isNotEmpty);
      expect(CTAText.viewDocs, isNotEmpty);
    });

    test('form CTAs are non-empty', () {
      expect(CTAText.sendMessage, isNotEmpty);
      expect(CTAText.downloadNow, isNotEmpty);
      expect(CTAText.calculateSavings, isNotEmpty);
    });
  });

  group('PasswordPolicy (L21: shared constants)', () {
    test('minLength is at least 8 characters', () {
      expect(PasswordPolicy.minLength, greaterThanOrEqualTo(8));
    });

    test('maxLength is greater than minLength', () {
      expect(PasswordPolicy.maxLength, greaterThan(PasswordPolicy.minLength));
    });

    test('maxLength is reasonable (< 256)', () {
      expect(PasswordPolicy.maxLength, lessThan(256));
    });

    test('minLength is 8 for DOS protection', () {
      expect(PasswordPolicy.minLength, equals(8));
    });

    test('maxLength is 128 to prevent password field DoS', () {
      expect(PasswordPolicy.maxLength, equals(128));
    });
  });
}
