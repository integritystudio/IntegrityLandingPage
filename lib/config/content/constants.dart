/// Shared constants used across content configuration.
///
/// DRY principle: Define once, use everywhere.
/// Update these values in one place to change them across the entire app.
library;

import '../../services/content_loader.dart';

// =============================================================================
// COMPANY INFORMATION
// =============================================================================

/// Core company branding and identity constants.
abstract final class CompanyInfo {
  static const String name = 'Integrity Studio';
  static const String tagline = 'AI Observability That Proves Compliance';
  static String get copyright => '\u00A9 ${DateTime.now().year} Integrity Studio. All rights reserved.';
  static const String foundedYear = '2025';
  static const String locationCity = 'Austin';
  static const String locationRegion = 'Texas';
  static const String email = 'hello@integritystudio.ai';
  static const String phone = '(512) 829-1644';
}

// =============================================================================
// CALL-TO-ACTION STRINGS
// =============================================================================

/// Standardized CTA button text used across the application.
abstract final class CTAText {
  // Primary CTAs
  static const String startFreeTrial = 'Start Free Trial';
  static const String getStarted = 'Get Started';
  static const String scheduledDemo = 'Schedule Demo';
  static const String requestDemo = 'Request Demo';
  static const String contactSales = 'Contact Sales';
  static const String learnMore = 'Learn More';

  // Navigation CTAs
  static const String backToHome = 'Back to Home';
  static const String viewAll = 'View All';
  static const String viewDocs = 'View Documentation';

  // Form CTAs
  static const String sendMessage = 'Send Message';
  static const String downloadNow = 'Download Now';
  static const String calculateSavings = 'Calculate Savings';
}

// =============================================================================
// EXTERNAL URLS
// =============================================================================

/// External URLs and links used throughout the application.
/// Values with content.yaml equivalents are loaded via [Content];
/// the rest are defined as constants here.
abstract final class ExternalUrls {
  // Calendly (from content.yaml: urls.external.calendly_demo / calendly_intro)
  static String get calendlyDemo => Content.calendlyUrl;
  static String get calendlyIntro => Content.calendlyIntroUrl;

  // Status page (from content.yaml: urls.external.status_page)
  static String get statusPage => Content.statusPageUrl;

  // Documentation
  static const String euAiAct = 'https://integritystudio.ai/docs/tracing#eu-ai-act';

  // Social media (from content.yaml: urls.external.linkedin / github)
  static String get linkedIn => Content.linkedInUrl;
  static String get github => Content.githubUrl;

  // Personal (from content.yaml: urls.external.founder_linkedin)
  static String get founderLinkedIn => Content.founderLinkedInUrl;

  // Calendly deep dive (from content.yaml: urls.external.deep_dive)
  static String get calendlyDeepDive => Content.deepDiveUrl;

  // Location (from content.yaml: urls.external.address)
  static String get googleMaps => Content.addressUrl;
}

// =============================================================================
// INTERNAL ROUTES
// =============================================================================

/// Internal route paths for navigation.
abstract final class Routes {
  // Main pages
  static const String home = '/';
  static const String blog = '/blog';
  static const String docs = '/docs';
  static const String pricing = '/pricing';
  static const String about = '/about';
  static const String contact = '/contact';
  static const String signup = '/signup';
  static const String signupTeam = '/signup?tier=Team';

  // Feature pages
  static const String features = '/features';

  // Anchor sections
  static const String pricingSection = '#pricing';
  static const String services = '#services';
  static const String demo = '/demo';

  // Documentation
  static const String docsObservability = '/docs/llm-observability';
  static const String docsTracing = '/docs/tracing';
  static const String docsQuickstart = '/docs/quickstart';
  static const String docsCompliance = '/compliance';
  static const String docsIntegrations = '/docs/integrations';
  static const String docsAgents = '/docs/agents';
  static const String docsAlerts = '/docs/alerts';

  // Resources
  static const String api = '/api';
  static const String careers = '/careers';
  static const String privacy = '/privacy';
  static const String terms = '/terms';
  static const String cookies = '/cookies';
  static const String accessibility = '/accessibility';
  static const String security = '/security';
  static const String status = '/status';

