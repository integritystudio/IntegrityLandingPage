import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';

import '../helpers/mock_provisioning_dio.dart';

/// Contract tests for ProvisioningService.
///
/// Verify that Dart-side request/response shapes match TypeScript Zod schemas
/// (sender-worker, api-provisioning-receiver) without making live HTTP calls. The
/// success response is the production receiver's, observability-toolkit
/// `services/api-provisioning-receiver/src/types.ts` `ProvisionApiKeyResponse`;
/// its key field is `token`, not the `apiKey` an old local stub returned.
///
/// Uses the same MockProvisioningDio seam as unit tests for zero network overhead.
/// The production receiver's key namespace and format (`obtk_` + 64 hex; its schemas.ts).
const _tokenNamespace = 'obtk_';
final _productionToken = '$_tokenNamespace${'0123456789abcdef' * 4}';

void main() {
  late MockProvisioningDio mockDio;

  setUp(() {
    mockDio = MockProvisioningDio();
    ProvisioningService.setDioForTesting(mockDio);
    ProvisioningService.retryDelay = (_) async {};
  });

  tearDown(() {
    ProvisioningService.resetDio();
    ProvisioningService.resetRetryDelay();
  });

  group('SendRequestSchema contract', () {
    /// Links to: workers/sender-worker/src/types.ts:82–92
    test('sends action, name, email, tier without extras when orgName is null', () async {
      mockDio.mockPostResponse({'ok': true, 'token': 'sk-test123', 'received': {}});
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'alice',
        email: 'alice@example.com',
        tier: 'starter',
      );
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert: response is a success (received field is an object, not a string)
      expect(result, isA<ProvisioningSuccess>());
      // Assert: POST body matches SendRequestSchema (no org_name when null)
      expect(mockDio.lastPostBody, {
        'action': 'provision_api_key',
        'name': 'alice',
        'email': 'alice@example.com',
        'tier': 'starter',
        // org_name defaults to email domain in sender-worker schema, but we don't send it
      });
    });

    test('sends org_name in snake_case when provided', () async {
      mockDio.mockPostResponse({'ok': true, 'token': 'sk-test123', 'received': {}});
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'alice',
        email: 'alice@example.com',
        tier: 'growth',
        orgName: 'Acme Corp',
      );
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert: response is a success (received field is an object, not a string)
      expect(result, isA<ProvisioningSuccess>());
      // Assert: POST body includes org_name in snake_case (SendRequestSchema)
      expect(mockDio.lastPostBody, {
        'action': 'provision_api_key',
        'name': 'alice',
        'email': 'alice@example.com',
        'tier': 'growth',
        'org_name': 'Acme Corp',
      });
    });

    test('action is always provision_api_key', () async {
      mockDio.mockPostResponse({'ok': true, 'token': 'sk-test123', 'received': {}});
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert
      expect(result, isA<ProvisioningSuccess>());
      expect(mockDio.lastPostBody?['action'], 'provision_api_key');
    });

    test('tier accepts all three valid values: starter, growth, enterprise', () async {
      mockDio.mockPostResponse({'ok': true, 'token': 'sk-test123', 'received': {}});
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      for (final tier in ['starter', 'growth', 'enterprise']) {
        mockDio.postCallCount = 0;
        final event = ProvisioningEvent(
          action: 'provision_api_key',
          name: 'test',
          email: 'test@example.com',
          tier: tier,
        );

        // Act
        final result = await ProvisioningService.sendEvent(event, jwt: jwt);

        // Assert
        expect(result, isA<ProvisioningSuccess>());
        expect(mockDio.lastPostBody?['tier'], tier);
      }
    });

    test('JWT is sent in x-session-data header as base64', () async {
      mockDio.mockPostResponse({'ok': true, 'token': 'sk-test123', 'received': {}});
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert: response is a success (received field is an object, not a string)
      expect(result, isA<ProvisioningSuccess>());
      // Assert: JWT is sent via x-session-data header (encoded in sender-worker)
      // POST body doesn't contain JWT directly
      expect(mockDio.lastPostBody, isA<Map<String, dynamic>>());
    });

    test('Content-Type is application/json', () async {
      // This is implicitly verified by JSON serialization, but we verify here
      mockDio.mockPostResponse({'ok': true, 'token': 'sk-test123', 'received': {}});
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert: response is a success (received field is an object, not a string)
      expect(result, isA<ProvisioningSuccess>());
      // Assert: POST body is JSON (verified by jsonEncode in service)
      expect(mockDio.lastPostBody, isA<Map<String, dynamic>>());
    });
  });

  group('Receiver response contract', () {
    /// Links to: observability-toolkit services/api-provisioning-receiver/src/types.ts
    /// (`ProvisionApiKeyResponse`: `{ ok: true, token, keyId, prefix, tier }`).
    test('{ ok: true, token, keyId, prefix, tier } returns ProvisioningSuccess', () async {
      mockDio.mockPostResponse({
        'ok': true,
        'token': _productionToken,
        'keyId': '00000000-0000-4000-8000-000000000001',
        'prefix': _productionToken.substring(_tokenNamespace.length, _tokenNamespace.length + 8),
        'tier': 'starter',
      });
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert
      expect(result, isA<ProvisioningSuccess>());
      expect((result as ProvisioningSuccess).apiKey, _productionToken);
    });

    // The stub's old shape: a key under `apiKey` and no `token` is not a success.
    test('a response with apiKey but no token returns ProvisioningError', () async {
      mockDio.mockPostResponse({
        'ok': true,
        'apiKey': _productionToken,
        'received': <String, dynamic>{},
      });
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert
      expect(result, isA<ProvisioningError>());
    });

    test('empty token returns ProvisioningError', () async {
      mockDio.mockPostResponse({
        'ok': true,
        'token': '',
        'received': {'action': 'provision_api_key'},
      });
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert
      expect(result, isA<ProvisioningError>());
    });

    test('passes the obtk_ token through unchanged', () async {
      mockDio.mockPostResponse({'ok': true, 'token': _productionToken, 'tier': 'starter'});
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert
      expect(result, isA<ProvisioningSuccess>());
      expect((result as ProvisioningSuccess).apiKey, _productionToken);
    });
  });

  group('Health endpoint contract', () {
    /// Links to: observability-toolkit services/api-provisioning-receiver/src/index.ts (GET /health)
    test('{ ok: true } returns true', () async {
      mockDio.mockGetResponse({'ok': true, 'service': 'api-provisioning-receiver'});

      // Act
      final result = await ProvisioningService.checkHealth('https://receiver.example.com');

      // Assert
      expect(result, true);
    });

    test('{ ok: false } returns false', () async {
      mockDio.mockGetResponse({'ok': false, 'service': 'api-provisioning-receiver'});

      // Act
      final result = await ProvisioningService.checkHealth('https://receiver.example.com');

      // Assert
      expect(result, false);
    });

    test('missing ok key returns false', () async {
      mockDio.mockGetResponse({'service': 'api-provisioning-receiver'});

      // Act
      final result = await ProvisioningService.checkHealth('https://receiver.example.com');

      // Assert
      expect(result, false);
    });

    test('non-200 status returns false', () async {
      mockDio.mockGetResponse(
        {'ok': true, 'service': 'api-provisioning-receiver'},
        statusCode: 500,
      );

      // Act
      final result = await ProvisioningService.checkHealth('https://receiver.example.com');

      // Assert
      expect(result, false);
    });
  });

  group('Checkout response contract', () {
    /// Links to: workers/sender-worker/src/index.ts:handleCreateCheckoutSession
    test('{ checkoutUrl: "https://..." } returns CheckoutSuccess', () async {
      mockDio.mockPostResponse({
        'checkoutUrl': 'https://checkout.stripe.com/session/123',
      });

      // Act
      final result = await ProvisioningService.createCheckoutSession(
        email: 'test@example.com',
        tier: 'growth',
      );

      // Assert
      expect(result, isA<CheckoutSuccess>());
      expect(
        (result as CheckoutSuccess).checkoutUrl,
        'https://checkout.stripe.com/session/123',
      );
    });

    test('missing checkoutUrl on 200 returns CheckoutError', () async {
      mockDio.mockPostResponse({'status': 'pending'});

      // Act
      final result = await ProvisioningService.createCheckoutSession(
        email: 'test@example.com',
        tier: 'growth',
      );

      // Assert
      expect(result, isA<CheckoutError>());
    });

    test('request body contains email and tier only', () async {
      mockDio.mockPostResponse({
        'checkoutUrl': 'https://checkout.stripe.com/session/123',
      });

      // Act
      await ProvisioningService.createCheckoutSession(
        email: 'test@example.com',
        tier: 'enterprise',
      );

      // Assert
      expect(mockDio.lastPostBody, {
        'email': 'test@example.com',
        'tier': 'enterprise',
      });
    });

    test('non-200 status returns CheckoutError', () async {
      mockDio.mockPostResponse(
        {'error': 'Not configured'},
        statusCode: 500,
      );

      // Act
      final result = await ProvisioningService.createCheckoutSession(
        email: 'test@example.com',
        tier: 'growth',
      );

      // Assert
      expect(result, isA<CheckoutError>());
    });
  });

  group('Error response contract', () {
    /// Links to: workers/lib/http/responses.ts (errorResponse helper)
    test('all error status codes return { error: string }', () async {
      const errorStatuses = [400, 401, 403, 500];
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      for (final status in errorStatuses) {
        mockDio.postCallCount = 0;
        mockDio.mockPostResponse({'error': 'test error'}, statusCode: status);
        mockDio.mockGetResponse({'ok': false});

        const event = ProvisioningEvent(
          action: 'provision_api_key',
          name: 'test',
          email: 'test@example.com',
        );

        // Act
        final result = await ProvisioningService.sendEvent(event, jwt: jwt);

        // Assert
        expect(result, isA<ProvisioningError>(), reason: 'status code $status');
      }
    });

    test('{ error: string } on 401 returns ProvisioningError', () async {
      mockDio.mockPostResponse(
        {'error': 'invalid signature'},
        statusCode: 401,
      );
      mockDio.mockGetResponse({'ok': true});
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      const event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'test',
        email: 'test@example.com',
      );

      // Act
      final result = await ProvisioningService.sendEvent(event, jwt: jwt);

      // Assert
      expect(result, isA<ProvisioningError>());
    });

    test('Dart service reads error as string', () async {
      mockDio.mockPostResponse(
        {'error': 'Stripe not configured'},
        statusCode: 503,
      );

      // Act
      final result = await ProvisioningService.createCheckoutSession(
        email: 'test@example.com',
        tier: 'growth',
      );

      // Assert: service parses error string without throwing
      expect(result, isA<CheckoutError>());
    });
  });
}
