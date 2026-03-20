import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import 'cookie_shell.dart';
import '../pages/landing_page.dart';
import '../pages/blog_page.dart';
import '../pages/comparison_page.dart';
import '../pages/sources_page.dart';
import '../pages/legal_page.dart';
import '../pages/about_page.dart';
import '../pages/signup_page.dart';
import '../pages/auth_page.dart';
import '../pages/provision_page.dart';
import '../pages/sender_health_page.dart';
import '../pages/pricing_page.dart';
import '../services/provisioning_service.dart';
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

/// Returns a callback that navigates to the home route.
/// Used to avoid repeating `() => context.go(Routes.home)` across every route.
VoidCallback _goHome(BuildContext context) => () => context.go(Routes.home);

GoRoute _homeRoute(VoidCallback onShowCookieSettings) => GoRoute(
      path: '/',
      builder: (context, state) => LandingPage(
        onShowCookieSettings: onShowCookieSettings,
        scrollToSection: state.uri.queryParameters['section'],
      ),
    );

List<GoRoute> _blogRoutes() => [
      GoRoute(
        path: '/blog',
        builder: (context, state) => BlogPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/whylabs-alternative',
        builder: (context, state) => ComparisonPage.whylabs(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/compare/arize-ai-alternative',
        builder: (context, state) => ComparisonPage.arize(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/sources',
        builder: (context, state) => SourcesPage(onBack: _goHome(context)),
      ),
    ];

List<GoRoute> _mainPageRoutes(VoidCallback onShowCookieSettings) => [
      GoRoute(
        path: '/about',
        builder: (context, state) => AboutPage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
      GoRoute(
        path: '/features',
        builder: (context, state) => FeaturesPage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
      GoRoute(
        path: '/status',
        builder: (context, state) => StatusPage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => PricingPage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => ContactPage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
          ref: state.uri.queryParameters['ref'],
        ),
      ),
      GoRoute(
        path: '/demo',
        builder: (context, state) => DemoPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/careers',
        builder: (context, state) => CareersPage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
    ];

List<GoRoute> _authRoutes(VoidCallback onShowCookieSettings) => [
      GoRoute(
        path: '/request_success',
        builder: (context, state) => RequestSuccessPage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
      GoRoute(
        path: '/request_failure',
        builder: (context, state) => RequestFailurePage(
          onBack: _goHome(context),
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => HelpCenterPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/oauth/callback',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return OAuthCallbackPage(
            onBack: _goHome(context),
            code: params['code'],
            state: params['state'],
            error: params['error'],
            errorDescription: params['error_description'],
            success: params['success'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupPage(
          tier: state.uri.queryParameters['tier'] ?? 'starter',
          onBack: _goHome(context),
        ),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => AuthPage(
          mode: AuthMode.signIn,
          onBack: _goHome(context),
        ),
      ),
      GoRoute(
        path: '/provision',
        redirect: (context, state) {
          if (state.extra is! AuthSuccess) return Routes.signin;
          return null;
        },
        builder: (context, state) => ProvisionPage(
          auth: state.extra as AuthSuccess,
          onBack: _goHome(context),
        ),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => SenderHealthPage(
          onBack: _goHome(context),
        ),
      ),
    ];

List<GoRoute> _legalRoutes() => [
      GoRoute(
        path: '/privacy',
        builder: (context, state) => LegalPage.privacy(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => LegalPage.terms(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/cookies',
        builder: (context, state) => LegalPage.cookies(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/accessibility',
        builder: (context, state) => LegalPage.accessibility(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/security',
        builder: (context, state) => SecurityPage(onBack: _goHome(context)),
      ),
    ];

List<GoRoute> _docsRoutes() => [
      GoRoute(
        path: '/docs',
        builder: (context, state) => DocsIndexPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/docs/llm-observability',
        builder: (context, state) => DocsObservabilityPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/docs/tracing',
        builder: (context, state) => DocsTracingPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/docs/integrations',
        builder: (context, state) => DocsInteroperabilityPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/api',
        builder: (context, state) => DocsApiPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/api/toolkit',
        builder: (context, state) => ApiToolkitPage(
          onBack: () => context.go(Routes.docs),
        ),
      ),
      GoRoute(
        path: '/docs/quickstart',
        builder: (context, state) => DocsQuickstartPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/docs/alerts',
        builder: (context, state) => DocsAlertsPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/docs/agents',
        builder: (context, state) => DocsAgentsPage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/compliance',
        builder: (context, state) => CompliancePage(onBack: _goHome(context)),
      ),
      GoRoute(
        path: '/eu-ai-act',
        builder: (context, state) => EuAiActPage(onBack: _goHome(context)),
      ),
    ];

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
          _homeRoute(onShowCookieSettings),
          ..._blogRoutes(),
          ..._mainPageRoutes(onShowCookieSettings),
          ..._authRoutes(onShowCookieSettings),
          ..._legalRoutes(),
          ..._docsRoutes(),
        ],
      ),
    ],

    // Handle unknown routes by going to home
    errorBuilder: (context, state) => LandingPage(
      onShowCookieSettings: onShowCookieSettings,
    ),
  );
}
