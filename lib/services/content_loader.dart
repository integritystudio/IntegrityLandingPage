/// Content loader service for loading content from YAML.
///
/// Loads content from content.yaml at runtime and provides typed access.
library;

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Service for loading and accessing content from content.yaml.
class ContentLoader {
  static ContentLoader? _instance;
  static YamlMap? _content;
  static bool _isLoaded = false;

  ContentLoader._();

  /// Get singleton instance.
  static ContentLoader get instance {
    _instance ??= ContentLoader._();
    return _instance!;
  }

  /// Whether content has been loaded.
  bool get isLoaded => _isLoaded;

  /// Load content from YAML file.
  Future<void> load() async {
    if (_isLoaded) return;

    final yamlString = await rootBundle.loadString('content.yaml');
    _content = loadYaml(yamlString) as YamlMap;
    _isLoaded = true;
  }

  /// Load content from a YAML string (for testing).
  ///
  /// This allows tests to inject content without requiring asset loading.
  void loadFromString(String yamlString) {
    _content = loadYaml(yamlString) as YamlMap;
    _isLoaded = true;
  }

  /// Reset content state (for testing).
  ///
  /// Clears loaded content so it can be reloaded.
  static void reset() {
    _content = null;
    _isLoaded = false;
  }

  /// Get the raw YAML content.
  YamlMap? get rawContent => _content;

  // ===========================================================================
  // COMPANY INFORMATION
  // ===========================================================================

  /// Get company info.
  Map<String, dynamic> get company => _getMap('company');

  String get companyName => _getString('company.name');
  String get companyTagline => _getString('company.tagline');
  String get companyCopyright => _getString('company.copyright');
  String get companyEmail => _getString('company.contact.email');
  String get companyPhone => _getString('company.contact.phone');
  String get companyCity => _getString('company.location.city');
  String get companyRegion => _getString('company.location.region');
  String get companyFoundedYear => _getString('company.founded_year');

  // ===========================================================================
  // URLS
  // ===========================================================================

  String get calendlyUrl => _getString('urls.external.calendly_demo');
  String get statusPageUrl => _getString('urls.external.status_page');
  String get linkedInUrl => _getString('urls.external.linkedin');
  String get xUrl => _getString('urls.external.x');
  String get githubUrl => _getString('urls.external.github');
  String get founderLinkedInUrl => _getString('urls.external.founder_linkedin');
  String get founderXUrl => _getString('urls.external.founder_x');

  // ===========================================================================
  // CTA TEXT
  // ===========================================================================

  String get ctaStartFreeTrial => _getString('cta_text.primary.start_free_trial');
  String get ctaGetStarted => _getString('cta_text.primary.get_started');
  String get ctaScheduleDemo => _getString('cta_text.primary.schedule_demo');
  String get ctaRequestDemo => _getString('cta_text.primary.request_demo');
  String get ctaContactSales => _getString('cta_text.primary.contact_sales');
  String get ctaLearnMore => _getString('cta_text.primary.learn_more');
  String get ctaSendMessage => _getString('cta_text.form.send_message');

  // ===========================================================================
  // TRUST INDICATORS
  // ===========================================================================

  List<String> get trustIndicators => _getStringList('trust_indicators.current');
  List<String> get legacyTrustIndicators => _getStringList('trust_indicators.legacy');

  // ===========================================================================
  // PLATFORM METRICS
  // ===========================================================================

  String get metricsUptime => _getString('platform_metrics.uptime');
  String get metricsTracesProcessed => _getString('platform_metrics.traces_processed');
  String get metricsAiTeams => _getString('platform_metrics.ai_teams');
  String get metricsSetupTime => _getString('platform_metrics.setup_time');

  // ===========================================================================
  // PRICING
  // ===========================================================================

  String get pricingTitle => _getString('pricing.title');
  String get pricingSubtitle => _getString('pricing.subtitle');
  String get pricingAnnualDiscount => _getString('pricing_constants.annual_discount');
  List<Map<String, dynamic>> get pricingTiers => _getMapList('pricing.tiers');

