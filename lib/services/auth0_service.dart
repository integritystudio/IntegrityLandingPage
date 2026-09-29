import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../config/content/constants.dart';
import '../theme/timings.dart';
import 'auth0_browser.dart';
import 'auth0_config.dart';

export 'auth0_browser.dart' show Auth0Browser, BrowserStore;

/// A signed-in user: the API access token and the email Auth0 holds for them.
class Auth0Session {
  final String accessToken;

  /// As Auth0 returns it. The receiver compares it byte for byte with /userinfo,
  /// so it must not be normalised.
  final String email;
  final DateTime expiresAt;

  const Auth0Session({
    required this.accessToken,
    required this.email,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'email': email,
        'expiresAt': expiresAt.toIso8601String(),
      };

  static Auth0Session? tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Auth0Session(
        accessToken: json['accessToken'] as String,
        email: json['email'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// What the signup form collected, carried across the Auth0 redirect so the
/// callback can provision the right org and send a paid tier on to checkout.
class SignupIntent {
  final String tier;

  /// The company name an enterprise signup entered, or null to let the receiver
  /// name the org (the email domain for a team org, the email for a personal one).
  final String? orgName;

  const SignupIntent({required this.tier, this.orgName});

  bool get isPaidTier =>
      tier == SignupTiers.growth || tier == SignupTiers.enterprise;

  Map<String, dynamic> toJson() => {
        'tier': tier,
        if (orgName != null) 'orgName': orgName,
      };

  static SignupIntent? tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SignupIntent(
        tier: SignupTiers.normalize(json['tier'] as String?),
        orgName: json['orgName'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The outcome of a completed Auth0 redirect.
class Auth0CallbackResult {
  final Auth0Session session;

  /// Set when the redirect began on the signup form.
  final SignupIntent? signup;

  const Auth0CallbackResult({required this.session, this.signup});
}

class Auth0Exception implements Exception {
  final String message;

  /// True when Auth0 answered and refused (a bad code, a revoked refresh token);
  /// false for a network failure, which says nothing about the stored tokens.
  final bool rejected;

  const Auth0Exception(this.message, {this.rejected = false});

  @override
  String toString() => 'Auth0Exception: $message';
}

/// Signs users in through Auth0 Universal Login (authorization code + PKCE, RFC 7636)
/// with the SPA client integritystudio.dev also uses, so both sites share one Auth0
/// session. The refresh token (rotating) persists in localStorage; the access token
/// lives in sessionStorage and is refreshed shortly before it expires.
abstract final class Auth0Service {
  static const String _stateKey = 'auth0_state';
  static const String _verifierKey = 'auth0_code_verifier';
  static const String _signupKey = 'auth0_signup_intent';
  static const String _sessionKey = 'auth0_session';
  static const String _refreshTokenKey = 'auth0_refresh_token';

  static const int _randomByteLength = 32;
  static const int _byteValueCount = 256;

  /// Refresh this long before expiry so a token never lapses mid-request.
  static const Duration _expiryLeeway = Duration(minutes: 1);

  static const String _errorInvalidCallback =
      'This sign-in link is invalid or has already been used. Please sign in again.';
  static const String _errorNetwork =
      'Could not reach the sign-in service. Please check your connection and try again.';
  static const String _errorTokenResponse =
      'Sign-in failed. Please try again.';

  static Dio _dio = _defaultDio();
  static Auth0Browser _browser = Auth0Browser.platformDefault();
  static DateTime Function() _now = DateTime.now;
  static Random _random = Random.secure();

  /// One refresh at a time: with rotation, a second request carrying the same
  /// refresh token counts as reuse and revokes the whole token family.
  static Future<Auth0Session?>? _refreshing;

  static Dio _defaultDio() => Dio(BaseOptions(
        connectTimeout: AppTimings.httpConnectTimeout,
        receiveTimeout: AppTimings.httpReceiveTimeout,
      ));

  @visibleForTesting
  static void setForTesting({
    Dio? dio,
    Auth0Browser? browser,
    DateTime Function()? now,
    Random? random,
  }) {
    if (dio != null) _dio = dio;
    if (browser != null) _browser = browser;
    if (now != null) _now = now;
    if (random != null) _random = random;
  }

  @visibleForTesting
  static void resetForTesting() {
    _dio = _defaultDio();
    _browser = Auth0Browser.platformDefault();
    _now = DateTime.now;
    _random = Random.secure();
    _refreshing = null;
  }

  static String get _redirectUri => '${_browser.origin}${Routes.callback}';

  /// Whether a session is stored; it may still turn out to be expired or revoked,
  /// which [currentSession] resolves.
  static bool get hasSession =>
      _browser.read(BrowserStore.local, _refreshTokenKey) != null ||
      _browser.read(BrowserStore.session, _sessionKey) != null;

  /// Send the user to the Auth0 login page. [signup] opens the sign-up screen and
  /// is handed back by [handleCallback]; [loginHint] pre-fills the email.
  static void login({String? loginHint, SignupIntent? signup}) {
    final verifier = _randomBase64Url();
    final state = _randomBase64Url();
    _browser.write(BrowserStore.session, _verifierKey, verifier);
    _browser.write(BrowserStore.session, _stateKey, state);
    if (signup != null) {
      _browser.write(BrowserStore.session, _signupKey, jsonEncode(signup.toJson()));
    } else {
      _browser.remove(BrowserStore.session, _signupKey);
    }
    _browser.navigate(authorizeUrl(
      redirectUri: _redirectUri,
      state: state,
      codeChallenge: codeChallenge(verifier),
      signup: signup != null,
      loginHint: loginHint,
    ).toString());
  }

  /// Complete the redirect back from Auth0: check `state`, then exchange the code.
  /// The stored state, verifier and signup intent are single use and cleared first,
  /// so a replayed or reloaded callback URL fails rather than signs in twice.
  static Future<Auth0CallbackResult> handleCallback(Uri uri) async {
    final storedState = _browser.read(BrowserStore.session, _stateKey);
    final verifier = _browser.read(BrowserStore.session, _verifierKey);
    final signup = SignupIntent.tryDecode(_browser.read(BrowserStore.session, _signupKey));
    for (final key in [_stateKey, _verifierKey, _signupKey]) {
      _browser.remove(BrowserStore.session, key);
    }

    final params = uri.queryParameters;
    final error = params['error'];
    if (error != null) {
      throw Auth0Exception(params['error_description'] ?? error, rejected: true);
    }
    final code = params['code'];
    final state = params['state'];
    if (code == null ||
        state == null ||
        storedState == null ||
        verifier == null ||
        !constantTimeEquals(storedState, state)) {
      throw const Auth0Exception(_errorInvalidCallback, rejected: true);
    }

    final session = await _requestTokens({
      'grant_type': 'authorization_code',
      'client_id': Auth0Config.clientId,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': _redirectUri,
    });
    return Auth0CallbackResult(session: session, signup: signup);
  }

  /// The signed-in session, refreshed when its access token is about to expire.
  /// Null when nobody is signed in, or when Auth0 refuses the refresh token (which
  /// then signs the user out locally).
  static Future<Auth0Session?> currentSession() {
    final stored = Auth0Session.tryDecode(_browser.read(BrowserStore.session, _sessionKey));
    if (stored != null && stored.expiresAt.isAfter(_now().add(_expiryLeeway))) {
      return Future.value(stored);
    }
    return _refreshing ??= _refresh(stored?.email).whenComplete(() => _refreshing = null);
  }

  static Future<Auth0Session?> _refresh(String? knownEmail) async {
    final refreshToken = _browser.read(BrowserStore.local, _refreshTokenKey);
    if (refreshToken == null) return null;
    try {
      return await _requestTokens({
        'grant_type': 'refresh_token',
        'client_id': Auth0Config.clientId,
        'refresh_token': refreshToken,
      }, knownEmail: knownEmail);
    } on Auth0Exception catch (e) {
      if (e.rejected) clearSession();
      return null;
    }
  }

  /// Forget the tokens in this browser without leaving the page.
  static void clearSession() {
    _browser.remove(BrowserStore.session, _sessionKey);
    _browser.remove(BrowserStore.local, _refreshTokenKey);
  }

  /// Sign out here and end the Auth0 session, which also signs the user out of
  /// integritystudio.dev. Auth0 returns them to this site's home page.
  static void logout() {
    clearSession();
    _browser.navigate(logoutUrl(returnTo: '${_browser.origin}${Routes.home}').toString());
  }

  static Future<Auth0Session> _requestTokens(
    Map<String, String> body, {
    String? knownEmail,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post(
        'https://${Auth0Config.domain}/oauth/token',
        data: body,
        options: Options(
          // Form encoding is a CORS "simple" request: no preflight round trip.
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null,
        ),
      );
    } on DioException {
      throw const Auth0Exception(_errorNetwork);
    }

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : const <String, dynamic>{};
    if (response.statusCode != 200) {
      throw Auth0Exception(
        data['error_description'] as String? ?? _errorTokenResponse,
        rejected: true,
      );
    }

    final accessToken = data['access_token'];
    final expiresIn = data['expires_in'];
    final email = emailFromIdToken(data['id_token'] as String?) ?? knownEmail;
    if (accessToken is! String || expiresIn is! int || email == null) {
      throw const Auth0Exception(_errorTokenResponse, rejected: true);
    }

    final session = Auth0Session(
      accessToken: accessToken,
      email: email,
      expiresAt: _now().add(Duration(seconds: expiresIn)),
    );
    _browser.write(BrowserStore.session, _sessionKey, jsonEncode(session.toJson()));
    final refreshToken = data['refresh_token'];
    if (refreshToken is String) {
      _browser.write(BrowserStore.local, _refreshTokenKey, refreshToken);
    }
    return session;
  }

  // ---------------------------------------------------------------------------
  // Pure helpers
  // ---------------------------------------------------------------------------

  @visibleForTesting
  static Uri authorizeUrl({
    required String redirectUri,
    required String state,
    required String codeChallenge,
    bool signup = false,
    String? loginHint,
  }) =>
      Uri.https(Auth0Config.domain, '/authorize', {
        'response_type': 'code',
        'client_id': Auth0Config.clientId,
        'redirect_uri': redirectUri,
        'audience': Auth0Config.audience,
        'scope': Auth0Config.scope,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        if (signup) 'screen_hint': 'signup',
        if (loginHint != null && loginHint.isNotEmpty) 'login_hint': loginHint,
      });

  @visibleForTesting
  static Uri logoutUrl({required String returnTo}) =>
      Uri.https(Auth0Config.domain, '/v2/logout', {
        'client_id': Auth0Config.clientId,
        'returnTo': returnTo,
      });

  /// S256 code challenge: base64url(SHA-256(ASCII(verifier))), unpadded.
  @visibleForTesting
  static String codeChallenge(String verifier) =>
      _base64UrlNoPad(sha256.convert(ascii.encode(verifier)).bytes);

  /// The `email` claim of an ID token. The token came straight from Auth0's token
  /// endpoint over TLS, so it is read, not verified; nothing authorises on it.
  @visibleForTesting
  static String? emailFromIdToken(String? idToken) {
    final parts = idToken?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final email = (jsonDecode(payload) as Map<String, dynamic>)['email'];
      return email is String && email.isNotEmpty ? email : null;
    } catch (_) {
      return null;
    }
  }

  /// Compares every character, so the time taken does not reveal a matching prefix.
  @visibleForTesting
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static String _randomBase64Url() => _base64UrlNoPad(
      List<int>.generate(_randomByteLength, (_) => _random.nextInt(_byteValueCount)));

  static String _base64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
