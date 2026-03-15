import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'analytics.dart';
import 'http_status.dart';

/// Contact form API endpoint (Cloudflare Worker).
/// Configurable via --dart-define=CONTACT_API_URL for staging/development.
const _contactApiUrl = String.fromEnvironment(
  'CONTACT_API_URL',
  defaultValue: 'https://integrity-studio-contact.alyshia-b38.workers.dev',
);

/// Contact form data model.
class ContactFormData {
  final String name;
  final String email;
  final String? organization;
  final String? message;
  final String? companySize;
  final String? useCase;
  final String? ref;

  const ContactFormData({
    required this.name,
    required this.email,
    this.organization,
    this.message,
    this.companySize,
    this.useCase,
    this.ref,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        if (organization != null) 'organization': organization,
        if (message != null) 'message': message,
        if (companySize != null) 'companySize': companySize,
        if (useCase != null) 'useCase': useCase,
        if (ref != null) 'ref': ref,
      };
}

/// Contact form submission payload with security tokens.
class ContactFormPayload {
  final ContactFormData formData;
  final String? csrfToken;
  final int timestamp;
  final String? userAgent;

  ContactFormPayload({
    required this.formData,
    this.csrfToken,
    int? timestamp,
    this.userAgent,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}

/// Contact form response.
sealed class ContactFormResponse {
  const ContactFormResponse();
}

/// Successful submission response.
class ContactFormSuccess extends ContactFormResponse {
  final String message;
  final String submissionId;

  const ContactFormSuccess({
    required this.message,
    required this.submissionId,
  });
}

/// Error response.
class ContactFormError extends ContactFormResponse {
  final String error;
  final Map<String, String>? fieldErrors;
  final int? retryAfterSeconds;

  const ContactFormError({
    required this.error,
    this.fieldErrors,
    this.retryAfterSeconds,
  });
}

/// Contact form validation errors.
class ContactFormErrors {
  String? name;
  String? email;
  String? organization;
  String? message;
  String? companySize;
  String? useCase;

  ContactFormErrors({
    this.name,
    this.email,
    this.organization,
    this.message,
    this.companySize,
    this.useCase,
  });

  bool get hasErrors =>
      name != null ||
      email != null ||
      organization != null ||
      message != null ||
      companySize != null ||
      useCase != null;

  Map<String, String> toMap() {
    final map = <String, String>{};
    if (name != null) map['name'] = name!;
    if (email != null) map['email'] = email!;
    if (organization != null) map['organization'] = organization!;
    if (message != null) map['message'] = message!;
    if (companySize != null) map['companySize'] = companySize!;
    if (useCase != null) map['useCase'] = useCase!;
    return map;
  }
}

/// Contact form service for submission and validation.
class ContactService {
  ContactService._();

  // Error message constants (per project rule: no magic strings)
  static const String _errorSecurityToken =
      'Security token expired. Please try again.';
  static const String _errorServerError = 'Server error. Please try again.';
  static const String _errorTimeout =
      'Connection timed out. Please check your internet and try again.';
  static const String _errorNetwork =
      'Network error: Unable to submit form. Please try again.';
  static const String _errorUnexpected =
      'An unexpected error occurred. Please try again.';
  static const String _errorUnableToSubmit =
      'Unable to submit form. Please try again.';
  static const String _errorTooManyRequests =
      'Too many requests. Please try again later.';
  static const String _errorFormValidation =
      'Please fix the errors in the form';

  static const int _maxServerErrorLength = 200;

  /// Sanitise server-supplied error strings before displaying in UI.
  /// Guards against reflected content and malformed responses.
  static String _sanitiseServerError(String? raw, String fallback) {
    if (raw == null ||
        raw.trim().isEmpty ||
        raw.length > _maxServerErrorLength) {
      return fallback;
    }
    return raw;
  }

  static Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Set a custom Dio instance for testing.
  @visibleForTesting
  static void setDioForTesting(Dio dio) {
    _dio = dio;
  }

  /// Reset Dio to default instance.
  @visibleForTesting
  static void resetDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  /// Retry delay function, injectable for testing.
  @visibleForTesting
  static Future<void> Function(Duration) retryDelay = Future.delayed;

  /// Reset retry delay to default.
  @visibleForTesting
  static void resetRetryDelay() {
    retryDelay = Future.delayed;
  }

  /// Validate email format (RFC 5321 subset).
  /// Local part: 1-64 chars, no leading/trailing/consecutive dots.
  /// Domain: valid labels with 2+ char TLD.
  static bool isValidEmail(String email) {
    if (email.length > 254) return false;
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty || local.length > 64) return false;
    if (RegExp(r'^\.|\.{2,}|\.$').hasMatch(local)) return false;
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+$').hasMatch(local)) return false;
    if (!RegExp(r'^([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$')
        .hasMatch(domain)) {
      return false;
    }
    return true;
  }

  // Field length limits for security (prevent memory exhaustion, DoS)
  static const int maxNameLength = 100;
  static const int maxEmailLength = 254; // RFC 5321
  static const int maxOrganizationLength = 200;
  static const int maxCompanySizeLength = 100;
  static const int maxUseCaseLength = 200;
  static const int maxMessageLength = 5000;

  /// Validate contact form data.
  ///
  /// Returns validation errors or empty errors if valid.
  static ContactFormErrors validateForm(ContactFormData formData) {
    final errors = ContactFormErrors();

    // Validate name
    if (formData.name.trim().isEmpty) {
      errors.name = 'Please enter your full name';
    } else if (formData.name.length > maxNameLength) {
      errors.name = 'Name must be under $maxNameLength characters';
    }

    // Validate email
    if (formData.email.trim().isEmpty) {
      errors.email = 'Please enter your email address';
    } else if (formData.email.length > maxEmailLength) {
      errors.email = 'Email must be under $maxEmailLength characters';
    } else if (!isValidEmail(formData.email)) {
      errors.email = 'Please enter a valid email address';
    }

    // Validate organization (optional but length-limited)
    if (formData.organization != null &&
        formData.organization!.length > maxOrganizationLength) {
      errors.organization =
          'Organization must be under $maxOrganizationLength characters';
    }

    // Validate companySize (optional but length-limited)
    if (formData.companySize != null &&
        formData.companySize!.length > maxCompanySizeLength) {
      errors.companySize =
          'Company size must be under $maxCompanySizeLength characters';
    }

    // Validate useCase (optional but length-limited)
    if (formData.useCase != null &&
        formData.useCase!.length > maxUseCaseLength) {
      errors.useCase =
          'Use case must be under $maxUseCaseLength characters';
    }

    // Validate message (optional but length-limited)
    if (formData.message != null &&
        formData.message!.length > maxMessageLength) {
      errors.message = 'Message must be under $maxMessageLength characters';
    }

    return errors;
  }

  /// Check if form data is valid.
  static bool isFormValid(ContactFormData formData) {
    return !validateForm(formData).hasErrors;
  }

  /// Fetch a fresh CSRF token from the server.
  /// Tokens are fetched per-submission to eliminate cache/expiration mismatch
  /// and race conditions from concurrent submissions.
  static Future<String?> _fetchCsrfToken() async {
    try {
      final response = await _dio.get(_contactApiUrl);
      final data = response.data as Map<String, dynamic>;
      return data['csrfToken'] as String?;
    } catch (e) {
      // Log CSRF fetch failures to Sentry for monitoring
      ErrorTrackingService.captureException(
        e,
        context: 'ContactService._fetchCsrfToken',
        extra: {
          'endpoint': _contactApiUrl,
          'type': 'csrf_fetch_failure',
        },
      );
      return null;
    }
  }

  /// Generate a unique idempotency key for deduplicating submissions.
  /// Uses 256 bits (32 bytes) for birthday-attack resistance.
  static String _generateIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate a UUID v4 request ID for distributed tracing (#29).
  static String _generateRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // Retry configuration for transient network errors.
  static const int _maxRetries = 2;

  /// Submit contact form to Cloudflare Worker endpoint.
  ///
  /// Sends contact form data via POST request to the contact API.
  /// The worker handles email delivery via Resend.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<ContactFormResponse> submitForm(
    ContactFormPayload payload,
  ) async {
    // Validate form data first
    final errors = validateForm(payload.formData);
    if (errors.hasErrors) {
      return ContactFormError(
        error: _errorFormValidation,
        fieldErrors: errors.toMap(),
      );
    }

    // Generate idempotency key once per submission (persists across retries)
    final idempotencyKey = _generateIdempotencyKey();
    // Generate request ID for distributed tracing (#29)
    final requestId = _generateRequestId();

    // Fetch CSRF token once; re-fetch only on 403
    var csrfToken = await _fetchCsrfToken();

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          _contactApiUrl,
          data: jsonEncode(payload.formData.toJson()),
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              if (csrfToken != null) 'X-CSRF-Token': csrfToken,
              'X-Idempotency-Key': idempotencyKey,
              'X-Request-ID': requestId,
            },
            // Accept all non-null status codes — HTTP errors are handled in
            // the explicit dispatch below so Dio must not throw on 4xx/5xx.
            validateStatus: (status) => status != null,
          ),
        );

