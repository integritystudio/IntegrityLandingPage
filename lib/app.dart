import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/theme.dart';
import 'routing/app_router.dart';
import 'routing/cookie_shell.dart';
import 'services/analytics.dart';
import 'services/consent_manager.dart';
import 'services/tracking.dart';

class IntegrityStudioApp extends StatefulWidget {
  const IntegrityStudioApp({super.key});

  @override
  State<IntegrityStudioApp> createState() => _IntegrityStudioAppState();
}

class _IntegrityStudioAppState extends State<IntegrityStudioApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Set initial banner state before creating router
    cookieBannerNotifier.value = !ConsentManager.hasConsent();
    // Create router once - it stays stable throughout app lifecycle
    _router = createAppRouter(
      onConsentGiven: _handleConsentGiven,
      onShowCookieSettings: _showCookieSettings,
    );
    // Initialize tracking for returning users
    _initializeTracking();
  }

  /// Initialize tracking for returning users with saved consent
  Future<void> _initializeTracking() async {
    try {
      if (ConsentManager.hasConsent()) {
        final prefs = await ConsentManager.getStoredConsent();
        if (prefs != null && kIsWeb) {
          // Update Consent Mode with stored preferences
          TrackingWeb.updateConsent(
            analytics: prefs.analytics,
            marketing: prefs.marketing,
          );

          // Initialize analytics if previously consented
          if (prefs.analytics) {
            await AnalyticsService.initialize();
          }

          // Initialize Facebook Pixel if marketing was consented
          if (prefs.marketing) {
            TrackingWeb.injectFacebookPixel();
            TrackingWeb.sendFBPageView();
          }
        }
      }
    } catch (e, stackTrace) {
      ErrorTrackingService.captureException(
        e,
        stackTrace: stackTrace,
        context: 'IntegrityStudioApp._initializeTracking',
      );
    }
  }

  void _handleConsentGiven() {
    // Update banner visibility without recreating router
    cookieBannerNotifier.value = false;
  }

  void _showCookieSettings() {
    // Update banner visibility without recreating router
    cookieBannerNotifier.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Integrity Studio - Enterprise AI Observability',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
