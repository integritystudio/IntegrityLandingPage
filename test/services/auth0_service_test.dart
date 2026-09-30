import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/auth0_config.dart';
import 'package:integrity_studio_ai/services/auth0_service.dart';

import '../helpers/fake_auth0_browser.dart';
import '../helpers/mock_http_adapter.dart';

const _origin = 'https://integritystudio.ai';
const _email = 'User@Example.com';
const _tokenPath = '/oauth/token';
const _expiresInSeconds = 86400;

/// An unsigned JWT-shaped string carrying [claims]; the service only reads it.
String _idToken(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(claims)}.signature';
}

Map<String, dynamic> _tokenResponse({
  String accessToken = 'access-1',
  String? refreshToken = 'refresh-1',
  String? email = _email,
}) =>
    {
      'access_token': accessToken,
      'expires_in': _expiresInSeconds,
      'token_type': 'Bearer',
      if (email != null) 'id_token': _idToken({'email': email}),
      'refresh_token': ?refreshToken,
    };

void main() {
  late FakeAuth0Browser browser;
  late MockHttpAdapter http;
  var now = DateTime.utc(2026, 9, 29, 12);

  setUp(() {
    browser = FakeAuth0Browser(origin: _origin);
    http = MockHttpAdapter();
    now = DateTime.utc(2026, 9, 29, 12);
    Auth0Service.setForTesting(
      dio: dioWithMockAdapter(http),
      browser: browser,
      now: () => now,
      random: Random(1),
    );
  });

  tearDown(Auth0Service.resetForTesting);

  /// Start a login and return the state it sent to Auth0.
  String startLogin({SignupIntent? signup}) {
    Auth0Service.login(signup: signup);
    return browser.lastNavigation!.queryParameters['state']!;
  }

  Uri callback(Map<String, String> params) =>
      Uri.parse('$_origin/callback').replace(queryParameters: params);

  group('pure helpers', () {
    // Expected value computed independently: base64.urlsafe_b64encode(
    // hashlib.sha256(verifier).digest()).rstrip(b'=') in Python.
    test('codeChallenge is the unpadded base64url SHA-256 of the verifier', () {
      expect(
        Auth0Service.codeChallenge('M25iVXpKU3puUjFaYWg3T1NDTDQtcW1ROUY5YXlwalNoc0hhakxifmZHag'),
        'qjrzSW9gMiUgpUvqgEPE4_-8swvyCtfOVvg55o5S_es',
      );
    });

    test('emailFromIdToken reads the email claim and rejects malformed tokens', () {
      expect(Auth0Service.emailFromIdToken(_idToken({'email': _email})), _email);
      expect(Auth0Service.emailFromIdToken(_idToken({'sub': 'x'})), isNull);
      expect(Auth0Service.emailFromIdToken('not-a-jwt'), isNull);
      expect(Auth0Service.emailFromIdToken('a.%%%.c'), isNull);
      expect(Auth0Service.emailFromIdToken(null), isNull);
    });

    test('constantTimeEquals compares whole strings', () {
      expect(Auth0Service.constantTimeEquals('abc', 'abc'), isTrue);
      expect(Auth0Service.constantTimeEquals('abc', 'abd'), isFalse);
      expect(Auth0Service.constantTimeEquals('abc', 'ab'), isFalse);
      // The shorter string first: a forged state longer than the stored one must be
      // rejected, not read past its end.
      expect(Auth0Service.constantTimeEquals('ab', 'abc'), isFalse);
      expect(Auth0Service.constantTimeEquals('', 'x'), isFalse);
      expect(Auth0Service.constantTimeEquals('', ''), isTrue);
      // A trailing NUL XORs to zero against the padding, so only the length
      // check separates these (CR57).
      expect(Auth0Service.constantTimeEquals('ab\u0000', 'ab'), isFalse);
    });

    test('logoutUrl ends the Auth0 session and returns to the given page', () {
      final url = Auth0Service.logoutUrl(returnTo: '$_origin/');
      expect(url.host, Auth0Config.domain);
      expect(url.path, '/v2/logout');
      expect(url.queryParameters, {'client_id': Auth0Config.clientId, 'returnTo': '$_origin/'});
    });
  });

  group('login', () {
    test('redirects to /authorize with PKCE S256, state, audience and offline access', () {
      Auth0Service.login(loginHint: 'a@b.co');

      final url = browser.lastNavigation!;
      final params = url.queryParameters;
      expect(url.host, Auth0Config.domain);
      expect(url.path, '/authorize');
      expect(params['response_type'], 'code');
      expect(params['client_id'], Auth0Config.clientId);
      expect(params['redirect_uri'], '$_origin/callback');
      expect(params['audience'], Auth0Config.audience);
      expect(params['scope'], contains('offline_access'));
      expect(params['code_challenge_method'], 'S256');
      expect(params['login_hint'], 'a@b.co');
      expect(params, isNot(contains('screen_hint')));
      // A returning user with a live Auth0 session is signed in without a prompt.
      expect(params, isNot(contains('prompt')));

      // The challenge sent is the hash of the verifier kept for the callback.
      final verifier = browser.stores[BrowserStore.session]!['auth0_code_verifier']!;
      expect(params['code_challenge'], Auth0Service.codeChallenge(verifier));
      expect(browser.stores[BrowserStore.session]!['auth0_state'], params['state']);
    });

    test('signup opens the sign-up screen and keeps the intent for the callback', () {
      Auth0Service.login(signup: const SignupIntent(tier: 'growth', orgName: 'Acme'));

      expect(browser.lastNavigation!.queryParameters['screen_hint'], 'signup');
      expect(browser.stores[BrowserStore.session]!['auth0_signup_intent'], isNotNull);
    });

    // An existing Auth0 session would otherwise answer silently, signing in whoever the
    // browser is already logged in as instead of showing the sign-up screen.
    test('signup forces the prompt past an existing Auth0 session', () {
      Auth0Service.login(signup: const SignupIntent(tier: 'starter'), loginHint: 'new@b.co');

      final params = browser.lastNavigation!.queryParameters;
      expect(params['prompt'], 'login');
      expect(params['login_hint'], 'new@b.co');
    });

    test('a plain login drops a signup intent left by an abandoned signup', () {
      Auth0Service.login(signup: const SignupIntent(tier: 'growth'));
      Auth0Service.login();

      expect(browser.stores[BrowserStore.session]!, isNot(contains('auth0_signup_intent')));
    });
  });

  group('handleCallback', () {
    test('exchanges the code with the stored verifier and stores the session', () async {
      final state = startLogin(signup: const SignupIntent(tier: 'enterprise', orgName: 'Acme'));
      final verifier = browser.stores[BrowserStore.session]!['auth0_code_verifier'];
      http.stubJson('POST', _tokenResponse(), path: _tokenPath);

      final result = await Auth0Service.handleCallback(callback({'code': 'c1', 'state': state}));

      expect(result.session.accessToken, 'access-1');
      expect(result.session.email, _email, reason: 'email is kept exactly as Auth0 returns it');
      expect(result.session.expiresAt, now.add(const Duration(seconds: _expiresInSeconds)));
      expect(result.signup?.tier, 'enterprise');
      expect(result.signup?.orgName, 'Acme');

      final request = http.requestLog.single;
      expect(request.uri.toString(), 'https://${Auth0Config.domain}/oauth/token');
      expect(request.contentType, Headers.formUrlEncodedContentType);
      expect(request.data, {
        'grant_type': 'authorization_code',
        'client_id': Auth0Config.clientId,
        'code': 'c1',
        'code_verifier': verifier,
        'redirect_uri': '$_origin/callback',
      });
      expect(browser.stores[BrowserStore.local]!['auth0_refresh_token'], 'refresh-1');
      expect(Auth0Service.hasSession, isTrue);
    });

    test('clears the one-time values even when the exchange succeeds', () async {
      final state = startLogin(signup: const SignupIntent(tier: 'growth'));
      http.stubJson('POST', _tokenResponse(), path: _tokenPath);

      await Auth0Service.handleCallback(callback({'code': 'c1', 'state': state}));

      final session = browser.stores[BrowserStore.session]!;
      expect(session.keys, isNot(containsAll(['auth0_state', 'auth0_code_verifier'])));
      expect(session, isNot(contains('auth0_signup_intent')));
    });

    test('rejects a state that does not match, without calling Auth0', () async {
      startLogin();

      await expectLater(
        Auth0Service.handleCallback(callback({'code': 'c1', 'state': 'forged'})),
        throwsA(isA<Auth0Exception>()),
      );
      expect(http.requestLog, isEmpty);
    });

    test('rejects a replayed callback: the state is single use', () async {
      final state = startLogin();
      http.stubJson('POST', _tokenResponse(), path: _tokenPath);
      final uri = callback({'code': 'c1', 'state': state});
      await Auth0Service.handleCallback(uri);

      await expectLater(Auth0Service.handleCallback(uri), throwsA(isA<Auth0Exception>()));
      expect(http.requestLog, hasLength(1));
    });

    test('rejects a callback that no login in this tab started', () async {
      await expectLater(
        Auth0Service.handleCallback(callback({'code': 'c1', 'state': 's'})),
        throwsA(isA<Auth0Exception>()),
      );
    });

    test('surfaces the error Auth0 sends back', () async {
      startLogin();

      await expectLater(
        Auth0Service.handleCallback(
            callback({'error': 'access_denied', 'error_description': 'User cancelled'})),
        throwsA(isA<Auth0Exception>().having((e) => e.message, 'message', 'User cancelled')),
      );
    });

    test('a refused code exchange is an error', () async {
      final state = startLogin();
      http.stubJson('POST', {'error': 'invalid_grant', 'error_description': 'Invalid code'},
          statusCode: 403, path: _tokenPath);

      await expectLater(
        Auth0Service.handleCallback(callback({'code': 'c1', 'state': state})),
        throwsA(isA<Auth0Exception>().having((e) => e.rejected, 'rejected', isTrue)),
      );
      expect(Auth0Service.hasSession, isFalse);
    });

    test('a network failure is an error that does not claim a refusal', () async {
      final state = startLogin();
      http.stubError('POST', DioExceptionType.connectionError, path: _tokenPath);

      await expectLater(
        Auth0Service.handleCallback(callback({'code': 'c1', 'state': state})),
        throwsA(isA<Auth0Exception>().having((e) => e.rejected, 'rejected', isFalse)),
      );
    });

    test('a response without an email is an error', () async {
      final state = startLogin();
      http.stubJson('POST', _tokenResponse(email: null), path: _tokenPath);

      await expectLater(
        Auth0Service.handleCallback(callback({'code': 'c1', 'state': state})),
        throwsA(isA<Auth0Exception>()),
      );
    });
  });

  group('currentSession', () {
    Future<void> signIn() async {
      final state = startLogin();
      http.stubJson('POST', _tokenResponse(), path: _tokenPath);
      await Auth0Service.handleCallback(callback({'code': 'c1', 'state': state}));
      http.requestLog.clear();
    }

    test('is null when nobody has signed in', () async {
      expect(await Auth0Service.currentSession(), isNull);
      expect(Auth0Service.hasSession, isFalse);
    });

    test('returns the stored session while its token is fresh', () async {
      await signIn();

      final session = await Auth0Service.currentSession();

      expect(session?.accessToken, 'access-1');
      expect(http.requestLog, isEmpty);
    });

    test('refreshes an expiring token and stores the rotated refresh token', () async {
      await signIn();
      now = now.add(const Duration(seconds: _expiresInSeconds));
      http.stubJson('POST', _tokenResponse(accessToken: 'access-2', refreshToken: 'refresh-2'),
          path: _tokenPath);

      final session = await Auth0Service.currentSession();

      expect(session?.accessToken, 'access-2');
      expect(http.requestLog.single.data, {
        'grant_type': 'refresh_token',
        'client_id': Auth0Config.clientId,
        'refresh_token': 'refresh-1',
      });
      expect(browser.stores[BrowserStore.local]!['auth0_refresh_token'], 'refresh-2');
    });

    test('restores a session in a new tab from the refresh token alone', () async {
      await signIn();
      browser.stores[BrowserStore.session]!.clear();
      http.stubJson('POST', _tokenResponse(accessToken: 'access-2'), path: _tokenPath);

      final session = await Auth0Service.currentSession();

      expect(session?.accessToken, 'access-2');
      expect(session?.email, _email);
    });

    test('keeps the known email when a refresh returns no ID token', () async {
      await signIn();
      now = now.add(const Duration(seconds: _expiresInSeconds));
      http.stubJson('POST', _tokenResponse(accessToken: 'access-2', email: null),
          path: _tokenPath);

      expect((await Auth0Service.currentSession())?.email, _email);
    });

    test('sends one refresh for concurrent callers: rotation treats a second as reuse',
        () async {
      await signIn();
      now = now.add(const Duration(seconds: _expiresInSeconds));
      http.stubJson('POST', _tokenResponse(accessToken: 'access-2'), path: _tokenPath);

      final sessions = await Future.wait([
        Auth0Service.currentSession(),
        Auth0Service.currentSession(),
      ]);

      expect(sessions.map((s) => s?.accessToken), ['access-2', 'access-2']);
      expect(http.requestLog, hasLength(1));
    });

    test('signs out locally when Auth0 refuses the refresh token', () async {
      await signIn();
      now = now.add(const Duration(seconds: _expiresInSeconds));
      http.stubJson('POST', {'error': 'invalid_grant'}, statusCode: 403, path: _tokenPath);

      expect(await Auth0Service.currentSession(), isNull);
      expect(Auth0Service.hasSession, isFalse);
    });

    test('keeps the refresh token through a network failure', () async {
      await signIn();
      now = now.add(const Duration(seconds: _expiresInSeconds));
      http.stubError('POST', DioExceptionType.connectionError, path: _tokenPath);

      expect(await Auth0Service.currentSession(), isNull);
      expect(browser.stores[BrowserStore.local]!['auth0_refresh_token'], 'refresh-1');
    });
  });

  group('logout', () {
    test('forgets the tokens and ends the Auth0 session, returning home', () async {
      final state = startLogin();
      http.stubJson('POST', _tokenResponse(), path: _tokenPath);
      await Auth0Service.handleCallback(callback({'code': 'c1', 'state': state}));

      Auth0Service.logout();

      expect(Auth0Service.hasSession, isFalse);
      expect(browser.lastNavigation, Auth0Service.logoutUrl(returnTo: '$_origin/'));
    });
  });
}
