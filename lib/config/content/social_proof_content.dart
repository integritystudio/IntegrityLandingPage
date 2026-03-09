/// Social proof section content.
///
/// NOTE: Testimonials are now sourced from content.yaml via AppContent.socialProof.
/// This file contains only legacy placeholder content for reference.
library;

import 'models.dart';
import 'constants.dart';

/// Social proof content variants.
///
/// @deprecated Use AppContent.socialProof instead, which loads from content.yaml.
abstract final class SocialProofContentVariants {
  /// Placeholder content (legacy - use AppContent.socialProof instead)
  static final placeholder = SocialProofContent(
    title: 'Trusted by AI Teams',
    logos: _placeholderLogos,
    testimonials: [], // Testimonials now sourced from content.yaml
    statsHeadline: 'Enterprise-Grade Performance',
    stats: {
      'Traces Processed': PlatformMetrics.tracesProcessed,
      'Uptime': PlatformMetrics.uptime,
      'Setup Time': '< ${PlatformMetrics.setupTime}',
    },
  );

  static const _placeholderLogos = [
    CustomerLogoContent(name: 'Enterprise Client', industry: 'Finance'),
    CustomerLogoContent(name: 'Tech Startup', industry: 'SaaS'),
    CustomerLogoContent(name: 'Healthcare Co', industry: 'Healthcare'),
  ];
}
