/// Hero section content variants.
///
/// Supports A/B testing with multiple positioning variants.
library;

import 'models.dart';
import 'constants.dart';

/// Hero content variants for A/B testing.
abstract final class HeroContentVariants {
  /// Current production content (EU AI Act positioning)
  /// Rationale: White space opportunity - no competitor owns compliance messaging
  static const current = HeroContent(
    badge: 'EU AI Act Ready',
    headline: 'AI Observability That\nProves Compliance',
    subheadline:
        'Full traceability for every LLM decision. '
        'Automated risk documentation. Audit-ready from day one. '
        'Enterprise-grade monitoring with compliance built-in.',
    primaryCTA: CTAText.startFreeTrial,
    secondaryCTA: CTAText.requestDemo,
    trustIndicators: TrustIndicators.current,
  );

  /// Variant B: Agent-first positioning
  /// For A/B testing - targets agentic AI category
  static const agentFirst = HeroContent(
    badge: 'AI Observability Platform',
    headline: 'See Every Decision\nYour AI Agents Make',
    subheadline:
        'End-to-end visibility into your AI agent workflows. '
        'Track performance, debug issues, and optimize costs '
        'with comprehensive tracing and analytics.',
    primaryCTA: CTAText.startFreeTrial,
    secondaryCTA: CTAText.requestDemo,
    trustIndicators: TrustIndicators.current,
  );

  /// Variant C: Cost-focused positioning
  /// For A/B testing - targets FinOps-conscious buyers
  static const costFocused = HeroContent(
    badge: 'LLM Cost Intelligence',
    headline: 'Know Your AI Spend\nBefore It Surprises You',
    subheadline:
        'Real-time cost tracking for every LLM call. '
        'Set budgets, get alerts, and optimize spend '
        'with granular token-level attribution.',
    primaryCTA: CTAText.startFreeTrial,
    secondaryCTA: CTAText.requestDemo,
    trustIndicators: TrustIndicators.current,
  );

  /// Legacy content (pre-audit) - kept for rollback
  static const legacy = HeroContent(
    badge: 'AI Observability Platform',
    headline: 'Understand Your\nAI in Production',
    subheadline:
        'Enterprise-grade observability for LLM applications. '
        'Monitor performance, track costs, and debug issues '
        'with comprehensive tracing and analytics.',
    primaryCTA: CTAText.startFreeTrial,
    secondaryCTA: CTAText.requestDemo,
    trustIndicators: TrustIndicators.legacy,
  );
}
