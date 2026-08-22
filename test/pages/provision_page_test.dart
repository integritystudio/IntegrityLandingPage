import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:integrity_studio_ai/pages/provision_page.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';
import 'package:integrity_studio_ai/widgets/common/alert.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/copyable_code_field.dart';
import '../helpers/mock_http_adapter.dart';
import '../helpers/test_helpers.dart';

/// ProvisionPage contract:
/// - Shows the authenticated email and a Generate API Key button.
/// - Generate sends a provision_api_key event derived from the auth email
///   (lowercased, trimmed, name = local part) with the JWT attached.
/// - Success shows the key in a copyable field, swaps Generate for
///   Go to Dashboard, and loads org context via bootstrap.
/// - Failure shows a sanitized error and keeps Generate available.
/// - Go to Dashboard opens the external dashboard SPA; a launcher failure
///   is reported, never thrown (#55 pattern).
void main() {
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  late MockHttpAdapter adapter;

  setUp(() {
    setUpOverflowErrorSuppression();
    initializeTestContent();
    adapter = MockHttpAdapter();
    ProvisioningService.setDioForTesting(dioWithMockAdapter(adapter));
    ProvisioningService.retryDelay = (_) async {};
  });

  tearDown(() {
    ProvisioningService.resetDio();
    ProvisioningService.resetRetryDelay();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
    tearDownOverflowErrorSuppression();
  });

  /// Records URLs the page asked the platform to open; [fail] makes every
  /// launch throw instead, exercising the error-capture path.
  List<String> mockUrlLauncher({bool fail = false}) {
    final launched = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
      if (fail) {
        throw PlatformException(code: 'LAUNCH_ERROR');
      }
      if (call.method == 'canLaunch') return true;
      launched.add((call.arguments as Map)['url'] as String);
      return true;
    });
    return launched;
  }

  const auth = AuthSuccess(jwt: 'test-jwt', email: 'user@example.com');

  Future<void> pumpProvisionPage(
    WidgetTester tester, {
    AuthSuccess auth = auth,
    VoidCallback? onBack,
  }) async {
    setDesktopSize(tester);
    await tester.pumpWidget(MaterialApp(
      theme: testTheme,
      home: ProvisionPage(auth: auth, onBack: onBack),
    ));
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  void stubProvisionSuccess({String apiKey = 'isk_test_key_123'}) {
    adapter.stubJson(
      'POST',
      {'ok': true, 'apiKey': apiKey, 'received': 'ack'},
      path: '/send',
    );
  }

  void stubBootstrapSuccess({int monthlyUnits = 10000}) {
    adapter.stubJson(
      'POST',
      {
        'organizations': [
          {
            'id': 'org-1',
            'name': 'Acme Corp',
            'role': 'owner',
            'plan_key': 'growth',
            'billing_status': 'active',
          },
        ],
        'active_org_id': 'org-1',
        'entitlements': {'monthly_units': monthlyUnits},
        'usage_snapshot': {'month_to_date_units': 4200},
      },
      path: '/bootstrap',
    );
  }

  /// Taps Generate and settles the request + bootstrap round trips.
  Future<void> generateKey(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(GradientButton, 'Generate API Key'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    clearOverflowExceptions(tester);
  }

  group('initial state', () {
    testWidgets('shows the authenticated email and Generate button',
        (tester) async {
      await pumpProvisionPage(tester);

      expect(find.text('Provision API Key'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Generate API Key'),
          findsOneWidget);
      expect(find.byType(CopyableCodeField), findsNothing);
    });

    testWidgets('shows back button only when onBack is provided',
        (tester) async {
      var backCalled = false;
      await pumpProvisionPage(tester, onBack: () => backCalled = true);

      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backCalled, isTrue);
    });

    testWidgets('hides back button when onBack is null', (tester) async {
      await pumpProvisionPage(tester);

      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  group('provisioning request', () {
    testWidgets(
        'sends provision_api_key event derived from the auth email with JWT',
        (tester) async {
      stubProvisionSuccess();
      stubBootstrapSuccess();
      await pumpProvisionPage(
        tester,
        auth: const AuthSuccess(jwt: 'test-jwt', email: ' User@Example.COM '),
      );

      await generateKey(tester);

      final sendRequest =
          adapter.requestLog.singleWhere((r) => r.path.endsWith('/send'));
      final body = jsonDecode(sendRequest.data as String);
      expect(body['action'], equals('provision_api_key'));
      expect(body['email'], equals('user@example.com'));
      expect(body['name'], equals('user'));
      expect(
        sendRequest.headers['x-session-data'],
        equals(base64Encode(utf8.encode('test-jwt'))),
      );
    });

    testWidgets('disables the button while the request is in flight',
        (tester) async {
      // Gate the response so the request is observably in flight, then release
      // it — stubNever would leave dio's timeout Timer pending at teardown.
      final gate = adapter.stubDelayedJson(
          'POST', {'ok': true, 'apiKey': 'isk_gated', 'received': 'ack'});
      await pumpProvisionPage(tester);

      await tester.tap(find.byType(GradientButton));
      await tester.pump();

      final button = tester.widget<GradientButton>(find.byType(GradientButton));
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);

      gate.complete();
      await tester.pump(const Duration(milliseconds: 100));
      clearOverflowExceptions(tester);
    });
  });

  group('provisioning success', () {
    testWidgets('shows the API key and swaps Generate for Go to Dashboard',
        (tester) async {
      stubProvisionSuccess(apiKey: 'isk_live_abc');
      stubBootstrapSuccess();
      await pumpProvisionPage(tester);

      await generateKey(tester);

      expect(find.byType(CopyableCodeField), findsOneWidget);
      expect(find.text('isk_live_abc'), findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Go to Dashboard'),
          findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Generate API Key'),
          findsNothing);
    });

    testWidgets('shows org context with usage against the monthly quota',
        (tester) async {
      stubProvisionSuccess();
      stubBootstrapSuccess(monthlyUnits: 10000);
      await pumpProvisionPage(tester);

      await generateKey(tester);

      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('growth'), findsOneWidget);
      expect(find.text('4200 / 10000 units this month'), findsOneWidget);
    });

    testWidgets('omits the usage line when the plan has no monthly quota',
        (tester) async {
      stubProvisionSuccess();
      stubBootstrapSuccess(monthlyUnits: 0);
      await pumpProvisionPage(tester);

      await generateKey(tester);

      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.textContaining('units this month'), findsNothing);
    });

    testWidgets('still shows the API key when bootstrap fails',
        (tester) async {
      stubProvisionSuccess(apiKey: 'isk_live_abc');
      adapter.stubJson('POST', {'error': 'unauthorized'},
          statusCode: 401, path: '/bootstrap');
      await pumpProvisionPage(tester);

      await generateKey(tester);

      expect(find.text('isk_live_abc'), findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Go to Dashboard'),
          findsOneWidget);
      expect(find.text('Acme Corp'), findsNothing);
    });
  });

  group('provisioning failure', () {
    testWidgets('shows the server error and keeps Generate available',
        (tester) async {
      adapter.stubJson('POST', {'error': 'No organization found'},
          statusCode: 400, path: '/send');
      await pumpProvisionPage(tester);

      await generateKey(tester);

      expect(find.byType(Alert), findsOneWidget);
      expect(find.text('No organization found'), findsOneWidget);
      expect(find.byType(CopyableCodeField), findsNothing);
      expect(find.widgetWithText(GradientButton, 'Generate API Key'),
          findsOneWidget);
    });

    testWidgets('treats a 200 without an apiKey as an error', (tester) async {
      adapter.stubJson('POST', {'ok': true}, path: '/send');
      await pumpProvisionPage(tester);

      await generateKey(tester);

      expect(find.byType(Alert), findsOneWidget);
      expect(find.byType(CopyableCodeField), findsNothing);
      // Bootstrap runs only after a usable key exists.
      expect(
        adapter.requestLog.where((r) => r.path.endsWith('/bootstrap')),
        isEmpty,
      );
    });

    testWidgets('clears a previous error when retrying succeeds',
        (tester) async {
      adapter.stubJson('POST', {'error': 'No organization found'},
          statusCode: 400, path: '/send');
      await pumpProvisionPage(tester);
      await generateKey(tester);
      expect(find.byType(Alert), findsOneWidget);

      stubProvisionSuccess(apiKey: 'isk_retry_ok');
      stubBootstrapSuccess();
      await generateKey(tester);

      expect(find.byType(Alert), findsNothing);
      expect(find.text('isk_retry_ok'), findsOneWidget);
    });
  });

  group('go to dashboard', () {
    testWidgets('opens the dashboard SPA', (tester) async {
      final launched = mockUrlLauncher();
      stubProvisionSuccess();
      stubBootstrapSuccess();
      await pumpProvisionPage(tester);
      await generateKey(tester);

      await tester
          .tap(find.widgetWithText(GradientButton, 'Go to Dashboard'));
      await tester.pump();

      expect(launched, [ExternalUrls.dashboardApp]);
    });

    testWidgets('survives a launcher failure without crashing (#55 pattern)',
        (tester) async {
      mockUrlLauncher(fail: true);
      stubProvisionSuccess(apiKey: 'isk_live_abc');
      stubBootstrapSuccess();
      await pumpProvisionPage(tester);
      await generateKey(tester);

      await tester
          .tap(find.widgetWithText(GradientButton, 'Go to Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The failure is captured, not thrown: page still standing, key visible.
      expect(tester.takeException(), isNull);
      expect(find.text('isk_live_abc'), findsOneWidget);
    });
  });
}