  // Comparison pages
  static const String whylabsAlternative = '/whylabs-alternative';
  static const String arizeAlternative = '/compare/arize-ai-alternative';

  // Information pages
  static const String sources = '/sources';
}

// =============================================================================
// TRUST INDICATORS & SOCIAL PROOF
// =============================================================================

/// Standard trust indicators displayed throughout the site.
/// NOTE: Keep in sync with content.yaml trust_indicators.current
abstract final class TrustIndicators {
  /// Current production trust indicators (EU AI Act positioning)
  static const List<String> current = [
    'EU AI Act Ready',
    'Enterprise Security',
    '99.9% Uptime',
    '15-min Setup',
  ];

  /// Legacy trust indicators (trial-focused)
  static const List<String> legacy = [
    'No credit card required',
    '14-day free trial',
    'Cancel anytime',
  ];
}

// =============================================================================
// PLATFORM METRICS
// =============================================================================

/// Platform performance and scale metrics for social proof.
/// Platform performance and scale metrics.
/// Values loaded from content.yaml: platform_metrics.*
abstract final class PlatformMetrics {
  static String get uptime => Content.metricsUptime;
  static String get uptimeSla => Content.metricsUptimeSla;
  static String get tracesProcessed => Content.metricsTracesProcessed;
  static String get tracesProcessedPeriod => Content.metricsTracesProcessedPeriod;
  static String get aiTeams => Content.metricsAiTeams;
  static String get setupTime => Content.metricsSetupTime;
  static String get setupTimeLabel => Content.metricsSetupTimeLabel;
}

// =============================================================================
// PRICING CONSTANTS
// =============================================================================

/// Pricing-related constants.
abstract final class PricingConstants {
  static const String annualDiscount = 'Save 20%';
  static const String monthlyLabel = 'Monthly';
  static const String annualLabel = 'Annual';
  static const String enterpriseNote = 'Need custom solutions? ';
  static const String enterpriseLink = 'Contact our sales team';

  // Free tier limits
  static const String freeTracesLimit = '50K traces/month';
  static const String freeRetention = '7-day retention';

  // Team tier limits
  static const String teamTracesLimit = '500K traces/month';
  static const String teamRetention = '30-day retention';

  // Enterprise
  static const String unlimitedTraces = 'Unlimited traces';
  static const String enterpriseRetention = '1-year retention';
}

// =============================================================================
// FORM MESSAGES
// =============================================================================

/// Standard form success/error messages.
abstract final class FormMessages {
  static const String contactSuccess =
      "Thank you for reaching out! We'll get back to you within one business day.";
  static const String contactError =
      'Something went wrong. Please try again or email us directly at ${CompanyInfo.email}';
  static const String subscribeSuccess = 'Thanks for subscribing!';
  static const String subscribeError = 'Could not subscribe. Please try again.';
}

// =============================================================================
// COMPLIANCE DISCLAIMERS
// =============================================================================

/// Legal disclaimers for compliance messaging.
abstract final class ComplianceDisclaimers {
  /// EU AI Act compliance disclaimer (full version).
  static const String euAiAct =
      'Integrity Studio provides tools designed to support EU AI Act compliance efforts. '
      'Actual compliance requires independent legal review, third-party assessment, and '
      'organization-specific implementation. This platform does not constitute legal advice '
      'or guarantee regulatory compliance.';

  /// Security disclaimer.
  static const String security =
      'Security certifications in progress. Current measures include encryption at rest '
      'and in transit, regular penetration testing, and adherence to OWASP guidelines.';

  /// Human oversight disclaimer.
  static const String humanOversight =
      'Human oversight tools provide technical infrastructure for approval workflows. '
      'Organizations are responsible for defining oversight policies, training reviewers, '
      'and ensuring meaningful human review of AI decisions.';

  /// General platform disclaimer for footer.
  static const String general =
      'This platform provides tools to support AI governance and observability. '
      'It does not guarantee regulatory compliance or constitute legal advice.';

  /// Short version for inline use.
  static const String euAiActShort = 'Tools to support EU AI Act compliance efforts.';
}

// =============================================================================
// CITED STATISTICS
// =============================================================================

