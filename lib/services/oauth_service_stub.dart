/// No-op stub for OAuthService on non-web platforms.
///
/// All methods throw [UnsupportedError] or return safe defaults.
/// Real implementation: oauth_service_web.dart (web platform only).
library;

class OAuthService {
  OAuthService._();

  static Future<String> buildAuthorizationUrl({
    required String domain,
    required String clientId,
    required String redirectUri,
    required String audience,
    String scopes = 'openid profile email',
  }) async {
    throw UnsupportedError('OAuthService is only available on web');
  }

  static bool validateCallback({required String returnedState}) => false;

  static String? consumeCodeVerifier() => null;
}
