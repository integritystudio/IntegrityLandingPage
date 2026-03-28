// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// Redirect the browser to [url] via `window.location.href`.
void launchUrl(String url) {
  web.window.location.href = url;
}
