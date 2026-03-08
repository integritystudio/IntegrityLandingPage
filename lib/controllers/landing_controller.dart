import 'package:flutter/material.dart';
import '../services/analytics.dart';
import '../config/content.dart';

/// Controller for landing page business logic
///
/// Responsibilities:
/// - Scroll depth tracking
/// - Section navigation
/// - Content management (A/B testing)
/// - Analytics coordination
///
/// Usage:
/// ```dart
/// final controller = LandingController(
///   onShowDemoModal: () => DemoModal.show(context, onScheduleDemo: launchCalendly),
/// );
///
/// // In widget
/// ScrollController(controller: controller.scrollController);
///
/// // Track scroll
/// controller.scrollController.addListener(() {
///   controller.handleScrollUpdate();
/// });
///
/// // Navigate to section
/// controller.scrollToSection(sectionKey);
/// ```
class LandingController extends ChangeNotifier {
  // Scroll controller for the page
  final ScrollController scrollController = ScrollController();

  // Callbacks for UI actions (requires BuildContext)
  final VoidCallback? onShowDemoModal;

  // Section keys for navigation
  final Map<String, GlobalKey> _sectionKeys = {};

  // Track scroll depth milestones
  final Set<int> _trackedMilestones = {};
  static const List<int> _scrollMilestones = [25, 50, 75, 100];

  // Content variants for A/B testing
  String? _contentVariant;

  // Page view tracked flag
  bool _hasTrackedPageView = false;

  LandingController({
    this.onShowDemoModal,
  });

  /// Get current hero content based on variant
  HeroContent get heroContent {
    if (_contentVariant != null) {
      return AppContent.getHeroVariant(_contentVariant!);
    }
    return AppContent.hero;
  }

  /// Get current pricing content
  PricingContent get pricingContent => AppContent.pricing;

  /// Get current features content
  FeaturesContent get featuresContent => AppContent.features;

  /// Get current CTA content
  CTAContent get ctaContent => AppContent.cta;

  /// Initialize the controller
  void initialize() {
    if (!_hasTrackedPageView) {
      AnalyticsService.trackPageView('landing');
      _hasTrackedPageView = true;
    }
    scrollController.addListener(_handleScroll);
  }

  /// Set content variant for A/B testing
  void setContentVariant(String variant) {
    _contentVariant = variant;
    notifyListeners();
  }

  /// Register a section key for navigation
  void registerSection(String sectionId, GlobalKey key) {
    _sectionKeys[sectionId] = key;
  }

  /// Get section key by ID
  GlobalKey? getSectionKey(String sectionId) => _sectionKeys[sectionId];

  /// Handle scroll position updates
  void _handleScroll() {
    final maxScroll = scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final percentage = ((scrollController.offset / maxScroll) * 100).round();

    // Track milestone scroll depths (25%, 50%, 75%, 100%)
    for (final milestone in _scrollMilestones) {
      if (percentage >= milestone && !_trackedMilestones.contains(milestone)) {
        _trackedMilestones.add(milestone);
        AnalyticsService.trackScrollDepth(milestone);
      }
    }
  }

  /// Scroll to a specific section
  void scrollToSection(String sectionId) {
    final key = _sectionKeys[sectionId];
    if (key == null) return;

    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Scroll to pricing section
  void scrollToPricing() => scrollToSection('pricing');

  /// Scroll to CTA section
  void scrollToCTA() => scrollToSection('cta');

  /// Handle Get Started CTA click
  void handleGetStarted({String location = 'hero'}) {
    AnalyticsService.trackCTAClick(
      buttonName: 'Get Started',
      location: location,
      ctaType: 'primary',
    );
    scrollToPricing();
  }

  /// Handle Request Demo CTA click
  void handleRequestDemo() {
    AnalyticsService.trackCTAClick(
      buttonName: 'Request Demo',
      location: 'hero',
      ctaType: 'secondary',
    );
    onShowDemoModal?.call();
  }

  /// Handle pricing tier selection (analytics only; navigation stays in widget)
  void handleTierSelection(String tier) {
    AnalyticsService.trackPricingView(tier);
  }

  /// Handle feature interaction
  void handleFeatureInteraction(String featureTitle) {
    AnalyticsService.trackFeatureInteraction(featureTitle);
  }

  /// Reset scroll tracking (e.g., on navigation)
  void resetScrollTracking() {
    _trackedMilestones.clear();
  }

  @override
  void dispose() {
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    super.dispose();
  }
}

