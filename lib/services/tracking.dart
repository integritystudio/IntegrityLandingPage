// Platform-aware tracking service.
//
// Uses conditional imports to load web-specific implementation
// on web platform and no-op on other platforms.
export 'tracking_none.dart'
    if (dart.library.js_interop) 'tracking_web.dart';
