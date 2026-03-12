/// Content loader service for loading content from YAML.
///
/// Loads content from content.yaml at runtime and provides typed access.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Thrown when content.yaml cannot be loaded or parsed.
class ContentLoadException implements Exception {
  const ContentLoadException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => cause != null
      ? 'ContentLoadException: $message (caused by: $cause)'
      : 'ContentLoadException: $message';
}

/// Service for loading and accessing content from content.yaml.
///
/// All members are static. Use [ContentLoader.load] to initialize,
/// then access content via static getters (e.g. [ContentLoader.companyName]).
/// The [Content] facade provides identical static access with shorter call sites.
class ContentLoader {
  ContentLoader._();

  static YamlMap? _content;
  static bool _isLoaded = false;
  static Completer<void>? _loadCompleter;

  /// Whether content has been loaded.
  static bool get isLoaded => _isLoaded;

  /// Load content from YAML file.
  ///
  /// Concurrent callers await the same load operation — only one
  /// rootBundle fetch is issued even if called from multiple init paths.
  ///
  /// Throws [ContentLoadException] if the asset cannot be read or parsed.
  static Future<void> load() async {
    if (_isLoaded) return;
    if (_loadCompleter != null) return _loadCompleter!.future;
    _loadCompleter = Completer<void>();
    _mapCache.clear();
    _listCache.clear();
    _stringListCache.clear();
    _stringMapCache.clear();

    try {
      final String yamlString;
      try {
        yamlString = await rootBundle.loadString('content.yaml');
      } on Object catch (e, st) {
        throw ContentLoadException(
          'Failed to load content.yaml asset',
          cause: e,
          stackTrace: st,
        );
      }

      final Object? parsed;
      try {
        parsed = loadYaml(yamlString);
      } on Object catch (e, st) {
        throw ContentLoadException(
          'Failed to parse content.yaml',
          cause: e,
          stackTrace: st,
        );
      }

      if (parsed is! YamlMap) {
        throw ContentLoadException(
          'content.yaml must be a YAML map at root level, got ${parsed.runtimeType}',
        );
      }
      _content = parsed;
      _isLoaded = true;
      _loadCompleter!.complete();
    } on Object catch (e) {
      final completer = _loadCompleter!;
      _loadCompleter = null;
      completer.completeError(e);
      rethrow;
    }
  }

  /// Load content from a YAML string (for testing).
  ///
  /// This allows tests to inject content without requiring asset loading.
  @visibleForTesting
  static void loadFromString(String yamlString) {
    _mapCache.clear();
    _listCache.clear();
    _stringListCache.clear();
    _stringMapCache.clear();
    final parsed = loadYaml(yamlString);
    if (parsed is! YamlMap) {
      throw ContentLoadException(
        'YAML content must be a map at root level, got ${parsed.runtimeType}',
      );
    }
    _content = parsed;
    _isLoaded = true;
  }

