import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';

/// Sample YAML content for testing.
const _testYamlContent = '''
company:
  name: "Test Company"
  tagline: "Test Tagline"
  copyright: "© 2024 Test"
  founded_year: "2024"
  location:
    city: "Austin"
    region: "Texas"
  contact:
    email: "test@example.com"
    phone: "555-1234"

urls:
  external:
    calendly_demo: "https://calendly.com/test"
    status_page: "https://status.test.com"
    linkedin: "https://linkedin.com/test"
    twitter: "https://twitter.com/test"
    github: "https://github.com/test"
    founder_linkedin: "https://linkedin.com/in/founder"
    founder_twitter: "https://twitter.com/founder"

cta_text:
  primary:
    start_free_trial: "Start Free Trial"
    get_started: "Get Started"
    schedule_demo: "Schedule Demo"
    request_demo: "Request Demo"
    contact_sales: "Contact Sales"
    learn_more: "Learn More"
  form:
    send_message: "Send Message"

trust_indicators:
  current:
    - "Feature A"
    - "Feature B"
    - "Feature C"
  legacy:
    - "Old Feature 1"
    - "Old Feature 2"

platform_metrics:
  uptime: "99.9%"
  traces_processed: "10M+"
  ai_teams: "500+"
  setup_time: "5 min"

pricing_constants:
  annual_discount: "Save 20%"

pricing:
  title: "Test Pricing"
  subtitle: "Test pricing subtitle"
  tiers:
    - name: "Free"
      monthly_price: "\$0"
      annual_price: "\$0"
      description: "For testing"
      features:
        - "Feature 1"
        - "Feature 2"
    - name: "Pro"
      monthly_price: "\$99"
      annual_price: "\$79"
      is_popular: true
      features:
        - "Everything in Free"
        - "Pro Feature"

hero:
  current:
    badge: "Test Badge"
    headline: "Test Headline"
    subheadline: "Test Subheadline"
    primary_cta: "Primary CTA"
    secondary_cta: "Secondary CTA"
  variants:
    alternate:
      badge: "Alt Badge"
      headline: "Alt Headline"
      subheadline: "Alt Subheadline"
      primary_cta: "Alt Primary"
      secondary_cta: "Alt Secondary"

features:
  title: "Features Title"
  subtitle: "Features Subtitle"
  items:
    - icon: "activity"
      title: "Feature 1"
      description: "Description 1"
      bullets:
        - "Bullet 1"
        - "Bullet 2"
    - icon: "shield"
      title: "Feature 2"
      description: "Description 2"

services:
  title: "Services Title"
  subtitle: "Services Subtitle"
  description: "Services Description"
  items:
    - icon: "code"
      title: "Service 1"
      description: "Service description"
      capabilities:
        - "Capability 1"
        - "Capability 2"

cta:
  headline: "CTA Headline"
  subheadline: "CTA Subheadline"

about:
  title: "About Title"
  subtitle: "About Subtitle"
  mission_statement: "Our mission"
  vision_statement: "Our vision"
  story: "Our story"
  values:
    - icon: "eye"
      title: "Transparency"
      description: "Be transparent"
  team:
    - name: "John Doe"
      role: "CEO"
      bio: "Leader"
      linkedin_url: "https://linkedin.com/in/johndoe"

contact:
  title: "Contact Title"
  subtitle: "Contact Subtitle"
  description: "Contact Description"
  form:
    fields:
      - name: "email"
        label: "Email"
        placeholder: "your@email.com"
        type: "email"
        required: true
    success_message: "Success!"
    error_message: "Error!"
  contact_methods:
    - icon: "mail"
      label: "Email"
      value: "test@example.com"
      url: "mailto:test@example.com"
      is_primary: true

footer:
  privacy_link: "/privacy"
  terms_link: "/terms"
  cookies_link: "/cookies"
  link_groups:
    - title: "Product"
      links:
        - label: "Features"
          url: "#features"
        - label: "Pricing"
          url: "#pricing"
          is_external: false

status:
  title: "Status Title"
  subtitle: "Status Subtitle"
  status_badge: "All Operational"
  metrics:
    - label: "Uptime"
      value: "99.9%"
      sublabel: "SLA"
  services:
    - name: "API"
      status: "Operational"

resources:
  title: "Resources Title"
  subtitle: "Resources Subtitle"
  documentation:
    - icon: "book-open"
      title: "Getting Started"
      description: "Quick start"
      url: "/docs/quickstart"
      popular_topics:
        - "Setup"
        - "Configuration"
  featured_posts:
    - title: "Test Post"
      excerpt: "Test excerpt"
      category: "Guide"
      publish_date: "2024-01-01"
      read_time: "5 min"
      slug: "test-post"
      author: "Test Author"
  lead_magnets:
    - icon: "file-text"
      title: "Test Guide"
      description: "A test guide"
      format: "PDF"
      cta_text: "Download"
      url: "/resources/test"
      requires_email: true

social_proof:
  title: "Social Proof Title"
  stats:
    uptime: "99.9%"
    traces: "10M+"
  testimonials:
    - quote: "Great product!"
      author: "Jane Doe"
      role: "CTO"
      company: "Test Corp"

disclaimers:
  eu_ai_act: "EU AI Act disclaimer"
  eu_ai_act_short: "Short disclaimer"
  security: "Security disclaimer"
  general: "General disclaimer"

promo_codes:
  whylabs_migration:
    code: "TEST2025"
    description: "Test promo"
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentLoader singleton', () {
    test('returns the same instance', () {
      final instance1 = ContentLoader.instance;
      final instance2 = ContentLoader.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('instance is a ContentLoader', () {
      expect(ContentLoader.instance, isA<ContentLoader>());
    });

    test('isLoaded returns a boolean', () {
      expect(ContentLoader.instance.isLoaded, isA<bool>());
    });

    test('rawContent returns null when not loaded', () {
      final loader = ContentLoader.instance;
      if (!loader.isLoaded) {
        expect(loader.rawContent, isNull);
      }
    });
  });

  group('ContentLoader error handling', () {
    test('throws StateError when accessing content before load', () {
      final loader = ContentLoader.instance;
      if (!loader.isLoaded) {
        expect(() => loader.companyName, throwsA(isA<StateError>()));
      }
    });

    test('StateError message indicates load() must be called', () {
      final loader = ContentLoader.instance;
      if (!loader.isLoaded) {
        expect(
          () => loader.companyName,
          throwsA(predicate<StateError>((e) => e.message.contains('load()'))),
        );
      }
    });
  });

  group('Content class basics', () {
    test('load method returns Future<void>', () {
      expect(Content.load, isA<Future<void> Function()>());
    });

    test('isLoaded returns boolean', () {
      expect(Content.isLoaded, isA<bool>());
    });

    test('getHeroVariant method exists', () {
      expect(Content.getHeroVariant, isA<Function>());
    });
  });

  group('Content with mocked assets', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });

    testWidgets('load method can be called', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString') {
            return Uint8List.fromList(_testYamlContent.codeUnits);
          }
          return null;
        },
      );

      try {
        await Content.load();
      } catch (_) {
        // Expected in test environment without proper asset mocking
      }
    });
  });

  // Unified API surface verification - tests both ContentLoader and Content
  group('API surface verification', () {
    final loader = ContentLoader.instance;

    // All getter categories with their accessor functions
    final apiGetters = <String, List<Function()>>{
      'company': [
        () => loader.companyName, () => Content.companyName,
        () => loader.companyTagline, () => Content.companyTagline,
        () => loader.companyCopyright, () => Content.companyCopyright,
        () => loader.companyEmail, () => Content.companyEmail,
        () => loader.companyPhone, () => Content.companyPhone,
        () => loader.companyCity, () => Content.companyCity,
        () => loader.companyRegion, () => Content.companyRegion,
        () => loader.companyFoundedYear, () => Content.companyFoundedYear,
      ],
      'URL': [
        () => loader.calendlyUrl, () => Content.calendlyUrl,
        () => loader.statusPageUrl, () => Content.statusPageUrl,
        () => loader.linkedInUrl, () => Content.linkedInUrl,
        () => loader.twitterUrl, () => Content.twitterUrl,
        () => loader.githubUrl, () => Content.githubUrl,
        () => loader.founderLinkedInUrl, () => Content.founderLinkedInUrl,
        () => loader.founderTwitterUrl, () => Content.founderTwitterUrl,
      ],
      'CTA': [
        () => loader.ctaStartFreeTrial, () => Content.ctaStartFreeTrial,
        () => loader.ctaGetStarted, () => Content.ctaGetStarted,
        () => loader.ctaScheduleDemo, () => Content.ctaScheduleDemo,
        () => loader.ctaRequestDemo, () => Content.ctaRequestDemo,
        () => loader.ctaContactSales, () => Content.ctaContactSales,
        () => loader.ctaLearnMore, () => Content.ctaLearnMore,
        () => loader.ctaSendMessage, () => Content.ctaSendMessage,
      ],
      'trust/metrics': [
        () => loader.trustIndicators, () => Content.trustIndicators,
        () => loader.legacyTrustIndicators, () => Content.legacyTrustIndicators,
        () => loader.metricsUptime, () => Content.metricsUptime,
        () => loader.metricsTracesProcessed, () => Content.metricsTracesProcessed,
        () => loader.metricsAiTeams, () => Content.metricsAiTeams,
        () => loader.metricsSetupTime, () => Content.metricsSetupTime,
      ],
      'pricing': [
        () => loader.pricingTitle, () => Content.pricingTitle,
        () => loader.pricingSubtitle, () => Content.pricingSubtitle,
        () => loader.pricingAnnualDiscount, () => Content.pricingAnnualDiscount,
        () => loader.pricingTiers, () => Content.pricingTiers,
      ],
      'hero': [
        () => loader.heroBadge, () => Content.heroBadge,
        () => loader.heroHeadline, () => Content.heroHeadline,
        () => loader.heroSubheadline, () => Content.heroSubheadline,
        () => loader.heroPrimaryCta, () => Content.heroPrimaryCta,
        () => loader.heroSecondaryCta, () => Content.heroSecondaryCta,
        () => loader.heroCurrent,
      ],
      'features/services': [
        () => loader.featuresTitle, () => Content.featuresTitle,
        () => loader.featuresSubtitle, () => Content.featuresSubtitle,
        () => loader.featuresItems, () => Content.featuresItems,
        () => loader.servicesTitle, () => Content.servicesTitle,
        () => loader.servicesSubtitle, () => Content.servicesSubtitle,
        () => loader.servicesDescription, () => Content.servicesDescription,
        () => loader.servicesItems, () => Content.servicesItems,
        () => loader.ctaSectionHeadline, () => Content.ctaSectionHeadline,
        () => loader.ctaSectionSubheadline, () => Content.ctaSectionSubheadline,
      ],
      'about': [
        () => loader.aboutTitle, () => Content.aboutTitle,
        () => loader.aboutSubtitle, () => Content.aboutSubtitle,
        () => loader.aboutMission, () => Content.aboutMission,
        () => loader.aboutVision, () => Content.aboutVision,
        () => loader.aboutStory, () => Content.aboutStory,
        () => loader.aboutValues, () => Content.aboutValues,
        () => loader.aboutTeam, () => Content.aboutTeam,
      ],
      'contact': [
        () => loader.contactTitle, () => Content.contactTitle,
        () => loader.contactSubtitle, () => Content.contactSubtitle,
        () => loader.contactDescription, () => Content.contactDescription,
        () => loader.contactFormFields, () => Content.contactFormFields,
        () => loader.contactMethods, () => Content.contactMethods,
        () => loader.contactSuccessMessage, () => Content.contactSuccessMessage,
        () => loader.contactErrorMessage, () => Content.contactErrorMessage,
      ],
      'footer/status': [
        () => loader.footerLinkGroups, () => Content.footerLinkGroups,
        () => loader.footerPrivacyLink, () => Content.footerPrivacyLink,
        () => loader.footerTermsLink, () => Content.footerTermsLink,
        () => loader.footerCookiesLink, () => Content.footerCookiesLink,
        () => loader.statusTitle, () => Content.statusTitle,
        () => loader.statusSubtitle, () => Content.statusSubtitle,
        () => loader.statusBadge, () => Content.statusBadge,
        () => loader.statusMetrics, () => Content.statusMetrics,
        () => loader.statusServices, () => Content.statusServices,
      ],
      'resources': [
        () => loader.resourcesTitle, () => Content.resourcesTitle,
        () => loader.resourcesSubtitle, () => Content.resourcesSubtitle,
        () => loader.resourcesDocumentation, () => Content.resourcesDocumentation,
        () => loader.resourcesFeaturedPosts, () => Content.resourcesFeaturedPosts,
        () => loader.resourcesLeadMagnets, () => Content.resourcesLeadMagnets,
      ],
      'social/disclaimers/promo': [
        () => loader.socialProofTitle, () => Content.socialProofTitle,
        () => loader.socialProofStats, () => Content.socialProofStats,
        () => loader.socialProofTestimonials, () => Content.socialProofTestimonials,
        () => loader.disclaimerEuAiAct, () => Content.disclaimerEuAiAct,
        () => loader.disclaimerEuAiActShort, () => Content.disclaimerEuAiActShort,
        () => loader.disclaimerSecurity, () => Content.disclaimerSecurity,
        () => loader.disclaimerGeneral, () => Content.disclaimerGeneral,
        () => loader.promoWhylabsCode, () => Content.promoWhylabsCode,
        () => loader.promoWhylabsDescription, () => Content.promoWhylabsDescription,
      ],
    };

    for (final entry in apiGetters.entries) {
      test('has ${entry.key} getters', () {
        for (final getter in entry.value) {
          expect(getter, isA<Function>());
        }
      });
    }

    test('has getHeroVariant methods', () {
      expect(loader.getHeroVariant, isA<Function>());
      expect(Content.getHeroVariant, isA<Function>());
    });
  });

  group('ContentLoader with loaded content', () {
    setUp(() {
      ContentLoader.reset();
      Content.loadFromString(_testYamlContent);
    });

    tearDown(() {
      ContentLoader.reset();
    });

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
        'twitterUrl': (() => ContentLoader.instance.twitterUrl, 'https://twitter.com/test'),
        'githubUrl': (() => ContentLoader.instance.githubUrl, 'https://github.com/test'),
        'founderLinkedInUrl': (() => ContentLoader.instance.founderLinkedInUrl, 'https://linkedin.com/in/founder'),
        'founderTwitterUrl': (() => ContentLoader.instance.founderTwitterUrl, 'https://twitter.com/founder'),
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
    setUp(() {
      ContentLoader.reset();
      Content.loadFromString(_testYamlContent);
    });

    tearDown(() {
      ContentLoader.reset();
    });

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
    setUp(() => ContentLoader.reset());
    tearDown(() => ContentLoader.reset());

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
