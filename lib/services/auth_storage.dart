// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Persists the Auth0 JWT in browser localStorage.
///
/// localStorage survives page reloads within the same origin but is not
/// accessible cross-origin (integritystudio.dev cannot read integritystudio.ai
/// storage). The JWT is passed explicitly in the dashboard redirect URL.
///
/// On non-web platforms all operations are no-ops.
class AuthStorage {
  AuthStorage._();

  static const String _jwtKey = 'auth_jwt';

  /// Persist [jwt] to localStorage.
  static void saveJwt(String jwt) {
    if (!kIsWeb) return;
    try {
      web.window.localStorage.setItem(_jwtKey, jwt);
    } catch (_) {
      // Storage unavailable (e.g. private browsing with strict settings)
    }
  }

  /// Return the stored JWT, or null if none is saved.
  static String? getJwt() {
    if (!kIsWeb) return null;
    try {
      return web.window.localStorage.getItem(_jwtKey);
    } catch (_) {
      return null;
    }
  }

  /// Remove the stored JWT (call on sign-out).
  static void clearJwt() {
    if (!kIsWeb) return;
    try {
      web.window.localStorage.removeItem(_jwtKey);
    } catch (_) {}
  }
}
