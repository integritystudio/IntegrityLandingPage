/// Content data models for the application.
///
/// These are pure data classes without static content instances.
/// Content instances are defined in their respective content files.
library;

import 'package:flutter/material.dart';

// =============================================================================
// HERO SECTION MODELS
// =============================================================================

/// Hero section content model.
@immutable
class HeroContent {
  final String badge;
  final String headline;
  final String subheadline;
  final String primaryCTA;
  final String secondaryCTA;
  final List<String> trustIndicators;

  const HeroContent({
    required this.badge,
    required this.headline,
    required this.subheadline,
    required this.primaryCTA,
    required this.secondaryCTA,
    required this.trustIndicators,
  });
}

// =============================================================================
// PRICING SECTION MODELS
// =============================================================================

/// Pricing tier data model.
@immutable
class PricingTierContent {
  final String name;
  final String monthlyPrice;
  final String annualPrice;
  final String? period;
  final String? description;
  final List<String> features;
  final bool isPopular;
  final String ctaText;

  const PricingTierContent({
    required this.name,
    required this.monthlyPrice,
    required this.annualPrice,
    this.period,
    this.description,
    required this.features,
    this.isPopular = false,
    required this.ctaText,
  });
}

/// Pricing section content model.
@immutable
class PricingContent {
  final String title;
  final String subtitle;
  final String monthlyLabel;
  final String annualLabel;
  final String annualBadge;
  final String enterpriseNote;
  final String enterpriseLink;
  final List<PricingTierContent> tiers;

  const PricingContent({
    required this.title,
    required this.subtitle,
    required this.monthlyLabel,
    required this.annualLabel,
    required this.annualBadge,
    required this.enterpriseNote,
    required this.enterpriseLink,
    required this.tiers,
  });
}

// =============================================================================
// FEATURES SECTION MODELS
// =============================================================================

/// Feature card data model.
@immutable
class FeatureCardContent {
  final IconData icon;
  final String title;
  final String description;
  final List<String> bullets;

  const FeatureCardContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.bullets,
  });
}

/// Features section content model.
@immutable
class FeaturesContent {
  final String title;
  final String subtitle;
  final List<FeatureCardContent> features;

  const FeaturesContent({
    required this.title,
    required this.subtitle,
    required this.features,
  });
}

// =============================================================================
// CTA SECTION MODELS
// =============================================================================

/// CTA section content model.
@immutable
class CTAContent {
  final String headline;
  final String subheadline;
  final String primaryCTA;
  final String secondaryCTA;

  const CTAContent({
    required this.headline,
    required this.subheadline,
    required this.primaryCTA,
    required this.secondaryCTA,
  });
}

// =============================================================================
// SOCIAL PROOF MODELS
// =============================================================================

/// Customer logo for social proof.
@immutable
class CustomerLogoContent {
  final String name;
  final String? logoAsset;
  final String? industry;

  const CustomerLogoContent({
    required this.name,
    this.logoAsset,
    this.industry,
  });
}

/// Testimonial content.
@immutable
class TestimonialContent {
  final String quote;
  final String author;
  final String role;
  final String company;
  final String? avatarAsset;
  final String? metric;
  final String? metricContext;

  const TestimonialContent({
    required this.quote,
    required this.author,
    required this.role,
    required this.company,
    this.avatarAsset,
    this.metric,
    this.metricContext,
  });
}

/// Social proof section content.
@immutable
class SocialProofContent {
  final String title;
  final List<CustomerLogoContent> logos;
  final List<TestimonialContent> testimonials;
  final String? statsHeadline;
  final Map<String, String>? stats;

  const SocialProofContent({
    required this.title,
    required this.logos,
    required this.testimonials,
    this.statsHeadline,
    this.stats,
  });
}

// =============================================================================
// STATUS SECTION MODELS
// =============================================================================

/// Status metric item.
@immutable
class StatusMetricContent {
  final String label;
  final String value;
  final String? sublabel;
  final bool isOperational;

  const StatusMetricContent({
    required this.label,
    required this.value,
    this.sublabel,
    this.isOperational = true,
  });
}

/// Status service item.
@immutable
class StatusServiceContent {
  final String name;
  final String status;
  final bool isOperational;

  const StatusServiceContent({
    required this.name,
    required this.status,
    this.isOperational = true,
  });
}

