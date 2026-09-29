import 'auth0_browser.dart';

/// Off the web there is no browser: nothing is stored and navigation does nothing.
Auth0Browser createAuth0Browser() => const _InertAuth0Browser();

class _InertAuth0Browser implements Auth0Browser {
  const _InertAuth0Browser();

  @override
  String get origin => '';

  @override
  String? read(BrowserStore store, String key) => null;

  @override
  void write(BrowserStore store, String key, String value) {}

  @override
  void remove(BrowserStore store, String key) {}

  @override
  void navigate(String url) {}
}
