import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/contact_service.dart';

/// Unit tests for ContactService.
///
/// Tests validation, form submission, and email routing behavior.
/// Uses mock Dio to simulate API responses.
void main() {
  late _MockDio mockDio;

  setUp(() {
    mockDio = _MockDio();
    ContactService.setDioForTesting(mockDio);
    ContactService.clearCsrfCache();
  });

  tearDown(() {
    ContactService.resetDio();
    ContactService.clearCsrfCache();
  });

  group('ContactFormData', () {
    test('toJson includes all required fields', () {
      const data = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'Test message content.',
      );

      final json = data.toJson();

      expect(json['name'], 'John Doe');
      expect(json['email'], 'john@example.com');
      expect(json['message'], 'Test message content.');
      expect(json.containsKey('organization'), false);
    });

    test('toJson includes optional organization', () {
      const data = ContactFormData(
        name: 'Jane Doe',
        email: 'jane@example.com',
        organization: 'ACME Corp',
        message: 'Enterprise inquiry.',
      );

      final json = data.toJson();

      expect(json['organization'], 'ACME Corp');
    });
  });

  group('Form Validation', () {
    test('validates empty name', () {
      const data = ContactFormData(
        name: '',
        email: 'test@example.com',
        message: 'Valid message here.',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.name, isNotNull);
      expect(errors.name, contains('name'));
    });

    test('validates whitespace-only name', () {
      const data = ContactFormData(
        name: '   ',
        email: 'test@example.com',
        message: 'Valid message here.',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.name, isNotNull);
    });

    test('validates name length limit', () {
      final data = ContactFormData(
        name: 'A' * 101, // Over 100 char limit
        email: 'test@example.com',
        message: 'Valid message here.',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.name, isNotNull);
      expect(errors.name, contains('100'));
    });

    test('validates empty email', () {
      const data = ContactFormData(
        name: 'John Doe',
        email: '',
        message: 'Valid message here.',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.email, isNotNull);
    });

    test('validates invalid email format', () {
      const invalidEmails = [
        'invalid',
        'invalid@',
        '@invalid.com',
        'invalid@.com',
        'invalid@domain',
      ];

      for (final email in invalidEmails) {
        final data = ContactFormData(
          name: 'John Doe',
          email: email,
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(data);

        expect(errors.email, isNotNull,
            reason: 'Should reject invalid email: $email');
      }
    });

    test('accepts valid email formats', () {
      const validEmails = [
        'test@example.com',
        'user.name@domain.co.uk',
        'user+tag@example.org',
        'a@b.io',
      ];

      for (final email in validEmails) {
        final data = ContactFormData(
          name: 'John Doe',
          email: email,
          message: 'Valid message here.',
        );

        final errors = ContactService.validateForm(data);

        expect(errors.email, isNull,
            reason: 'Should accept valid email: $email');
      }
    });

    test('validates empty message', () {
      const data = ContactFormData(
        name: 'John Doe',
        email: 'test@example.com',
        message: '',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.message, isNotNull);
    });

    test('validates message minimum length', () {
      const data = ContactFormData(
        name: 'John Doe',
        email: 'test@example.com',
        message: 'Short',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.message, isNotNull);
      expect(errors.message, contains('10'));
    });

    test('validates message maximum length', () {
      final data = ContactFormData(
        name: 'John Doe',
        email: 'test@example.com',
        message: 'A' * 5001, // Over 5000 char limit
      );

      final errors = ContactService.validateForm(data);

      expect(errors.message, isNotNull);
      expect(errors.message, contains('5000'));
    });

    test('validates organization length limit', () {
      final data = ContactFormData(
        name: 'John Doe',
        email: 'test@example.com',
        organization: 'A' * 201, // Over 200 char limit
        message: 'Valid message here.',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.organization, isNotNull);
      expect(errors.organization, contains('200'));
    });

    test('accepts valid form data', () {
      const data = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        organization: 'ACME Corp',
        message: 'This is a valid test message with enough content.',
      );

      final errors = ContactService.validateForm(data);

      expect(errors.hasErrors, false);
    });

    test('isFormValid returns correct boolean', () {
      const validData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'Valid message content here.',
      );

      const invalidData = ContactFormData(
        name: '',
        email: 'invalid',
        message: '',
      );

      expect(ContactService.isFormValid(validData), true);
      expect(ContactService.isFormValid(invalidData), false);
    });
  });

  group('Email Validation', () {
    test('isValidEmail returns true for valid emails', () {
      expect(ContactService.isValidEmail('test@example.com'), true);
      expect(ContactService.isValidEmail('user.name@domain.co.uk'), true);
      expect(ContactService.isValidEmail('hello@integritystudio.ai'), true);
      expect(ContactService.isValidEmail('sales@integritystudio.ai'), true);
      expect(ContactService.isValidEmail('security@integritystudio.ai'), true);
      expect(ContactService.isValidEmail('help@integritystudio.ai'), true);
    });

    test('isValidEmail returns false for invalid emails', () {
      expect(ContactService.isValidEmail('invalid'), false);
      expect(ContactService.isValidEmail('invalid@'), false);
      expect(ContactService.isValidEmail('@domain.com'), false);
      expect(ContactService.isValidEmail('spaces in@email.com'), false);
    });
  });

  group('Form Submission', () {
    test('returns validation error for invalid form', () async {
      const invalidData = ContactFormData(
        name: '',
        email: 'invalid',
        message: 'short',
      );

      final payload = ContactFormPayload(formData: invalidData);
      final response = await ContactService.submitForm(payload);

      expect(response, isA<ContactFormError>());
      final error = response as ContactFormError;
      expect(error.error, contains('errors'));
      expect(error.fieldErrors, isNotNull);
    });

    test('submits valid form and returns success', () async {
      // Mock CSRF token response
      mockDio.mockGetResponse({'csrfToken': 'test_token_123'});

      // Mock POST response
      mockDio.mockPostResponse({
        'success': true,
        'message': "Thank you! We'll respond within 24 hours.",
        'submissionId': 'sub_abc123',
      });

      const validData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid test message.',
      );

      final payload = ContactFormPayload(formData: validData);
      final response = await ContactService.submitForm(payload);

      expect(response, isA<ContactFormSuccess>());
      final success = response as ContactFormSuccess;
      expect(success.message, contains('Thank you'));
      expect(success.submissionId, 'sub_abc123');
    });

    test('handles server error response', () async {
      mockDio.mockGetResponse({'csrfToken': 'test_token'});
      mockDio.mockPostResponse(
        {'success': false, 'error': 'Server error occurred'},
        statusCode: 200,
      );

      const validData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid test message.',
      );

      final payload = ContactFormPayload(formData: validData);
      final response = await ContactService.submitForm(payload);

      expect(response, isA<ContactFormError>());
    });

    test('handles network timeout', () async {
      mockDio.mockGetResponse({'csrfToken': 'test_token'});
      mockDio.mockPostError(DioExceptionType.connectionTimeout);

      const validData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid test message.',
      );

      final payload = ContactFormPayload(formData: validData);
      final response = await ContactService.submitForm(payload);

      expect(response, isA<ContactFormError>());
      final error = response as ContactFormError;
      expect(error.error.toLowerCase(), contains('timed out'));
    });

    test('handles receive timeout', () async {
      mockDio.mockGetResponse({'csrfToken': 'test_token'});
      mockDio.mockPostError(DioExceptionType.receiveTimeout);

      const validData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid test message.',
      );

      final payload = ContactFormPayload(formData: validData);
      final response = await ContactService.submitForm(payload);

      expect(response, isA<ContactFormError>());
      final error = response as ContactFormError;
      expect(error.error.toLowerCase(), contains('timed out'));
    });

    test('handles generic network error', () async {
      mockDio.mockGetResponse({'csrfToken': 'test_token'});
      mockDio.mockPostError(DioExceptionType.unknown);

      const validData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid test message.',
      );

      final payload = ContactFormPayload(formData: validData);
      final response = await ContactService.submitForm(payload);

      expect(response, isA<ContactFormError>());
      final error = response as ContactFormError;
      expect(error.error.toLowerCase(), contains('network'));
    });

    test('clears CSRF cache after successful submission', () async {
      mockDio.mockGetResponse({'csrfToken': 'original_token'});
      mockDio.mockPostResponse({
        'success': true,
        'message': 'Success',
        'submissionId': 'sub_123',
      });

      const validData = ContactFormData(
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid test message.',
      );

      // First submission
      final payload1 = ContactFormPayload(formData: validData);
      await ContactService.submitForm(payload1);

      // Reset mock to return a new token
      mockDio.mockGetResponse({'csrfToken': 'new_token'});
      mockDio.mockPostResponse({
        'success': true,
        'message': 'Success',
        'submissionId': 'sub_456',
      });

      // Second submission should fetch new token
      final payload2 = ContactFormPayload(formData: validData);
      await ContactService.submitForm(payload2);

      // Verify GET was called twice (once for each submission)
      expect(mockDio.getCallCount, 2);
    });
  });

  group('ContactFormErrors', () {
    test('hasErrors returns true when any error exists', () {
      final errors1 = ContactFormErrors(name: 'Name error');
      final errors2 = ContactFormErrors(email: 'Email error');
      final errors3 = ContactFormErrors(message: 'Message error');
      final errors4 = ContactFormErrors(organization: 'Org error');

      expect(errors1.hasErrors, true);
      expect(errors2.hasErrors, true);
      expect(errors3.hasErrors, true);
      expect(errors4.hasErrors, true);
    });

    test('hasErrors returns false when no errors', () {
      final errors = ContactFormErrors();

      expect(errors.hasErrors, false);
    });

    test('toMap only includes non-null errors', () {
      final errors = ContactFormErrors(
        name: 'Name is required',
        email: 'Invalid email',
      );

      final map = errors.toMap();

      expect(map.length, 2);
      expect(map['name'], 'Name is required');
      expect(map['email'], 'Invalid email');
      expect(map.containsKey('message'), false);
      expect(map.containsKey('organization'), false);
    });
  });

  group('ContactFormPayload', () {
    test('uses provided timestamp', () {
      const data = ContactFormData(
        name: 'Test',
        email: 'test@example.com',
        message: 'Test message.',
      );

      final payload = ContactFormPayload(
        formData: data,
        timestamp: 1234567890,
      );

      expect(payload.timestamp, 1234567890);
    });

    test('generates timestamp when not provided', () {
      const data = ContactFormData(
        name: 'Test',
        email: 'test@example.com',
        message: 'Test message.',
      );

      final before = DateTime.now().millisecondsSinceEpoch;
      final payload = ContactFormPayload(formData: data);
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(payload.timestamp, greaterThanOrEqualTo(before));
      expect(payload.timestamp, lessThanOrEqualTo(after));
    });
  });
}