/// Status section content.
@immutable
class StatusContent {
  final String title;
  final String subtitle;
  final String statusBadge;
  final bool allOperational;
  final List<StatusMetricContent> metrics;
  final List<StatusServiceContent> services;
  final String statusPageUrl;
  final String statusPageCta;

  const StatusContent({
    required this.title,
    required this.subtitle,
    required this.statusBadge,
    required this.allOperational,
    required this.metrics,
    required this.services,
    required this.statusPageUrl,
    required this.statusPageCta,
  });
}

// =============================================================================
// FOOTER MODELS
// =============================================================================

/// Footer link.
@immutable
class FooterLink {
  final String label;
  final String url;
  final bool isExternal;

  const FooterLink({
    required this.label,
    required this.url,
    this.isExternal = false,
  });
}

/// Footer link group.
@immutable
class FooterLinkGroup {
  final String title;
  final List<FooterLink> links;

  const FooterLinkGroup({
    required this.title,
    required this.links,
  });
}

/// Footer content.
@immutable
class FooterContent {
  final String companyName;
  final String tagline;
  final String copyright;
  final List<FooterLinkGroup> linkGroups;
  final String privacyLink;
  final String termsLink;
  final String cookiesLink;
  final String accessibilityLink;
  final String cookieSettingsLabel;

  const FooterContent({
    required this.companyName,
    required this.tagline,
    required this.copyright,
    required this.linkGroups,
    required this.privacyLink,
    required this.termsLink,
    required this.cookiesLink,
    required this.accessibilityLink,
    required this.cookieSettingsLabel,
  });
}

// =============================================================================
// SERVICES SECTION MODELS
// =============================================================================

/// Service item.
@immutable
class ServiceItemContent {
  final IconData icon;
  final String title;
  final String description;
  final List<String> capabilities;
  final String? ctaText;
  final String? ctaUrl;
  final String? disclaimer;

  const ServiceItemContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.capabilities,
    this.ctaText,
    this.ctaUrl,
    this.disclaimer,
  });
}

/// Services section content.
@immutable
class ServicesContent {
  final String sectionId;
  final String title;
  final String subtitle;
  final String description;
  final List<ServiceItemContent> services;
  final String ctaText;
  final String ctaUrl;

  const ServicesContent({
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.services,
    required this.ctaText,
    required this.ctaUrl,
  });
}

// =============================================================================
// ABOUT SECTION MODELS
// =============================================================================

/// Team member profile.
@immutable
class TeamMemberContent {
  final String name;
  final String role;
  final String bio;
  final String? avatarAsset;
  final String? imageAlt;
  final String? linkedInUrl;
  final String? xUrl;
  final String? githubUrl;
  final String? websiteUrl;

  const TeamMemberContent({
    required this.name,
    required this.role,
    required this.bio,
    this.avatarAsset,
    this.imageAlt,
    this.linkedInUrl,
    this.xUrl,
    this.githubUrl,
    this.websiteUrl,
  });
}

/// Company value.
@immutable
class CompanyValueContent {
  final IconData icon;
  final String title;
  final String description;

  const CompanyValueContent({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// About section content.
@immutable
class AboutContent {
  final String sectionId;
  final String title;
  final String subtitle;
  final String missionStatement;
  final String visionStatement;
  final String story;
  final List<CompanyValueContent> values;
  final List<TeamMemberContent> team;
  final String locationCity;
  final String locationRegion;
  final String foundedYear;

  const AboutContent({
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.missionStatement,
    required this.visionStatement,
    required this.story,
    required this.values,
    required this.team,
    required this.locationCity,
    required this.locationRegion,
    required this.foundedYear,
  });
}

// =============================================================================
// RESOURCES SECTION MODELS
// =============================================================================

/// Blog post preview.
@immutable
class BlogPostPreviewContent {
  final String title;
  final String excerpt;
  final String category;
  final String publishDate;
  final String readTime;
  final String slug;
  final String? featuredImageAsset;
  final String? author;

  const BlogPostPreviewContent({
    required this.title,
    required this.excerpt,
    required this.category,
    required this.publishDate,
    required this.readTime,
    required this.slug,
    this.featuredImageAsset,
    this.author,
  });
}

/// Documentation category.
@immutable
class DocCategoryContent {
  final IconData icon;
  final String title;
  final String description;
  final String url;
  final List<String> popularTopics;

  const DocCategoryContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.url,
    required this.popularTopics,
  });
}

/// Lead magnet/downloadable resource.
@immutable
class LeadMagnetContent {
  final IconData icon;
  final String title;
  final String description;
  final String format;
  final String ctaText;
  final String url;
  final bool requiresEmail;

