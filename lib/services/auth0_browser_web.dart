// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

import 'auth0_browser.dart';

Auth0Browser createAuth0Browser() => const _WebAuth0Browser();

class _WebAuth0Browser implements Auth0Browser {
  const _WebAuth0Browser();

  web.Storage _storage(BrowserStore store) => switch (store) {
        BrowserStore.session => web.window.sessionStorage,
        BrowserStore.local => web.window.localStorage,
      };

  @override
  String get origin => web.window.location.origin;

  // Storage can throw (e.g. private browsing with strict settings); treat that as empty.
  @override
  String? read(BrowserStore store, String key) {
    try {
      return _storage(store).getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(BrowserStore store, String key, String value) {
    try {
      _storage(store).setItem(key, value);
    } catch (_) {}
  }

  @override
  void remove(BrowserStore store, String key) {
    try {
      _storage(store).removeItem(key);
    } catch (_) {}
  }

  @override
  void navigate(String url) => web.window.location.assign(url);
}
