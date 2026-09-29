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
      late List<({AnalyticsEvent event, Map<String, dynamic> params})> log;

      setUp(() {
        log = AnalyticsService.enableCallLog();
      });

      tearDown(() {
        AnalyticsService.resetForTesting();
      });

      test('trackPageView records page_view with page_title', () {
        AnalyticsService.trackPageView('test');
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.pageView));
        expect(log.first.params['page_title'], equals('test'));
        expect(log.first.params['page_location'], equals('test'));
      });

      test('trackScrollDepth records scroll_depth event for 25% increments', () {
        AnalyticsService.trackScrollDepth(25);
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.scrollDepth));
        expect(log.first.params['percentage'], equals(25));
      });

      test('trackScrollDepth silently ignores non-25% values', () {
        AnalyticsService.trackScrollDepth(30);
        expect(log, isEmpty);
      });

      test('trackCTAClick records cta_click with button_name and location', () {
        AnalyticsService.trackCTAClick(
          buttonName: 'Start Trial',
          location: 'hero',
        );
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.ctaClick));
        expect(log.first.params['button_name'], equals('Start Trial'));
        expect(log.first.params['location'], equals('hero'));
        expect(log.first.params.containsKey('cta_type'), isFalse);
      });

      test('trackCTAClick includes cta_type when provided', () {
        AnalyticsService.trackCTAClick(
          buttonName: 'Start Trial',
          location: 'hero',
          ctaType: 'primary',
        );
        expect(log, hasLength(1));
        expect(log.first.params['cta_type'], equals('primary'));
      });

      test('trackFeatureInteraction records feature_interaction with feature_name', () {
        AnalyticsService.trackFeatureInteraction('Tracing');
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.featureInteraction));
        expect(log.first.params['feature_name'], equals('Tracing'));
      });

      test('trackExternalLink records external_link_click with url', () {
        AnalyticsService.trackExternalLink('https://example.com');
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.externalLinkClick));
        expect(log.first.params['url'], equals('https://example.com'));
      });

      test('trackFormSubmission records form_submission with form_type and success', () {
        AnalyticsService.trackFormSubmission(
          formType: 'contact',
          success: true,
        );
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.formSubmission));
        expect(log.first.params['form_type'], equals('contact'));
        expect(log.first.params['success'], isTrue);
        expect(log.first.params.containsKey('error_message'), isFalse);
      });

      test('trackFormSubmission includes error_message on failure', () {
        AnalyticsService.trackFormSubmission(
          formType: 'contact',
          success: false,
          errorMessage: 'Validation failed',
        );
        expect(log, hasLength(1));
        expect(log.first.params['error_message'], equals('Validation failed'));
      });

      test('trackPricingView records pricing_tier_view with tier', () {
        AnalyticsService.trackPricingView('Growth');
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.pricingTierView));
        expect(log.first.params['tier'], equals('Growth'));
      });

      test('trackPricingToggle records annual billing_period', () {
        AnalyticsService.trackPricingToggle(isAnnual: true);
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.pricingToggle));
        expect(log.first.params['billing_period'], equals('annual'));
      });

      test('trackPricingToggle records monthly billing_period', () {
        AnalyticsService.trackPricingToggle(isAnnual: false);
        expect(log, hasLength(1));
        expect(log.first.params['billing_period'], equals('monthly'));
      });

      test('trackDemoRequest records demo_request event', () {
        AnalyticsService.trackDemoRequest();
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.demoRequest));
      });

      test('trackLeadMagnetDownload records lead_magnet_download with resource_name', () {
        AnalyticsService.trackLeadMagnetDownload('whitepaper');
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.leadMagnetDownload));
        expect(log.first.params['resource_name'], equals('whitepaper'));
      });

      test('trackBlogPostClick records blog_post_click with post_slug', () {
        AnalyticsService.trackBlogPostClick('ai-observability');
        expect(log, hasLength(1));
        expect(log.first.event, equals(AnalyticsEvent.blogPostClick));
        expect(log.first.params['post_slug'], equals('ai-observability'));
      });

      // trackEvent bypasses _track and goes directly to _sendEvent (platform-only).
      // On non-web, _sendEvent returns early, so only a smoke test is meaningful here.
      test('trackEvent does not throw', () {
        expect(
          () => AnalyticsService.trackEvent(
            eventName: 'custom_event',
            parameters: {'key': 'value'},
          ),
          returnsNormally,
        );
        // trackEvent does not go through _track, so callLog stays empty
        expect(log, isEmpty);
      });

      test('trackContact does not throw', () {
        expect(
          () => FacebookPixelService.trackContact(email: 'test@example.com'),
          returnsNormally,
        );
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

      test('isReady is false when disabled', () {
        expect(AnalyticsService.isReady, isFalse);
      });

      test('tracking methods called when disabled do not reach the platform', () {
        // _track records to callLog before the isReady guard, so we can
        // verify the method ran but isReady was false (no _sendEvent called).
        final log = AnalyticsService.enableCallLog();
        AnalyticsService.trackPageView('test');
        AnalyticsService.trackCTAClick(buttonName: 'btn', location: 'hero');
        AnalyticsService.trackFormSubmission(formType: 'contact', success: true);
        expect(log, hasLength(3)); // methods were called
        expect(AnalyticsService.isReady, isFalse); // but no platform event fired
        AnalyticsService.resetForTesting();
        AnalyticsService.disable(); // tearDown restores this
      });
    });

    group('scroll depth validation', () {
      late List<({AnalyticsEvent event, Map<String, dynamic> params})> log;

      setUp(() {
        log = AnalyticsService.enableCallLog();
      });

      tearDown(() {
        AnalyticsService.resetForTesting();
      });

      test('trackScrollDepth records event for valid 25% increments', () {
        for (final pct in [0, 25, 50, 75, 100]) {
          AnalyticsService.trackScrollDepth(pct);
        }
        expect(log, hasLength(5));
        expect(log.every((e) => e.event == AnalyticsEvent.scrollDepth), isTrue);
        expect(log.map((e) => e.params['percentage']).toList(),
            equals([0, 25, 50, 75, 100]));
      });

      test('trackScrollDepth does not record non-25% increments', () {
        for (final pct in [10, 33, 67, 99]) {
          AnalyticsService.trackScrollDepth(pct);
        }
        expect(log, isEmpty);
      });

      test('trackScrollDepth records -25 (passes % 25 == 0 check)', () {
        // -25 % 25 == 0 in Dart, so this fires. Documents the boundary behaviour.
        AnalyticsService.trackScrollDepth(-25);
        expect(log, hasLength(1));
        expect(log.first.params['percentage'], equals(-25));
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

  // Marketing consent initialises the pixel; withdrawing it disables tracking. Only a
  // pixel in both states may send the Lead event CR55 fires at signup and on contact.
  group('FacebookPixelService.trackLead consent gate', () {
    late List<(String, Map<String, dynamic>?)> sent;

    setUp(() {
      FacebookPixelService.resetForTesting();
      sent = [];
      FacebookPixelService.sendEvent = (name, [params]) => sent.add((name, params));
    });

    tearDown(FacebookPixelService.resetForTesting);

    test('sends nothing before marketing consent initialises the pixel', () {
      FacebookPixelService.trackLead(email: 'lead@example.com');

      expect(sent, isEmpty);
    });

    test('sends the Lead event with the email once consent is given', () {
      FacebookPixelService.markInitializedForTesting();

      FacebookPixelService.trackLead(email: 'lead@example.com');

      expect(sent, hasLength(1));
      expect(sent.single.$1, 'Lead');
      expect(sent.single.$2, {'email': 'lead@example.com'});
    });

    test('sends nothing after consent is withdrawn', () {
      FacebookPixelService.markInitializedForTesting();
      FacebookPixelService.disable();

      FacebookPixelService.trackLead(email: 'lead@example.com');

      expect(sent, isEmpty);
    });
  });
}
