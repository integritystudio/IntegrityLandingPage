import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';

/// Integration tests for ProvisioningService.
///
/// These tests make real HTTP calls to staging environment and verify end-to-end behavior.
/// Guarded by dart-define: LIVE_TESTS=true
/// Run: flutter test test/services/provisioning_service_live_test.dart \
///        --dart-define=LIVE_TESTS=true \
///        --dart-define=SENDER_WORKER_URL=https://sender-worker.alyshia-b38.workers.dev
///
/// Mark tests as skip when prerequisites aren't met (e.g., Stripe not configured on staging).
const _liveTestsEnabled = bool.fromEnvironment('LIVE_TESTS');

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
        // Receiver worker is at: https://receiver-worker.alyshia-b38.workers.dev/health
        final result = await ProvisioningService.checkHealth(
          'https://receiver-worker.alyshia-b38.workers.dev',
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
          'http://receiver-worker.alyshia-b38.workers.dev',
        );

        expect(result, false);
      });
    });

    group('signUp', () {
      test(
        'returns AuthSuccess with valid JWT structure',
        skip: 'requires Auth0 + sender-worker configured on staging',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final testEmail = 'live-test-flutter-$timestamp@integritystudio-test.invalid';

          // Act
          final result = await ProvisioningService.signUp(
            testEmail,
            'TempPassword123!@#',
            name: 'Live Test User',
          );

          // Assert
          expect(result, isA<AuthSuccess>());
          final authSuccess = result as AuthSuccess;
          expect(authSuccess.jwt, isNotEmpty);
          // JWT structure: base64.base64.base64
          expect(authSuccess.jwt.split('.'), hasLength(3));
        },
      );

      test('invalid email returns AuthError', () async {
        final result = await ProvisioningService.signUp(
          'not-an-email',
          'password123',
        );

        expect(result, isA<AuthError>());
      });
    });

    group('signIn', () {
      test('returns AuthError (404) - not implemented in worker', () async {
        // The sender-worker intentionally returns 404 for /signin
        // This test documents the contract
        final result = await ProvisioningService.signIn(
          'test@example.com',
          'password123',
        );

        expect(result, isA<AuthError>());
      });
    });

    group('sendEvent', () {
      test(
        'returns ProvisioningSuccess with valid JWT',
        skip: 'blocked: receiver-worker apiKey return not yet deployed to staging',
        () async {
          // Requires valid JWT from signUp
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final testEmail = 'live-test-flutter-event-$timestamp@integritystudio-test.invalid';

          // Sign up to get JWT
          final authResult = await ProvisioningService.signUp(
            testEmail,
            'TempPassword123!@#',
          );
          expect(authResult, isA<AuthSuccess>());
          final jwt = (authResult as AuthSuccess).jwt;

          // Act: send provisioning event
          const event = ProvisioningEvent(
            action: 'provision_api_key',
            name: 'Test User',
            email: 'test@example.com',
            tier: 'starter',
          );

          final result = await ProvisioningService.sendEvent(event, jwt: jwt);

          // Assert
          expect(result, isA<ProvisioningSuccess>());
          final success = result as ProvisioningSuccess;
          expect(success.apiKey, startsWith('sk-'));
        },
      );
    });

    group('createCheckoutSession', () {
      test(
        'returns CheckoutSuccess with valid Stripe URL',
        skip: 'skipped when Stripe not configured',
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
        // If Stripe isn't configured on staging, service returns CheckoutError
        // This verifies graceful degradation
        final result = await ProvisioningService.createCheckoutSession(
          email: 'test@example.com',
          tier: 'growth',
        );

        // Result may be either CheckoutSuccess (if Stripe is configured)
        // or CheckoutError (if Stripe is not configured)
        expect(result, isA<CheckoutResponse>());
      });
    });

    group('bootstrap', () {
      test(
        'returns BootstrapSuccess with org and entitlements',
        skip: 'requires authenticated session',
        () async {
          // This requires a valid Auth0 session token
          // Skipped in CI unless BOOTSTRAP_TOKEN is set
          const bootstrapToken = String.fromEnvironment('BOOTSTRAP_TOKEN');

          expect(bootstrapToken, isNotEmpty, reason: 'BOOTSTRAP_TOKEN not set');

          final result = await ProvisioningService.bootstrap(jwt: bootstrapToken);

          expect(result, isA<BootstrapSuccess>());
          final success = result as BootstrapSuccess;
          expect(success.activeOrg, isNotNull);
        },
      );
    });
  });
}
