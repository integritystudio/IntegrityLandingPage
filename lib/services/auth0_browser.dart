import 'auth0_browser_stub.dart'
    if (dart.library.js_interop) 'auth0_browser_web.dart' as platform;

/// Which browser storage a value lives in.
enum BrowserStore {
  /// Per tab, cleared when the tab closes.
  session,

  /// Per origin, survives reloads and new tabs.
  local,
}

/// The browser surface the Auth0 flow needs: storage, navigation and the page origin.
///
/// The web implementation wraps `window`; off the web it is inert. Tests inject their
/// own through `Auth0Service.setForTesting`.
abstract interface class Auth0Browser {
  static Auth0Browser platformDefault() => platform.createAuth0Browser();

  /// The page's origin, e.g. `https://integritystudio.ai`.
  String get origin;

  String? read(BrowserStore store, String key);
  void write(BrowserStore store, String key, String value);
  void remove(BrowserStore store, String key);

  /// Leave the app for [url] (a top-level navigation, not a popup).
  void navigate(String url);
}
