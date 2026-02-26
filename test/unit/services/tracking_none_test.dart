import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/tracking_none.dart';

void main() {
  group('TrackingWeb stub', () {
    group('consent methods', () {
      test('initializeConsentMode does not throw', () {
        expect(() => TrackingWeb.initializeConsentMode(), returnsNormally);
      });

      test('updateConsent does not throw', () {
        expect(
          () => TrackingWeb.updateConsent(
            analytics: true,
            marketing: false,
          ),
          returnsNormally,
        );
      });

      test('updateConsent accepts all false', () {
        expect(
          () => TrackingWeb.updateConsent(
            analytics: false,
            marketing: false,
          ),
          returnsNormally,
        );
      });

      test('updateConsent accepts all true', () {
        expect(
          () => TrackingWeb.updateConsent(
            analytics: true,
            marketing: true,
          ),
          returnsNormally,
        );
      });
    });

    group('GTM methods', () {
      test('injectGTM does not throw', () {
        expect(() => TrackingWeb.injectGTM(), returnsNormally);
      });

      test('sendEvent does not throw', () {
        expect(
          () => TrackingWeb.sendEvent('test_event', {'key': 'value'}),
          returnsNormally,
        );
      });

      test('sendEvent accepts empty parameters', () {
        expect(
          () => TrackingWeb.sendEvent('test_event', {}),
          returnsNormally,
        );
      });

      test('sendPageView does not throw', () {
        expect(
          () => TrackingWeb.sendPageView('/test', 'Test Page'),
          returnsNormally,
        );
      });

      test('isGTMInjected returns false on non-web', () {
        expect(TrackingWeb.isGTMInjected, isFalse);
      });
    });

    group('Facebook Pixel methods', () {
      test('injectFacebookPixel does not throw', () {
        expect(() => TrackingWeb.injectFacebookPixel(), returnsNormally);
      });

      test('sendFBEvent does not throw', () {
        expect(
          () => TrackingWeb.sendFBEvent('Lead'),
          returnsNormally,
        );
      });

      test('sendFBEvent accepts parameters', () {
        expect(
          () => TrackingWeb.sendFBEvent('Lead', {'email': 'test@test.com'}),
          returnsNormally,
        );
      });

      test('sendFBEvent accepts null parameters', () {
        expect(
          () => TrackingWeb.sendFBEvent('PageView', null),
          returnsNormally,
        );
      });

      test('sendFBPageView does not throw', () {
        expect(() => TrackingWeb.sendFBPageView(), returnsNormally);
      });

      test('isFBPixelInjected returns false on non-web', () {
        expect(TrackingWeb.isFBPixelInjected, isFalse);
      });
    });

    group('storage methods', () {
      test('getFromStorage returns null on non-web', () {
        expect(TrackingWeb.getFromStorage('test_key'), isNull);
      });

      test('getFromStorage returns null for any key', () {
        expect(TrackingWeb.getFromStorage('consent_preferences'), isNull);
        expect(TrackingWeb.getFromStorage('analytics_enabled'), isNull);
        expect(TrackingWeb.getFromStorage('random_key'), isNull);
      });

      test('setToStorage does not throw', () {
        expect(
          () => TrackingWeb.setToStorage('key', 'value'),
          returnsNormally,
        );
      });

      test('setToStorage accepts empty values', () {
        expect(
          () => TrackingWeb.setToStorage('key', ''),
          returnsNormally,
        );
      });

      test('removeFromStorage does not throw', () {
        expect(
          () => TrackingWeb.removeFromStorage('key'),
          returnsNormally,
        );
      });

      test('removeFromStorage accepts non-existent key', () {
        expect(
          () => TrackingWeb.removeFromStorage('non_existent'),
          returnsNormally,
        );
      });
    });

    group('integration scenarios', () {
      test('typical consent flow does not throw', () {
        // Simulate typical consent flow
        expect(() {
          TrackingWeb.initializeConsentMode();
          TrackingWeb.updateConsent(analytics: false, marketing: false);

          // User accepts analytics
          TrackingWeb.updateConsent(analytics: true, marketing: false);
          TrackingWeb.injectGTM();

          // Track page view
          TrackingWeb.sendPageView('/home', 'Home Page');
          TrackingWeb.sendEvent('page_view', {'page': 'home'});
        }, returnsNormally);
      });

      test('full marketing consent flow does not throw', () {
        expect(() {
          TrackingWeb.initializeConsentMode();
          TrackingWeb.updateConsent(analytics: true, marketing: true);

          TrackingWeb.injectGTM();
          TrackingWeb.injectFacebookPixel();

          TrackingWeb.sendPageView('/landing', 'Landing Page');
          TrackingWeb.sendFBPageView();

          TrackingWeb.sendEvent('cta_click', {'button': 'signup'});
          TrackingWeb.sendFBEvent('Lead', {'email': 'user@example.com'});
        }, returnsNormally);
      });

      test('storage operations in sequence do not throw', () {
        expect(() {
          TrackingWeb.setToStorage('consent', 'accepted');
          final value = TrackingWeb.getFromStorage('consent');
          expect(value, isNull); // Stub always returns null
          TrackingWeb.removeFromStorage('consent');
        }, returnsNormally);
      });
    });
  });
}