  /// Reset content state (for testing).
  ///
  /// Clears loaded content so it can be reloaded.
  @visibleForTesting
  static void reset() {
    // Complete any in-flight load with an error so awaiting callers don't leak.
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      _loadCompleter!.completeError(
        StateError('ContentLoader.reset() called while load() was in progress'),
      );
    }
    _content = null;
    _isLoaded = false;
    _loadCompleter = null;
    _mapCache.clear();
    _listCache.clear();
    _stringListCache.clear();
    _stringMapCache.clear();
  }

  /// Get the raw YAML content.
  static YamlMap? get rawContent => _content;

  // ===========================================================================
  // COMPANY INFORMATION
  // ===========================================================================

  /// Get company info.
  static Map<String, dynamic> get company => _getMap('company');

  static String get companyName => _getString('company.name');
  static String get companyTagline => _getString('company.tagline');
  static String get companyCopyright => _getString('company.copyright');
  static String get companyEmail => _getString('company.contact.email');
  static String get companyPhone => _getString('company.contact.phone');
  static String get companyCity => _getString('company.location.city');
  static String get companyRegion => _getString('company.location.region');
  static String get companyFoundedYear => _getString('company.founded_year');

  // ===========================================================================
  // URLS
  // ===========================================================================

  static String get calendlyUrl => _getString('urls.external.calendly_demo');
  static String get calendlyIntroUrl => _getString('urls.external.calendly_intro');
  static String get statusPageUrl => _getString('urls.external.status_page');
  static String get linkedInUrl => _getString('urls.external.linkedin');
  static String get githubUrl => _getString('urls.external.github');
  static String get founderLinkedInUrl => _getString('urls.external.founder_linkedin');
  static String get deepDiveUrl => _getString('urls.external.deep_dive');
  static String get addressUrl => _getString('urls.external.address');

  // ===========================================================================
  // CTA TEXT
  // ===========================================================================

  static String get ctaStartFreeTrial => _getString('cta_text.primary.start_free_trial');
  static String get ctaGetStarted => _getString('cta_text.primary.get_started');
  static String get ctaScheduleDemo => _getString('cta_text.primary.schedule_demo');
  static String get ctaRequestDemo => _getString('cta_text.primary.request_demo');
  static String get ctaContactSales => _getString('cta_text.primary.contact_sales');
  static String get ctaLearnMore => _getString('cta_text.primary.learn_more');
  static String get ctaBackToHome => _getString('cta_text.navigation.back_to_home');
  static String get ctaViewAll => _getString('cta_text.navigation.view_all');
  static String get ctaViewDocs => _getString('cta_text.navigation.view_docs');
  static String get ctaSendMessage => _getString('cta_text.form.send_message');
  static String get ctaDownloadNow => _getString('cta_text.form.download_now');
  static String get ctaCalculateSavings => _getString('cta_text.form.calculate_savings');
  static String get ctaKeepInTouch => _getString('cta_text.careers.keep_in_touch');

  // ===========================================================================
  // TRUST INDICATORS
  // ===========================================================================

  static List<String> get trustIndicators => _getStringList('trust_indicators.current');
  static List<String> get legacyTrustIndicators => _getStringList('trust_indicators.legacy');

  // ===========================================================================
  // PLATFORM METRICS
  // ===========================================================================

  static String get metricsUptime => _getString('platform_metrics.uptime');
  static String get metricsUptimeSla => _getString('platform_metrics.uptime_sla');
  static String get metricsTracesProcessed => _getString('platform_metrics.traces_processed');
  static String get metricsTracesProcessedPeriod => _getString('platform_metrics.traces_processed_period');
  static String get metricsAiTeams => _getString('platform_metrics.ai_teams');
  static String get metricsSetupTime => _getString('platform_metrics.setup_time');
  static String get metricsSetupTimeLabel => _getString('platform_metrics.setup_time_label');

  // ===========================================================================
  // PRICING
  // ===========================================================================

  static String get pricingTitle => _getString('pricing.title');
  static String get pricingSubtitle => _getString('pricing.subtitle');
  static String get pricingAnnualDiscount => _getString('pricing_constants.annual_discount');
  static List<Map<String, dynamic>> get pricingTiers => _getMapList('pricing.tiers');

  // ===========================================================================
  // HERO
  // ===========================================================================

  static Map<String, dynamic> get heroCurrent => _getMap('hero.current');
  static String get heroBadge => _getString('hero.current.badge');
  static String get heroHeadline => _getString('hero.current.headline');
  static String get heroSubheadline => _getString('hero.current.subheadline');
  static String get heroPrimaryCta => _getString('hero.current.primary_cta');
  static String get heroSecondaryCta => _getString('hero.current.secondary_cta');

  /// Get hero variant by name. Falls back to current hero for empty/unknown variants.
  static Map<String, dynamic> getHeroVariant(String variant) {
    if (variant.isEmpty || variant == 'current') return heroCurrent;
    final value = _getValue('hero.variants.$variant');
    if (value == null) return heroCurrent;
    if (value is YamlMap) return _yamlMapToMap(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return heroCurrent;
  }

  // ===========================================================================
  // FEATURES
  // ===========================================================================

  static String get featuresTitle => _getString('features.title');
  static String get featuresSubtitle => _getString('features.subtitle');
  static List<Map<String, dynamic>> get featuresItems => _getMapList('features.items');

  // ===========================================================================
  // SERVICES
  // ===========================================================================

  static String get servicesTitle => _getString('services.title');
  static String get servicesSubtitle => _getString('services.subtitle');
  static String get servicesDescription => _getString('services.description');
  static List<Map<String, dynamic>> get servicesItems => _getMapList('services.items');

  // ===========================================================================
  // CTA SECTION
  // ===========================================================================

  static String get ctaSectionHeadline => _getString('cta.headline');
  static String get ctaSectionSubheadline => _getString('cta.subheadline');

  // ===========================================================================
  // ABOUT
  // ===========================================================================

  static String get aboutTitle => _getString('about.title');
  static String get aboutSubtitle => _getString('about.subtitle');
  static String get aboutMission => _getString('about.mission_statement');
  static String get aboutVision => _getString('about.vision_statement');
  static String get aboutStory => _getString('about.story');
  static List<Map<String, dynamic>> get aboutValues => _getMapList('about.values');
  static List<Map<String, dynamic>> get aboutTeam => _getMapList('about.team');

  // ===========================================================================
  // CONTACT
  // ===========================================================================

  static String get contactTitle => _getString('contact.title');
  static String get contactSubtitle => _getString('contact.subtitle');
  static String get contactDescription => _getString('contact.description');
  static List<Map<String, dynamic>> get contactFormFields => _getMapList('contact.form.fields');
  static List<Map<String, dynamic>> get contactMethods => _getMapList('contact.contact_methods');
  static String get contactScheduleDemoValue => (contactMethods
          .where((m) => m['label'] == _scheduleDemoLabel)
          .firstOrNull?['value'] as String?) ??
      _scheduleDemoFallback;
  static String get contactSuccessMessage => _getString('contact.form.success_message');
  static String get contactErrorMessage => _getString('contact.form.error_message');

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  static List<Map<String, dynamic>> get footerLinkGroups => _getMapList('footer.link_groups');
  static String get footerPrivacyLink => _getString('footer.privacy_link');
  static String get footerTermsLink => _getString('footer.terms_link');
  static String get footerCookiesLink => _getString('footer.cookies_link');

  // ===========================================================================
  // STATUS
  // ===========================================================================

  static String get statusTitle => _getString('status.title');
  static String get statusSubtitle => _getString('status.subtitle');
  static String get statusBadge => _getString('status.status_badge');
  static List<Map<String, dynamic>> get statusMetrics => _getMapList('status.metrics');
  static List<Map<String, dynamic>> get statusServices => _getMapList('status.services');

  // ===========================================================================
  // RESOURCES
  // ===========================================================================

  static String get resourcesTitle => _getString('resources.title');
  static String get resourcesSubtitle => _getString('resources.subtitle');
  static List<Map<String, dynamic>> get resourcesDocumentation => _getMapList('resources.documentation');
  static List<Map<String, dynamic>> get resourcesFeaturedPosts => _getMapList('resources.featured_posts');
  static List<Map<String, dynamic>> get resourcesLeadMagnets => _getMapList('resources.lead_magnets');

  // ===========================================================================
  // SOCIAL PROOF
  // ===========================================================================

  static String get socialProofTitle => _getString('social_proof.title');
  static Map<String, String> get socialProofStats {
    return _stringMapCache.putIfAbsent('social_proof.stats', () {
      final stats = _getMap('social_proof.stats');
      return stats.map((k, v) => MapEntry(k.toString(), v.toString()));
    });
  }

  static List<Map<String, dynamic>> get socialProofTestimonials => _getMapList('social_proof.testimonials');

  // ===========================================================================
  // DISCLAIMERS
  // ===========================================================================

  static String get disclaimerEuAiAct => _getString('disclaimers.eu_ai_act');
  static String get disclaimerEuAiActShort => _getString('disclaimers.eu_ai_act_short');
  static String get disclaimerSecurity => _getString('disclaimers.security');
  static String get disclaimerGeneral => _getString('disclaimers.general');

  // ===========================================================================
  // STATISTICS - INDUSTRY
  // ===========================================================================

  static String get statisticsMarketSizeValue => _getString('statistics.industry.market_size.value');
  static String get statisticsMarketSizeLabel => _getString('statistics.industry.market_size.label');
  static String get statisticsMarketSizeSource => _getString('statistics.industry.market_size.source');
  static String get statisticsMarketSizeSourceUrl => _getString('statistics.industry.market_size.source_url');

  static String get statisticsMarketGrowthValue => _getString('statistics.industry.market_growth.value');
  static String get statisticsMarketGrowthLabel => _getString('statistics.industry.market_growth.label');
  static String get statisticsMarketGrowthSource => _getString('statistics.industry.market_growth.source');
  static String get statisticsMarketGrowthSourceUrl => _getString('statistics.industry.market_growth.source_url');

  static String get statisticsEnterpriseBudgetsValue => _getString('statistics.industry.enterprise_budgets.value');
  static String get statisticsEnterpriseBudgetsLabel => _getString('statistics.industry.enterprise_budgets.label');
  static String get statisticsEnterpriseBudgetsSource => _getString('statistics.industry.enterprise_budgets.source');
  static String get statisticsEnterpriseBudgetsSourceUrl => _getString('statistics.industry.enterprise_budgets.source_url');

  // ===========================================================================
  // STATISTICS - CUSTOMER DATA
  // ===========================================================================

  static String get statisticsDebuggingValue => _getString('statistics.customer_data.debugging_improvement.value');
  static String get statisticsDebuggingLabel => _getString('statistics.customer_data.debugging_improvement.label');
  static String get statisticsDebuggingSource => _getString('statistics.customer_data.debugging_improvement.source');

  static String get statisticsCostReductionValue => _getString('statistics.customer_data.cost_reduction.value');
  static String get statisticsCostReductionLabel => _getString('statistics.customer_data.cost_reduction.label');
  static String get statisticsCostReductionSource => _getString('statistics.customer_data.cost_reduction.source');

  // ===========================================================================
  // STATISTICS - PLATFORM
  // ===========================================================================

  static String get statisticsTracesValue => _getString('statistics.platform.traces_processed.value');
  static String get statisticsTracesLabel => _getString('statistics.platform.traces_processed.label');
  static String get statisticsTracesSource => _getString('statistics.platform.traces_processed.source');

  static String get statisticsSetupTimeValue => _getString('statistics.platform.setup_time.value');
  static String get statisticsSetupTimeLabel => _getString('statistics.platform.setup_time.label');
  static String get statisticsSetupTimeSource => _getString('statistics.platform.setup_time.source');

  static String get statisticsUptimeValue => _getString('statistics.platform.uptime_target.value');
  static String get statisticsUptimeLabel => _getString('statistics.platform.uptime_target.label');
  static String get statisticsUptimeSource => _getString('statistics.platform.uptime_target.source');

  static String get statisticsSourceDisclaimer => _getString('statistics.source_disclaimer');

  // ===========================================================================
  // BLOG CONTENT
  // ===========================================================================

  static String get blogPageTitle => _getString('blog.page_title');
  static String get blogPageSubtitle => _getString('blog.page_subtitle');
  static List<Map<String, dynamic>> get blogPosts => _getMapList('blog.posts');

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  static const _scheduleDemoLabel = 'Schedule a Demo';
  static const _scheduleDemoFallback = 'Book a 15-minute call';

  // Cache for converted maps/lists — avoids repeated YamlMap deep-copy on
  // every property access (e.g. during Flutter build cycles).
  static final Map<String, Map<String, dynamic>> _mapCache = {};
  static final Map<String, List<Map<String, dynamic>>> _listCache = {};
  static final Map<String, List<String>> _stringListCache = {};
  static final Map<String, Map<String, String>> _stringMapCache = {};

  /// Get a value by dot-notation path.
  static dynamic _getValue(String path) {
    assert(!path.contains('..'), 'Invalid content path: "$path" (double dot)');
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
  static String _getString(String path) {
    final value = _getValue(path);
    return value?.toString() ?? '';
  }

  /// Get a map by path.
  static Map<String, dynamic> _getMap(String path) {
    return _mapCache.putIfAbsent(path, () {
      final value = _getValue(path);
      assert(value != null, 'Required content key "$path" is missing from content.yaml');
      if (value is YamlMap) return _yamlMapToMap(value);
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    });
  }

  /// Get a list of strings by path.
  static List<String> _getStringList(String path) {
    return _stringListCache.putIfAbsent(path, () {
      final value = _getValue(path);
      if (value is YamlList) return value.map((e) => e.toString()).toList();
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    });
  }

  /// Get a list of maps by path.
  static List<Map<String, dynamic>> _getMapList(String path) {
    return _listCache.putIfAbsent(path, () {
      final value = _getValue(path);
      List<dynamic>? list;
      if (value is YamlList) list = value;
      if (value is List) list = value;
      if (list == null) return [];
      return list.map((e) {
        if (e is YamlMap) return _yamlMapToMap(e);
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    });
  }

  /// Convert YamlMap to Map recursively.
  static Map<String, dynamic> _yamlMapToMap(YamlMap yamlMap) {
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
  static List<dynamic> _yamlListToList(YamlList yamlList) {
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
  /// Load content from YAML. Call this before using any content.
  static Future<void> load() => ContentLoader.load();

  /// Load content from a YAML string (for testing).
  @visibleForTesting
  static void loadFromString(String yamlString) =>
      ContentLoader.loadFromString(yamlString);

  /// Reset content state (for testing).
  @visibleForTesting
  static void reset() => ContentLoader.reset();

  /// Whether content has been loaded.
  static bool get isLoaded => ContentLoader.isLoaded;

  // Company
  static String get companyName => ContentLoader.companyName;
  static String get companyTagline => ContentLoader.companyTagline;
  static String get companyCopyright => ContentLoader.companyCopyright;
  static String get companyEmail => ContentLoader.companyEmail;
  static String get companyPhone => ContentLoader.companyPhone;
  static String get companyCity => ContentLoader.companyCity;
  static String get companyRegion => ContentLoader.companyRegion;
  static String get companyFoundedYear => ContentLoader.companyFoundedYear;

  // URLs
  static String get calendlyUrl => ContentLoader.calendlyUrl;
  static String get calendlyIntroUrl => ContentLoader.calendlyIntroUrl;
  static String get statusPageUrl => ContentLoader.statusPageUrl;
  static String get linkedInUrl => ContentLoader.linkedInUrl;
  static String get githubUrl => ContentLoader.githubUrl;
  static String get founderLinkedInUrl => ContentLoader.founderLinkedInUrl;
  static String get deepDiveUrl => ContentLoader.deepDiveUrl;
  static String get addressUrl => ContentLoader.addressUrl;

  // CTA Text
  static String get ctaStartFreeTrial => ContentLoader.ctaStartFreeTrial;
  static String get ctaGetStarted => ContentLoader.ctaGetStarted;
  static String get ctaScheduleDemo => ContentLoader.ctaScheduleDemo;
  static String get ctaRequestDemo => ContentLoader.ctaRequestDemo;
  static String get ctaContactSales => ContentLoader.ctaContactSales;
  static String get ctaLearnMore => ContentLoader.ctaLearnMore;
  static String get ctaBackToHome => ContentLoader.ctaBackToHome;
  static String get ctaViewAll => ContentLoader.ctaViewAll;
  static String get ctaViewDocs => ContentLoader.ctaViewDocs;
  static String get ctaSendMessage => ContentLoader.ctaSendMessage;
  static String get ctaDownloadNow => ContentLoader.ctaDownloadNow;
  static String get ctaCalculateSavings => ContentLoader.ctaCalculateSavings;
  static String get ctaKeepInTouch => ContentLoader.ctaKeepInTouch;

  // Trust Indicators
  static List<String> get trustIndicators => ContentLoader.trustIndicators;
  static List<String> get legacyTrustIndicators => ContentLoader.legacyTrustIndicators;

  // Platform Metrics
  static String get metricsUptime => ContentLoader.metricsUptime;
  static String get metricsUptimeSla => ContentLoader.metricsUptimeSla;
  static String get metricsTracesProcessed => ContentLoader.metricsTracesProcessed;
  static String get metricsTracesProcessedPeriod => ContentLoader.metricsTracesProcessedPeriod;
  static String get metricsAiTeams => ContentLoader.metricsAiTeams;
  static String get metricsSetupTime => ContentLoader.metricsSetupTime;
  static String get metricsSetupTimeLabel => ContentLoader.metricsSetupTimeLabel;

  // Pricing
  static String get pricingTitle => ContentLoader.pricingTitle;
  static String get pricingSubtitle => ContentLoader.pricingSubtitle;
  static String get pricingAnnualDiscount => ContentLoader.pricingAnnualDiscount;
  static List<Map<String, dynamic>> get pricingTiers => ContentLoader.pricingTiers;

  // Hero
  static String get heroBadge => ContentLoader.heroBadge;
  static String get heroHeadline => ContentLoader.heroHeadline;
  static String get heroSubheadline => ContentLoader.heroSubheadline;
  static String get heroPrimaryCta => ContentLoader.heroPrimaryCta;
  static String get heroSecondaryCta => ContentLoader.heroSecondaryCta;
  static Map<String, dynamic> getHeroVariant(String variant) =>
      ContentLoader.getHeroVariant(variant);

  // Features
  static String get featuresTitle => ContentLoader.featuresTitle;
  static String get featuresSubtitle => ContentLoader.featuresSubtitle;
  static List<Map<String, dynamic>> get featuresItems => ContentLoader.featuresItems;

  // Services
  static String get servicesTitle => ContentLoader.servicesTitle;
  static String get servicesSubtitle => ContentLoader.servicesSubtitle;
  static String get servicesDescription => ContentLoader.servicesDescription;
  static List<Map<String, dynamic>> get servicesItems => ContentLoader.servicesItems;

  // CTA Section
  static String get ctaSectionHeadline => ContentLoader.ctaSectionHeadline;
  static String get ctaSectionSubheadline => ContentLoader.ctaSectionSubheadline;

  // About
  static String get aboutTitle => ContentLoader.aboutTitle;
  static String get aboutSubtitle => ContentLoader.aboutSubtitle;
  static String get aboutMission => ContentLoader.aboutMission;
  static String get aboutVision => ContentLoader.aboutVision;
  static String get aboutStory => ContentLoader.aboutStory;
  static List<Map<String, dynamic>> get aboutValues => ContentLoader.aboutValues;
  static List<Map<String, dynamic>> get aboutTeam => ContentLoader.aboutTeam;

  // Contact
  static String get contactTitle => ContentLoader.contactTitle;
  static String get contactSubtitle => ContentLoader.contactSubtitle;
  static String get contactDescription => ContentLoader.contactDescription;
  static List<Map<String, dynamic>> get contactFormFields =>
      ContentLoader.contactFormFields;
  static List<Map<String, dynamic>> get contactMethods =>
      ContentLoader.contactMethods;
  static String get contactScheduleDemoValue =>
      ContentLoader.contactScheduleDemoValue;
  static String get contactSuccessMessage => ContentLoader.contactSuccessMessage;
  static String get contactErrorMessage => ContentLoader.contactErrorMessage;

  // Footer
  static List<Map<String, dynamic>> get footerLinkGroups =>
      ContentLoader.footerLinkGroups;
  static String get footerPrivacyLink => ContentLoader.footerPrivacyLink;
  static String get footerTermsLink => ContentLoader.footerTermsLink;
  static String get footerCookiesLink => ContentLoader.footerCookiesLink;

  // Status
  static String get statusTitle => ContentLoader.statusTitle;
  static String get statusSubtitle => ContentLoader.statusSubtitle;
  static String get statusBadge => ContentLoader.statusBadge;
  static List<Map<String, dynamic>> get statusMetrics => ContentLoader.statusMetrics;
  static List<Map<String, dynamic>> get statusServices =>
      ContentLoader.statusServices;

  // Resources
  static String get resourcesTitle => ContentLoader.resourcesTitle;
  static String get resourcesSubtitle => ContentLoader.resourcesSubtitle;
  static List<Map<String, dynamic>> get resourcesDocumentation =>
      ContentLoader.resourcesDocumentation;
  static List<Map<String, dynamic>> get resourcesFeaturedPosts =>
      ContentLoader.resourcesFeaturedPosts;
  static List<Map<String, dynamic>> get resourcesLeadMagnets =>
      ContentLoader.resourcesLeadMagnets;

  // Social Proof
  static String get socialProofTitle => ContentLoader.socialProofTitle;
  static Map<String, String> get socialProofStats => ContentLoader.socialProofStats;
  static List<Map<String, dynamic>> get socialProofTestimonials =>
      ContentLoader.socialProofTestimonials;

  // Disclaimers
  static String get disclaimerEuAiAct => ContentLoader.disclaimerEuAiAct;
  static String get disclaimerEuAiActShort => ContentLoader.disclaimerEuAiActShort;
  static String get disclaimerSecurity => ContentLoader.disclaimerSecurity;
  static String get disclaimerGeneral => ContentLoader.disclaimerGeneral;

  // Statistics - Industry
  static String get statisticsMarketSizeValue => ContentLoader.statisticsMarketSizeValue;
  static String get statisticsMarketSizeLabel => ContentLoader.statisticsMarketSizeLabel;
  static String get statisticsMarketSizeSource => ContentLoader.statisticsMarketSizeSource;
  static String get statisticsMarketSizeSourceUrl => ContentLoader.statisticsMarketSizeSourceUrl;

  static String get statisticsMarketGrowthValue => ContentLoader.statisticsMarketGrowthValue;
  static String get statisticsMarketGrowthLabel => ContentLoader.statisticsMarketGrowthLabel;
  static String get statisticsMarketGrowthSource => ContentLoader.statisticsMarketGrowthSource;
  static String get statisticsMarketGrowthSourceUrl => ContentLoader.statisticsMarketGrowthSourceUrl;

  static String get statisticsEnterpriseBudgetsValue => ContentLoader.statisticsEnterpriseBudgetsValue;
  static String get statisticsEnterpriseBudgetsLabel => ContentLoader.statisticsEnterpriseBudgetsLabel;
  static String get statisticsEnterpriseBudgetsSource => ContentLoader.statisticsEnterpriseBudgetsSource;
  static String get statisticsEnterpriseBudgetsSourceUrl => ContentLoader.statisticsEnterpriseBudgetsSourceUrl;

  // Statistics - Customer Data
  static String get statisticsDebuggingValue => ContentLoader.statisticsDebuggingValue;
  static String get statisticsDebuggingLabel => ContentLoader.statisticsDebuggingLabel;
  static String get statisticsDebuggingSource => ContentLoader.statisticsDebuggingSource;

  static String get statisticsCostReductionValue => ContentLoader.statisticsCostReductionValue;
  static String get statisticsCostReductionLabel => ContentLoader.statisticsCostReductionLabel;
  static String get statisticsCostReductionSource => ContentLoader.statisticsCostReductionSource;

  // Statistics - Platform
  static String get statisticsTracesValue => ContentLoader.statisticsTracesValue;
  static String get statisticsTracesLabel => ContentLoader.statisticsTracesLabel;
  static String get statisticsTracesSource => ContentLoader.statisticsTracesSource;

  static String get statisticsSetupTimeValue => ContentLoader.statisticsSetupTimeValue;
  static String get statisticsSetupTimeLabel => ContentLoader.statisticsSetupTimeLabel;
  static String get statisticsSetupTimeSource => ContentLoader.statisticsSetupTimeSource;

  static String get statisticsUptimeValue => ContentLoader.statisticsUptimeValue;
  static String get statisticsUptimeLabel => ContentLoader.statisticsUptimeLabel;
  static String get statisticsUptimeSource => ContentLoader.statisticsUptimeSource;

  static String get statisticsSourceDisclaimer => ContentLoader.statisticsSourceDisclaimer;

  // Blog
  static String get blogPageTitle => ContentLoader.blogPageTitle;
  static String get blogPageSubtitle => ContentLoader.blogPageSubtitle;
  static List<Map<String, dynamic>> get blogPosts => ContentLoader.blogPosts;
}