/// Mock Dio for testing ContactService.
class _MockDio implements Dio {
  Map<String, dynamic>? _mockGetResponseData;
  Map<String, dynamic>? _mockPostResponseData;
  int _mockPostStatusCode = 200;
  DioExceptionType? _mockPostError;
  int getCallCount = 0;

  void mockGetResponse(Map<String, dynamic> data) {
    _mockGetResponseData = data;
  }

  void mockPostResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    _mockPostResponseData = data;
    _mockPostStatusCode = statusCode;
    _mockPostError = null;
  }

  void mockPostError(DioExceptionType type) {
    _mockPostError = type;
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    getCallCount++;
    return Response<T>(
      data: _mockGetResponseData as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (_mockPostError != null) {
      throw DioException(
        type: _mockPostError!,
        requestOptions: RequestOptions(path: path),
      );
    }

    return Response<T>(
      data: _mockPostResponseData as T,
      statusCode: _mockPostStatusCode,
      requestOptions: RequestOptions(path: path),
    );
  }

  // Required interface implementations (not used in tests)
  @override
  BaseOptions get options => BaseOptions();

  @override
  set options(BaseOptions options) {}

  @override
  Interceptors get interceptors => Interceptors();

  @override
  HttpClientAdapter get httpClientAdapter => throw UnimplementedError();

  @override
  set httpClientAdapter(HttpClientAdapter adapter) {}

  @override
  Transformer get transformer => throw UnimplementedError();

  @override
  set transformer(Transformer transformer) {}

  @override
  void close({bool force = false}) {}

  @override
  Future<Response<T>> delete<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Dio clone({
    BaseOptions? options,
    Interceptors? interceptors,
    HttpClientAdapter? httpClientAdapter,
    Transformer? transformer,
  }) =>
      this;

  @override
  Future<Response> download(String urlPath, dynamic savePath,
          {ProgressCallback? onReceiveProgress,
          Map<String, dynamic>? queryParameters,
          CancelToken? cancelToken,
          bool deleteOnError = true,
          String lengthHeader = Headers.contentLengthHeader,
          Object? data,
          Options? options,
          FileAccessMode fileAccessMode = FileAccessMode.write}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> getUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> head<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> headUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> patch<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> patchUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> postUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> put<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> putUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> request<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          CancelToken? cancelToken,
          Options? options,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> requestUri<T>(Uri uri,
          {Object? data,
          CancelToken? cancelToken,
          Options? options,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> deleteUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response> downloadUri(Uri uri, dynamic savePath,
          {ProgressCallback? onReceiveProgress,
          CancelToken? cancelToken,
          bool deleteOnError = true,
          String lengthHeader = Headers.contentLengthHeader,
          Object? data,
          Options? options,
          FileAccessMode fileAccessMode = FileAccessMode.write}) =>
      throw UnimplementedError();
}