  // ===========================================================================
  // HERO
  // ===========================================================================

  Map<String, dynamic> get heroCurrent => _getMap('hero.current');
  String get heroBadge => _getString('hero.current.badge');
  String get heroHeadline => _getString('hero.current.headline');
  String get heroSubheadline => _getString('hero.current.subheadline');
  String get heroPrimaryCta => _getString('hero.current.primary_cta');
  String get heroSecondaryCta => _getString('hero.current.secondary_cta');

  /// Get hero variant by name.
  Map<String, dynamic> getHeroVariant(String variant) {
    if (variant == 'current') return heroCurrent;
    return _getMap('hero.variants.$variant');
  }

  // ===========================================================================
  // FEATURES
  // ===========================================================================

  String get featuresTitle => _getString('features.title');
  String get featuresSubtitle => _getString('features.subtitle');
  List<Map<String, dynamic>> get featuresItems => _getMapList('features.items');

  // ===========================================================================
  // SERVICES
  // ===========================================================================

  String get servicesTitle => _getString('services.title');
  String get servicesSubtitle => _getString('services.subtitle');
  String get servicesDescription => _getString('services.description');
  List<Map<String, dynamic>> get servicesItems => _getMapList('services.items');

  // ===========================================================================
  // CTA SECTION
  // ===========================================================================

  String get ctaSectionHeadline => _getString('cta.headline');
  String get ctaSectionSubheadline => _getString('cta.subheadline');

  // ===========================================================================
  // ABOUT
  // ===========================================================================

  String get aboutTitle => _getString('about.title');
  String get aboutSubtitle => _getString('about.subtitle');
  String get aboutMission => _getString('about.mission_statement');
  String get aboutVision => _getString('about.vision_statement');
  String get aboutStory => _getString('about.story');
  List<Map<String, dynamic>> get aboutValues => _getMapList('about.values');
  List<Map<String, dynamic>> get aboutTeam => _getMapList('about.team');

  // ===========================================================================
  // CONTACT
  // ===========================================================================

  String get contactTitle => _getString('contact.title');
  String get contactSubtitle => _getString('contact.subtitle');
  String get contactDescription => _getString('contact.description');
  List<Map<String, dynamic>> get contactFormFields => _getMapList('contact.form.fields');
  List<Map<String, dynamic>> get contactMethods => _getMapList('contact.contact_methods');
  String get contactSuccessMessage => _getString('contact.form.success_message');
  String get contactErrorMessage => _getString('contact.form.error_message');

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  List<Map<String, dynamic>> get footerLinkGroups => _getMapList('footer.link_groups');
  String get footerPrivacyLink => _getString('footer.privacy_link');
  String get footerTermsLink => _getString('footer.terms_link');
  String get footerCookiesLink => _getString('footer.cookies_link');

  // ===========================================================================
  // STATUS
  // ===========================================================================

  String get statusTitle => _getString('status.title');
  String get statusSubtitle => _getString('status.subtitle');
  String get statusBadge => _getString('status.status_badge');
  List<Map<String, dynamic>> get statusMetrics => _getMapList('status.metrics');
  List<Map<String, dynamic>> get statusServices => _getMapList('status.services');

  // ===========================================================================
  // RESOURCES
  // ===========================================================================

  String get resourcesTitle => _getString('resources.title');
  String get resourcesSubtitle => _getString('resources.subtitle');
  List<Map<String, dynamic>> get resourcesDocumentation => _getMapList('resources.documentation');
  List<Map<String, dynamic>> get resourcesFeaturedPosts => _getMapList('resources.featured_posts');
  List<Map<String, dynamic>> get resourcesLeadMagnets => _getMapList('resources.lead_magnets');

  // ===========================================================================
  // SOCIAL PROOF
  // ===========================================================================

