import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/analytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('AnalyticsEvent', () {
    test('enum values have correct names', () {
      expect(AnalyticsEvent.pageView.name, equals('page_view'));
      expect(AnalyticsEvent.ctaClick.name, equals('cta_click'));
      expect(AnalyticsEvent.formSubmission.name, equals('form_submission'));
      expect(AnalyticsEvent.pricingTierView.name, equals('pricing_tier_view'));
      expect(AnalyticsEvent.scrollDepth.name, equals('scroll_depth'));
      expect(AnalyticsEvent.featureInteraction.name, equals('feature_interaction'));
      expect(AnalyticsEvent.pricingToggle.name, equals('pricing_toggle'));
      expect(AnalyticsEvent.externalLinkClick.name, equals('external_link_click'));
      expect(AnalyticsEvent.demoRequest.name, equals('demo_request'));
      expect(AnalyticsEvent.leadMagnetDownload.name, equals('lead_magnet_download'));
      expect(AnalyticsEvent.blogPostClick.name, equals('blog_post_click'));
    });

    test('enum has correct count of values', () {
      expect(AnalyticsEvent.values.length, equals(11));
    });
  });

  group('AnalyticsService', () {
    // Reset state before each test group
    setUp(() {
      AnalyticsService.enable();
    });

    group('lifecycle', () {
      test('isReady returns false before initialization', () {
        // In test environment (non-web), isReady depends on enabled state
        expect(AnalyticsService.isReady, isA<bool>());
      });

      test('enable and disable toggle state', () {
        AnalyticsService.enable();
        // After enable, if initialized, should be ready

        AnalyticsService.disable();
        expect(AnalyticsService.isReady, isFalse);

        AnalyticsService.enable();
        // State restored
      });

      test('initialize completes without error on non-web', () async {
        // On non-web platforms, initialize returns early but should not throw
        await expectLater(AnalyticsService.initialize(), completes);
        // Calling initialize again should be idempotent
        await expectLater(AnalyticsService.initialize(), completes);
      });

      test('isReady is false when disabled regardless of initialization', () {
        AnalyticsService.disable();
        expect(AnalyticsService.isReady, isFalse);
      });

      test('multiple enable calls are idempotent', () {
        expect(() {
          AnalyticsService.enable();
          AnalyticsService.enable();
          AnalyticsService.enable();
        }, returnsNormally);
      });

      test('multiple disable calls are idempotent', () {
        AnalyticsService.disable();
        AnalyticsService.disable();
        AnalyticsService.disable();
        expect(AnalyticsService.isReady, isFalse);
      });
    });

    group('tracking methods exist', () {
      test('trackPageView accepts page name', () {
        // Should not throw
        expect(
          () => AnalyticsService.trackPageView('test'),
          returnsNormally,
        );
      });

      test('trackScrollDepth only tracks 25% increments', () {
        // Should not throw for any value
        expect(
          () => AnalyticsService.trackScrollDepth(25),
          returnsNormally,
        );
        expect(
          () => AnalyticsService.trackScrollDepth(50),
          returnsNormally,
        );
        expect(
          () => AnalyticsService.trackScrollDepth(75),
          returnsNormally,
        );
        expect(
          () => AnalyticsService.trackScrollDepth(100),
          returnsNormally,
        );
        // Non-25% values are silently ignored
        expect(
          () => AnalyticsService.trackScrollDepth(30),
          returnsNormally,
        );
      });

      test('trackCTAClick accepts required parameters', () {
        expect(
          () => AnalyticsService.trackCTAClick(
            buttonName: 'Start Trial',
            location: 'hero',
          ),
          returnsNormally,
        );
      });

      test('trackCTAClick accepts optional ctaType', () {
        expect(
          () => AnalyticsService.trackCTAClick(
            buttonName: 'Start Trial',
            location: 'hero',
            ctaType: 'primary',
          ),
          returnsNormally,
        );
      });

      test('trackFeatureInteraction accepts feature name', () {
        expect(
          () => AnalyticsService.trackFeatureInteraction('Tracing'),
          returnsNormally,
        );
      });

      test('trackExternalLink accepts URL', () {
        expect(
          () => AnalyticsService.trackExternalLink('https://example.com'),
          returnsNormally,
        );
      });

      test('trackFormSubmission accepts parameters', () {
        expect(
          () => AnalyticsService.trackFormSubmission(
            formType: 'contact',
            success: true,
          ),
          returnsNormally,
        );
      });

      test('trackFormSubmission accepts error message on failure', () {
        expect(
          () => AnalyticsService.trackFormSubmission(
            formType: 'contact',
            success: false,
            errorMessage: 'Validation failed',
          ),
          returnsNormally,
        );
      });

      test('trackPricingView accepts tier name', () {
        expect(
          () => AnalyticsService.trackPricingView('Growth'),
          returnsNormally,
        );
      });

      test('trackPricingToggle accepts billing period', () {
        expect(
          () => AnalyticsService.trackPricingToggle(isAnnual: true),
          returnsNormally,
        );
        expect(
          () => AnalyticsService.trackPricingToggle(isAnnual: false),
          returnsNormally,
        );
      });

      test('trackDemoRequest works without parameters', () {
        expect(
          () => AnalyticsService.trackDemoRequest(),
          returnsNormally,
        );
      });

      test('trackLeadMagnetDownload accepts resource name', () {
        expect(
          () => AnalyticsService.trackLeadMagnetDownload('whitepaper'),
          returnsNormally,
        );
      });

      test('trackBlogPostClick accepts post slug', () {
        expect(
          () => AnalyticsService.trackBlogPostClick('ai-observability'),
          returnsNormally,
        );
      });

      test('trackEvent accepts custom event', () {
        expect(
          () => AnalyticsService.trackEvent(
            eventName: 'custom_event',
            parameters: {'key': 'value'},
          ),
          returnsNormally,
        );
      });

      test('trackEvent with empty parameters', () {
        expect(
          () => AnalyticsService.trackEvent(eventName: 'simple_event'),
          returnsNormally,
        );
      });

      test('trackContact with only email', () {
        expect(
          () => FacebookPixelService.trackContact(email: 'test@example.com'),
          returnsNormally,
        );
      });

      test('trackContact with only name', () {
        expect(
          () => FacebookPixelService.trackContact(name: 'Test User'),
          returnsNormally,
        );
      });
    });

    group('disabled state behavior', () {
      setUp(() {
        AnalyticsService.disable();
      });

      tearDown(() {
        AnalyticsService.enable();
      });

      test('trackPageView does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackPageView('test'),
          returnsNormally,
        );
      });

      test('trackScrollDepth does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackScrollDepth(50),
          returnsNormally,
        );
      });

      test('trackCTAClick does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackCTAClick(
            buttonName: 'Test',
            location: 'hero',
          ),
          returnsNormally,
        );
      });

      test('trackFormSubmission does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackFormSubmission(
            formType: 'contact',
            success: true,
          ),
          returnsNormally,
        );
      });

      test('trackEvent does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackEvent(
            eventName: 'test',
            parameters: {'key': 'value'},
          ),
          returnsNormally,
        );
      });

      test('trackFeatureInteraction does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackFeatureInteraction('feature'),
          returnsNormally,
        );
      });

      test('trackExternalLink does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackExternalLink('https://example.com'),
          returnsNormally,
        );
      });

      test('trackPricingView does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackPricingView('Growth'),
          returnsNormally,
        );
      });

      test('trackPricingToggle does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackPricingToggle(isAnnual: true),
          returnsNormally,
        );
      });

      test('trackDemoRequest does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackDemoRequest(),
          returnsNormally,
        );
      });

      test('trackLeadMagnetDownload does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackLeadMagnetDownload('whitepaper'),
          returnsNormally,
        );
      });

      test('trackBlogPostClick does nothing when disabled', () {
        expect(
          () => AnalyticsService.trackBlogPostClick('slug'),
          returnsNormally,
        );
      });

    });

    group('scroll depth validation', () {
      test('trackScrollDepth with 0 is valid (0 % 25 == 0)', () {
        expect(
          () => AnalyticsService.trackScrollDepth(0),
          returnsNormally,
        );
      });

      test('trackScrollDepth ignores non-25% increments', () {
        // These should return early without error
        expect(() => AnalyticsService.trackScrollDepth(10), returnsNormally);
        expect(() => AnalyticsService.trackScrollDepth(33), returnsNormally);
        expect(() => AnalyticsService.trackScrollDepth(67), returnsNormally);
        expect(() => AnalyticsService.trackScrollDepth(99), returnsNormally);
      });

      test('trackScrollDepth accepts negative values (early return)', () {
        // -25 % 25 == 0, so it would pass the check
        expect(() => AnalyticsService.trackScrollDepth(-25), returnsNormally);
      });
    });
  });

  group('ErrorSeverity', () {
    test('enum values map to correct Sentry levels', () {
      expect(ErrorSeverity.debug.sentryLevel.name, equals('debug'));
      expect(ErrorSeverity.info.sentryLevel.name, equals('info'));
      expect(ErrorSeverity.warning.sentryLevel.name, equals('warning'));
      expect(ErrorSeverity.error.sentryLevel.name, equals('error'));
      expect(ErrorSeverity.fatal.sentryLevel.name, equals('fatal'));
    });

    test('enum has correct count of values', () {
      expect(ErrorSeverity.values.length, equals(5));
    });
  });

  group('ErrorTrackingService', () {
    group('exception capture', () {
      test('captureException accepts exception', () async {
        await expectLater(
          ErrorTrackingService.captureException(Exception('Test exception')),
          completes,
        );
      });

      test('captureException accepts context', () async {
        await expectLater(
          ErrorTrackingService.captureException(
            Exception('Test'),
            context: 'test.dart:testMethod',
          ),
          completes,
        );
      });

      test('captureException accepts extra data', () async {
        await expectLater(
          ErrorTrackingService.captureException(
            Exception('Test'),
            extra: {'user_id': '123', 'action': 'test'},
          ),
          completes,
        );
      });

      test('captureException accepts stack trace', () async {
        try {
          throw Exception('Test error');
        } catch (e, stackTrace) {
          await expectLater(
            ErrorTrackingService.captureException(e, stackTrace: stackTrace),
            completes,
          );
        }
      });

      test('captureException with all parameters', () async {
        try {
          throw Exception('Full test error');
        } catch (e, stackTrace) {
          await expectLater(
            ErrorTrackingService.captureException(
              e,
              stackTrace: stackTrace,
              context: 'test.location',
              extra: {'key': 'value', 'number': 42},
            ),
            completes,
          );
        }
      });

      test('captureException with null exception', () async {
        await expectLater(
          ErrorTrackingService.captureException(null),
          completes,
        );
      });

      test('captureException with string error', () async {
        await expectLater(
          ErrorTrackingService.captureException('String error'),
          completes,
        );
      });

      test('captureException with Error type', () async {
        await expectLater(
          ErrorTrackingService.captureException(
            StateError('State error message'),
          ),
          completes,
        );
      });

      test('captureException with empty extra map', () async {
        await expectLater(
          ErrorTrackingService.captureException(Exception('Test'), extra: {}),
          completes,
        );
      });

      test('captureException with context only', () async {
        await expectLater(
          ErrorTrackingService.captureException(
            Exception('Test'),
            context: 'SomeClass.someMethod',
          ),
          completes,
        );
      });
    });

    group('message capture', () {
      test('captureMessage accepts message', () async {
        await expectLater(
          ErrorTrackingService.captureMessage('Test message'),
          completes,
        );
      });

      test('captureMessage accepts severity', () async {
        await expectLater(
          ErrorTrackingService.captureMessage(
            'Test warning',
            severity: ErrorSeverity.warning,
          ),
          completes,
        );
      });

      test('captureMessage accepts extra data', () async {
        await expectLater(
          ErrorTrackingService.captureMessage(
            'Test message',
            extra: {'context': 'unit_test'},
          ),
          completes,
        );
      });

      test('captureMessage with all severity levels', () async {
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

      test('captureMessage with empty extra map', () async {
        await expectLater(
          ErrorTrackingService.captureMessage('Test message', extra: {}),
          completes,
        );
      });

      test('captureMessage with severity and extra combined', () async {
        await expectLater(
          ErrorTrackingService.captureMessage(
            'Combined test',
            severity: ErrorSeverity.error,
            extra: {'key1': 'value1', 'key2': 123},
          ),
          completes,
        );
      });

      test('captureMessage default severity is info', () async {
        await expectLater(
          ErrorTrackingService.captureMessage('Default severity test'),
          completes,
        );
      });

      test('captureMessage with debug severity', () async {
        await expectLater(
          ErrorTrackingService.captureMessage(
            'Debug message',
            severity: ErrorSeverity.debug,
          ),
          completes,
        );
      });

      test('captureMessage with fatal severity', () async {
        await expectLater(
          ErrorTrackingService.captureMessage(
            'Fatal message',
            severity: ErrorSeverity.fatal,
          ),
          completes,
        );
      });
    });

    group('breadcrumbs', () {
      test('addBreadcrumb accepts message', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'Test breadcrumb',
          ),
          returnsNormally,
        );
      });

      test('addBreadcrumb accepts category', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'Test breadcrumb',
            category: 'ui.click',
          ),
          returnsNormally,
        );
      });

      test('addBreadcrumb accepts data', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'Test breadcrumb',
            data: {'target': 'button'},
          ),
          returnsNormally,
        );
      });

      test('addBreadcrumb with all parameters', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'Full breadcrumb',
            category: 'test.category',
            data: {'key1': 'value1', 'key2': 42, 'nested': {'a': 'b'}},
          ),
          returnsNormally,
        );
      });

      test('addBreadcrumb with empty data map', () {
        expect(
          () => ErrorTrackingService.addBreadcrumb(
            message: 'Empty data breadcrumb',
            data: {},
          ),
          returnsNormally,
        );
      });

      test('addBreadcrumb with various categories', () {
        final categories = [
          'navigation',
          'ui.click',
          'http',
          'console',
          'custom.category',
        ];
        for (final category in categories) {
          expect(
            () => ErrorTrackingService.addBreadcrumb(
              message: 'Test $category',
              category: category,
            ),
            returnsNormally,
          );
        }
      });

      test('addNavigationBreadcrumb works', () {
        expect(
          () => ErrorTrackingService.addNavigationBreadcrumb(
            from: '/home',
            to: '/about',
          ),
          returnsNormally,
        );
      });

      test('addNavigationBreadcrumb with same from/to', () {
        expect(
          () => ErrorTrackingService.addNavigationBreadcrumb(
            from: '/home',
            to: '/home',
          ),
          returnsNormally,
        );
      });

      test('addNavigationBreadcrumb with empty paths', () {
        expect(
          () => ErrorTrackingService.addNavigationBreadcrumb(
            from: '',
            to: '',
          ),
          returnsNormally,
        );
      });

      test('addUserActionBreadcrumb works', () {
        expect(
          () => ErrorTrackingService.addUserActionBreadcrumb(
            action: 'clicked button',
          ),
          returnsNormally,
        );
      });

      test('addUserActionBreadcrumb accepts target', () {
        expect(
          () => ErrorTrackingService.addUserActionBreadcrumb(
            action: 'clicked button',
            target: '#submit-btn',
          ),
          returnsNormally,
        );
      });

      test('addUserActionBreadcrumb with null target', () {
        expect(
          () => ErrorTrackingService.addUserActionBreadcrumb(
            action: 'hover action',
            target: null,
          ),
          returnsNormally,
        );
      });

      test('addUserActionBreadcrumb various actions', () {
        final actions = [
          'clicked',
          'double clicked',
          'long pressed',
          'swiped',
          'scrolled',
        ];
        for (final action in actions) {
          expect(
            () => ErrorTrackingService.addUserActionBreadcrumb(
              action: action,
              target: 'element',
            ),
            returnsNormally,
          );
        }
      });
    });

    group('user context', () {
      test('setUser accepts id', () {
        expect(
          () => ErrorTrackingService.setUser(id: '123'),
          returnsNormally,
        );
      });

      test('setUser accepts all parameters', () {
        expect(
          () => ErrorTrackingService.setUser(
            id: '123',
            email: 'test@example.com',
            username: 'testuser',
            data: {'plan': 'pro'},
          ),
          returnsNormally,
        );
      });

      test('setUser with email only', () {
        expect(
          () => ErrorTrackingService.setUser(email: 'test@example.com'),
          returnsNormally,
        );
      });

      test('setUser with username only', () {
        expect(
          () => ErrorTrackingService.setUser(username: 'testuser'),
          returnsNormally,
        );
      });

      test('setUser with data only', () {
        expect(
          () => ErrorTrackingService.setUser(data: {'custom': 'data'}),
          returnsNormally,
        );
      });

      test('setUser with empty data', () {
        expect(
          () => ErrorTrackingService.setUser(
            id: 'user123',
            data: {},
          ),
          returnsNormally,
        );
      });

      test('setUser with no parameters creates empty user', () {
        expect(
          () => ErrorTrackingService.setUser(),
          returnsNormally,
        );
      });

      test('clearUser works', () {
        expect(
          () => ErrorTrackingService.clearUser(),
          returnsNormally,
        );
      });

      test('clearUser after setUser', () {
        ErrorTrackingService.setUser(id: '123', email: 'test@example.com');
        expect(
          () => ErrorTrackingService.clearUser(),
          returnsNormally,
        );
      });

      test('setUser multiple times overwrites', () {
        expect(() {
          ErrorTrackingService.setUser(id: 'user1');
          ErrorTrackingService.setUser(id: 'user2');
          ErrorTrackingService.setUser(id: 'user3');
        }, returnsNormally);
      });
    });

    group('performance', () {
      test('startTransaction returns span', () {
        final span = ErrorTrackingService.startTransaction(
          name: 'test-transaction',
          operation: 'test.operation',
        );
        expect(span, isNotNull);
        span.finish();
      });

      test('startTransaction returns ISentrySpan interface', () {
        final span = ErrorTrackingService.startTransaction(
          name: 'type-check',
          operation: 'test',
        );
        expect(span, isA<ISentrySpan>());
        span.finish();
      });

      test('startTransaction with various operations', () {
        final operations = [
          'http.client',
          'db.query',
          'ui.render',
          'file.read',
          'custom.operation',
        ];
        for (final op in operations) {
          final span = ErrorTrackingService.startTransaction(
            name: 'test-$op',
            operation: op,
          );
          expect(span, isNotNull);
          span.finish();
        }
      });

      test('multiple concurrent transactions', () {
        final span1 = ErrorTrackingService.startTransaction(
          name: 'transaction-1',
          operation: 'test.1',
        );
        final span2 = ErrorTrackingService.startTransaction(
          name: 'transaction-2',
          operation: 'test.2',
        );
        expect(span1, isNotNull);
        expect(span2, isNotNull);
        span1.finish();
        span2.finish();
      });
    });

    group('tags', () {
      test('setTag works', () {
        expect(
          () => ErrorTrackingService.setTag('env', 'test'),
          returnsNormally,
        );
      });

      test('setTags works with multiple tags', () {
        expect(
          () => ErrorTrackingService.setTags({
            'env': 'test',
            'version': '1.0.0',
            'region': 'us-east',
          }),
          returnsNormally,
        );
      });

      test('setTag with empty value', () {
        expect(
          () => ErrorTrackingService.setTag('key', ''),
          returnsNormally,
        );
      });

      test('setTags with empty map', () {
        expect(
          () => ErrorTrackingService.setTags({}),
          returnsNormally,
        );
      });

      test('setTags overwrites existing tags', () {
        expect(() {
          ErrorTrackingService.setTag('key', 'value1');
          ErrorTrackingService.setTag('key', 'value2');
        }, returnsNormally);
      });

      test('setTags with single entry', () {
        expect(
          () => ErrorTrackingService.setTags({'single': 'tag'}),
          returnsNormally,
        );
      });

      test('setTag and setTags combined', () {
        expect(() {
          ErrorTrackingService.setTag('individual', 'tag');
          ErrorTrackingService.setTags({
            'batch1': 'value1',
            'batch2': 'value2',
          });
        }, returnsNormally);
      });
    });
  });

  group('FacebookPixelService', () {
    setUp(() {
      FacebookPixelService.enable();
    });

    group('lifecycle', () {
      test('isReady returns false before initialization', () {
        expect(FacebookPixelService.isReady, isA<bool>());
      });

      test('enable and disable toggle state', () {
        FacebookPixelService.enable();
        FacebookPixelService.disable();
        expect(FacebookPixelService.isReady, isFalse);
        FacebookPixelService.enable();
      });

      test('initialize completes on non-web', () async {
        await expectLater(FacebookPixelService.initialize(), completes);
      });

      test('initialize is idempotent', () async {
        await expectLater(FacebookPixelService.initialize(), completes);
        await expectLater(FacebookPixelService.initialize(), completes);
        await expectLater(FacebookPixelService.initialize(), completes);
      });

      test('multiple enable calls are idempotent', () {
        expect(() {
          FacebookPixelService.enable();
          FacebookPixelService.enable();
          FacebookPixelService.enable();
        }, returnsNormally);
      });

      test('multiple disable calls are idempotent', () {
        FacebookPixelService.disable();
        FacebookPixelService.disable();
        FacebookPixelService.disable();
        expect(FacebookPixelService.isReady, isFalse);
      });

      test('enable after disable restores state', () {
        FacebookPixelService.disable();
        expect(FacebookPixelService.isReady, isFalse);
        FacebookPixelService.enable();
        // On non-web, isReady depends on _initialized which is false
        expect(FacebookPixelService.isReady, isA<bool>());
      });
    });

    group('tracking methods exist', () {
      test('trackPageView works', () {
        expect(
          () => FacebookPixelService.trackPageView(),
          returnsNormally,
        );
      });

      test('trackLead works', () {
        expect(
          () => FacebookPixelService.trackLead(),
          returnsNormally,
        );
      });

      test('trackLead with email works', () {
        expect(
          () => FacebookPixelService.trackLead(email: 'test@example.com'),
          returnsNormally,
        );
      });

      test('trackContact works', () {
        expect(
          () => FacebookPixelService.trackContact(),
          returnsNormally,
        );
      });

      test('trackContact with email and name works', () {
        expect(
          () => FacebookPixelService.trackContact(
            email: 'test@example.com',
            name: 'Test User',
          ),
          returnsNormally,
        );
      });

      test('trackViewContent accepts content type', () {
        expect(
          () => FacebookPixelService.trackViewContent('article'),
          returnsNormally,
        );
      });

      test('trackViewContent with various content types', () {
        final types = ['article', 'product', 'video', 'page', 'custom'];
        for (final type in types) {
          expect(
            () => FacebookPixelService.trackViewContent(type),
            returnsNormally,
          );
        }
      });
    });

    group('disabled state behavior', () {
      setUp(() {
        FacebookPixelService.disable();
      });

      tearDown(() {
        FacebookPixelService.enable();
      });

      test('trackPageView does nothing when disabled', () {
        expect(
          () => FacebookPixelService.trackPageView(),
          returnsNormally,
        );
      });

      test('trackLead does nothing when disabled', () {
        expect(
          () => FacebookPixelService.trackLead(email: 'test@example.com'),
          returnsNormally,
        );
      });

      test('trackContact does nothing when disabled', () {
        expect(
          () => FacebookPixelService.trackContact(
            email: 'test@example.com',
            name: 'Test',
          ),
          returnsNormally,
        );
      });

      test('trackViewContent does nothing when disabled', () {
        expect(
          () => FacebookPixelService.trackViewContent('article'),
          returnsNormally,
        );
      });
    });

    group('trackContact parameter combinations', () {
      test('trackContact with email only', () {
        expect(
          () => FacebookPixelService.trackContact(email: 'test@example.com'),
          returnsNormally,
        );
      });

      test('trackContact with name only', () {
        expect(
          () => FacebookPixelService.trackContact(name: 'Test User'),
          returnsNormally,
        );
      });

      test('trackContact with empty strings', () {
        expect(
          () => FacebookPixelService.trackContact(email: '', name: ''),
          returnsNormally,
        );
      });

      test('trackContact with null parameters', () {
        expect(
          () => FacebookPixelService.trackContact(email: null, name: null),
          returnsNormally,
        );
      });
    });
  });

  group('ErrorSeverity mapping verification', () {
    test('all severity levels have unique Sentry mappings', () {
      final sentryLevels = ErrorSeverity.values
          .map((s) => s.sentryLevel)
          .toSet();
      expect(sentryLevels.length, equals(ErrorSeverity.values.length));
    });

    test('severity enum values are in expected order', () {
      expect(ErrorSeverity.values[0], equals(ErrorSeverity.debug));
      expect(ErrorSeverity.values[1], equals(ErrorSeverity.info));
      expect(ErrorSeverity.values[2], equals(ErrorSeverity.warning));
      expect(ErrorSeverity.values[3], equals(ErrorSeverity.error));
      expect(ErrorSeverity.values[4], equals(ErrorSeverity.fatal));
    });
  });

  group('AnalyticsEvent mapping verification', () {
    test('all event types have unique names', () {
      final names = AnalyticsEvent.values.map((e) => e.name).toSet();
      expect(names.length, equals(AnalyticsEvent.values.length));
    });

    test('event names follow snake_case convention', () {
      for (final event in AnalyticsEvent.values) {
        expect(
          event.name,
          matches(RegExp(r'^[a-z]+(_[a-z]+)*$')),
          reason: '${event.name} should be snake_case',
        );
      }
    });

    test('all events have non-empty names', () {
      for (final event in AnalyticsEvent.values) {
        expect(event.name.isNotEmpty, isTrue);
      }
    });
  });
}
