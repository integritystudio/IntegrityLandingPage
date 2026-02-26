/// No-op implementation for non-web platforms.
///
/// All methods are no-ops since GTM/analytics only run on web.
/// Class is named TrackingWeb to match the web implementation
/// (required by Dart's conditional import pattern in tracking.dart).
class TrackingWeb {
  TrackingWeb._();

  static void initializeConsentMode() {}

  static void updateConsent({
    required bool analytics,
    required bool marketing,
  }) {}

  static void injectGTM() {}

  static void sendEvent(String eventName, Map<String, dynamic> parameters) {}

  static void sendPageView(String pagePath, String pageTitle) {}

  static void injectFacebookPixel() {}

  static void sendFBEvent(String eventName, [Map<String, dynamic>? parameters]) {}

  static void sendFBPageView() {}

  static String? getFromStorage(String key) => null;

  static void setToStorage(String key, String value) {}

  static void removeFromStorage(String key) {}

  static bool get isGTMInjected => false;

  static bool get isFBPixelInjected => false;
}
