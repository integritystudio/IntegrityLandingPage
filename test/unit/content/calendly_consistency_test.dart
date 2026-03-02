// Regression tests: Calendly URL and duration labels must stay consistent
// across all content sources (constants, content models, content.yaml).
//
// Background: The Calendly event is 15 minutes but labels in 4 files
// previously said "30 minutes". These tests prevent that drift.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {
  group('Calendly duration consistency', () {
    test('ExternalUrls.calendlyDemo contains 15min slug', () {
      expect(ExternalUrls.calendlyDemo, contains('15min'));
      expect(ExternalUrls.calendlyDemo, isNot(contains('30min')));
    });

    test('ContactContent calendlyUrl matches ExternalUrls constant', () {
      final content = AppContent.contact;
      expect(content.calendlyUrl, equals(ExternalUrls.calendlyDemo));
    });

    test('Schedule a Demo method value says 15-minute', () {
      final content = AppContent.contact;
      final demoMethod = content.contactMethods.firstWhere(
        (m) => m.label == 'Schedule a Demo',
      );

      expect(demoMethod.value, contains('15-minute'));
      expect(demoMethod.value, isNot(contains('30')));
    });

    test('Schedule a Demo method URL matches calendly constant', () {
      final content = AppContent.contact;
      final demoMethod = content.contactMethods.firstWhere(
        (m) => m.label == 'Schedule a Demo',
      );

      expect(demoMethod.url, equals(ExternalUrls.calendlyDemo));
    });

    test('no content source references 30-minute for calendly calls', () {
      final content = AppContent.contact;

      // Check all contact method values
      for (final method in content.contactMethods) {
        if (method.value.toLowerCase().contains('call') ||
            method.value.toLowerCase().contains('demo')) {
          expect(method.value, isNot(contains('30')),
              reason:
                  'Contact method "${method.label}" should not reference 30 minutes');
        }
      }
    });
  });

  group('Calendly content.yaml consistency', () {
    late String yamlContent;

    setUpAll(() {
      final file = File('content.yaml');
      expect(file.existsSync(), isTrue,
          reason: 'content.yaml must exist at project root');
      yamlContent = file.readAsStringSync();
    });

    test('content.yaml calendly_demo URL contains 15min', () {
      expect(yamlContent, contains('calendly.com/alyshialedlie/15min'));
      expect(yamlContent, isNot(contains('calendly.com/alyshialedlie/30min')));
    });

    test('content.yaml contact method value says 15-minute', () {
      // The YAML value field near the calendly URL
      expect(yamlContent, contains('Book a 15-minute call'));
      expect(yamlContent, isNot(contains('Book a 30-minute call')));
    });
  });

  group('JSON-LD calendly consistency', () {
    test('JSON-LD demo event description says 15-minute', () {
      final file = File('jsonld_combined.json');
      if (!file.existsSync()) {
        markTestSkipped('jsonld_combined.json not present');
        return;
      }

      final raw = file.readAsStringSync();
      // No 30-minute references in any demo/calendly context
      final lines = raw.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('calendly') || line.contains('demo')) {
          expect(line, isNot(contains('30-minute')),
              reason: 'jsonld_combined.json line ${i + 1} references 30-minute');
        }
      }
    });

    test('JSON-LD calendly URLs use 15min slug', () {
      final file = File('jsonld_combined.json');
      if (!file.existsSync()) {
        markTestSkipped('jsonld_combined.json not present');
        return;
      }

      final raw = file.readAsStringSync();
      expect(raw, isNot(contains('calendly.com/alyshialedlie/30min')));
      // Verify 15min URLs are present
      expect(raw, contains('calendly.com/alyshialedlie/15min'));
    });
  });

  group('Static HTML calendly consistency', () {
    test('whylabs migration guide says 15-minute', () {
      final file = File('web/resources/whylabs-migration-guide.html');
      if (!file.existsSync()) {
        markTestSkipped('whylabs-migration-guide.html not present');
        return;
      }

      final html = file.readAsStringSync();
      expect(html, isNot(contains('30-minute')),
          reason: 'WhyLabs migration guide should say 15-minute not 30');
      expect(html, contains('15-minute'));
    });
  });
}
