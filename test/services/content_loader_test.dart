import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';

import '../helpers/test_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentLoader error handling', () {
    setUp(() => ContentLoader.reset());
    tearDown(() => ContentLoader.reset());

    test('throws StateError when accessing content before load', () {
      expect(() => ContentLoader.companyName, throwsA(isA<StateError>()));
    });

    test('StateError message indicates load() must be called', () {
      expect(
        () => ContentLoader.companyName,
        throwsA(predicate<StateError>((e) => e.message.contains('load()'))),
      );
    });

    test('rawContent returns null when not loaded', () {
      expect(ContentLoader.rawContent, isNull);
    });
  });

  group('API surface verification', () {
    setUp(setUpContentLoaderTest);
    tearDown(tearDownContentLoaderTest);

    test('all getters are accessible when loaded', () {
      // Company
      expect(ContentLoader.companyName, isNotEmpty);
      expect(ContentLoader.companyName, isNotEmpty);

      // URLs
      expect(ContentLoader.calendlyUrl, startsWith('http'));
      expect(ContentLoader.calendlyUrl, startsWith('http'));

      // CTAs
      expect(ContentLoader.ctaStartFreeTrial, isNotEmpty);
      expect(ContentLoader.ctaStartFreeTrial, isNotEmpty);

      // Trust/Metrics
      expect(ContentLoader.trustIndicators, isNotEmpty);
      expect(ContentLoader.trustIndicators, isNotEmpty);

      // Pricing
      expect(ContentLoader.pricingTiers, isNotEmpty);
      expect(ContentLoader.pricingTiers, isNotEmpty);

      // Hero
      expect(ContentLoader.heroBadge, isNotEmpty);
      expect(ContentLoader.heroBadge, isNotEmpty);

      // Features/Services
      expect(ContentLoader.featuresItems, isNotEmpty);
      expect(ContentLoader.servicesItems, isNotEmpty);

      // About
      expect(ContentLoader.aboutTitle, isNotEmpty);
      expect(ContentLoader.aboutTeam, isNotEmpty);

      // Contact
      expect(ContentLoader.contactFormFields, isNotEmpty);
      expect(ContentLoader.contactMethods, isNotEmpty);

      // Footer/Status
      expect(ContentLoader.footerLinkGroups, isNotEmpty);
      expect(ContentLoader.statusServices, isNotEmpty);

      // Resources
      expect(ContentLoader.resourcesDocumentation, isNotEmpty);
      expect(ContentLoader.resourcesFeaturedPosts, isNotEmpty);

      // Social/Disclaimers
      expect(ContentLoader.socialProofTestimonials, isNotEmpty);
      expect(ContentLoader.disclaimerEuAiAct, isNotEmpty);
    });

    test('getHeroVariant methods work', () {
      expect(ContentLoader.getHeroVariant('current'), isNotEmpty);
      expect(ContentLoader.getHeroVariant('current'), isNotEmpty);
    });

  });

  group('ContentLoader with loaded content', () {
    setUp(setUpContentLoaderTest);
    tearDown(tearDownContentLoaderTest);

    // Table-driven string value tests
    group('string values', () {
      final stringValues = <String, (String Function(), String)>{
        'companyName': (() => ContentLoader.companyName, 'Test Company'),
        'companyTagline': (() => ContentLoader.companyTagline, 'Test Tagline'),
        'companyCopyright': (() => ContentLoader.companyCopyright, '© 2024 Test'),
        'companyEmail': (() => ContentLoader.companyEmail, 'test@example.com'),
        'companyPhone': (() => ContentLoader.companyPhone, '555-1234'),
        'companyCity': (() => ContentLoader.companyCity, 'Austin'),
        'companyRegion': (() => ContentLoader.companyRegion, 'Texas'),
        'companyFoundedYear': (() => ContentLoader.companyFoundedYear, '2024'),
        'calendlyUrl': (() => ContentLoader.calendlyUrl, 'https://calendly.com/test'),
        'statusPageUrl': (() => ContentLoader.statusPageUrl, 'https://status.test.com'),
        'linkedInUrl': (() => ContentLoader.linkedInUrl, 'https://linkedin.com/test'),
        'githubUrl': (() => ContentLoader.githubUrl, 'https://github.com/test'),
        'founderLinkedInUrl': (() => ContentLoader.founderLinkedInUrl, 'https://linkedin.com/in/founder'),
        'ctaStartFreeTrial': (() => ContentLoader.ctaStartFreeTrial, 'Start Free Trial'),
        'ctaGetStarted': (() => ContentLoader.ctaGetStarted, 'Get Started'),
        'ctaScheduleDemo': (() => ContentLoader.ctaScheduleDemo, 'Schedule Demo'),
        'ctaRequestDemo': (() => ContentLoader.ctaRequestDemo, 'Request Demo'),
        'ctaContactSales': (() => ContentLoader.ctaContactSales, 'Contact Sales'),
        'ctaLearnMore': (() => ContentLoader.ctaLearnMore, 'Learn More'),
        'ctaSendMessage': (() => ContentLoader.ctaSendMessage, 'Send Message'),
        'metricsUptime': (() => ContentLoader.metricsUptime, '99.9%'),
        'metricsTracesProcessed': (() => ContentLoader.metricsTracesProcessed, '10M+'),
        'metricsAiTeams': (() => ContentLoader.metricsAiTeams, '500+'),
        'metricsSetupTime': (() => ContentLoader.metricsSetupTime, '5 min'),
        'pricingTitle': (() => ContentLoader.pricingTitle, 'Test Pricing'),
        'pricingSubtitle': (() => ContentLoader.pricingSubtitle, 'Test pricing subtitle'),
        'pricingAnnualDiscount': (() => ContentLoader.pricingAnnualDiscount, 'Save 20%'),
        'heroBadge': (() => ContentLoader.heroBadge, 'Test Badge'),
        'heroHeadline': (() => ContentLoader.heroHeadline, 'Test Headline'),
        'heroSubheadline': (() => ContentLoader.heroSubheadline, 'Test Subheadline'),
        'heroPrimaryCta': (() => ContentLoader.heroPrimaryCta, 'Primary CTA'),
        'heroSecondaryCta': (() => ContentLoader.heroSecondaryCta, 'Secondary CTA'),
        'featuresTitle': (() => ContentLoader.featuresTitle, 'Features Title'),
        'featuresSubtitle': (() => ContentLoader.featuresSubtitle, 'Features Subtitle'),
        'servicesTitle': (() => ContentLoader.servicesTitle, 'Services Title'),
        'servicesSubtitle': (() => ContentLoader.servicesSubtitle, 'Services Subtitle'),
        'servicesDescription': (() => ContentLoader.servicesDescription, 'Services Description'),
        'ctaSectionHeadline': (() => ContentLoader.ctaSectionHeadline, 'CTA Headline'),
        'ctaSectionSubheadline': (() => ContentLoader.ctaSectionSubheadline, 'CTA Subheadline'),
        'aboutTitle': (() => ContentLoader.aboutTitle, 'About Title'),
        'aboutSubtitle': (() => ContentLoader.aboutSubtitle, 'About Subtitle'),
        'aboutMission': (() => ContentLoader.aboutMission, 'Our mission'),
        'aboutVision': (() => ContentLoader.aboutVision, 'Our vision'),
        'aboutStory': (() => ContentLoader.aboutStory, 'Our story'),
        'contactTitle': (() => ContentLoader.contactTitle, 'Contact Title'),
        'contactSubtitle': (() => ContentLoader.contactSubtitle, 'Contact Subtitle'),
        'contactDescription': (() => ContentLoader.contactDescription, 'Contact Description'),
        'contactSuccessMessage': (() => ContentLoader.contactSuccessMessage, 'Success!'),
        'contactErrorMessage': (() => ContentLoader.contactErrorMessage, 'Error!'),
        'footerPrivacyLink': (() => ContentLoader.footerPrivacyLink, '/privacy'),
        'footerTermsLink': (() => ContentLoader.footerTermsLink, '/terms'),
        'footerCookiesLink': (() => ContentLoader.footerCookiesLink, '/cookies'),
        'statusTitle': (() => ContentLoader.statusTitle, 'Status Title'),
        'statusSubtitle': (() => ContentLoader.statusSubtitle, 'Status Subtitle'),
        'statusBadge': (() => ContentLoader.statusBadge, 'All Operational'),
        'resourcesTitle': (() => ContentLoader.resourcesTitle, 'Resources Title'),
        'resourcesSubtitle': (() => ContentLoader.resourcesSubtitle, 'Resources Subtitle'),
        'socialProofTitle': (() => ContentLoader.socialProofTitle, 'Social Proof Title'),
        'disclaimerEuAiAct': (() => ContentLoader.disclaimerEuAiAct, 'EU AI Act disclaimer'),
        'disclaimerEuAiActShort': (() => ContentLoader.disclaimerEuAiActShort, 'Short disclaimer'),
        'disclaimerSecurity': (() => ContentLoader.disclaimerSecurity, 'Security disclaimer'),
        'disclaimerGeneral': (() => ContentLoader.disclaimerGeneral, 'General disclaimer'),
      };

      for (final entry in stringValues.entries) {
        test('${entry.key} returns correct value', () {
          expect(entry.value.$1(), equals(entry.value.$2));
        });
      }
    });

    group('list getters', () {
      test('trustIndicators returns correct values', () {
        final indicators = ContentLoader.trustIndicators;
        expect(indicators, isA<List<String>>());
        expect(indicators, containsAll(['Feature A', 'Feature B', 'Feature C']));
      });

      test('legacyTrustIndicators returns correct values', () {
        final indicators = ContentLoader.legacyTrustIndicators;
        expect(indicators, containsAll(['Old Feature 1', 'Old Feature 2']));
      });

      test('pricingTiers returns correct structure', () {
        final tiers = ContentLoader.pricingTiers;
        expect(tiers, isA<List<Map<String, dynamic>>>());
        expect(tiers.length, equals(2));
        expect(tiers[0]['name'], equals('Free'));
        expect(tiers[1]['is_popular'], isTrue);
      });

      test('featuresItems returns correct structure', () {
        final items = ContentLoader.featuresItems;
        expect(items.length, equals(2));
        expect(items[0]['title'], equals('Feature 1'));
        expect((items[0]['bullets'] as List).length, equals(2));
      });

      test('servicesItems returns correct structure', () {
        final items = ContentLoader.servicesItems;
        expect(items[0]['title'], equals('Service 1'));
      });

      test('aboutValues returns correct structure', () {
        final values = ContentLoader.aboutValues;
        expect(values[0]['title'], equals('Transparency'));
      });

      test('aboutTeam returns correct structure', () {
        final team = ContentLoader.aboutTeam;
        expect(team[0]['name'], equals('John Doe'));
        expect(team[0]['role'], equals('CEO'));
      });

      test('contactFormFields returns correct structure', () {
        final fields = ContentLoader.contactFormFields;
        expect(fields[0]['name'], equals('email'));
        expect(fields[0]['required'], isTrue);
      });

      test('contactMethods returns correct structure', () {
        final methods = ContentLoader.contactMethods;
        expect(methods[0]['label'], equals('Email'));
        expect(methods[0]['is_primary'], isTrue);
      });

      test('footerLinkGroups returns correct structure', () {
        final groups = ContentLoader.footerLinkGroups;
        expect(groups[0]['title'], equals('Product'));
        expect(groups[0]['links'], isA<List>());
      });

      test('statusMetrics returns correct structure', () {
        final metrics = ContentLoader.statusMetrics;
        expect(metrics[0]['label'], equals('Uptime'));
        expect(metrics[0]['value'], equals('99.9%'));
      });

      test('statusServices returns correct structure', () {
        final services = ContentLoader.statusServices;
        expect(services[0]['name'], equals('API'));
        expect(services[0]['status'], equals('Operational'));
      });

      test('resourcesDocumentation returns correct structure', () {
        final docs = ContentLoader.resourcesDocumentation;
        expect(docs[0]['title'], equals('Getting Started'));
        expect(docs[0]['popular_topics'], isA<List>());
      });

      test('resourcesFeaturedPosts returns correct structure', () {
        final posts = ContentLoader.resourcesFeaturedPosts;
        expect(posts[0]['title'], equals('Test Post'));
        expect(posts[0]['slug'], equals('test-post'));
      });

      test('resourcesLeadMagnets returns correct structure', () {
        final magnets = ContentLoader.resourcesLeadMagnets;
        expect(magnets[0]['title'], equals('Test Guide'));
        expect(magnets[0]['requires_email'], isTrue);
      });

      test('socialProofTestimonials returns correct structure', () {
        final testimonials = ContentLoader.socialProofTestimonials;
        expect(testimonials[0]['quote'], equals('Great product!'));
        expect(testimonials[0]['author'], equals('Jane Doe'));
      });
    });

    group('map getters', () {
      test('company returns all company data', () {
        final company = ContentLoader.company;
        expect(company['name'], equals('Test Company'));
        expect(company['tagline'], equals('Test Tagline'));
      });

      test('heroCurrent returns current hero data', () {
        final hero = ContentLoader.heroCurrent;
        expect(hero['badge'], equals('Test Badge'));
        expect(hero['headline'], equals('Test Headline'));
      });

      test('socialProofStats returns stats map', () {
        final stats = ContentLoader.socialProofStats;
        expect(stats, isA<Map<String, String>>());
        expect(stats['uptime'], equals('99.9%'));
        expect(stats['traces'], equals('10M+'));
      });
    });

    group('hero variants', () {
      test('getHeroVariant returns current variant', () {
        final hero = ContentLoader.getHeroVariant('current');
        expect(hero['badge'], equals('Test Badge'));
      });

      test('getHeroVariant returns alternate variant', () {
        final hero = ContentLoader.getHeroVariant('alternate');
        expect(hero['badge'], equals('Alt Badge'));
        expect(hero['headline'], equals('Alt Headline'));
      });
    });

    group('state verification', () {
      test('rawContent is not null after loading', () {
        expect(ContentLoader.rawContent, isNotNull);
      });

      test('isLoaded returns true after loading', () {
        expect(ContentLoader.isLoaded, isTrue);
      });
    });
  });

  group('Content static methods', () {
    setUp(setUpContentLoaderTest);
    tearDown(tearDownContentLoaderTest);

    test('ContentLoader.isLoaded returns true after loading', () {
      expect(ContentLoader.isLoaded, isTrue);
    });

    test('ContentLoader.reset clears loaded state', () {
      ContentLoader.reset();
      expect(ContentLoader.isLoaded, isFalse);
    });

    test('Content static getters delegate correctly', () {
      expect(ContentLoader.companyName, equals('Test Company'));
      expect(ContentLoader.trustIndicators, contains('Feature A'));
    });

    test('ContentLoader.getHeroVariant returns correct variant', () {
      final hero = ContentLoader.getHeroVariant('alternate');
      expect(hero['badge'], equals('Alt Badge'));
    });
  });

  group('ContentLoader edge cases', () {
    setUp(() => ContentLoader.reset());
    tearDown(() => ContentLoader.reset());

    test('_getMap asserts on missing key in debug mode', () {
      ContentLoader.loadFromString('company:\n  name: "Test"\n');
      // _getMap fires an assertion in debug mode for missing keys.
      // In release mode it falls back to empty map.
      expect(
        () => ContentLoader.heroCurrent,
        throwsA(isA<AssertionError>()),
      );
    });

    test('_getStringList returns empty list for non-existent path', () {
      ContentLoader.loadFromString('company:\n  name: "Test"\n');
      final result = ContentLoader.trustIndicators;
      expect(result, isA<List<String>>());
      expect(result, isEmpty);
    });

    test('_getMapList returns empty list for non-existent path', () {
      ContentLoader.loadFromString('company:\n  name: "Test"\n');
      final result = ContentLoader.pricingTiers;
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result, isEmpty);
    });

    test('loadFromString overwrites previous content', () {
      ContentLoader.loadFromString('company:\n  name: "First"\n');
      expect(ContentLoader.companyName, equals('First'));

      ContentLoader.loadFromString('company:\n  name: "Second"\n');
      expect(ContentLoader.companyName, equals('Second'));
    });

    test('deeply nested YAML is handled correctly', () {
      ContentLoader.loadFromString('company:\n  contact:\n    email: "deep@nested.com"\n');
      expect(ContentLoader.companyEmail, equals('deep@nested.com'));
    });
  });

  group('ContentLoadException', () {
    setUp(() => ContentLoader.reset());
    tearDown(() => ContentLoader.reset());

    test('toString without cause omits caused-by clause', () {
      const ex = ContentLoadException('something failed');
      expect(ex.toString(), equals('ContentLoadException: something failed'));
    });

    test('toString with cause includes caused-by clause', () {
      const ex = ContentLoadException(
        'something failed',
        cause: 'root error',
      );
      expect(
        ex.toString(),
        equals('ContentLoadException: something failed (caused by: root error)'),
      );
    });

    test('loadFromString throws ContentLoadException on bare string YAML', () {
      expect(
        () => ContentLoader.loadFromString('just a string'),
        throwsA(isA<ContentLoadException>()),
      );
    });

    test('loadFromString throws ContentLoadException on YAML list', () {
      expect(
        () => ContentLoader.loadFromString('- item1\n- item2\n'),
        throwsA(isA<ContentLoadException>()),
      );
    });

    test('loadFromString ContentLoadException message describes type', () {
      expect(
        () => ContentLoader.loadFromString('just a string'),
        throwsA(
          predicate<ContentLoadException>(
            (e) => e.message.contains('map at root level'),
          ),
        ),
      );
    });
  });
}
