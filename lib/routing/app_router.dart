import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'cookie_shell.dart';
import '../pages/landing_page.dart';
import '../pages/blog_page.dart';
import '../pages/comparison_page.dart';
import '../pages/sources_page.dart';
import '../pages/legal_page.dart';
import '../pages/about_page.dart';
import '../pages/signup_page.dart';
import '../pages/pricing_page.dart';
import '../pages/contact_page.dart';
import '../pages/careers_page.dart';
import '../pages/security_page.dart';
import '../pages/docs_observability_page.dart';
import '../pages/docs_tracing_page.dart';
import '../pages/docs_interoperability_page.dart';
import '../pages/docs_api_page.dart';
import '../pages/docs_quickstart_page.dart';
import '../pages/docs_alerts_page.dart';
import '../pages/docs_index_page.dart';
import '../pages/docs_agents_page.dart';
import '../pages/compliance_page.dart';
import '../pages/eu_ai_act_page.dart';
import '../pages/api_toolkit_page.dart';
import '../pages/help_center_page.dart';
import '../pages/features_page.dart';
import '../pages/status_page.dart';
import '../pages/demo_page.dart';
import '../pages/request_success_page.dart';
import '../pages/request_failure_page.dart';
import '../pages/oauth_callback_page.dart';

/// Creates the application router with all routes and redirects.
///
/// Parameters:
/// - [onConsentGiven]: Callback when user gives consent
/// - [onShowCookieSettings]: Callback to show cookie settings (passed to pages with footer)
///
/// Note: Cookie banner visibility is controlled via [cookieBannerNotifier] to avoid
/// recreating the router (which would reset navigation to '/').
GoRouter createAppRouter({
  required VoidCallback onConsentGiven,
  required VoidCallback onShowCookieSettings,
}) {
  return GoRouter(
    // Note: Don't set initialLocation - let GoRouter use browser URL for deep linking
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == '/docs/security/audit-trails') return '/docs/tracing';
      if (path.startsWith('/reports/')) return '/docs';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => CookieBannerShell(
          onConsentGiven: onConsentGiven,
          child: child,
        ),
        routes: [
          // Home
          GoRoute(
            path: '/',
            builder: (context, state) => LandingPage(
              onShowCookieSettings: onShowCookieSettings,
              scrollToSection: state.uri.queryParameters['section'],
            ),
          ),

          // Blog
          GoRoute(
            path: '/blog',
            builder: (context, state) => BlogPage(
              onBack: () => context.go('/'),
            ),
          ),

          // Comparison pages
          GoRoute(
            path: '/whylabs-alternative',
            builder: (context, state) => ComparisonPage.whylabs(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/compare/arize-ai-alternative',
            builder: (context, state) => ComparisonPage.arize(
              onBack: () => context.go('/'),
            ),
          ),

          // Sources
          GoRoute(
            path: '/sources',
            builder: (context, state) => SourcesPage(
              onBack: () => context.go('/'),
            ),
          ),

          // Main pages with cookie settings
          GoRoute(
            path: '/about',
            builder: (context, state) => AboutPage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),
          GoRoute(
            path: '/features',
            builder: (context, state) => FeaturesPage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),
          GoRoute(
            path: '/status',
            builder: (context, state) => StatusPage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),
          GoRoute(
            path: '/pricing',
            builder: (context, state) => PricingPage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),
          GoRoute(
            path: '/contact',
            builder: (context, state) => ContactPage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),
          GoRoute(
            path: '/demo',
            builder: (context, state) => DemoPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/careers',
            builder: (context, state) => CareersPage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),

          // Request result pages
          GoRoute(
            path: '/request_success',
            builder: (context, state) => RequestSuccessPage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),
          GoRoute(
            path: '/request_failure',
            builder: (context, state) => RequestFailurePage(
              onBack: () => context.go('/'),
              onShowCookieSettings: onShowCookieSettings,
            ),
          ),
          GoRoute(
            path: '/support',
            builder: (context, state) => HelpCenterPage(
              onBack: () => context.go('/'),
            ),
          ),

          // OAuth callback
          GoRoute(
            path: '/oauth/callback',
            builder: (context, state) {
              final params = state.uri.queryParameters;
              return OAuthCallbackPage(
                onBack: () => context.go('/'),
                code: params['code'],
                state: params['state'],
                error: params['error'],
                errorDescription: params['error_description'],
              );
            },
          ),

          // Signup with tier query parameter
          GoRoute(
            path: '/signup',
            builder: (context, state) {
              final tier = state.uri.queryParameters['tier'] ?? 'starter';
              return SignupPage(
                tier: tier,
                onBack: () => context.go('/'),
              );
            },
          ),

          // Legal pages
          GoRoute(
            path: '/privacy',
            builder: (context, state) => LegalPage.privacy(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/terms',
            builder: (context, state) => LegalPage.terms(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/cookies',
            builder: (context, state) => LegalPage.cookies(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/accessibility',
            builder: (context, state) => LegalPage.accessibility(
              onBack: () => context.go('/'),
            ),
          ),

          // Security
          GoRoute(
            path: '/security',
            builder: (context, state) => SecurityPage(
              onBack: () => context.go('/'),
            ),
          ),

          // Documentation
          GoRoute(
            path: '/docs',
            builder: (context, state) => DocsIndexPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/docs/llm-observability',
            builder: (context, state) => DocsObservabilityPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/docs/tracing',
            builder: (context, state) => DocsTracingPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/docs/integrations',
            builder: (context, state) => DocsInteroperabilityPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/api',
            builder: (context, state) => DocsApiPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/api/toolkit',
            builder: (context, state) => ApiToolkitPage(
              onBack: () => context.go('/docs'),
            ),
          ),
          GoRoute(
            path: '/docs/quickstart',
            builder: (context, state) => DocsQuickstartPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/docs/alerts',
            builder: (context, state) => DocsAlertsPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/docs/agents',
            builder: (context, state) => DocsAgentsPage(
              onBack: () => context.go('/'),
            ),
          ),

          // Compliance
          GoRoute(
            path: '/compliance',
            builder: (context, state) => CompliancePage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/eu-ai-act',
            builder: (context, state) => EuAiActPage(
              onBack: () => context.go('/'),
            ),
          ),
        ],
      ),
    ],

    // Handle unknown routes by going to home
    errorBuilder: (context, state) => LandingPage(
      onShowCookieSettings: onShowCookieSettings,
    ),
  );
}
