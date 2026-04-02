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
  static const String locationRegionAbbrev = 'TX';
  static const String email = 'hello@integritystudio.ai';
  static const String privacyEmail = 'privacy@integritystudio.ai';
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
  static String get backToHome => ContentLoader.ctaBackToHome;
  static String get viewAll => ContentLoader.ctaViewAll;
  static String get viewDocs => ContentLoader.ctaViewDocs;

  // Careers CTAs
  static String get keepInTouch => ContentLoader.ctaKeepInTouch;

  // Form CTAs
  static String get sendMessage => ContentLoader.ctaSendMessage;
  static String get downloadNow => ContentLoader.ctaDownloadNow;
  static String get calculateSavings => ContentLoader.ctaCalculateSavings;
}

// =============================================================================
// EXTERNAL URLS
// =============================================================================

/// External URLs and links used throughout the application.
/// Values with content.yaml equivalents are loaded via [ContentLoader];
/// the rest are defined as constants here.
abstract final class ExternalUrls {
  // Calendly (from content.yaml: urls.external.calendly_demo / calendly_intro)
  static String get calendlyDemo => ContentLoader.calendlyUrl;
  static String get calendlyIntro => ContentLoader.calendlyIntroUrl;

  // Status page (from content.yaml: urls.external.status_page)
  static String get statusPage => ContentLoader.statusPageUrl;

  // Dashboard app (authenticated product)
  static const String dashboardApp = 'https://integritystudio.dev';

  // Documentation
  static const String euAiAct = 'https://integritystudio.ai/docs/tracing#eu-ai-act';

  // Social media (from content.yaml: urls.external.linkedin / github)
  static String get linkedIn => ContentLoader.linkedInUrl;
  static String get github => ContentLoader.githubUrl;

  // Personal (from content.yaml: urls.external.founder_linkedin)
  static String get founderLinkedIn => ContentLoader.founderLinkedInUrl;

  // Calendly deep dive (from content.yaml: urls.external.deep_dive)
  static String get calendlyDeepDive => ContentLoader.deepDiveUrl;

  // Location (from content.yaml: urls.external.address)
  static String get googleMaps => ContentLoader.addressUrl;
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
  static const String login = '/login';
  static const String provision = '/provision';
  static const String checkout = '/checkout';
  static const String checkoutSuccess = '/checkout-success';
  static const String senderHealth = '/health';
  static const String dashboard = '/dashboard';
  static const String billingStatus = '/billing';
  static const String usageSummary = '/usage';
  static const String entitlements = '/entitlements';
  static const String quotaStatus = '/quota';

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
  static String get uptime => ContentLoader.metricsUptime;
  static String get uptimeSla => ContentLoader.metricsUptimeSla;
  static String get tracesProcessed => ContentLoader.metricsTracesProcessed;
  static String get tracesProcessedPeriod => ContentLoader.metricsTracesProcessedPeriod;
  static String get aiTeams => ContentLoader.metricsAiTeams;
  static String get setupTime => ContentLoader.metricsSetupTime;
  static String get setupTimeLabel => ContentLoader.metricsSetupTimeLabel;
}

// =============================================================================
// PRICING CONSTANTS
// =============================================================================

/// Pricing-related constants.
abstract final class PricingConstants {
  static const String annualDiscount = 'Save 20%';
  static const String monthlyLabel = 'Monthly';
  static const String annualLabel = 'Annual';

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
// AUTHENTICATION CONSTRAINTS
// =============================================================================

/// Password validation constraints shared by client UI and auth logic.
abstract final class PasswordPolicy {
  static const int minLength = 8;
  static const int maxLength = 128;
}

// =============================================================================
// QUOTA THRESHOLDS
// =============================================================================

/// Ratio thresholds for quota/usage progress bar coloring.
///
/// Shared by UsageSummaryPage (_UsageBar, _DailyBarChartPainter) and
/// QuotaStatusPage (_QuotaRow) to ensure consistent color semantics.
abstract final class QuotaThresholds {
  /// At or above this ratio, show danger color (e.g. AppColors.error).
  static const double danger = 0.90;

  /// At or above this ratio (but below [danger]), show warning color.
  static const double warning = 0.75;
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
    value: ContentLoader.statisticsMarketSizeValue,
    label: ContentLoader.statisticsMarketSizeLabel,
    source: ContentLoader.statisticsMarketSizeSource,
    sourceUrl: ContentLoader.statisticsMarketSizeSourceUrl,
    type: StatisticType.industry,
  );

  static CitedStatistic get marketGrowth => CitedStatistic(
    value: ContentLoader.statisticsMarketGrowthValue,
    label: ContentLoader.statisticsMarketGrowthLabel,
    source: ContentLoader.statisticsMarketGrowthSource,
    sourceUrl: ContentLoader.statisticsMarketGrowthSourceUrl,
    type: StatisticType.industry,
  );

  static CitedStatistic get enterpriseBudgets => CitedStatistic(
    value: ContentLoader.statisticsEnterpriseBudgetsValue,
    label: ContentLoader.statisticsEnterpriseBudgetsLabel,
    source: ContentLoader.statisticsEnterpriseBudgetsSource,
    sourceUrl: ContentLoader.statisticsEnterpriseBudgetsSourceUrl,
    type: StatisticType.industry,
  );

  // Customer Results (Aggregated Internal Data) - loaded from content.yaml
  static CitedStatistic get debuggingImprovement => CitedStatistic(
    value: ContentLoader.statisticsDebuggingValue,
    label: ContentLoader.statisticsDebuggingLabel,
    source: ContentLoader.statisticsDebuggingSource,
    type: StatisticType.customerData,
  );

  static CitedStatistic get costReduction => CitedStatistic(
    value: ContentLoader.statisticsCostReductionValue,
    label: ContentLoader.statisticsCostReductionLabel,
    source: ContentLoader.statisticsCostReductionSource,
    type: StatisticType.customerData,
  );

  // Platform Metrics - loaded from content.yaml
  static CitedStatistic get tracesProcessed => CitedStatistic(
    value: ContentLoader.statisticsTracesValue,
    label: ContentLoader.statisticsTracesLabel,
    source: ContentLoader.statisticsTracesSource,
    type: StatisticType.platformMetric,
  );

  static CitedStatistic get setupTime => CitedStatistic(
    value: ContentLoader.statisticsSetupTimeValue,
    label: ContentLoader.statisticsSetupTimeLabel,
    source: ContentLoader.statisticsSetupTimeSource,
    type: StatisticType.platformMetric,
  );

  // SLA Targets - loaded from content.yaml
  static CitedStatistic get uptimeTarget => CitedStatistic(
    value: ContentLoader.statisticsUptimeValue,
    label: ContentLoader.statisticsUptimeLabel,
    source: ContentLoader.statisticsUptimeSource,
    type: StatisticType.slaTarget,
  );

  /// Footer disclaimer for statistics - loaded from content.yaml.
  static String get sourceDisclaimer => ContentLoader.statisticsSourceDisclaimer;

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
  static const String agentFirst = 'agent_first';
  static const String costFocused = 'cost_focused';
}
