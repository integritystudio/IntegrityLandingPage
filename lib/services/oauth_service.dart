// Platform-aware OAuth PKCE + CSRF service.
//
// Loads the web implementation (oauth_service_web.dart) on web,
// and a no-op stub (oauth_service_stub.dart) on all other platforms.
export 'oauth_service_stub.dart'
    if (dart.library.js_interop) 'oauth_service_web.dart';