  String get socialProofTitle => _getString('social_proof.title');
  Map<String, String> get socialProofStats {
    final stats = _getMap('social_proof.stats');
    return stats.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  List<Map<String, dynamic>> get socialProofTestimonials => _getMapList('social_proof.testimonials');

  // ===========================================================================
  // DISCLAIMERS
  // ===========================================================================

  String get disclaimerEuAiAct => _getString('disclaimers.eu_ai_act');
  String get disclaimerEuAiActShort => _getString('disclaimers.eu_ai_act_short');
  String get disclaimerSecurity => _getString('disclaimers.security');
  String get disclaimerGeneral => _getString('disclaimers.general');

  // ===========================================================================
  // PROMO CODES
  // ===========================================================================

  String get promoWhylabsCode => _getString('promo_codes.whylabs_migration.code');
  String get promoWhylabsDescription => _getString('promo_codes.whylabs_migration.description');

  // ===========================================================================
  // STATISTICS - INDUSTRY
  // ===========================================================================

  String get statisticsMarketSizeValue => _getString('statistics.industry.market_size.value');
  String get statisticsMarketSizeLabel => _getString('statistics.industry.market_size.label');
  String get statisticsMarketSizeSource => _getString('statistics.industry.market_size.source');
  String get statisticsMarketSizeSourceUrl => _getString('statistics.industry.market_size.source_url');

  String get statisticsMarketGrowthValue => _getString('statistics.industry.market_growth.value');
  String get statisticsMarketGrowthLabel => _getString('statistics.industry.market_growth.label');
  String get statisticsMarketGrowthSource => _getString('statistics.industry.market_growth.source');
  String get statisticsMarketGrowthSourceUrl => _getString('statistics.industry.market_growth.source_url');

  String get statisticsEnterpriseBudgetsValue => _getString('statistics.industry.enterprise_budgets.value');
  String get statisticsEnterpriseBudgetsLabel => _getString('statistics.industry.enterprise_budgets.label');
  String get statisticsEnterpriseBudgetsSource => _getString('statistics.industry.enterprise_budgets.source');
  String get statisticsEnterpriseBudgetsSourceUrl => _getString('statistics.industry.enterprise_budgets.source_url');

  // ===========================================================================
  // STATISTICS - CUSTOMER DATA
  // ===========================================================================

  String get statisticsDebuggingValue => _getString('statistics.customer_data.debugging_improvement.value');
  String get statisticsDebuggingLabel => _getString('statistics.customer_data.debugging_improvement.label');
  String get statisticsDebuggingSource => _getString('statistics.customer_data.debugging_improvement.source');

  String get statisticsCostReductionValue => _getString('statistics.customer_data.cost_reduction.value');
  String get statisticsCostReductionLabel => _getString('statistics.customer_data.cost_reduction.label');
  String get statisticsCostReductionSource => _getString('statistics.customer_data.cost_reduction.source');

  // ===========================================================================
  // STATISTICS - PLATFORM
  // ===========================================================================

  String get statisticsTracesValue => _getString('statistics.platform.traces_processed.value');
  String get statisticsTracesLabel => _getString('statistics.platform.traces_processed.label');
  String get statisticsTracesSource => _getString('statistics.platform.traces_processed.source');

  String get statisticsSetupTimeValue => _getString('statistics.platform.setup_time.value');
  String get statisticsSetupTimeLabel => _getString('statistics.platform.setup_time.label');
  String get statisticsSetupTimeSource => _getString('statistics.platform.setup_time.source');

  String get statisticsUptimeValue => _getString('statistics.platform.uptime_target.value');
  String get statisticsUptimeLabel => _getString('statistics.platform.uptime_target.label');
  String get statisticsUptimeSource => _getString('statistics.platform.uptime_target.source');

  String get statisticsSourceDisclaimer => _getString('statistics.source_disclaimer');

  // ===========================================================================
  // BLOG CONTENT
  // ===========================================================================

  String get blogPageTitle => _getString('blog.page_title');
  String get blogPageSubtitle => _getString('blog.page_subtitle');
  List<Map<String, dynamic>> get blogPosts => _getMapList('blog.posts');

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Get a value by dot-notation path.
  dynamic _getValue(String path) {
    if (_content == null) {
      throw StateError('Content not loaded. Call load() first.');
    }

    final parts = path.split('.');
    dynamic current = _content;

    for (final part in parts) {
      if (current is YamlMap) {
        current = current[part];
      } else if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  /// Get a string value by path.
  String _getString(String path) {
    final value = _getValue(path);
    return value?.toString() ?? '';
  }

  /// Get a map by path.
  Map<String, dynamic> _getMap(String path) {
    final value = _getValue(path);
    if (value is YamlMap) {
      return _yamlMapToMap(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  /// Get a list of strings by path.
  List<String> _getStringList(String path) {
    final value = _getValue(path);
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Get a list of maps by path.
  List<Map<String, dynamic>> _getMapList(String path) {
    final value = _getValue(path);
    if (value is YamlList) {
      return value.map((e) {
        if (e is YamlMap) return _yamlMapToMap(e);
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }
    if (value is List) {
      return value.map((e) {
        if (e is YamlMap) return _yamlMapToMap(e);
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }

  /// Convert YamlMap to Map recursively.
  Map<String, dynamic> _yamlMapToMap(YamlMap yamlMap) {
    final map = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is YamlMap) {
        map[key] = _yamlMapToMap(value);
      } else if (value is YamlList) {
        map[key] = _yamlListToList(value);
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  /// Convert YamlList to List recursively.
  List<dynamic> _yamlListToList(YamlList yamlList) {
    return yamlList.map((item) {
      if (item is YamlMap) return _yamlMapToMap(item);
      if (item is YamlList) return _yamlListToList(item);
      return item;
    }).toList();
  }
}

/// Global content accessor.
///
/// Usage:
/// ```dart
/// // In main.dart or app initialization:
/// await Content.load();
///
/// // Anywhere in the app:
/// Text(Content.companyName);
/// Text(Content.heroHeadline);
/// ```
class Content {
  static final _loader = ContentLoader.instance;

  /// Load content from YAML. Call this before using any content.
  static Future<void> load() => _loader.load();

  /// Load content from a YAML string (for testing).
  static void loadFromString(String yamlString) =>
      _loader.loadFromString(yamlString);

  /// Reset content state (for testing).
  static void reset() => ContentLoader.reset();

  /// Whether content has been loaded.
  static bool get isLoaded => _loader.isLoaded;

  // Company
  static String get companyName => _loader.companyName;
  static String get companyTagline => _loader.companyTagline;
  static String get companyCopyright => _loader.companyCopyright;
  static String get companyEmail => _loader.companyEmail;
  static String get companyPhone => _loader.companyPhone;
  static String get companyCity => _loader.companyCity;
  static String get companyRegion => _loader.companyRegion;
  static String get companyFoundedYear => _loader.companyFoundedYear;

  // URLs
  static String get calendlyUrl => _loader.calendlyUrl;
  static String get statusPageUrl => _loader.statusPageUrl;
  static String get linkedInUrl => _loader.linkedInUrl;
  static String get xUrl => _loader.xUrl;
  static String get githubUrl => _loader.githubUrl;
  static String get founderLinkedInUrl => _loader.founderLinkedInUrl;
  static String get founderXUrl => _loader.founderXUrl;

  // CTA Text
  static String get ctaStartFreeTrial => _loader.ctaStartFreeTrial;
  static String get ctaGetStarted => _loader.ctaGetStarted;
  static String get ctaScheduleDemo => _loader.ctaScheduleDemo;
  static String get ctaRequestDemo => _loader.ctaRequestDemo;
  static String get ctaContactSales => _loader.ctaContactSales;
  static String get ctaLearnMore => _loader.ctaLearnMore;
  static String get ctaSendMessage => _loader.ctaSendMessage;

  // Trust Indicators
  static List<String> get trustIndicators => _loader.trustIndicators;
  static List<String> get legacyTrustIndicators => _loader.legacyTrustIndicators;

  // Platform Metrics
  static String get metricsUptime => _loader.metricsUptime;
  static String get metricsTracesProcessed => _loader.metricsTracesProcessed;
  static String get metricsAiTeams => _loader.metricsAiTeams;
  static String get metricsSetupTime => _loader.metricsSetupTime;

  // Pricing
  static String get pricingTitle => _loader.pricingTitle;
  static String get pricingSubtitle => _loader.pricingSubtitle;
  static String get pricingAnnualDiscount => _loader.pricingAnnualDiscount;
  static List<Map<String, dynamic>> get pricingTiers => _loader.pricingTiers;

  // Hero
  static String get heroBadge => _loader.heroBadge;
  static String get heroHeadline => _loader.heroHeadline;
  static String get heroSubheadline => _loader.heroSubheadline;
  static String get heroPrimaryCta => _loader.heroPrimaryCta;
  static String get heroSecondaryCta => _loader.heroSecondaryCta;
  static Map<String, dynamic> getHeroVariant(String variant) =>
      _loader.getHeroVariant(variant);

  // Features
  static String get featuresTitle => _loader.featuresTitle;
  static String get featuresSubtitle => _loader.featuresSubtitle;
  static List<Map<String, dynamic>> get featuresItems => _loader.featuresItems;

  // Services
  static String get servicesTitle => _loader.servicesTitle;
  static String get servicesSubtitle => _loader.servicesSubtitle;
  static String get servicesDescription => _loader.servicesDescription;
  static List<Map<String, dynamic>> get servicesItems => _loader.servicesItems;

  // CTA Section
  static String get ctaSectionHeadline => _loader.ctaSectionHeadline;
  static String get ctaSectionSubheadline => _loader.ctaSectionSubheadline;

  // About
  static String get aboutTitle => _loader.aboutTitle;
  static String get aboutSubtitle => _loader.aboutSubtitle;
  static String get aboutMission => _loader.aboutMission;
  static String get aboutVision => _loader.aboutVision;
  static String get aboutStory => _loader.aboutStory;
  static List<Map<String, dynamic>> get aboutValues => _loader.aboutValues;
  static List<Map<String, dynamic>> get aboutTeam => _loader.aboutTeam;

  // Contact
  static String get contactTitle => _loader.contactTitle;
  static String get contactSubtitle => _loader.contactSubtitle;
  static String get contactDescription => _loader.contactDescription;
  static List<Map<String, dynamic>> get contactFormFields =>
      _loader.contactFormFields;
  static List<Map<String, dynamic>> get contactMethods =>
      _loader.contactMethods;
  static String get contactSuccessMessage => _loader.contactSuccessMessage;
  static String get contactErrorMessage => _loader.contactErrorMessage;

  // Footer
  static List<Map<String, dynamic>> get footerLinkGroups =>
      _loader.footerLinkGroups;
  static String get footerPrivacyLink => _loader.footerPrivacyLink;
  static String get footerTermsLink => _loader.footerTermsLink;
  static String get footerCookiesLink => _loader.footerCookiesLink;

  // Status
  static String get statusTitle => _loader.statusTitle;
  static String get statusSubtitle => _loader.statusSubtitle;
  static String get statusBadge => _loader.statusBadge;
  static List<Map<String, dynamic>> get statusMetrics => _loader.statusMetrics;
  static List<Map<String, dynamic>> get statusServices =>
      _loader.statusServices;

  // Resources
  static String get resourcesTitle => _loader.resourcesTitle;
  static String get resourcesSubtitle => _loader.resourcesSubtitle;
  static List<Map<String, dynamic>> get resourcesDocumentation =>
      _loader.resourcesDocumentation;
  static List<Map<String, dynamic>> get resourcesFeaturedPosts =>
      _loader.resourcesFeaturedPosts;
  static List<Map<String, dynamic>> get resourcesLeadMagnets =>
      _loader.resourcesLeadMagnets;

  // Social Proof
  static String get socialProofTitle => _loader.socialProofTitle;
  static Map<String, String> get socialProofStats => _loader.socialProofStats;
  static List<Map<String, dynamic>> get socialProofTestimonials =>
      _loader.socialProofTestimonials;

  // Disclaimers
  static String get disclaimerEuAiAct => _loader.disclaimerEuAiAct;
  static String get disclaimerEuAiActShort => _loader.disclaimerEuAiActShort;
  static String get disclaimerSecurity => _loader.disclaimerSecurity;
  static String get disclaimerGeneral => _loader.disclaimerGeneral;

  // Promo Codes
  static String get promoWhylabsCode => _loader.promoWhylabsCode;
  static String get promoWhylabsDescription => _loader.promoWhylabsDescription;

  // Statistics - Industry
  static String get statisticsMarketSizeValue => _loader.statisticsMarketSizeValue;
  static String get statisticsMarketSizeLabel => _loader.statisticsMarketSizeLabel;
  static String get statisticsMarketSizeSource => _loader.statisticsMarketSizeSource;
  static String get statisticsMarketSizeSourceUrl => _loader.statisticsMarketSizeSourceUrl;

  static String get statisticsMarketGrowthValue => _loader.statisticsMarketGrowthValue;
  static String get statisticsMarketGrowthLabel => _loader.statisticsMarketGrowthLabel;
  static String get statisticsMarketGrowthSource => _loader.statisticsMarketGrowthSource;
  static String get statisticsMarketGrowthSourceUrl => _loader.statisticsMarketGrowthSourceUrl;

  static String get statisticsEnterpriseBudgetsValue => _loader.statisticsEnterpriseBudgetsValue;
  static String get statisticsEnterpriseBudgetsLabel => _loader.statisticsEnterpriseBudgetsLabel;
  static String get statisticsEnterpriseBudgetsSource => _loader.statisticsEnterpriseBudgetsSource;
  static String get statisticsEnterpriseBudgetsSourceUrl => _loader.statisticsEnterpriseBudgetsSourceUrl;

  // Statistics - Customer Data
  static String get statisticsDebuggingValue => _loader.statisticsDebuggingValue;
  static String get statisticsDebuggingLabel => _loader.statisticsDebuggingLabel;
  static String get statisticsDebuggingSource => _loader.statisticsDebuggingSource;

  static String get statisticsCostReductionValue => _loader.statisticsCostReductionValue;
  static String get statisticsCostReductionLabel => _loader.statisticsCostReductionLabel;
  static String get statisticsCostReductionSource => _loader.statisticsCostReductionSource;

  // Statistics - Platform
  static String get statisticsTracesValue => _loader.statisticsTracesValue;
  static String get statisticsTracesLabel => _loader.statisticsTracesLabel;
  static String get statisticsTracesSource => _loader.statisticsTracesSource;

  static String get statisticsSetupTimeValue => _loader.statisticsSetupTimeValue;
  static String get statisticsSetupTimeLabel => _loader.statisticsSetupTimeLabel;
  static String get statisticsSetupTimeSource => _loader.statisticsSetupTimeSource;

  static String get statisticsUptimeValue => _loader.statisticsUptimeValue;
  static String get statisticsUptimeLabel => _loader.statisticsUptimeLabel;
  static String get statisticsUptimeSource => _loader.statisticsUptimeSource;

  static String get statisticsSourceDisclaimer => _loader.statisticsSourceDisclaimer;

  // Blog
  static String get blogPageTitle => _loader.blogPageTitle;
  static String get blogPageSubtitle => _loader.blogPageSubtitle;
  static List<Map<String, dynamic>> get blogPosts => _loader.blogPosts;
}
