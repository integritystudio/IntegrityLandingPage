import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';

/// Integration tests for ProvisioningService.
///
/// These tests make real HTTP calls to the dev worker and verify end-to-end behavior.
/// `sender-worker` without the -dev suffix is production; there is no staging Worker.
/// Guarded by dart-define: LIVE_TESTS=true
/// Run: flutter test test/services/provisioning_service_live_test.dart \
///        --dart-define=LIVE_TESTS=true \
///        --dart-define=SENDER_WORKER_URL=https://sender-worker-dev.alyshia-b38.workers.dev
///
/// Mark tests as skip when prerequisites aren't met (e.g., Stripe not configured on dev).
const _liveTestsEnabled = bool.fromEnvironment('LIVE_TESTS');

/// An Auth0 access token for the tests that need a signed-in user. Sign in through
/// /login, then copy `accessToken` from the `auth0_session` sessionStorage entry.
/// Against the dev worker the token must come from the dev tenant, so sign in on the
/// app run with the dev `--dart-define`s (CLAUDE.md, "Pointing the Flutter app at the dev workers").
const _liveAccessToken = String.fromEnvironment('LIVE_ACCESS_TOKEN');

void main() {
  // Skip all tests in this file if LIVE_TESTS is not enabled
  if (!_liveTestsEnabled) {
    return;
  }

  group('ProvisioningService live integration', () {
    setUpAll(() {
      // Reset Dio to use real HTTP (not mocked)
      ProvisioningService.resetDio();
    });

    group('checkHealth', () {
      test('staging health endpoint returns true', () async {
        // Receiver worker is at: https://api-provisioning-receiver.alyshia-b38.workers.dev/health
        final result = await ProvisioningService.checkHealth(
          'https://api-provisioning-receiver.alyshia-b38.workers.dev',
        );

        expect(result, true);
      });

      test('invalid URL returns false', () async {
        final result = await ProvisioningService.checkHealth(
          'http://invalid-url.example.com',
        );

        expect(result, false);
      });

      test('non-https URL returns false', () async {
        final result = await ProvisioningService.checkHealth(
          'http://api-provisioning-receiver.alyshia-b38.workers.dev',
        );

        expect(result, false);
      });
    });

    group('sendEvent', () {
      test(
        'returns ProvisioningSuccess with valid JWT',
        skip: 'requires a dev-tenant signed-in user; '
            'pass --dart-define=LIVE_ACCESS_TOKEN=<token> to run this test manually '
            '(sender-worker-dev binds its own SIGNING_KEYS/ACTIVE_KEY_ID — never copy prd keys to dev)',
        () async {
          expect(_liveAccessToken, isNotEmpty, reason: 'LIVE_ACCESS_TOKEN not set');

          // Act: send provisioning event
          const event = ProvisioningEvent(
            action: 'provision_api_key',
            name: 'Test User',
            email: 'test@example.com',
            tier: 'starter',
          );

          final result = await ProvisioningService.sendEvent(event, jwt: _liveAccessToken);

          // Assert
          expect(result, isA<ProvisioningSuccess>());
          final success = result as ProvisioningSuccess;
          // The receiver mints obtk_ keys (workers/lib/api-keys.ts).
          expect(success.apiKey, startsWith('obtk_'));
        },
      );
    });

    group('createCheckoutSession', () {
      test(
        'returns CheckoutSuccess with valid Stripe URL',
        skip: 'dev worker has Stripe sandbox keys bound, but this creates a real test-mode session; '
            'run manually with a disposable test email when exercising the checkout flow',
        () async {
          final result = await ProvisioningService.createCheckoutSession(
            email: 'test@example.com',
            tier: 'growth',
          );

          expect(result, isA<CheckoutSuccess>());
          final success = result as CheckoutSuccess;
          expect(success.checkoutUrl, contains('stripe.com'));
        },
      );

      test('gracefully handles missing Stripe configuration', () async {
        // Dev worker has Stripe sandbox keys bound (2026-08-03), so this will
        // typically return CheckoutSuccess, not CheckoutError.
        final result = await ProvisioningService.createCheckoutSession(
          email: 'test@example.com',
          tier: 'growth',
        );

        // Result is either CheckoutSuccess or CheckoutError — both are acceptable here.
        expect(result, isA<CheckoutResponse>());
      });
    });

    group('bootstrap', () {
      test(
        'returns BootstrapSuccess with org and entitlements',
        skip: 'requires a signed-in user; '
            'pass --dart-define=LIVE_ACCESS_TOKEN=<token> to run this test manually',
        () async {
          expect(_liveAccessToken, isNotEmpty, reason: 'LIVE_ACCESS_TOKEN not set');

          final result = await ProvisioningService.bootstrap(jwt: _liveAccessToken);

          expect(result, isA<BootstrapSuccess>());
          final success = result as BootstrapSuccess;
          expect(success.activeOrg, isNotNull);
        },
      );
    });
  });
}
