import 'package:integrity_studio_ai/services/auth0_service.dart';

/// In-memory stand-in for the browser: two stores and a record of navigations.
class FakeAuth0Browser implements Auth0Browser {
  FakeAuth0Browser({this.origin = 'https://integritystudio.ai'});

  @override
  final String origin;

  final Map<BrowserStore, Map<String, String>> stores = {
    BrowserStore.session: {},
    BrowserStore.local: {},
  };

  /// Every URL the app navigated to, in order.
  final List<Uri> navigations = [];

  Uri? get lastNavigation => navigations.isEmpty ? null : navigations.last;

  @override
  String? read(BrowserStore store, String key) => stores[store]![key];

  @override
  void write(BrowserStore store, String key, String value) =>
      stores[store]![key] = value;

  @override
  void remove(BrowserStore store, String key) => stores[store]!.remove(key);

  @override
  void navigate(String url) => navigations.add(Uri.parse(url));
}