        // CSRF token rejected — refresh and retry immediately (no backoff).
        // Unlike transient 500/504 errors, a 403 means the token is stale,
        // not that the server is overloaded, so a fresh token fetch is the
        // correct recovery and delay would only hurt UX.
        if (response.statusCode == HttpStatus.forbidden.code) {
          if (attempt < _maxRetries) {
            csrfToken = await _fetchCsrfToken();
            continue;
          }
          return const ContactFormError(
            error: _errorSecurityToken,
          );
        }

        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const <String, dynamic>{};

        // Retryable server errors (500, 504)
        if (response.statusCode == HttpStatus.internalServerError.code ||
            response.statusCode == HttpStatus.gatewayTimeout.code) {
          if (attempt < _maxRetries) {
            await retryDelay(Duration(seconds: 1 << attempt));
            continue;
          }
          return ContactFormError(
            error: _sanitiseServerError(
                data['error'] as String?, _errorServerError),
          );
        }

        if (response.statusCode == HttpStatus.tooManyRequests.code) {
          final retryAfterRaw =
              int.tryParse(response.headers.value('retry-after') ?? '');
          final retryAfter =
              retryAfterRaw != null && retryAfterRaw > 0 ? retryAfterRaw : null;
          final bodyRetryAfter = data['retryAfter'] as int?;
          final seconds = retryAfter ??
              (bodyRetryAfter != null && bodyRetryAfter > 0
                  ? bodyRetryAfter
                  : null);
          return ContactFormError(
            error: seconds != null
                ? 'Too many requests. Please try again in $seconds seconds.'
                : _errorTooManyRequests,
            retryAfterSeconds: seconds,
          );
        }

