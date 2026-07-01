import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {

  group('ServicesContent', () {
    group('current content', () {
      test('has required fields', () {
        final content = AppContent.services;

        expect(content.sectionId, equals('services'));
        expect(content.title, isNotEmpty);
        expect(content.subtitle, isNotEmpty);
        expect(content.ctaText, isNotEmpty);
        expect(content.ctaUrl, isNotEmpty);
      });

      test('has description for EU AI Act positioning', () {
        final content = AppContent.services;

        expect(content.description, isNotEmpty);
        expect(content.description.length, greaterThan(50));
      });

      test('has 6 services', () {
        final content = AppContent.services;

        expect(content.services.length, equals(6));
      });

      test('service titles cover all platform capabilities', () {
        final content = AppContent.services;
        final titles = content.services.map((s) => s.title).toList();

        expect(titles, contains('LLM Monitoring & Tracing'));
        expect(titles, contains('Agent Observability'));
        expect(titles, contains('Compliance & Governance'));
        expect(titles, contains('Analytics & Dashboards'));
        expect(titles, contains('Alerting & Incident Management'));
        expect(titles, contains('Developer Experience'));
      });

      test('each service has required fields', () {
        final content = AppContent.services;

        for (final service in content.services) {
          expect(service.title, isNotEmpty);
          expect(service.description, isNotEmpty);
          expect(service.capabilities, isNotEmpty);
          expect(service.capabilities.length, greaterThanOrEqualTo(3));
        }
      });

      test('each service has an icon', () {
        final content = AppContent.services;

        for (final service in content.services) {
          expect(service.icon, isNotNull);
        }
      });

      test('most services have CTA links', () {
        final content = AppContent.services;
        final servicesWithCta =
            content.services.where((s) => s.ctaText != null).toList();

        expect(servicesWithCta.length, greaterThanOrEqualTo(4));
      });
    });

    group('ServiceItemContent', () {
      test('creates with all required fields', () {
        const service = ServiceItemContent(
          icon: LucideIcons.activity,
          title: 'Test Service',
          description: 'Test description',
          capabilities: ['Capability 1', 'Capability 2'],
          ctaText: 'Learn More',
          ctaUrl: '/test',
        );

        expect(service.icon, equals(LucideIcons.activity));
        expect(service.title, equals('Test Service'));
        expect(service.description, equals('Test description'));
        expect(service.capabilities.length, equals(2));
        expect(service.ctaText, equals('Learn More'));
        expect(service.ctaUrl, equals('/test'));
      });

      test('CTA fields are optional', () {
        const service = ServiceItemContent(
          icon: LucideIcons.bot,
          title: 'No CTA Service',
          description: 'Service without CTA',
          capabilities: ['Cap 1'],
        );

        expect(service.ctaText, isNull);
        expect(service.ctaUrl, isNull);
      });
    });

    group('ServicesContent constructor', () {
      test('creates with all required fields', () {
        const content = ServicesContent(
          sectionId: 'test-services',
          title: 'Test Title',
          subtitle: 'Test Subtitle',
          description: 'Test Description',
          services: [],
          ctaText: 'Test CTA',
          ctaUrl: '/test',
        );

        expect(content.sectionId, equals('test-services'));
        expect(content.title, equals('Test Title'));
        expect(content.subtitle, equals('Test Subtitle'));
        expect(content.description, equals('Test Description'));
        expect(content.services, isEmpty);
        expect(content.ctaText, equals('Test CTA'));
        expect(content.ctaUrl, equals('/test'));
      });
    });

    group('content quality', () {
      test('compliance service mentions EU AI Act', () {
        final content = AppContent.services;
        final complianceService = content.services.firstWhere(
          (s) => s.title.toLowerCase().contains('compliance'),
        );

        expect(
          complianceService.description.toLowerCase(),
          contains('eu ai act'),
        );
      });

      test('monitoring service mentions latency metrics', () {
        final content = AppContent.services;
        final monitoringService = content.services.firstWhere(
          (s) => s.title.toLowerCase().contains('monitoring'),
        );

        expect(
          monitoringService.description.toLowerCase(),
          contains('latency'),
        );
      });

      test('developer experience service mentions SDKs', () {
        final content = AppContent.services;
        final devService = content.services.firstWhere(
          (s) => s.title.toLowerCase().contains('developer'),
        );

        expect(
          devService.description.toLowerCase(),
          contains('sdk'),
        );
      });
    });
  });
}
