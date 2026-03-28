/// No-op stub for URL launching on non-web platforms.
library;

/// Redirect the browser to [url]. No-op on non-web platforms.
// ignore: avoid_print
void launchUrl(String url) => print('[url_launcher_stub] launchUrl called: $url');