        if (response.statusCode == HttpStatus.ok.code && data['success'] == true) {
          return ContactFormSuccess(
            message: _sanitiseServerError(data['message'] as String?,
                "Thank you for your message! We'll respond within 24 hours."),
            submissionId: data['submissionId'] as String? ??
                'local_${DateTime.now().millisecondsSinceEpoch}',
          );
        } else {
          // Non-retryable: client error or unexpected status
          return ContactFormError(
            error: _sanitiseServerError(
                data['error'] as String?, _errorUnableToSubmit),
          );
        }
      } on DioException catch (e) {
        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isRetryable && attempt < _maxRetries) {
          // Exponential backoff: 1s, 2s
          await retryDelay(Duration(seconds: 1 << attempt));
          continue;
        }

        // Log to Sentry on final attempt
        ErrorTrackingService.captureException(
          e,
          stackTrace: e.stackTrace,
          context: 'ContactService.submitForm',
          extra: {
            'endpoint': _contactApiUrl,
            'type': 'contact_form',
            'attempt': attempt + 1,
            'requestId': requestId,
          },
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const ContactFormError(
            error: _errorTimeout,
          );
        }
        return const ContactFormError(
          error: _errorNetwork,
        );
      } catch (e, stackTrace) {
        // Non-retryable unexpected errors
        ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const ContactFormError(
          error: _errorUnexpected,
        );
      }
    }

    // Unreachable, but satisfies the return type
    return const ContactFormError(
      error: _errorUnexpected,
    );
  }
}
