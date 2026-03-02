import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/contact_service.dart';
import 'package:integrity_studio_ai/services/http_status.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'contact_service_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  group('ContactFormData', () {
    test('creates instance with required fields', () {
      const formData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'Hello, this is a test message.',
      );

      expect(formData.name, equals('John Doe'));
      expect(formData.email, equals('john@example.com'));
      expect(formData.message, equals('Hello, this is a test message.'));
      expect(formData.organization, isNull);
    });

    test('creates instance with optional organization', () {
      const formData = ContactFormData(
        name: 'Jane Doe',
        email: 'jane@company.com',
        organization: 'ACME Corp',
        message: 'Test message with organization.',
      );

      expect(formData.organization, equals('ACME Corp'));
    });

    group('toJson', () {
      test('converts to JSON with required fields', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test message',
        );

        final json = formData.toJson();

        expect(json['name'], equals('John Doe'));
        expect(json['email'], equals('john@example.com'));
        expect(json['message'], equals('Test message'));
        expect(json.containsKey('organization'), isFalse);
      });

      test('includes organization when present', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          organization: 'Test Company',
          message: 'Test message',
        );

        final json = formData.toJson();

        expect(json['organization'], equals('Test Company'));
      });

      test('includes companySize when present', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          companySize: '50-200',
          message: 'Test message',
        );

        final json = formData.toJson();

        expect(json['companySize'], equals('50-200'));
      });

      test('excludes companySize when null', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test message',
        );

        final json = formData.toJson();

        expect(json.containsKey('companySize'), isFalse);
      });

      test('includes useCase when present', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          useCase: 'AI Observability',
          message: 'Test message',
        );

        final json = formData.toJson();

        expect(json['useCase'], equals('AI Observability'));
      });

      test('excludes useCase when null', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test message',
        );

        final json = formData.toJson();

        expect(json.containsKey('useCase'), isFalse);
      });

      test('excludes message when null', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
        );

        final json = formData.toJson();

        expect(json.containsKey('message'), isFalse);
      });
    });
  });

  group('ContactFormPayload', () {
    test('creates with default timestamp', () {
      final payload = ContactFormPayload(
        formData: const ContactFormData(
          name: 'Test',
          email: 'test@test.com',
          message: 'Message',
        ),
      );

      expect(payload.timestamp, isNotNull);
      expect(payload.timestamp, greaterThan(0));
    });

    test('creates with custom timestamp', () {
      final payload = ContactFormPayload(
        formData: const ContactFormData(
          name: 'Test',
          email: 'test@test.com',
          message: 'Message',
        ),
        timestamp: 1234567890,
      );

      expect(payload.timestamp, equals(1234567890));
    });

    test('includes CSRF token', () {
      final payload = ContactFormPayload(
        formData: const ContactFormData(
          name: 'Test',
          email: 'test@test.com',
          message: 'Message',
        ),
        csrfToken: 'abc123token',
      );

      expect(payload.csrfToken, equals('abc123token'));
    });

    test('includes user agent', () {
      final payload = ContactFormPayload(
        formData: const ContactFormData(
          name: 'Test',
          email: 'test@test.com',
          message: 'Message',
        ),
        userAgent: 'Mozilla/5.0 Test Browser',
      );

      expect(payload.userAgent, equals('Mozilla/5.0 Test Browser'));
    });
  });

  group('ContactFormErrors', () {
    test('hasErrors returns false when no errors', () {
      final errors = ContactFormErrors();

      expect(errors.hasErrors, isFalse);
    });

    test('hasErrors returns true when name error exists', () {
      final errors = ContactFormErrors(name: 'Name is required');

      expect(errors.hasErrors, isTrue);
    });

    test('hasErrors returns true when email error exists', () {
      final errors = ContactFormErrors(email: 'Invalid email');

      expect(errors.hasErrors, isTrue);
    });

    test('hasErrors returns true when message error exists', () {
      final errors = ContactFormErrors(message: 'Message too short');

      expect(errors.hasErrors, isTrue);
    });

    test('hasErrors returns true when organization error exists', () {
      final errors = ContactFormErrors(organization: 'Invalid org');

      expect(errors.hasErrors, isTrue);
    });

    test('hasErrors returns true when companySize error exists', () {
      final errors = ContactFormErrors(companySize: 'Too long');

      expect(errors.hasErrors, isTrue);
    });

    test('hasErrors returns true when useCase error exists', () {
      final errors = ContactFormErrors(useCase: 'Too long');

      expect(errors.hasErrors, isTrue);
    });

    group('toMap', () {
      test('returns empty map when no errors', () {
        final errors = ContactFormErrors();

        expect(errors.toMap(), isEmpty);
      });

      test('returns map with all errors', () {
        final errors = ContactFormErrors(
          name: 'Name error',
          email: 'Email error',
          organization: 'Org error',
          message: 'Message error',
          companySize: 'Size error',
          useCase: 'Use case error',
        );

        final map = errors.toMap();

        expect(map['name'], equals('Name error'));
        expect(map['email'], equals('Email error'));
        expect(map['organization'], equals('Org error'));
        expect(map['message'], equals('Message error'));
        expect(map['companySize'], equals('Size error'));
        expect(map['useCase'], equals('Use case error'));
      });

      test('returns map with only present errors', () {
        final errors = ContactFormErrors(
          email: 'Email error',
          message: 'Message error',
        );

        final map = errors.toMap();

        expect(map.length, equals(2));
        expect(map.containsKey('name'), isFalse);
        expect(map.containsKey('organization'), isFalse);
      });
    });
  });

  group('ContactService', () {
    group('isValidEmail', () {
      test('returns true for valid emails', () {
        expect(ContactService.isValidEmail('test@example.com'), isTrue);
        expect(ContactService.isValidEmail('user.name@domain.org'), isTrue);
        expect(ContactService.isValidEmail('user+tag@example.co.uk'), isTrue);
        expect(ContactService.isValidEmail('a@b.co'), isTrue);
      });

      test('returns false for invalid emails', () {
        expect(ContactService.isValidEmail(''), isFalse);
        expect(ContactService.isValidEmail('invalid'), isFalse);
        expect(ContactService.isValidEmail('missing@domain'), isFalse);
        expect(ContactService.isValidEmail('@nodomain.com'), isFalse);
        expect(ContactService.isValidEmail('spaces in@email.com'), isFalse);
        expect(ContactService.isValidEmail('double@@at.com'), isFalse);
        // Previously accepted, now correctly rejected (#24)
        expect(ContactService.isValidEmail('admin@-example.com'), isFalse);
        expect(ContactService.isValidEmail('test@example..com'), isFalse);
        expect(ContactService.isValidEmail('.leading@example.com'), isFalse);
        expect(ContactService.isValidEmail('trailing.@example.com'), isFalse);
      });
    });

    group('validateForm', () {
      test('returns no errors for valid form data', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message with enough characters.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.hasErrors, isFalse);
      });

      test('returns error for empty name', () {
        const formData = ContactFormData(
          name: '',
          email: 'john@example.com',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.name, isNotNull);
        expect(errors.name, contains('name'));
      });

      test('returns error for whitespace-only name', () {
        const formData = ContactFormData(
          name: '   ',
          email: 'john@example.com',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.name, isNotNull);
      });

      test('returns error for empty email', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: '',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.email, isNotNull);
        expect(errors.email, contains('email'));
      });

      test('returns error for invalid email format', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'invalid-email',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.email, isNotNull);
        expect(errors.email, contains('valid'));
      });

      test('accepts empty message (optional field)', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: '',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.message, isNull);
      });

      test('accepts short message (no minimum length)', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Short',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.message, isNull);
      });

      test('does not validate optional organization', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          organization: null,
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.organization, isNull);
        expect(errors.hasErrors, isFalse);
      });

      test('returns error for companySize exceeding max length', () {
        final formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          companySize: 'A' * 101,
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.companySize, isNotNull);
        expect(errors.companySize, contains('100'));
      });

      test('accepts companySize within max length', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          companySize: '50-200 employees',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.companySize, isNull);
      });

      test('returns error for useCase exceeding max length', () {
        final formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          useCase: 'A' * 201,
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.useCase, isNotNull);
        expect(errors.useCase, contains('200'));
      });

      test('accepts useCase within max length', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          useCase: 'AI Observability for ML pipelines',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.useCase, isNull);
      });

      // ================================================================
      // U5: Name exceeding maxNameLength (100)
      // ================================================================

      test('returns error for name exceeding max length', () {
        final formData = ContactFormData(
          name: 'A' * 101,
          email: 'john@example.com',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.name, isNotNull);
        expect(errors.name, contains('100'));
      });

      test('accepts name at max length', () {
        final formData = ContactFormData(
          name: 'A' * 100,
          email: 'john@example.com',
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.name, isNull);
      });

      // ================================================================
      // U6: Email exceeding maxEmailLength (254)
      // ================================================================

      test('returns error for email exceeding max length', () {
        // 264 chars: exceeds 254 limit, hits length check in validateForm
        final formData = ContactFormData(
          name: 'John Doe',
          email: '${'a' * 246}@test.com', // 255 chars > 254 limit
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.email, isNotNull);
        expect(errors.email, contains('254'));
      });

      // ================================================================
      // U7: Organization exceeding maxOrganizationLength (200)
      // ================================================================

      test('returns error for organization exceeding max length', () {
        final formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          organization: 'A' * 201,
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.organization, isNotNull);
        expect(errors.organization, contains('200'));
      });

      test('accepts organization at max length', () {
        final formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          organization: 'A' * 200,
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.organization, isNull);
      });

      // ================================================================
      // U8: Message exceeding maxMessageLength (5000)
      // ================================================================

      test('returns error for message exceeding max length', () {
        final formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'A' * 5001,
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.message, isNotNull);
        expect(errors.message, contains('5000'));
      });

      test('accepts message at max length', () {
        final formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'A' * 5000,
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.message, isNull);
      });

      test('returns multiple errors at once', () {
        const formData = ContactFormData(
          name: '',
          email: 'invalid',
        );

        final errors = ContactService.validateForm(formData);

        expect(errors.name, isNotNull);
        expect(errors.email, isNotNull);
      });
    });

    group('isFormValid', () {
      test('returns true for valid form', () {
        const formData = ContactFormData(
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message.',
        );

        expect(ContactService.isFormValid(formData), isTrue);
      });

      test('returns false for invalid form', () {
        const formData = ContactFormData(
          name: '',
          email: 'invalid',
          message: '',
        );

        expect(ContactService.isFormValid(formData), isFalse);
      });
    });

    group('submitForm', () {
      late MockDio mockDio;

      setUp(() {
        mockDio = MockDio();
        ContactService.setDioForTesting(mockDio);
        ContactService.retryDelay = (_) async {};
      });

      tearDown(() {
        ContactService.resetDio();
        ContactService.resetRetryDelay();
      });

      test('returns error for invalid form data', () async {
        // No mock setup needed - validation happens before HTTP call
        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: '',
            email: 'invalid',
            message: '',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.fieldErrors, isNotNull);
        expect(error.fieldErrors!.containsKey('name'), isTrue);
        expect(error.fieldErrors!.containsKey('email'), isTrue);
      });

      test('returns success for valid form data', () async {
        // Mock successful API response
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {
                'success': true,
                'message': 'Thank you for your message!',
                'submissionId': 'sub_test_123',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
        final success = response as ContactFormSuccess;
        expect(success.message, equals('Thank you for your message!'));
        expect(success.submissionId, equals('sub_test_123'));
      });

      test('success response includes submission ID', () async {
        // Mock successful API response
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {
                'success': true,
                'message': 'Your message has been received.',
                'submissionId': 'sub_mock_456',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isNotNull);
        expect(response, isA<ContactFormSuccess>());

        final success = response as ContactFormSuccess;
        expect(success.submissionId, isNotNull);
        expect(success.submissionId, startsWith('sub_'));
        expect(success.message, isNotNull);
      });

      test('returns error when API returns error response', () async {
        // Mock error API response
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 400,
              data: {
                'success': false,
                'error': 'Invalid request',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, equals('Invalid request'));
      });

      test('returns error on network failure after retries', () async {
        // Mock network error - all attempts fail
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenThrow(DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: ''),
        ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, contains('timed out'));
        // Verify retries happened (3 total attempts: 1 initial + 2 retries)
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(3);
      });

      test('succeeds on retry after transient failure', () async {
        var callCount = 0;
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw DioException(
              type: DioExceptionType.connectionTimeout,
              requestOptions: RequestOptions(path: ''),
            );
          }
          return Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: HttpStatus.ok.code,
            data: {
              'success': true,
              'message': 'Sent!',
              'submissionId': 'sub_retry_ok',
            },
          );
        });

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
        final success = response as ContactFormSuccess;
        expect(success.submissionId, equals('sub_retry_ok'));
        expect(callCount, equals(2));
      });

      test('succeeds when CSRF fetch fails (token optional)', () async {
        // CSRF fetch throws - submission should still proceed
        when(mockDio.get(any)).thenThrow(DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: ''),
        ));
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {
                'success': true,
                'message': 'Sent!',
                'submissionId': 'sub_csrf_fail_ok',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
      });

      test('succeeds when CSRF returns null token', () async {
        // CSRF fetch returns null token
        when(mockDio.get(any)).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {'csrfToken': null},
            ));
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {
                'success': true,
                'message': 'Sent!',
                'submissionId': 'sub_null_csrf',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
      });

      test('handles 429 with Retry-After header', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.tooManyRequests.code,
              headers: Headers.fromMap({
                'retry-after': ['30'],
              }),
              data: {
                'error': 'Too many requests.',
                'retryAfter': 30,
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.retryAfterSeconds, equals(30));
        expect(error.error, contains('30 seconds'));
      });

      // ================================================================
      // U1: 504 gateway timeout retry + exhaustion
      // ================================================================

      test('retries on 504 gateway timeout then succeeds', () async {
        var callCount = 0;
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.gatewayTimeout.code,
              data: {'error': 'Gateway Timeout'},
            );
          }
          return Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: HttpStatus.ok.code,
            data: {
              'success': true,
              'message': 'Sent!',
              'submissionId': 'sub_504_retry',
            },
          );
        });

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
        expect(callCount, equals(2));
      });

      test('returns error after exhausting 504 retries', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.gatewayTimeout.code,
              data: {'error': 'Gateway Timeout'},
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, contains('timeout'));
        // 3 total attempts: 1 initial + 2 retries
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(3);
      });

      // ================================================================
      // U2: Non-Dio exception in submitForm
      // ================================================================

      test('handles non-Dio exception in submitForm', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenThrow(const FormatException('Unexpected response format'));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, contains('unexpected'));
        // Non-Dio exceptions are not retried
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(1);
      });

      // ================================================================
      // U3: 429 without Retry-After header (seconds == null)
      // ================================================================

      test('handles 429 without Retry-After header', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.tooManyRequests.code,
              headers: Headers(),
              data: {
                'error': 'Too many requests.',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.retryAfterSeconds, isNull);
        expect(error.error, contains('try again later'));
      });

      // ================================================================
      // U4: receiveTimeout retry path
      // ================================================================

      test('retries on receiveTimeout and returns error after exhaustion',
          () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenThrow(DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: ''),
        ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, contains('timed out'));
        // Should retry: 3 total attempts
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(3);
      });

      test('retries on connectionError and returns error after exhaustion',
          () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenThrow(DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: ''),
        ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, contains('Network error'));
        // Should retry: 3 total attempts
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(3);
      });

      // ================================================================
      // U9: 200 response with success: false
      // ================================================================

      test('returns error for 200 response with success: false', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {
                'success': false,
                'error': 'Invalid company domain',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, equals('Invalid company domain'));
      });

      // ================================================================
      // U10: Success response with null message/submissionId
      // ================================================================

      test('uses fallback defaults when success response has null fields',
          () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {
                'success': true,
                // message and submissionId are null
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
        final success = response as ContactFormSuccess;
        expect(success.message, contains('Thank you'));
        expect(success.submissionId, startsWith('sub_'));
      });

      // ================================================================
      // CSRF fetch-once and 403 handling
      // ================================================================

      test('fetches CSRF token once on successful submission', () async {
        when(mockDio.get(any)).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {'csrfToken': 'token_abc'},
            ));
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {
                'success': true,
                'message': 'Sent!',
                'submissionId': 'sub_once',
              },
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
        // CSRF GET called exactly once (not per attempt)
        verify(mockDio.get(any)).called(1);
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(1);
      });

      test('does not re-fetch CSRF on non-403 retries', () async {
        // CSRF fetch succeeds once
        when(mockDio.get(any)).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {'csrfToken': 'token_stable'},
            ));
        // First attempt: 504, second attempt: success
        var postCount = 0;
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async {
          postCount++;
          if (postCount == 1) {
            return Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.gatewayTimeout.code,
              data: {'error': 'Gateway Timeout'},
            );
          }
          return Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: HttpStatus.ok.code,
            data: {
              'success': true,
              'message': 'Sent!',
              'submissionId': 'sub_no_refetch',
            },
          );
        });

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
        // CSRF GET called only once (not re-fetched on 504 retry)
        verify(mockDio.get(any)).called(1);
        expect(postCount, equals(2));
      });

      test('re-fetches CSRF on 403 and retries successfully', () async {
        var getCount = 0;
        when(mockDio.get(any)).thenAnswer((_) async {
          getCount++;
          return Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: HttpStatus.ok.code,
            data: {
              'csrfToken': getCount == 1 ? 'stale_token' : 'fresh_token',
            },
          );
        });

        var postCount = 0;
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async {
          postCount++;
          if (postCount == 1) {
            return Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.forbidden.code,
              data: {'error': 'Invalid CSRF token'},
            );
          }
          return Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: HttpStatus.ok.code,
            data: {
              'success': true,
              'message': 'Sent!',
              'submissionId': 'sub_csrf_refresh',
            },
          );
        });

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormSuccess>());
        // Initial fetch + re-fetch on 403
        expect(getCount, equals(2));
        expect(postCount, equals(2));
      });

      test('returns error after persistent 403 on all retries', () async {
        when(mockDio.get(any)).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.ok.code,
              data: {'csrfToken': 'always_stale'},
            ));
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: HttpStatus.forbidden.code,
              data: {'error': 'Invalid CSRF token'},
            ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        final error = response as ContactFormError;
        expect(error.error, contains('Security token expired'));
        // 3 POST attempts (initial + 2 retries)
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(3);
      });

      // ================================================================
      // validateStatus rejects unhandled 5xx
      // ================================================================

      test('rejects 500 via validateStatus as DioException', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
            data: {'error': 'Internal Server Error'},
          ),
        ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        // 500 is not retryable — single attempt
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(1);
      });

      test('rejects 502 via validateStatus as DioException', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 502,
            data: {'error': 'Bad Gateway'},
          ),
        ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        // 502 is not retryable — single attempt
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(1);
      });

      test('does not retry on non-retryable errors', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
          ),
        ));

        final payload = ContactFormPayload(
          formData: const ContactFormData(
            name: 'John Doe',
            email: 'john@example.com',
            message: 'This is a valid message for testing.',
          ),
        );

        final response = await ContactService.submitForm(payload);

        expect(response, isA<ContactFormError>());
        // Should only be called once (no retries for non-retryable errors)
        verify(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).called(1);
      });
    });
  });

  group('ContactFormResponse sealed class', () {
    test('ContactFormSuccess is a ContactFormResponse', () {
      const response = ContactFormSuccess(
        message: 'Success',
        submissionId: 'sub_123',
      );

      expect(response, isA<ContactFormResponse>());
    });

    test('ContactFormError is a ContactFormResponse', () {
      const response = ContactFormError(error: 'Error');

      expect(response, isA<ContactFormResponse>());
    });

    test('can pattern match on response types', () {
      const ContactFormResponse success = ContactFormSuccess(
        message: 'Success',
        submissionId: 'sub_123',
      );

      const ContactFormResponse error = ContactFormError(error: 'Error');

      String successResult = switch (success) {
        ContactFormSuccess(:final message) => 'Got success: $message',
        ContactFormError(:final error) => 'Got error: $error',
      };

      String errorResult = switch (error) {
        ContactFormSuccess(:final message) => 'Got success: $message',
        ContactFormError(:final error) => 'Got error: $error',
      };

      expect(successResult, equals('Got success: Success'));
      expect(errorResult, equals('Got error: Error'));
    });
  });
}
