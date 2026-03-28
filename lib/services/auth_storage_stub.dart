/// No-op stub for AuthStorage on non-web platforms.
library;

class AuthStorage {
  AuthStorage._();

  static void saveJwt(String jwt) {}
  static String? getJwt() => null;
  static void clearJwt() {}
}
