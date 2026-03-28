// Platform-aware URL launcher.
//
// Loads the web implementation on web, and a no-op stub on all other platforms.
export 'url_launcher_stub.dart'
    if (dart.library.js_interop) 'url_launcher_web.dart';
