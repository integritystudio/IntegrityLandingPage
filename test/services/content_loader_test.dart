import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';

import '../helpers/test_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentLoader singleton', () {
    test('returns the same instance', () {
      final instance1 = ContentLoader.instance;
      final instance2 = ContentLoader.instance;
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('ContentLoader error handling', () {
    setUp(() => Content.reset());
    tearDown(() => Content.reset());

    test('throws StateError when accessing content before load', () {
      expect(() => ContentLoader.instance.companyName, throwsA(isA<StateError>()));
    });

    test('StateError message indicates load() must be called', () {
      expect(
        () => ContentLoader.instance.companyName,
        throwsA(predicate<StateError>((e) => e.message.contains('load()'))),
      );
    });

    test('rawContent returns null when not loaded', () {
      expect(ContentLoader.instance.rawContent, isNull);
    });
  });

  group('API surface verification', () {
    setUp(setUpContentLoaderTest);
    tearDown(tearDownContentLoaderTest);

    test('all getters are accessible when loaded', () {
      final loader = ContentLoader.instance;

      // Company
      expect(loader.companyName, isNotEmpty);
      expect(Content.companyName, isNotEmpty);

      // URLs
      expect(loader.calendlyUrl, startsWith('http'));
      expect(Content.calendlyUrl, startsWith('http'));

      // CTAs
      expect(loader.ctaStartFreeTrial, isNotEmpty);
      expect(Content.ctaStartFreeTrial, isNotEmpty);

      // Trust/Metrics
      expect(loader.trustIndicators, isNotEmpty);
      expect(Content.trustIndicators, isNotEmpty);

      // Pricing
      expect(loader.pricingTiers, isNotEmpty);
      expect(Content.pricingTiers, isNotEmpty);

      // Hero
      expect(loader.heroBadge, isNotEmpty);
      expect(Content.heroBadge, isNotEmpty);

      // Features/Services
      expect(loader.featuresItems, isNotEmpty);
      expect(Content.servicesItems, isNotEmpty);

      // About
      expect(loader.aboutTitle, isNotEmpty);
      expect(Content.aboutTeam, isNotEmpty);

      // Contact
      expect(loader.contactFormFields, isNotEmpty);
      expect(Content.contactMethods, isNotEmpty);

      // Footer/Status
      expect(loader.footerLinkGroups, isNotEmpty);
      expect(Content.statusServices, isNotEmpty);

      // Resources
      expect(loader.resourcesDocumentation, isNotEmpty);
      expect(Content.resourcesFeaturedPosts, isNotEmpty);

      // Social/Disclaimers/Promo
      expect(loader.socialProofTestimonials, isNotEmpty);
      expect(Content.disclaimerEuAiAct, isNotEmpty);
      expect(loader.promoWhylabsCode, isNotEmpty);
    });

    test('getHeroVariant methods work', () {
      expect(ContentLoader.instance.getHeroVariant('current'), isNotEmpty);
      expect(Content.getHeroVariant('current'), isNotEmpty);
    });
  });

  group('ContentLoader with loaded content', () {
    setUp(setUpContentLoaderTest);
    tearDown(tearDownContentLoaderTest);

    // Table-driven string value tests
    group('string values', () {
      final stringValues = <String, (String Function(), String)>{
        'companyName': (() => ContentLoader.instance.companyName, 'Test Company'),
        'companyTagline': (() => ContentLoader.instance.companyTagline, 'Test Tagline'),
        'companyCopyright': (() => ContentLoader.instance.companyCopyright, '© 2024 Test'),
        'companyEmail': (() => ContentLoader.instance.companyEmail, 'test@example.com'),
        'companyPhone': (() => ContentLoader.instance.companyPhone, '555-1234'),
        'companyCity': (() => ContentLoader.instance.companyCity, 'Austin'),
        'companyRegion': (() => ContentLoader.instance.companyRegion, 'Texas'),
        'companyFoundedYear': (() => ContentLoader.instance.companyFoundedYear, '2024'),
        'calendlyUrl': (() => ContentLoader.instance.calendlyUrl, 'https://calendly.com/test'),
        'statusPageUrl': (() => ContentLoader.instance.statusPageUrl, 'https://status.test.com'),
        'linkedInUrl': (() => ContentLoader.instance.linkedInUrl, 'https://linkedin.com/test'),
        'xUrl': (() => ContentLoader.instance.xUrl, 'https://x.com/test'),
        'githubUrl': (() => ContentLoader.instance.githubUrl, 'https://github.com/test'),
        'founderLinkedInUrl': (() => ContentLoader.instance.founderLinkedInUrl, 'https://linkedin.com/in/founder'),
        'founderXUrl': (() => ContentLoader.instance.founderXUrl, 'https://x.com/founder'),
        'ctaStartFreeTrial': (() => ContentLoader.instance.ctaStartFreeTrial, 'Start Free Trial'),
        'ctaGetStarted': (() => ContentLoader.instance.ctaGetStarted, 'Get Started'),
        'ctaScheduleDemo': (() => ContentLoader.instance.ctaScheduleDemo, 'Schedule Demo'),
        'ctaRequestDemo': (() => ContentLoader.instance.ctaRequestDemo, 'Request Demo'),
        'ctaContactSales': (() => ContentLoader.instance.ctaContactSales, 'Contact Sales'),
        'ctaLearnMore': (() => ContentLoader.instance.ctaLearnMore, 'Learn More'),
        'ctaSendMessage': (() => ContentLoader.instance.ctaSendMessage, 'Send Message'),
        'metricsUptime': (() => ContentLoader.instance.metricsUptime, '99.9%'),
        'metricsTracesProcessed': (() => ContentLoader.instance.metricsTracesProcessed, '10M+'),
        'metricsAiTeams': (() => ContentLoader.instance.metricsAiTeams, '500+'),
        'metricsSetupTime': (() => ContentLoader.instance.metricsSetupTime, '5 min'),
        'pricingTitle': (() => ContentLoader.instance.pricingTitle, 'Test Pricing'),
        'pricingSubtitle': (() => ContentLoader.instance.pricingSubtitle, 'Test pricing subtitle'),
        'pricingAnnualDiscount': (() => ContentLoader.instance.pricingAnnualDiscount, 'Save 20%'),
        'heroBadge': (() => ContentLoader.instance.heroBadge, 'Test Badge'),
        'heroHeadline': (() => ContentLoader.instance.heroHeadline, 'Test Headline'),
        'heroSubheadline': (() => ContentLoader.instance.heroSubheadline, 'Test Subheadline'),
        'heroPrimaryCta': (() => ContentLoader.instance.heroPrimaryCta, 'Primary CTA'),
        'heroSecondaryCta': (() => ContentLoader.instance.heroSecondaryCta, 'Secondary CTA'),
        'featuresTitle': (() => ContentLoader.instance.featuresTitle, 'Features Title'),
        'featuresSubtitle': (() => ContentLoader.instance.featuresSubtitle, 'Features Subtitle'),
        'servicesTitle': (() => ContentLoader.instance.servicesTitle, 'Services Title'),
        'servicesSubtitle': (() => ContentLoader.instance.servicesSubtitle, 'Services Subtitle'),
        'servicesDescription': (() => ContentLoader.instance.servicesDescription, 'Services Description'),
        'ctaSectionHeadline': (() => ContentLoader.instance.ctaSectionHeadline, 'CTA Headline'),
        'ctaSectionSubheadline': (() => ContentLoader.instance.ctaSectionSubheadline, 'CTA Subheadline'),
        'aboutTitle': (() => ContentLoader.instance.aboutTitle, 'About Title'),
        'aboutSubtitle': (() => ContentLoader.instance.aboutSubtitle, 'About Subtitle'),
        'aboutMission': (() => ContentLoader.instance.aboutMission, 'Our mission'),
        'aboutVision': (() => ContentLoader.instance.aboutVision, 'Our vision'),
        'aboutStory': (() => ContentLoader.instance.aboutStory, 'Our story'),
        'contactTitle': (() => ContentLoader.instance.contactTitle, 'Contact Title'),
        'contactSubtitle': (() => ContentLoader.instance.contactSubtitle, 'Contact Subtitle'),
        'contactDescription': (() => ContentLoader.instance.contactDescription, 'Contact Description'),
        'contactSuccessMessage': (() => ContentLoader.instance.contactSuccessMessage, 'Success!'),
        'contactErrorMessage': (() => ContentLoader.instance.contactErrorMessage, 'Error!'),
        'footerPrivacyLink': (() => ContentLoader.instance.footerPrivacyLink, '/privacy'),
        'footerTermsLink': (() => ContentLoader.instance.footerTermsLink, '/terms'),
        'footerCookiesLink': (() => ContentLoader.instance.footerCookiesLink, '/cookies'),
        'statusTitle': (() => ContentLoader.instance.statusTitle, 'Status Title'),
        'statusSubtitle': (() => ContentLoader.instance.statusSubtitle, 'Status Subtitle'),
        'statusBadge': (() => ContentLoader.instance.statusBadge, 'All Operational'),
        'resourcesTitle': (() => ContentLoader.instance.resourcesTitle, 'Resources Title'),
        'resourcesSubtitle': (() => ContentLoader.instance.resourcesSubtitle, 'Resources Subtitle'),
        'socialProofTitle': (() => ContentLoader.instance.socialProofTitle, 'Social Proof Title'),
        'disclaimerEuAiAct': (() => ContentLoader.instance.disclaimerEuAiAct, 'EU AI Act disclaimer'),
        'disclaimerEuAiActShort': (() => ContentLoader.instance.disclaimerEuAiActShort, 'Short disclaimer'),
        'disclaimerSecurity': (() => ContentLoader.instance.disclaimerSecurity, 'Security disclaimer'),
        'disclaimerGeneral': (() => ContentLoader.instance.disclaimerGeneral, 'General disclaimer'),
        'promoWhylabsCode': (() => ContentLoader.instance.promoWhylabsCode, 'TEST2025'),
        'promoWhylabsDescription': (() => ContentLoader.instance.promoWhylabsDescription, 'Test promo'),
      };

      for (final entry in stringValues.entries) {
        test('${entry.key} returns correct value', () {
          expect(entry.value.$1(), equals(entry.value.$2));
        });
      }
    });

    group('list getters', () {
      test('trustIndicators returns correct values', () {
        final indicators = ContentLoader.instance.trustIndicators;
        expect(indicators, isA<List<String>>());
        expect(indicators, containsAll(['Feature A', 'Feature B', 'Feature C']));
      });

      test('legacyTrustIndicators returns correct values', () {
        final indicators = ContentLoader.instance.legacyTrustIndicators;
        expect(indicators, containsAll(['Old Feature 1', 'Old Feature 2']));
      });

      test('pricingTiers returns correct structure', () {
        final tiers = ContentLoader.instance.pricingTiers;
        expect(tiers, isA<List<Map<String, dynamic>>>());
        expect(tiers.length, equals(2));
        expect(tiers[0]['name'], equals('Free'));
        expect(tiers[1]['is_popular'], isTrue);
      });

      test('featuresItems returns correct structure', () {
        final items = ContentLoader.instance.featuresItems;
        expect(items.length, equals(2));
        expect(items[0]['title'], equals('Feature 1'));
        expect((items[0]['bullets'] as List).length, equals(2));
      });

      test('servicesItems returns correct structure', () {
        final items = ContentLoader.instance.servicesItems;
        expect(items[0]['title'], equals('Service 1'));
      });

      test('aboutValues returns correct structure', () {
        final values = ContentLoader.instance.aboutValues;
        expect(values[0]['title'], equals('Transparency'));
      });

      test('aboutTeam returns correct structure', () {
        final team = ContentLoader.instance.aboutTeam;
        expect(team[0]['name'], equals('John Doe'));
        expect(team[0]['role'], equals('CEO'));
      });

      test('contactFormFields returns correct structure', () {
        final fields = ContentLoader.instance.contactFormFields;
        expect(fields[0]['name'], equals('email'));
        expect(fields[0]['required'], isTrue);
      });

      test('contactMethods returns correct structure', () {
        final methods = ContentLoader.instance.contactMethods;
        expect(methods[0]['label'], equals('Email'));
        expect(methods[0]['is_primary'], isTrue);
      });

      test('footerLinkGroups returns correct structure', () {
        final groups = ContentLoader.instance.footerLinkGroups;
        expect(groups[0]['title'], equals('Product'));
        expect(groups[0]['links'], isA<List>());
      });

      test('statusMetrics returns correct structure', () {
        final metrics = ContentLoader.instance.statusMetrics;
        expect(metrics[0]['label'], equals('Uptime'));
        expect(metrics[0]['value'], equals('99.9%'));
      });

      test('statusServices returns correct structure', () {
        final services = ContentLoader.instance.statusServices;
        expect(services[0]['name'], equals('API'));
        expect(services[0]['status'], equals('Operational'));
      });

      test('resourcesDocumentation returns correct structure', () {
        final docs = ContentLoader.instance.resourcesDocumentation;
        expect(docs[0]['title'], equals('Getting Started'));
        expect(docs[0]['popular_topics'], isA<List>());
      });

      test('resourcesFeaturedPosts returns correct structure', () {
        final posts = ContentLoader.instance.resourcesFeaturedPosts;
        expect(posts[0]['title'], equals('Test Post'));
        expect(posts[0]['slug'], equals('test-post'));
      });

      test('resourcesLeadMagnets returns correct structure', () {
        final magnets = ContentLoader.instance.resourcesLeadMagnets;
        expect(magnets[0]['title'], equals('Test Guide'));
        expect(magnets[0]['requires_email'], isTrue);
      });

      test('socialProofTestimonials returns correct structure', () {
        final testimonials = ContentLoader.instance.socialProofTestimonials;
        expect(testimonials[0]['quote'], equals('Great product!'));
        expect(testimonials[0]['author'], equals('Jane Doe'));
      });
    });

    group('map getters', () {
      test('company returns all company data', () {
        final company = ContentLoader.instance.company;
        expect(company['name'], equals('Test Company'));
        expect(company['tagline'], equals('Test Tagline'));
      });

      test('heroCurrent returns current hero data', () {
        final hero = ContentLoader.instance.heroCurrent;
        expect(hero['badge'], equals('Test Badge'));
        expect(hero['headline'], equals('Test Headline'));
      });

      test('socialProofStats returns stats map', () {
        final stats = ContentLoader.instance.socialProofStats;
        expect(stats, isA<Map<String, String>>());
        expect(stats['uptime'], equals('99.9%'));
        expect(stats['traces'], equals('10M+'));
      });
    });

    group('hero variants', () {
      test('getHeroVariant returns current variant', () {
        final hero = ContentLoader.instance.getHeroVariant('current');
        expect(hero['badge'], equals('Test Badge'));
      });

      test('getHeroVariant returns alternate variant', () {
        final hero = ContentLoader.instance.getHeroVariant('alternate');
        expect(hero['badge'], equals('Alt Badge'));
        expect(hero['headline'], equals('Alt Headline'));
      });
    });

    group('state verification', () {
      test('rawContent is not null after loading', () {
        expect(ContentLoader.instance.rawContent, isNotNull);
      });

      test('isLoaded returns true after loading', () {
        expect(ContentLoader.instance.isLoaded, isTrue);
      });
    });
  });

  group('Content static methods', () {
    setUp(setUpContentLoaderTest);
    tearDown(tearDownContentLoaderTest);

    test('Content.isLoaded returns true after loading', () {
      expect(Content.isLoaded, isTrue);
    });

    test('Content.reset clears loaded state', () {
      Content.reset();
      expect(Content.isLoaded, isFalse);
    });

    test('Content static getters delegate correctly', () {
      expect(Content.companyName, equals('Test Company'));
      expect(Content.trustIndicators, contains('Feature A'));
    });

    test('Content.getHeroVariant returns correct variant', () {
      final hero = Content.getHeroVariant('alternate');
      expect(hero['badge'], equals('Alt Badge'));
    });
  });

  group('ContentLoader edge cases', () {
    setUp(() => Content.reset());
    tearDown(() => Content.reset());

    test('_getMap returns empty map for non-existent path', () {
      Content.loadFromString('company:\n  name: "Test"\n');
      final result = ContentLoader.instance.heroCurrent;
      expect(result, isA<Map<String, dynamic>>());
      expect(result, isEmpty);
    });

    test('_getStringList returns empty list for non-existent path', () {
      Content.loadFromString('company:\n  name: "Test"\n');
      final result = ContentLoader.instance.trustIndicators;
      expect(result, isA<List<String>>());
      expect(result, isEmpty);
    });

    test('_getMapList returns empty list for non-existent path', () {
      Content.loadFromString('company:\n  name: "Test"\n');
      final result = ContentLoader.instance.pricingTiers;
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result, isEmpty);
    });

    test('loadFromString overwrites previous content', () {
      Content.loadFromString('company:\n  name: "First"\n');
      expect(ContentLoader.instance.companyName, equals('First'));

      Content.loadFromString('company:\n  name: "Second"\n');
      expect(ContentLoader.instance.companyName, equals('Second'));
    });

    test('deeply nested YAML is handled correctly', () {
      Content.loadFromString('company:\n  contact:\n    email: "deep@nested.com"\n');
      expect(ContentLoader.instance.companyEmail, equals('deep@nested.com'));
    });
  });
}
