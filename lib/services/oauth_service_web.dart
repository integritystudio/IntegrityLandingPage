// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

/// Storage keys for PKCE and CSRF state.
const String _sessionStateKey = 'oauth_state';
const String _sessionVerifierKey = 'oauth_code_verifier';

// =============================================================================
// JS Interop — Web Crypto API
// =============================================================================

@JS('crypto.getRandomValues')
external JSUint8Array _getRandomValues(JSUint8Array array);

@JS('crypto.subtle.digest')
external JSPromise<JSArrayBuffer> _subtleDigest(JSString algorithm, JSArrayBuffer data);

// =============================================================================
// OAuth PKCE Service
// =============================================================================

/// Implements RFC 7636 PKCE and RFC 6749 state CSRF protection for Auth0.
///
/// Usage (initiate):
/// ```dart
/// final url = await OAuthService.buildAuthorizationUrl(
///   domain: 'your-tenant.auth0.com',
///   clientId: 'YOUR_CLIENT_ID',
///   redirectUri: 'https://integritystudio.ai/oauth/callback',
///   audience: 'https://api.integritystudio.dev',
/// );
/// web.window.location.href = url;
/// ```
///
/// Usage (callback):
/// ```dart
/// final valid = OAuthService.validateCallback(returnedState: state);
/// if (!valid) { /* reject — CSRF attack */ }
/// final verifier = OAuthService.consumeCodeVerifier();
/// // Exchange code + verifier with Auth0 token endpoint
/// ```
class OAuthService {
  OAuthService._();

  /// Maximum byte length for random buffers (verifier + state each).
  static const int _randomByteLength = 32;

  /// Build the Auth0 authorization URL with PKCE (S256) and CSRF state.
  ///
  /// Generates a fresh [code_verifier], [code_challenge], and [state] on each
  /// call and persists them to sessionStorage for retrieval on callback.
  /// sessionStorage is origin-scoped and cleared when the tab closes.
  ///
  /// Throws [UnsupportedError] on non-web platforms.
  static Future<String> buildAuthorizationUrl({
    required String domain,
    required String clientId,
    required String redirectUri,
    required String audience,
    String scopes = 'openid profile email',
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('OAuthService is only available on web');
    }

    final verifier = _generateBase64Url(_randomByteLength);
    final state = _generateBase64Url(_randomByteLength);
    final challenge = await _sha256Base64Url(verifier);

    _sessionStore(_sessionVerifierKey, verifier);
    _sessionStore(_sessionStateKey, state);

    final params = {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'audience': audience,
      'scope': scopes,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    };

    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://$domain/authorize?$query';
  }

  /// Validate the [returnedState] from the callback against the stored value.
  ///
  /// Returns true if states match (CSRF check passed). Always consumes and
  /// clears the stored state regardless of result to prevent replay.
  static bool validateCallback({required String returnedState}) {
    if (!kIsWeb) return false;
    final stored = _sessionLoad(_sessionStateKey);
    _sessionClear(_sessionStateKey);
    if (stored == null || stored.isEmpty) return false;
    return _constantTimeEquals(stored, returnedState);
  }

  /// Return and clear the stored PKCE code_verifier.
  ///
  /// Must be called once, immediately after a successful [validateCallback],
  /// to exchange the authorization code for tokens.
  /// Returns null if no verifier is stored (e.g. direct navigation to callback).
  static String? consumeCodeVerifier() {
    if (!kIsWeb) return null;
    final verifier = _sessionLoad(_sessionVerifierKey);
    _sessionClear(_sessionVerifierKey);
    return verifier;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generate [byteLength] random bytes and return as base64url-encoded string.
  static String _generateBase64Url(int byteLength) {
    final buffer = Uint8List(byteLength);
    final jsArray = buffer.toJS;
    _getRandomValues(jsArray);
    // Copy bytes back from the JS-mutated typed array
    final bytes = jsArray.toDart;
    return _base64UrlNoPad(bytes);
  }

  /// Compute SHA-256 over the UTF-8 bytes of [input] and return base64url.
  static Future<String> _sha256Base64Url(String input) async {
    final inputBytes = Uint8List.fromList(utf8.encode(input));
    final inputBuffer = inputBytes.buffer.toJS;
    final hashBuffer = await _subtleDigest('SHA-256'.toJS, inputBuffer).toDart;
    final hashBytes = Uint8List.fromList(
      hashBuffer.toDart.asUint8List(),
    );
    return _base64UrlNoPad(hashBytes);
  }

  /// Base64url encode without padding (RFC 7636 §4.2).
  static String _base64UrlNoPad(Uint8List bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Constant-time string comparison to prevent timing attacks on state check.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static void _sessionStore(String key, String value) {
    try {
      web.window.sessionStorage.setItem(key, value);
    } catch (_) {}
  }

  static String? _sessionLoad(String key) {
    try {
      return web.window.sessionStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  static void _sessionClear(String key) {
    try {
      web.window.sessionStorage.removeItem(key);
    } catch (_) {}
  }
}
