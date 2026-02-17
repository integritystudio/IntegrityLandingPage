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
      expect(CompanyInfo.copyright, contains('2025'));
    });

    test('has location info', () {
      expect(CompanyInfo.locationCity, isNotEmpty);
      expect(CompanyInfo.locationRegion, isNotEmpty);
    });

    test('has phone number', () {
      expect(CompanyInfo.phone, isNotEmpty);
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
}