  const LeadMagnetContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.format,
    required this.ctaText,
    required this.url,
    this.requiresEmail = true,
  });
}

/// Resources section content.
@immutable
class ResourcesContent {
  final String sectionId;
  final String title;
  final String subtitle;
  final List<DocCategoryContent> documentation;
  final List<BlogPostPreviewContent> featuredPosts;
  final List<LeadMagnetContent> leadMagnets;
  final String blogCtaText;
  final String blogCtaUrl;
  final String docsCtaText;
  final String docsCtaUrl;

  const ResourcesContent({
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.documentation,
    required this.featuredPosts,
    required this.leadMagnets,
    required this.blogCtaText,
    required this.blogCtaUrl,
    required this.docsCtaText,
    required this.docsCtaUrl,
  });
}

// =============================================================================
// CONTACT SECTION MODELS
// =============================================================================

/// Contact form field.
@immutable
class ContactFormFieldContent {
  final String name;
  final String label;
  final String placeholder;
  final String type;
  final bool required;
  final List<String>? options;

  const ContactFormFieldContent({
    required this.name,
    required this.label,
    required this.placeholder,
    required this.type,
    this.required = false,
    this.options,
  });
}

/// Contact method.
@immutable
class ContactMethodContent {
  final IconData icon;
  final String label;
  final String value;
  final String? url;
  final bool isPrimary;

  const ContactMethodContent({
    required this.icon,
    required this.label,
    required this.value,
    this.url,
    this.isPrimary = false,
  });
}

/// Contact section content.
@immutable
class ContactContent {
  final String sectionId;
  final String title;
  final String subtitle;
  final String description;
  final List<ContactFormFieldContent> formFields;
  final List<ContactMethodContent> contactMethods;
  final String formSubmitText;
  final String formSuccessMessage;
  final String formErrorMessage;
  final String calendlyUrl;
  final String calendlyCtaText;

  const ContactContent({
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.formFields,
    required this.contactMethods,
    required this.formSubmitText,
    required this.formSuccessMessage,
    required this.formErrorMessage,
    required this.calendlyUrl,
    required this.calendlyCtaText,
  });
}

// =============================================================================
// COMPARISON PAGE MODELS
// =============================================================================

/// Feature comparison item.
@immutable
class ComparisonFeature {
  final String feature;
  final String? ourValue;
  final String? theirValue;
  final bool ourSupport;
  final bool theirSupport;

  const ComparisonFeature({
    required this.feature,
    this.ourValue,
    this.theirValue,
    this.ourSupport = true,
    this.theirSupport = true,
  });
}

/// Migration step.
@immutable
class MigrationStep {
  final int number;
  final String title;
  final String description;
  final String? codeSnippet;
  final String? docsUrl;

  const MigrationStep({
    required this.number,
    required this.title,
    required this.description,
    this.codeSnippet,
    this.docsUrl,
  });
}

/// Comparison page content.
@immutable
class ComparisonPageContent {
  final String competitorName;
  final String pageTitle;
  final String metaDescription;
  final String heroHeadline;
  final String heroSubheadline;
  final String heroCtaText;
  final String? competitorStatus;
  final List<String> keyDifferentiators;
  final List<ComparisonFeature> featureComparison;
  final List<String> whyChooseUs;
  final List<String> whyChooseThem;
  final List<MigrationStep> migrationSteps;
  final String migrationTimeEstimate;
  final String? specialOfferBadge;
  final String? specialOfferText;

  const ComparisonPageContent({
    required this.competitorName,
    required this.pageTitle,
    required this.metaDescription,
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.heroCtaText,
    this.competitorStatus,
    required this.keyDifferentiators,
    required this.featureComparison,
    required this.whyChooseUs,
    required this.whyChooseThem,
    required this.migrationSteps,
    required this.migrationTimeEstimate,
    this.specialOfferBadge,
    this.specialOfferText,
  });
}
