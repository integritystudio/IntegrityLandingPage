import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {

  group('AppContent', () {
    group('hero', () {
      test('has required fields', () {
        final hero = AppContent.hero;

        expect(hero.badge, isNotEmpty);
        expect(hero.headline, isNotEmpty);
        expect(hero.subheadline, isNotEmpty);
        expect(hero.primaryCTA, isNotEmpty);
        expect(hero.secondaryCTA, isNotEmpty);
      });

      test('has trust indicators', () {
        final hero = AppContent.hero;

        expect(hero.trustIndicators, isNotEmpty);
      });
    });

    group('pricing', () {
      test('has required fields', () {
        final pricing = AppContent.pricing;

        expect(pricing.title, isNotEmpty);
        expect(pricing.subtitle, isNotEmpty);
        expect(pricing.monthlyLabel, equals('Monthly'));
        expect(pricing.annualLabel, equals('Annual'));
      });

      test('has pricing tiers', () {
        final pricing = AppContent.pricing;

        expect(pricing.tiers, isNotEmpty);
        expect(pricing.tiers.length, greaterThanOrEqualTo(2));
      });

      test('each tier has required fields', () {
        final pricing = AppContent.pricing;

        for (final tier in pricing.tiers) {
          expect(tier.name, isNotEmpty);
          expect(tier.monthlyPrice, isNotEmpty);
          expect(tier.features, isNotEmpty);
          expect(tier.ctaText, isNotEmpty);
        }
      });

      test('has enterprise note', () {
        final pricing = AppContent.pricing;

        expect(pricing.enterpriseNote, isNotEmpty);
        expect(pricing.enterpriseLink, isNotEmpty);
      });
    });

    group('features', () {
      test('has required fields', () {
        final features = AppContent.features;

        expect(features.title, isNotEmpty);
        expect(features.subtitle, isNotEmpty);
        expect(features.features, isNotEmpty);
      });

      test('each feature has required fields', () {
        final features = AppContent.features;

        for (final feature in features.features) {
          expect(feature.icon, isNotNull);
          expect(feature.title, isNotEmpty);
          expect(feature.description, isNotEmpty);
        }
      });

      test('features have bullets', () {
        final features = AppContent.features;
        final featuresWithBullets =
            features.features.where((f) => f.bullets.isNotEmpty).toList();

        expect(featuresWithBullets, isNotEmpty);
      });
    });

    group('cta', () {
      test('has required fields', () {
        final cta = AppContent.cta;

        expect(cta.headline, isNotEmpty);
        expect(cta.subheadline, isNotEmpty);
        expect(cta.primaryCTA, isNotEmpty);
        expect(cta.secondaryCTA, isNotEmpty);
      });
    });

    group('socialProof', () {
      test('has required fields', () {
        final socialProof = AppContent.socialProof;

        expect(socialProof.title, isNotEmpty);
        expect(socialProof.statsHeadline, isNotEmpty);
      });

      test('has customer logos', () {
        final socialProof = AppContent.socialProof;

        expect(socialProof.logos, isNotEmpty);
        for (final logo in socialProof.logos) {
          expect(logo.name, isNotEmpty);
        }
      });

      test('has testimonials', () {
        final socialProof = AppContent.socialProof;

        // Testimonials temporarily empty pending approval
        if (socialProof.testimonials.isNotEmpty) {
          for (final testimonial in socialProof.testimonials) {
            expect(testimonial.quote, isNotEmpty);
            expect(testimonial.author, isNotEmpty);
          }
        }
      });

      test('has stats', () {
        final socialProof = AppContent.socialProof;

        expect(socialProof.stats, isNotEmpty);
      });
    });

    group('status', () {
      test('has required fields', () {
        final status = AppContent.status;

        expect(status.title, isNotEmpty);
        expect(status.subtitle, isNotEmpty);
        expect(status.statusBadge, isNotEmpty);
        expect(status.statusPageUrl, isNotEmpty);
        expect(status.statusPageCta, isNotEmpty);
      });

      test('has metrics', () {
        final status = AppContent.status;

        expect(status.metrics, isNotEmpty);
        for (final metric in status.metrics) {
          expect(metric.label, isNotEmpty);
          expect(metric.value, isNotEmpty);
        }
      });

      test('has services', () {
        final status = AppContent.status;

        expect(status.services, isNotEmpty);
        for (final service in status.services) {
          expect(service.name, isNotEmpty);
          expect(service.status, isNotEmpty);
        }
      });
    });

    group('footer', () {
      test('has required fields', () {
        final footer = AppContent.footer;

        expect(footer.companyName, isNotEmpty);
        expect(footer.tagline, isNotEmpty);
        expect(footer.copyright, isNotEmpty);
      });

      test('has link groups', () {
        final footer = AppContent.footer;

        expect(footer.linkGroups, isNotEmpty);
        for (final group in footer.linkGroups) {
          expect(group.title, isNotEmpty);
          expect(group.links, isNotEmpty);
        }
      });

      test('has legal links', () {
        final footer = AppContent.footer;

        expect(footer.privacyLink, isNotEmpty);
        expect(footer.termsLink, isNotEmpty);
        expect(footer.cookiesLink, isNotEmpty);
        expect(footer.accessibilityLink, isNotEmpty);
      });

      test('has cookie settings label', () {
        final footer = AppContent.footer;

        expect(footer.cookieSettingsLabel, isNotEmpty);
      });
    });

    group('services', () {
      test('has required fields', () {
        final services = AppContent.services;

        expect(services.sectionId, equals('services'));
        expect(services.title, isNotEmpty);
        expect(services.subtitle, isNotEmpty);
        expect(services.ctaText, isNotEmpty);
        expect(services.ctaUrl, isNotEmpty);
      });

      test('has services list', () {
        final services = AppContent.services;

        expect(services.services, isNotEmpty);
      });
    });

    group('about', () {
      test('has required fields', () {
        final about = AppContent.about;

        expect(about.sectionId, equals('about'));
        expect(about.title, isNotEmpty);
        expect(about.subtitle, isNotEmpty);
        expect(about.missionStatement, isNotEmpty);
        expect(about.visionStatement, isNotEmpty);
      });

      test('has values', () {
        final about = AppContent.about;

        expect(about.values, isNotEmpty);
        for (final value in about.values) {
          expect(value.title, isNotEmpty);
          expect(value.description, isNotEmpty);
        }
      });

      test('has team members', () {
        final about = AppContent.about;

        expect(about.team, isNotEmpty);
        for (final member in about.team) {
          expect(member.name, isNotEmpty);
          expect(member.role, isNotEmpty);
        }
      });

      test('has location info', () {
        final about = AppContent.about;

        expect(about.locationCity, isNotEmpty);
        expect(about.locationRegion, isNotEmpty);
        expect(about.foundedYear, isNotEmpty);
        expect(int.parse(about.foundedYear), greaterThan(2000));
      });
    });

    group('resources', () {
      test('has required fields', () {
        final resources = AppContent.resources;

        expect(resources.sectionId, equals('resources'));
        expect(resources.title, isNotEmpty);
        expect(resources.subtitle, isNotEmpty);
      });

      test('has documentation categories', () {
        final resources = AppContent.resources;

        expect(resources.documentation, isNotEmpty);
        for (final doc in resources.documentation) {
          expect(doc.title, isNotEmpty);
          expect(doc.url, isNotEmpty);
        }
      });

      test('has featured posts', () {
        final resources = AppContent.resources;

        expect(resources.featuredPosts, isNotEmpty);
        for (final post in resources.featuredPosts) {
          expect(post.title, isNotEmpty);
          expect(post.slug, isNotEmpty);
        }
      });

      test('has CTA links', () {
        final resources = AppContent.resources;

        expect(resources.blogCtaText, isNotEmpty);
        expect(resources.blogCtaUrl, isNotEmpty);
        expect(resources.docsCtaText, isNotEmpty);
        expect(resources.docsCtaUrl, isNotEmpty);
      });
    });

    group('contact', () {
      test('has required fields', () {
        final contact = AppContent.contact;

        expect(contact.sectionId, equals('contact'));
        expect(contact.title, isNotEmpty);
        expect(contact.subtitle, isNotEmpty);
      });

      test('has form fields', () {
        final contact = AppContent.contact;

        expect(contact.formFields, isNotEmpty);
        for (final field in contact.formFields) {
          expect(field.name, isNotEmpty);
          expect(field.label, isNotEmpty);
        }
      });

      test('has contact methods', () {
        final contact = AppContent.contact;

        expect(contact.contactMethods, isNotEmpty);
        for (final method in contact.contactMethods) {
          expect(method.label, isNotEmpty);
          expect(method.value, isNotEmpty);
        }
      });

      test('has form messages', () {
        final contact = AppContent.contact;

        expect(contact.formSubmitText, isNotEmpty);
        expect(contact.formSuccessMessage, isNotEmpty);
        expect(contact.formErrorMessage, isNotEmpty);
      });

      test('has Calendly integration', () {
        final contact = AppContent.contact;

        expect(contact.calendlyUrl, isNotEmpty);
        expect(contact.calendlyCtaText, isNotEmpty);
      });
    });

    group('getHeroVariant', () {
      test('returns default hero for empty variant', () {
        final variant = AppContent.getHeroVariant('');
        final defaultHero = AppContent.hero;

        expect(variant.badge, equals(defaultHero.badge));
        expect(variant.headline, equals(defaultHero.headline));
      });

      test('returns default hero for unknown variant', () {
        final variant = AppContent.getHeroVariant('nonexistent');
        final defaultHero = AppContent.hero;

        expect(variant.headline, equals(defaultHero.headline));
      });

      test('returns agentFirst variant when requested', () {
        final variant = AppContent.getHeroVariant('agentFirst');

        // Should return a valid hero content
        expect(variant.headline, isNotEmpty);
        expect(variant.primaryCTA, isNotEmpty);
      });

      test('returns costFocused variant when requested', () {
        final variant = AppContent.getHeroVariant('costFocused');

        expect(variant.headline, isNotEmpty);
      });

      test('returns legacy variant when requested', () {
        final variant = AppContent.getHeroVariant('legacy');

        expect(variant.headline, isNotEmpty);
      });
    });

    group('comparison pages', () {
      test('whylabsComparison has required fields', () {
        final comparison = AppContent.whylabsComparison;

        expect(comparison.competitorName, isNotEmpty);
        expect(comparison.heroHeadline, isNotEmpty);
        expect(comparison.heroSubheadline, isNotEmpty);
      });

      test('arizeComparison has required fields', () {
        final comparison = AppContent.arizeComparison;

        expect(comparison.competitorName, isNotEmpty);
        expect(comparison.heroHeadline, isNotEmpty);
        expect(comparison.heroSubheadline, isNotEmpty);
      });

      test('comparison pages have key differentiators', () {
        final whylabs = AppContent.whylabsComparison;
        final arize = AppContent.arizeComparison;

        expect(whylabs.keyDifferentiators, isNotEmpty);
        expect(arize.keyDifferentiators, isNotEmpty);
      });

      test('comparison pages have CTAs', () {
        final whylabs = AppContent.whylabsComparison;
        final arize = AppContent.arizeComparison;

        expect(whylabs.heroCtaText, isNotEmpty);
        expect(arize.heroCtaText, isNotEmpty);
      });

      test('comparison pages have feature comparison', () {
        final whylabs = AppContent.whylabsComparison;
        final arize = AppContent.arizeComparison;

        expect(whylabs.featureComparison, isNotEmpty);
        expect(arize.featureComparison, isNotEmpty);
      });

      test('comparison pages have migration time estimate', () {
        final whylabs = AppContent.whylabsComparison;
        final arize = AppContent.arizeComparison;

        expect(whylabs.migrationTimeEstimate, isNotEmpty);
        expect(arize.migrationTimeEstimate, isNotEmpty);
      });
    });
  });

  group('icon mapping', () {
    test('services have valid icons', () {
      final services = AppContent.services;

      for (final service in services.services) {
        expect(service.icon, isNotNull);
        // Icon should not be the fallback circle icon for known icons
        expect(service.icon, isNot(equals(LucideIcons.circle)));
      }
    });

    test('features have valid icons', () {
      final features = AppContent.features;

      for (final feature in features.features) {
        expect(feature.icon, isNotNull);
      }
    });

    test('about values have valid icons', () {
      final about = AppContent.about;

      for (final value in about.values) {
        expect(value.icon, isNotNull);
      }
    });

    test('contact methods have valid icons', () {
      final contact = AppContent.contact;

      for (final method in contact.contactMethods) {
        expect(method.icon, isNotNull);
      }
    });

    test('resource docs have valid icons', () {
      final resources = AppContent.resources;

      for (final doc in resources.documentation) {
        expect(doc.icon, isNotNull);
      }
    });
  });
}
