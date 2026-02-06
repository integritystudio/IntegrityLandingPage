import 'dart:convert';
import 'package:dio/dio.dart';
import 'analytics.dart';

/// Contact form API endpoint (Cloudflare Worker).
const _contactApiUrl = 'https://integrity-studio-contact.alyshia-b38.workers.dev';

/// CSRF token cache.
String? _cachedCsrfToken;
int? _csrfTokenTimestamp;

/// Contact form data model.
class ContactFormData {
  final String name;
  final String email;
  final String? organization;
  final String message;
  final String? companySize;
  final String? useCase;

  const ContactFormData({
    required this.name,
    required this.email,
    this.organization,
    required this.message,
    this.companySize,
    this.useCase,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        if (organization != null) 'organization': organization,
        'message': message,
        if (companySize != null) 'companySize': companySize,
        if (useCase != null) 'useCase': useCase,
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

  const ContactFormError({
    required this.error,
    this.fieldErrors,
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

  static Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Set a custom Dio instance for testing.
  /// @visibleForTesting
  static void setDioForTesting(Dio dio) {
    _dio = dio;
  }

  /// Reset Dio to default instance.
  /// @visibleForTesting
  static void resetDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  /// Validate email format.
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
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

    // Validate message (optional, but if provided must meet length requirements)
    if (formData.message.trim().isNotEmpty) {
      if (formData.message.trim().length < 10) {
        errors.message = 'Please provide more details (at least 10 characters)';
      } else if (formData.message.length > maxMessageLength) {
        errors.message = 'Message must be under $maxMessageLength characters';
      }
    }

    return errors;
  }

  /// Check if form data is valid.
  static bool isFormValid(ContactFormData formData) {
    return !validateForm(formData).hasErrors;
  }

  /// Fetch a CSRF token from the server.
  /// Returns cached token if still valid (less than 5 minutes old).
  /// Reduced from 30 minutes for security - shorter cache windows reduce
  /// the attack surface for token replay attacks.
  static Future<String?> _fetchCsrfToken() async {
    // Use cached token if less than 5 minutes old (reduced from 30 for security)
    const maxAge = 5 * 60 * 1000; // 5 minutes
    if (_cachedCsrfToken != null &&
        _csrfTokenTimestamp != null &&
        DateTime.now().millisecondsSinceEpoch - _csrfTokenTimestamp! < maxAge) {
      return _cachedCsrfToken;
    }

    try {
      final response = await _dio.get(_contactApiUrl);
      final data = response.data as Map<String, dynamic>;
      _cachedCsrfToken = data['csrfToken'] as String?;
      _csrfTokenTimestamp = DateTime.now().millisecondsSinceEpoch;
      return _cachedCsrfToken;
    } catch (e) {
      // CSRF fetch failed - will be handled during form submission
      return null;
    }
  }

  /// Clear cached CSRF token (for testing).
  /// @visibleForTesting
  static void clearCsrfCache() {
    _cachedCsrfToken = null;
    _csrfTokenTimestamp = null;
  }

  /// Submit contact form to Cloudflare Worker endpoint.
  ///
  /// Sends contact form data via POST request to the contact API.
  /// The worker handles email delivery via Resend.
  static Future<ContactFormResponse> submitForm(
    ContactFormPayload payload,
  ) async {
    // Validate form data first
    final errors = validateForm(payload.formData);
    if (errors.hasErrors) {
      return ContactFormError(
        error: 'Please fix the errors in the form',
        fieldErrors: errors.toMap(),
      );
    }

    try {
      // Fetch CSRF token
      final csrfToken = await _fetchCsrfToken();

      final response = await _dio.post(
        _contactApiUrl,
        data: jsonEncode(payload.formData.toJson()),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (csrfToken != null) 'X-CSRF-Token': csrfToken,
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Invalidate CSRF token after successful submission to prevent replay
        clearCsrfCache();
        return ContactFormSuccess(
          message: data['message'] as String? ??
              "Thank you for your message! We'll respond within 24 hours.",
          submissionId: data['submissionId'] as String? ??
              'sub_${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        return ContactFormError(
          error: data['error'] as String? ?? 'Unable to submit form',
        );
      }
    } on DioException catch (e) {
      // Log to Sentry
      ErrorTrackingService.captureException(
        e,
        stackTrace: e.stackTrace,
        context: 'ContactService.submitForm',
        extra: {'endpoint': _contactApiUrl, 'type': 'contact_form'},
      );

      // Return user-friendly error
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const ContactFormError(
          error: 'Connection timed out. Please check your internet and try again.',
        );
      }
      return const ContactFormError(
        error: 'Network error: Unable to submit form. Please try again.',
      );
    } catch (e, stackTrace) {
      // Log unexpected errors to Sentry
      ErrorTrackingService.captureException(e, stackTrace: stackTrace);
      return const ContactFormError(
        error: 'An unexpected error occurred. Please try again.',
      );
    }
  }
}
