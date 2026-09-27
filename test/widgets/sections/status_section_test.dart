import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/models.dart';
import 'package:integrity_studio_ai/theme/colors.dart';
import 'package:integrity_studio_ai/widgets/sections/status_section.dart';
import '../../helpers/test_helpers.dart';

const _testContent = StatusContent(
  title: 'Platform Status',
  subtitle: 'Real-time operational health',
  statusBadge: 'All Systems Operational',
  allOperational: true,
  metrics: [
    StatusMetricContent(label: 'Uptime', value: '99.99%'),
    StatusMetricContent(label: 'Latency', value: '42ms', sublabel: 'p99'),
  ],
  services: [
    StatusServiceContent(name: 'API Gateway', status: 'Operational'),
    StatusServiceContent(name: 'Ingest Pipeline', status: 'Degraded'),
  ],
  statusPageUrl: 'https://status.example.com',
  statusPageCta: 'View Status Page',
);

const _noUrlContent = StatusContent(
  title: 'Platform Status',
  subtitle: 'Real-time operational health',
  statusBadge: 'All Systems Operational',
  allOperational: true,
  metrics: [
    StatusMetricContent(label: 'Uptime', value: '99.99%'),
  ],
  services: [
    StatusServiceContent(name: 'API Gateway', status: 'Operational'),
  ],
  statusPageUrl: '',
  statusPageCta: 'View Status Page',
);

// metrics must be non-empty to avoid the AppContent.status fallback
const _degradedContent = StatusContent(
  title: 'Platform Status',
  subtitle: 'Real-time operational health',
  statusBadge: 'Partial Outage',
  allOperational: false,
  metrics: [
    StatusMetricContent(label: 'Uptime', value: '95%', isOperational: false),
  ],
  services: [],
  statusPageUrl: '',
  statusPageCta: 'View Status Page',
);

void main() {
  group('StatusSection', () {
    group('widget structure', () {
      testWidgets('renders without throwing', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.byType(StatusSection), findsOneWidget);
      });

      testWidgets('renders section title', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.text('Platform Status'), findsOneWidget);
      });

      testWidgets('renders status badge text', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.text('All Systems Operational'), findsOneWidget);
      });

      testWidgets('renders metric values and labels', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.text('99.99%'), findsOneWidget);
        expect(find.text('Uptime'), findsOneWidget);
        expect(find.text('42ms'), findsOneWidget);
        expect(find.text('Latency'), findsOneWidget);
      });

      testWidgets('renders metric sublabel when present', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.text('p99'), findsOneWidget);
      });

      testWidgets('renders service names in services card', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.text('API Gateway'), findsOneWidget);
        expect(find.text('Ingest Pipeline'), findsOneWidget);
      });

      testWidgets('renders service statuses in services card', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.text('Operational'), findsAtLeastNWidgets(1));
        expect(find.text('Degraded'), findsOneWidget);
      });

      testWidgets('renders status page link when url is non-empty', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();
        expect(find.text('View Status Page'), findsOneWidget);
      });

      testWidgets('does not render status page link when url is empty', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _noUrlContent)),
        );
        await tester.pump();
        expect(find.text('View Status Page'), findsNothing);
      });
    });

    group('status badge color', () {
      testWidgets('badge uses success color when allOperational is true', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pump();

        // Badge text exists and the widget renders without error
        expect(find.text('All Systems Operational'), findsOneWidget);

        // Verify success color is used by checking no warning-colored text
        // for the operational badge (implementation detail: color is on the Text widget)
        final badgeText = tester.widget<Text>(
          find.text('All Systems Operational'),
        );
        expect(badgeText.style?.color, equals(AppColors.success));
      });

      testWidgets('badge uses warning color when allOperational is false', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _degradedContent)),
        );
        await tester.pump();

        expect(find.text('Partial Outage'), findsOneWidget);
        final badgeText = tester.widget<Text>(
          find.text('Partial Outage'),
        );
        expect(badgeText.style?.color, equals(AppColors.warning));
      });
    });

    group('accessibility', () {
      testWidgets('service rows have semantics labels', (tester) async {
        setDesktopSize(tester);
        final semanticsHandle = tester.ensureSemantics();
        await tester.pumpWidget(
          testableSection(const StatusSection(content: _testContent)),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(
          find.bySemanticsLabel(RegExp(r'API Gateway: Operational')),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.bySemanticsLabel(RegExp(r'Ingest Pipeline: Degraded')),
          findsAtLeastNWidgets(1),
        );

        semanticsHandle.dispose();
      });
    });
  });
}