/// Type of statistic for appropriate attribution display.
enum StatisticType {
  /// From industry reports (requires external citation)
  industry,

  /// From internal customer data (aggregated, anonymized)
  customerData,

  /// Platform metrics (internal measurement)
  platformMetric,

  /// Service level target (not a measured statistic)
  slaTarget,
}

/// A statistic with source attribution.
class CitedStatistic {
  final String value;
  final String label;
  final String source;
  final String? sourceUrl;
  final StatisticType type;

  const CitedStatistic({
    required this.value,
    required this.label,
    required this.source,
    this.sourceUrl,
    this.type = StatisticType.industry,
  });
}

/// Centralized statistics with source citations.
///
/// IMPORTANT: All statistics MUST be verifiable.
/// Statistics are loaded from content.yaml at runtime.
abstract final class AppStatistics {
  // Market Statistics (Industry Reports) - loaded from content.yaml
  static CitedStatistic get marketSize => CitedStatistic(
    value: Content.statisticsMarketSizeValue,
    label: Content.statisticsMarketSizeLabel,
    source: Content.statisticsMarketSizeSource,
    sourceUrl: Content.statisticsMarketSizeSourceUrl,
    type: StatisticType.industry,
  );

  static CitedStatistic get marketGrowth => CitedStatistic(
    value: Content.statisticsMarketGrowthValue,
    label: Content.statisticsMarketGrowthLabel,
    source: Content.statisticsMarketGrowthSource,
    sourceUrl: Content.statisticsMarketGrowthSourceUrl,
    type: StatisticType.industry,
  );

  static CitedStatistic get enterpriseBudgets => CitedStatistic(
    value: Content.statisticsEnterpriseBudgetsValue,
    label: Content.statisticsEnterpriseBudgetsLabel,
    source: Content.statisticsEnterpriseBudgetsSource,
    sourceUrl: Content.statisticsEnterpriseBudgetsSourceUrl,
    type: StatisticType.industry,
  );

  // Customer Results (Aggregated Internal Data) - loaded from content.yaml
  static CitedStatistic get debuggingImprovement => CitedStatistic(
    value: Content.statisticsDebuggingValue,
    label: Content.statisticsDebuggingLabel,
    source: Content.statisticsDebuggingSource,
    type: StatisticType.customerData,
  );

  static CitedStatistic get costReduction => CitedStatistic(
    value: Content.statisticsCostReductionValue,
    label: Content.statisticsCostReductionLabel,
    source: Content.statisticsCostReductionSource,
    type: StatisticType.customerData,
  );

  // Platform Metrics - loaded from content.yaml
  static CitedStatistic get tracesProcessed => CitedStatistic(
    value: Content.statisticsTracesValue,
    label: Content.statisticsTracesLabel,
    source: Content.statisticsTracesSource,
    type: StatisticType.platformMetric,
  );

  static CitedStatistic get setupTime => CitedStatistic(
    value: Content.statisticsSetupTimeValue,
    label: Content.statisticsSetupTimeLabel,
    source: Content.statisticsSetupTimeSource,
    type: StatisticType.platformMetric,
  );

  // SLA Targets - loaded from content.yaml
  static CitedStatistic get uptimeTarget => CitedStatistic(
    value: Content.statisticsUptimeValue,
    label: Content.statisticsUptimeLabel,
    source: Content.statisticsUptimeSource,
    type: StatisticType.slaTarget,
  );

  /// Footer disclaimer for statistics - loaded from content.yaml.
  static String get sourceDisclaimer => Content.statisticsSourceDisclaimer;

  /// Get all industry statistics.
  static List<CitedStatistic> get industryStats => [
        marketSize,
        marketGrowth,
        enterpriseBudgets,
      ];

  /// Get all customer result statistics.
  static List<CitedStatistic> get customerStats => [
        debuggingImprovement,
        costReduction,
      ];
}

// =============================================================================
// CONTENT VARIANTS (A/B Testing)
// =============================================================================

/// A/B test variant identifiers.
abstract final class ContentVariants {
  static const String current = 'current';
  static const String legacy = 'legacy';
  static const String agentFirst = 'agent-first';
  static const String costFocused = 'cost-focused';
}
