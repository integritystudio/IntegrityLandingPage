/// Centralized content configuration for the application.
///
/// This is the main barrel file that exports all content modules.
/// Import this file to access all content models and instances.
///
/// ## Architecture
///
/// Content is loaded from content.yaml at runtime and converted to typed models.
///
/// ## Usage
///
/// ```dart
/// import 'package:integrity_studio_ai/config/content.dart';
///
/// // Access current content via AppContent
/// final hero = AppContent.hero;
/// final pricing = AppContent.pricing;
/// ```
library;

// Exports (must come before declarations)
export 'content/models.dart';
export 'content/constants.dart';
export 'content/comparison_content.dart';
export 'content/security_content.dart';
export 'content/legal_content.dart';
export 'content/features_content.dart';
export 'content/status_content.dart';
export 'content/blog_content.dart';
export 'content/contact_content.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/content_loader.dart';
import 'content/constants.dart';
import 'content/models.dart';
import 'content/comparison_content.dart';

// =============================================================================
// ICON MAPPING
// =============================================================================

/// Maps icon names from YAML to LucideIcons.
IconData _iconFromString(String? iconName) {
  return switch (iconName) {
    'activity' => LucideIcons.activity,
    'git-branch' => LucideIcons.gitBranch,
    'clipboard-check' => LucideIcons.clipboardCheck,
    'shield' => LucideIcons.shield,
    'shield-check' => LucideIcons.shieldCheck,
    'bar-chart-3' => LucideIcons.barChart3,
    'alert-triangle' => LucideIcons.alertTriangle,
    'bot' => LucideIcons.bot,
    'bell' => LucideIcons.bell,
    'code' => LucideIcons.code,
    'code-2' => LucideIcons.code2,
    'eye' => LucideIcons.eye,
    'users' => LucideIcons.users,
    'scale' => LucideIcons.scale,
    'mail' => LucideIcons.mail,
    'calendar' => LucideIcons.calendar,
    'map-pin' => LucideIcons.mapPin,
    'linkedin' => LucideIcons.briefcase,
    'github' => LucideIcons.code,
    'book-open' => LucideIcons.bookOpen,
    'puzzle' => LucideIcons.puzzle,
    'calculator' => LucideIcons.calculator,
    'file-text' => LucideIcons.fileText,
    'zap' => LucideIcons.zap,
    _ => LucideIcons.circle,
  };
}

// =============================================================================
// CONTENT MANAGER
// =============================================================================

/// Centralized content manager providing access to content from YAML.
///
/// Usage:
/// ```dart
/// final heroContent = AppContent.hero;
/// final pricingContent = AppContent.pricing;
/// ```
abstract final class AppContent {
  /// Current hero section content
  static HeroContent get hero => HeroContent(
        badge: ContentLoader.heroBadge,
        headline: ContentLoader.heroHeadline,
        subheadline: ContentLoader.heroSubheadline,
        primaryCTA: ContentLoader.heroPrimaryCta,
        secondaryCTA: ContentLoader.heroSecondaryCta,
        trustIndicators: ContentLoader.trustIndicators,
      );

