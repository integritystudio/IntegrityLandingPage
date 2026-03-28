// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// Persists the Auth0 JWT in browser localStorage.
///
/// localStorage survives page reloads within the same origin but is not
/// accessible cross-origin (integritystudio.dev cannot read integritystudio.ai
/// storage). The JWT is passed explicitly in the dashboard redirect URL.
class AuthStorage {
  AuthStorage._();

  static const String _jwtKey = 'auth_jwt';

  static void saveJwt(String jwt) {
    try {
      web.window.localStorage.setItem(_jwtKey, jwt);
    } catch (_) {
      // Storage unavailable (e.g. private browsing with strict settings)
    }
  }

  static String? getJwt() {
    try {
      return web.window.localStorage.getItem(_jwtKey);
    } catch (_) {
      return null;
    }
  }

  static void clearJwt() {
    try {
      web.window.localStorage.removeItem(_jwtKey);
    } catch (_) {}
  }
}
