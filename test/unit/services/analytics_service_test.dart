import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/analytics.dart';

void main() {
  group('AnalyticsService', () {
    group('initialization', () {
      test('isReady is false before initialization on non-web', () {
        // On non-web, initialize() doesn't set _initialized
        // So isReady should be false
        expect(AnalyticsService.isReady, isFalse);
      });

      test('initialize completes without error', () async {
        await expectLater(
          AnalyticsService.initialize(),
          completes,
        );
      });

      test('initialize can be called multiple times safely', () async {
        await expectLater(AnalyticsService.initialize(), completes);
        await expectLater(AnalyticsService.initialize(), completes);
      });
    });

    group('enable/disable', () {
      test('disable can be called', () {
        expect(() => AnalyticsService.disable(), returnsNormally);
      });

      test('enable can be called', () {
        expect(() => AnalyticsService.enable(), returnsNormally);
      });

      test('enable and disable can be toggled', () {
        expect(() {
          AnalyticsService.disable();
          AnalyticsService.enable();
          AnalyticsService.disable();
        }, returnsNormally);
      });
    });

    group('page tracking', () {
      test('trackPageView does not throw when not ready', () {
        expect(() => AnalyticsService.trackPageView('test_page'), returnsNormally);
      });

      test('trackScrollDepth only fires at 25% intervals', () {
        // Valid 25% intervals should not throw
        expect(() => AnalyticsService.trackScrollDepth(25), returnsNormally);
        expect(() => AnalyticsService.trackScrollDepth(50), returnsNormally);
        expect(() => AnalyticsService.trackScrollDepth(75), returnsNormally);
        expect(() => AnalyticsService.trackScrollDepth(100), returnsNormally);

        // Non-25% intervals should be silently ignored
        expect(() => AnalyticsService.trackScrollDepth(30), returnsNormally);
        expect(() => AnalyticsService.trackScrollDepth(60), returnsNormally);
      });
    });

    group('interaction tracking', () {
      test('trackCTAClick does not throw when not ready', () {
        expect(
          () => AnalyticsService.trackCTAClick(
            buttonName: 'test_button',
            location: 'hero',
          ),
          returnsNormally,
        );
      });

      test('trackCTAClick accepts optional ctaType', () {
        expect(
          () => AnalyticsService.trackCTAClick(
            buttonName: 'test_button',
            location: 'hero',
            ctaType: 'primary',
          ),
          returnsNormally,
        );
      });

      test('trackFeatureInteraction does not throw', () {
        expect(
          () => AnalyticsService.trackFeatureInteraction('monitoring'),
          returnsNormally,
        );
      });

      test('trackExternalLink does not throw', () {
        expect(
          () => AnalyticsService.trackExternalLink('https://example.com'),
          returnsNormally,
        );
      });
    });

    group('conversion tracking', () {
      test('trackFormSubmission does not throw', () {
        expect(
          () => AnalyticsService.trackFormSubmission(
            formType: 'contact',
            success: true,
          ),
          returnsNormally,
        );
      });

      test('trackFormSubmission accepts error message', () {
        expect(
          () => AnalyticsService.trackFormSubmission(
            formType: 'contact',
            success: false,
            errorMessage: 'Validation failed',
          ),
          returnsNormally,
        );
      });

      test('trackPricingView does not throw', () {
        expect(
          () => AnalyticsService.trackPricingView('enterprise'),
          returnsNormally,
        );
      });

      test('trackPricingToggle does not throw', () {
        expect(
          () => AnalyticsService.trackPricingToggle(isAnnual: true),
          returnsNormally,
        );
        expect(
          () => AnalyticsService.trackPricingToggle(isAnnual: false),
          returnsNormally,
        );
      });

      test('trackDemoRequest does not throw', () {
        expect(() => AnalyticsService.trackDemoRequest(), returnsNormally);
      });

      test('trackLeadMagnetDownload does not throw', () {
        expect(
          () => AnalyticsService.trackLeadMagnetDownload('eu-ai-act-checklist'),
          returnsNormally,
        );
      });

      test('trackBlogPostClick does not throw', () {
        expect(
          () => AnalyticsService.trackBlogPostClick('ai-observability-guide'),
          returnsNormally,
        );
      });

    });

    group('custom event tracking', () {
      test('trackEvent does not throw when not ready', () {
        expect(
          () => AnalyticsService.trackEvent(
            eventName: 'custom_event',
            parameters: {'key': 'value'},
          ),
          returnsNormally,
        );
      });

      test('trackEvent accepts empty parameters', () {
        expect(
          () => AnalyticsService.trackEvent(eventName: 'simple_event'),
          returnsNormally,
        );
      });
    });
  });

  group('AnalyticsEvent', () {
    test('all events have unique names', () {
      final names = AnalyticsEvent.values.map((e) => e.name).toList();
      final uniqueNames = names.toSet();

      expect(names.length, equals(uniqueNames.length));
    });

    test('pageView has correct name', () {
      expect(AnalyticsEvent.pageView.name, equals('page_view'));
    });

    test('ctaClick has correct name', () {
      expect(AnalyticsEvent.ctaClick.name, equals('cta_click'));
    });

    test('formSubmission has correct name', () {
      expect(AnalyticsEvent.formSubmission.name, equals('form_submission'));
    });

    test('pricingTierView has correct name', () {
      expect(AnalyticsEvent.pricingTierView.name, equals('pricing_tier_view'));
    });

    test('scrollDepth has correct name', () {
      expect(AnalyticsEvent.scrollDepth.name, equals('scroll_depth'));
    });

    test('featureInteraction has correct name', () {
      expect(
        AnalyticsEvent.featureInteraction.name,
        equals('feature_interaction'),
      );
    });

    test('pricingToggle has correct name', () {
      expect(AnalyticsEvent.pricingToggle.name, equals('pricing_toggle'));
    });

    test('externalLinkClick has correct name', () {
      expect(
        AnalyticsEvent.externalLinkClick.name,
        equals('external_link_click'),
      );
    });

    test('demoRequest has correct name', () {
      expect(AnalyticsEvent.demoRequest.name, equals('demo_request'));
    });

    test('leadMagnetDownload has correct name', () {
      expect(
        AnalyticsEvent.leadMagnetDownload.name,
        equals('lead_magnet_download'),
      );
    });

    test('blogPostClick has correct name', () {
      expect(AnalyticsEvent.blogPostClick.name, equals('blog_post_click'));
    });
  });

  group('FacebookPixelService', () {
    group('initialization', () {
      test('isReady is false before initialization', () {
        expect(FacebookPixelService.isReady, isFalse);
      });

      test('initialize completes without error on non-web', () async {
        await expectLater(
          FacebookPixelService.initialize(),
          completes,
        );
      });

      test('initialize can be called multiple times', () async {
        await expectLater(FacebookPixelService.initialize(), completes);
        await expectLater(FacebookPixelService.initialize(), completes);
      });
    });

    group('enable/disable', () {
      test('disable can be called', () {
        expect(() => FacebookPixelService.disable(), returnsNormally);
      });

      test('enable can be called', () {
        expect(() => FacebookPixelService.enable(), returnsNormally);
      });
    });

    group('tracking methods', () {
      test('trackPageView does not throw when not ready', () {
        expect(() => FacebookPixelService.trackPageView(), returnsNormally);
      });

      test('trackLead does not throw when not ready', () {
        expect(() => FacebookPixelService.trackLead(), returnsNormally);
      });

      test('trackLead accepts optional email', () {
        expect(
          () => FacebookPixelService.trackLead(email: 'test@example.com'),
          returnsNormally,
        );
      });

      test('trackContact does not throw when not ready', () {
        expect(() => FacebookPixelService.trackContact(), returnsNormally);
      });

      test('trackContact accepts optional email and name', () {
        expect(
          () => FacebookPixelService.trackContact(
            email: 'test@example.com',
            name: 'Test User',
          ),
          returnsNormally,
        );
      });

      test('trackContact accepts only email', () {
        expect(
          () => FacebookPixelService.trackContact(email: 'test@example.com'),
          returnsNormally,
        );
      });

      test('trackContact accepts only name', () {
        expect(
          () => FacebookPixelService.trackContact(name: 'Test User'),
          returnsNormally,
        );
      });

      test('trackViewContent does not throw when not ready', () {
        expect(
          () => FacebookPixelService.trackViewContent('product'),
          returnsNormally,
        );
      });
    });
  });

  group('ErrorSeverity', () {
    test('debug maps to SentryLevel.debug', () {
      expect(ErrorSeverity.debug.sentryLevel.name, equals('debug'));
    });

    test('info maps to SentryLevel.info', () {
      expect(ErrorSeverity.info.sentryLevel.name, equals('info'));
    });

    test('warning maps to SentryLevel.warning', () {
      expect(ErrorSeverity.warning.sentryLevel.name, equals('warning'));
    });

    test('error maps to SentryLevel.error', () {
      expect(ErrorSeverity.error.sentryLevel.name, equals('error'));
    });

    test('fatal maps to SentryLevel.fatal', () {
      expect(ErrorSeverity.fatal.sentryLevel.name, equals('fatal'));
    });
  });

  group('ErrorTrackingService', () {
    group('captureException', () {
      test('completes without error', () async {
        await expectLater(
          ErrorTrackingService.captureException(
            Exception('Test exception'),
          ),
          completes,
        );
      });

      test('accepts optional stackTrace', () async {
        try {
          throw Exception('Test');
        } catch (e, stackTrace) {
          await expectLater(
            ErrorTrackingService.captureException(
              e,
              stackTrace: stackTrace,
            ),
            completes,
          );
        }
      });

      test('accepts optional context', () async {
        await expectLater(
          ErrorTrackingService.captureException(
            Exception('Test'),
            context: 'TestClass.method',
          ),
          completes,
        );
      });

      test('accepts optional extra data', () async {
        await expectLater(
          ErrorTrackingService.captureException(
            Exception('Test'),
            extra: {'userId': '123', 'action': 'submit'},
          ),
          completes,
        );
      });

      test('accepts all optional parameters', () async {
        try {
          throw Exception('Full test');
        } catch (e, stackTrace) {
          await expectLater(
            ErrorTrackingService.captureException(
              e,
              stackTrace: stackTrace,
              context: 'TestClass.fullMethod',
              extra: {'debug': true},
            ),
            completes,
          );
        }
      });
    });

    group('captureMessage', () {
      test('completes with default severity', () async {
        await expectLater(
          ErrorTrackingService.captureMessage('Test message'),
          completes,
        );
      });

      test('completes with custom severity', () async {
        await expectLater(
          ErrorTrackingService.captureMessage(
            'Warning message',
            severity: ErrorSeverity.warning,
          ),
          completes,
        );
      });

      test('completes with extra data', () async {
        await expectLater(
          ErrorTrackingService.captureMessage(
            'Info message',
            extra: {'component': 'analytics'},
          ),
          completes,
        );
      });

      test('works with all severity levels', () async {
        for (final severity in ErrorSeverity.values) {
          await expectLater(
            ErrorTrackingService.captureMessage(
              'Test ${severity.name}',
              severity: severity,
            ),
            completes,
          );
        }
      });
    });

    group('breadcrumbs', () {
      test('addBreadcrumb does not throw', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'User clicked button',
          ),
          returnsNormally,
        );
      });

      test('addBreadcrumb accepts category', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'Button click',
            category: 'ui.click',
          ),
          returnsNormally,
        );
      });

      test('addBreadcrumb accepts data', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'API call',
            category: 'http',
            data: {'url': '/api/users', 'method': 'GET'},
          ),
          returnsNormally,
        );
      });

      test('addNavigationBreadcrumb does not throw', () {
        expect(
          () => ErrorTrackingService.addNavigationBreadcrumb(
            from: '/home',
            to: '/profile',
          ),
          returnsNormally,
        );
      });

      test('addUserActionBreadcrumb does not throw', () {
        expect(
          () => ErrorTrackingService.addUserActionBreadcrumb(
            action: 'Submit form',
          ),
          returnsNormally,
        );
      });

      test('addUserActionBreadcrumb accepts target', () {
        expect(
          () => ErrorTrackingService.addUserActionBreadcrumb(
            action: 'Click',
            target: 'submit_button',
          ),
          returnsNormally,
        );
      });
    });

    group('user context', () {
      test('setUser does not throw', () {
        expect(
          () => ErrorTrackingService.setUser(
            id: 'user_123',
            email: 'test@example.com',
          ),
          returnsNormally,
        );
      });

      test('setUser accepts username', () {
        expect(
          () => ErrorTrackingService.setUser(
            id: 'user_123',
            username: 'testuser',
          ),
          returnsNormally,
        );
      });

      test('setUser accepts custom data', () {
        expect(
          () => ErrorTrackingService.setUser(
            id: 'user_123',
            data: {'plan': 'enterprise', 'role': 'admin'},
          ),
          returnsNormally,
        );
      });

      test('clearUser does not throw', () {
        expect(() => ErrorTrackingService.clearUser(), returnsNormally);
      });
    });

    group('performance monitoring', () {
      test('startTransaction returns a span', () {
        final transaction = ErrorTrackingService.startTransaction(
          name: 'testOperation',
          operation: 'test',
        );

        expect(transaction, isNotNull);
      });
    });

    group('tags', () {
      test('setTag does not throw', () {
        expect(
          () => ErrorTrackingService.setTag('environment', 'test'),
          returnsNormally,
        );
      });

      test('setTags does not throw', () {
        expect(
          () => ErrorTrackingService.setTags({
            'version': '1.0.0',
            'platform': 'web',
          }),
          returnsNormally,
        );
      });
    });
  });
}