  /// Current pricing section content
  static PricingContent get pricing => PricingContent(
        title: ContentLoader.pricingTitle,
        subtitle: ContentLoader.pricingSubtitle,
        monthlyLabel: 'Monthly',
        annualLabel: 'Annual',
        annualBadge: ContentLoader.pricingAnnualDiscount,
        tiers: ContentLoader.pricingTiers.map((tier) {
          return PricingTierContent(
            name: tier['name'] as String? ?? '',
            monthlyPrice: tier['monthly_price'] as String? ?? '',
            annualPrice: tier['annual_price'] as String? ?? '',
            period: tier['period'] as String?,
            description: tier['description'] as String?,
            features: (tier['features'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            isPopular: tier['is_popular'] as bool? ?? false,
            ctaText: tier['cta_text'] as String? ?? '',
          );
        }).toList(),
      );

  /// Current features section content
  static FeaturesContent get features => FeaturesContent(
        title: ContentLoader.featuresTitle,
        subtitle: ContentLoader.featuresSubtitle,
        features: ContentLoader.featuresItems.map((item) {
          return FeatureCardContent(
            icon: _iconFromString(item['icon'] as String?),
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            bullets: (item['bullets'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          );
        }).toList(),
      );

  /// Current CTA section content
  static CTAContent get cta => CTAContent(
        headline: ContentLoader.ctaSectionHeadline,
        subheadline: ContentLoader.ctaSectionSubheadline,
        primaryCTA: ContentLoader.ctaStartFreeTrial,
        secondaryCTA: ContentLoader.ctaScheduleDemo,
      );

  /// Current social proof content
  static SocialProofContent get socialProof => SocialProofContent(
        title: ContentLoader.socialProofTitle,
        logos: const [
          CustomerLogoContent(name: 'Enterprise Client', industry: 'Finance'),
          CustomerLogoContent(name: 'Tech Startup', industry: 'SaaS'),
          CustomerLogoContent(name: 'Healthcare Co', industry: 'Healthcare'),
        ],
        testimonials: ContentLoader.socialProofTestimonials.map((t) {
          return TestimonialContent(
            quote: t['quote'] as String? ?? '',
            author: t['author'] as String? ?? '',
            role: t['role'] as String? ?? '',
            company: t['company'] as String? ?? '',
            metric: t['metric'] as String?,
            metricContext: t['metric_context'] as String?,
          );
        }).toList(),
        statsHeadline: 'Enterprise-Grade Performance',
        stats: ContentLoader.socialProofStats,
      );

  /// Current status section content
  static StatusContent get status => StatusContent(
        title: ContentLoader.statusTitle,
        subtitle: ContentLoader.statusSubtitle,
        statusBadge: ContentLoader.statusBadge,
        allOperational: true,
        metrics: ContentLoader.statusMetrics.map((m) {
          return StatusMetricContent(
            label: m['label'] as String? ?? '',
            value: m['value'] as String? ?? '',
            sublabel: m['sublabel'] as String?,
          );
        }).toList(),
        services: ContentLoader.statusServices.map((s) {
          return StatusServiceContent(
            name: s['name'] as String? ?? '',
            status: s['status'] as String? ?? 'Operational',
          );
        }).toList(),
        statusPageUrl: ContentLoader.statusPageUrl,
        statusPageCta: 'View Full Status Page',
      );

  /// Current footer content
  static FooterContent get footer => FooterContent(
        companyName: ContentLoader.companyName,
        tagline: ContentLoader.companyTagline,
        copyright: ContentLoader.companyCopyright,
        linkGroups: ContentLoader.footerLinkGroups.map((group) {
          return FooterLinkGroup(
            title: group['title'] as String? ?? '',
            links: ((group['links'] as List?) ?? []).map((link) {
              final linkMap = link as Map<String, dynamic>;
              return FooterLink(
                label: linkMap['label'] as String? ?? '',
                url: linkMap['url'] as String? ?? '',
                isExternal: linkMap['is_external'] as bool? ?? false,
              );
            }).toList(),
          );
        }).toList(),
        privacyLink: ContentLoader.footerPrivacyLink,
        termsLink: ContentLoader.footerTermsLink,
        cookiesLink: ContentLoader.footerCookiesLink,
        accessibilityLink: '/accessibility',
        cookieSettingsLabel: 'Cookie Settings',
      );

  /// Current services section content
  static ServicesContent get services => ServicesContent(
        sectionId: 'services',
        title: ContentLoader.servicesTitle,
        subtitle: ContentLoader.servicesSubtitle,
        description: ContentLoader.servicesDescription,
        services: ContentLoader.servicesItems.map((item) {
          return ServiceItemContent(
            icon: _iconFromString(item['icon'] as String?),
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            capabilities: (item['capabilities'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            ctaText: item['cta_text'] as String?,
            ctaUrl: item['cta_url'] as String?,
            disclaimer: item['disclaimer'] as String?,
          );
        }).toList(),
        ctaText: ContentLoader.ctaStartFreeTrial,
        ctaUrl: Routes.signupGrowth,
      );

  /// Current about section content
  static AboutContent get about => AboutContent(
        sectionId: 'about',
        title: ContentLoader.aboutTitle,
        subtitle: ContentLoader.aboutSubtitle,
        missionStatement: ContentLoader.aboutMission,
        visionStatement: ContentLoader.aboutVision,
        story: ContentLoader.aboutStory,
        values: ContentLoader.aboutValues.map((v) {
          return CompanyValueContent(
            icon: _iconFromString(v['icon'] as String?),
            title: v['title'] as String? ?? '',
            description: v['description'] as String? ?? '',
          );
        }).toList(),
        team: ContentLoader.aboutTeam.map((t) {
          return TeamMemberContent(
            name: t['name'] as String? ?? '',
            role: t['role'] as String? ?? '',
            bio: t['bio'] as String? ?? '',
            linkedInUrl: t['linkedin_url'] as String?,
          );
        }).toList(),
        locationCity: ContentLoader.companyCity,
        locationRegion: ContentLoader.companyRegion,
        foundedYear: ContentLoader.companyFoundedYear,
      );

  /// Current resources section content
  static ResourcesContent get resources => ResourcesContent(
        sectionId: 'resources',
        title: ContentLoader.resourcesTitle,
        subtitle: ContentLoader.resourcesSubtitle,
        documentation: ContentLoader.resourcesDocumentation.map((d) {
          return DocCategoryContent(
            icon: _iconFromString(d['icon'] as String?),
            title: d['title'] as String? ?? '',
            description: d['description'] as String? ?? '',
            url: d['url'] as String? ?? '',
            popularTopics: (d['popular_topics'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          );
        }).toList(),
        featuredPosts: ContentLoader.resourcesFeaturedPosts.map((p) {
          return BlogPostPreviewContent(
            title: p['title'] as String? ?? '',
            excerpt: p['excerpt'] as String? ?? '',
            category: p['category'] as String? ?? '',
            publishDate: p['publish_date'] as String? ?? '',
            readTime: p['read_time'] as String? ?? '',
            slug: p['slug'] as String? ?? '',
            author: p['author'] as String?,
          );
        }).toList(),
        leadMagnets: ContentLoader.resourcesLeadMagnets.map((l) {
          return LeadMagnetContent(
            icon: _iconFromString(l['icon'] as String?),
            title: l['title'] as String? ?? '',
            description: l['description'] as String? ?? '',
            format: l['format'] as String? ?? '',
            ctaText: l['cta_text'] as String? ?? '',
            url: l['url'] as String? ?? '',
            requiresEmail: l['requires_email'] as bool? ?? true,
          );
        }).toList(),
        blogCtaText: 'View All Articles',
        blogCtaUrl: '/blog',
        docsCtaText: 'Browse Documentation',
        docsCtaUrl: '/docs',
      );

  /// Current contact section content
  static ContactContent get contact => ContactContent(
        sectionId: 'contact',
        title: ContentLoader.contactTitle,
        subtitle: ContentLoader.contactSubtitle,
        description: ContentLoader.contactDescription,
        formFields: ContentLoader.contactFormFields.map((f) {
          return ContactFormFieldContent(
            name: f['name'] as String? ?? '',
            label: f['label'] as String? ?? '',
            placeholder: f['placeholder'] as String? ?? '',
            type: f['type'] as String? ?? 'text',
            required: f['required'] as bool? ?? false,
            options: (f['options'] as List?)?.map((e) => e.toString()).toList(),
          );
        }).toList(),
        contactMethods: ContentLoader.contactMethods.map((m) {
          return ContactMethodContent(
            icon: _iconFromString(m['icon'] as String?),
            label: m['label'] as String? ?? '',
            value: m['value'] as String? ?? '',
            url: m['url'] as String?,
            isPrimary: m['is_primary'] as bool? ?? false,
          );
        }).toList(),
        formSubmitText: ContentLoader.ctaSendMessage,
        formSuccessMessage: ContentLoader.contactSuccessMessage,
        formErrorMessage: ContentLoader.contactErrorMessage,
        calendlyUrl: ContentLoader.calendlyUrl,
        calendlyCtaText: ContentLoader.ctaScheduleDemo,
      );

  /// Get hero content variant by name (for A/B testing)
  static HeroContent getHeroVariant(String variant) {
    final v = ContentLoader.getHeroVariant(variant);
    if (v.isEmpty) return hero;

    return HeroContent(
      badge: v['badge'] as String? ?? '',
      headline: v['headline'] as String? ?? '',
      subheadline: v['subheadline'] as String? ?? '',
      primaryCTA: v['primary_cta'] as String? ?? '',
      secondaryCTA: v['secondary_cta'] as String? ?? '',
      trustIndicators: ContentLoader.trustIndicators,
    );
  }

  /// WhyLabs comparison page content
  static ComparisonPageContent get whylabsComparison =>
      ComparisonPageVariants.whylabs;

  /// Arize AI comparison page content
  static ComparisonPageContent get arizeComparison =>
      ComparisonPageVariants.arize;
}

