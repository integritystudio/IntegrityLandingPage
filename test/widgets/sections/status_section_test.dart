import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {

  group('StatusSection', () {
    group('StatusContent', () {
      test('default content has required fields', () {
        final content = AppContent.status;

        expect(content.title, isNotEmpty);
        expect(content.subtitle, isNotEmpty);
        expect(content.statusBadge, isNotEmpty);
      });

      test('has metrics', () {
        final content = AppContent.status;

        expect(content.metrics, isNotEmpty);
      });

      test('each metric has required fields', () {
        final content = AppContent.status;

        for (final metric in content.metrics) {
          expect(metric.value, isNotEmpty);
          expect(metric.label, isNotEmpty);
        }
      });

      test('has services', () {
        final content = AppContent.status;

        expect(content.services, isNotEmpty);
      });

      test('each service has required fields', () {
        final content = AppContent.status;

        for (final service in content.services) {
          expect(service.name, isNotEmpty);
          expect(service.status, isNotEmpty);
        }
      });

      test('has status page url', () {
        final content = AppContent.status;

        expect(content.statusPageUrl, isNotEmpty);
      });
    });

    group('StatusMetricContent', () {
      test('creates with all required fields', () {
        const metric = StatusMetricContent(
          value: '99.99%',
          label: 'Uptime',
          sublabel: 'Last 30 days',
          isOperational: true,
        );

        expect(metric.value, equals('99.99%'));
        expect(metric.label, equals('Uptime'));
        expect(metric.sublabel, equals('Last 30 days'));
        expect(metric.isOperational, isTrue);
      });

      test('sublabel is optional', () {
        const metric = StatusMetricContent(
          value: '100%',
          label: 'Availability',
          isOperational: true,
        );

        expect(metric.sublabel, isNull);
      });
    });

    group('StatusServiceContent', () {
      test('creates with all required fields', () {
        const service = StatusServiceContent(
          name: 'API',
          status: 'Operational',
        );

        expect(service.name, equals('API'));
        expect(service.status, equals('Operational'));
        expect(service.isOperational, isTrue);
      });

      test('degraded service has isOperational false', () {
        const service = StatusServiceContent(
          name: 'Database',
          status: 'Degraded',
        );

        expect(service.isOperational, isFalse);
      });
    });

    group('StatusContent constructor', () {
      test('creates with all required fields', () {
        const content = StatusContent(
          title: 'Status',
          subtitle: 'Health check',
          statusBadge: 'All Systems Go',
          allOperational: true,
          metrics: [],
          services: [],
          statusPageUrl: 'https://status.example.com',
          statusPageCta: 'View Status',
        );

        expect(content.title, equals('Status'));
        expect(content.subtitle, equals('Health check'));
        expect(content.statusBadge, equals('All Systems Go'));
        expect(content.allOperational, isTrue);
        expect(content.metrics, isEmpty);
        expect(content.services, isEmpty);
        expect(content.statusPageUrl, equals('https://status.example.com'));
        expect(content.statusPageCta, equals('View Status'));
      });
    });
  });
}
