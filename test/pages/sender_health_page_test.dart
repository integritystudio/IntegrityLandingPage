import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/sender_health_page.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import '../helpers/mock_provisioning_dio.dart';
import '../helpers/test_helpers.dart';

void main() {
  const healthyLabel = 'Healthy';
  const unhealthyLabel = 'Unhealthy';
  const lastCheckPrefix = 'Last check:';
  const refreshLabel = 'Refresh';

  late MockProvisioningDio mockDio;

  setUp(() {
    setUpOverflowErrorSuppression();
    mockDio = MockProvisioningDio();
    ProvisioningService.setDioForTesting(mockDio);
  });

  tearDown(() {
    ProvisioningService.resetDio();
    ProvisioningService.resetRetryDelay();
    tearDownOverflowErrorSuppression();
  });

  /// Pumps the page and returns after the first frame, with the initial
  /// health check still in flight.
  Future<void> pumpSenderHealthPage(
    WidgetTester tester, {
    VoidCallback? onBack,
  }) async {
    setScreenSize(tester, TestScreenSizes.desktopLarge);
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: SenderHealthPage(onBack: onBack),
      ),
    );
    clearOverflowExceptions(tester);
  }

  OutlineButton refreshButton(WidgetTester tester) =>
      tester.widget<OutlineButton>(find.byType(OutlineButton));

  group('SenderHealthPage', () {
    group('structure', () {
      testWidgets('renders heading, card title, version and refresh button',
          (tester) async {
        mockDio.mockGetResponse({'ok': true});

        await pumpSenderHealthPage(tester);
        await tester.pumpAndSettle();

        expect(find.text('Service Status'), findsOneWidget);
        expect(find.text('Sender Worker'), findsOneWidget);
        expect(find.text('Version: 1.0.0'), findsOneWidget);
        expect(find.text(refreshLabel), findsOneWidget);
      });

      testWidgets('shows no back button when onBack is null', (tester) async {
        mockDio.mockGetResponse({'ok': true});

        await pumpSenderHealthPage(tester);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsNothing);
      });

      testWidgets('back button triggers onBack callback', (tester) async {
        mockDio.mockGetResponse({'ok': true});
        var backCalled = false;

        await pumpSenderHealthPage(tester, onBack: () => backCalled = true);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    group('initial health check', () {
      testWidgets('shows a spinner and no status while the check is pending',
          (tester) async {
        mockDio.mockGetResponse({'ok': true});

        await pumpSenderHealthPage(tester);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(healthyLabel), findsNothing);
        expect(find.text(unhealthyLabel), findsNothing);
        expect(find.textContaining(lastCheckPrefix), findsNothing);
      });

      testWidgets('disables refresh while the check is pending',
          (tester) async {
        mockDio.mockGetResponse({'ok': true});

        await pumpSenderHealthPage(tester);

        expect(refreshButton(tester).onPressed, isNull);
      });

      testWidgets('shows Healthy badge and last-check time when ok:true',
          (tester) async {
        mockDio.mockGetResponse({'ok': true});

        await pumpSenderHealthPage(tester);
        await tester.pumpAndSettle();

        expect(find.text(healthyLabel), findsOneWidget);
        expect(find.text(unhealthyLabel), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining(lastCheckPrefix), findsOneWidget);
        expect(refreshButton(tester).onPressed, isNotNull);
        expect(mockDio.getCallCount, 1);
      });

      group('shows Unhealthy badge', () {
        final cases = <String, void Function()>{
          'when the service answers 200 with ok:false': () =>
              mockDio.mockGetResponse({'ok': false}),
          'when the service answers 500': () =>
              mockDio.mockGetResponse({'error': 'down'}, statusCode: 500),
          'when every connection attempt fails': () =>
              mockDio.mockGetError(DioExceptionType.connectionError),
        };

        for (final entry in cases.entries) {
          testWidgets(entry.key, (tester) async {
            entry.value();

            await pumpSenderHealthPage(tester);
            await tester.pumpAndSettle();

            expect(find.text(unhealthyLabel), findsOneWidget);
            expect(find.text(healthyLabel), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            expect(find.textContaining(lastCheckPrefix), findsOneWidget);
          });
        }
      });
    });

    group('refresh', () {
      testWidgets('re-queries the service and reflects the new answer',
          (tester) async {
        mockDio.mockGetResponse({'ok': true});
        await pumpSenderHealthPage(tester);
        await tester.pumpAndSettle();
        expect(find.text(healthyLabel), findsOneWidget);

        mockDio.mockGetResponse({'ok': false});
        await tester.tap(find.text(refreshLabel));
        await tester.pumpAndSettle();

        expect(mockDio.getCallCount, 2);
        expect(find.text(unhealthyLabel), findsOneWidget);
        expect(find.text(healthyLabel), findsNothing);
      });

      testWidgets('keeps the previous badge visible while a refresh is pending',
          (tester) async {
        mockDio.mockGetResponse({'ok': true});
        await pumpSenderHealthPage(tester);
        await tester.pumpAndSettle();
        // Hold the refresh in flight: a transient error on its first attempt
        // sends the service into its retry backoff, which the injected
        // retryDelay keeps open until the test releases it. The mock numbers
        // attempts by its lifetime call count, and the initial check was call 0.
        final backoff = Completer<void>();
        ProvisioningService.retryDelay = (_) => backoff.future;
        mockDio.mockGetError(DioExceptionType.connectionTimeout,
            attemptNumber: 1);
        mockDio.mockGetResponse({'ok': true}, attemptNumber: 2);

        await tester.tap(find.text(refreshLabel));
        await tester.pump();

        expect(find.text(healthyLabel), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(refreshButton(tester).onPressed, isNull);

        backoff.complete();
        await tester.pumpAndSettle();

        expect(refreshButton(tester).onPressed, isNotNull);
        expect(find.text(healthyLabel), findsOneWidget);
      });
    });
  });
}
