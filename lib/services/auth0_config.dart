/// Auth0 settings for Universal Login.
///
/// The defaults are the production tenant's `integritystudio-dashboard` SPA client —
/// the same client integritystudio.dev signs in with, which is what lets the two sites
/// share one Auth0 session. Override them with `--dart-define` to run against the dev
/// tenant (whose SPA client allows `http://localhost:8080/callback`).
///
/// The domain is the tenant's custom domain, not its `dev-68gg87ow4mg4kzyo.us.auth0.com`
/// hostname (CR32, CR70). Auth0 keeps one session per hostname, so integritystudio.dev's
/// dashboard must use the same value or the shared sign-in stops being shared.
abstract final class Auth0Config {
  static const String domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'auth.integritystudio.ai',
  );

  static const String clientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'CNfd6xPPr2aLmvNyiearhmaLknAYvtnq',
  );

  /// The API the access token is minted for; api-gateway and the receiver check it.
  static const String audience = String.fromEnvironment(
    'AUTH0_AUDIENCE',
    defaultValue: 'https://api.integritystudio.dev',
  );

  /// `offline_access` asks for a refresh token, so a reload or a new tab keeps the
  /// user signed in without another trip to the login page.
  static const String scope = 'openid profile email offline_access';
}
