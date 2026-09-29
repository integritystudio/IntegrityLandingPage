/// Content helpers for tests: load the real content.yaml (the default for every
/// test, via flutter_test_config.dart), swap a fixture in for one test, and the
/// placeholder fixture content_loader_test.dart reads.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';
import 'load_content_stub.dart'
    if (dart.library.io) 'load_content_native.dart'
    if (dart.library.html) 'load_content_web.dart' as platform;

/// Initialize test content before running widget tests.
///
/// Loads from the real content.yaml file to ensure tests use actual values.
/// Call this in setUpAll or setUp for test files that use ContentLoader.
void initializeTestContent() {
  loadRealContent();
}

/// Async variant for web platform where dart:io is unavailable.
/// Loads content.yaml from Flutter assets via rootBundle.
Future<void> initializeTestContentAsync() async {
  await platform.loadRealContentAsync();
}

/// Loads [yaml] for the rest of the current test, and restores the real
/// content.yaml when it ends (web-safe), so no other test sees the fixture.
void withContent(String yaml) {
  ContentLoader.loadFromString(yaml);
  addTearDown(initializeTestContentAsync);
}

/// The real content.yaml with the first occurrence of [from] replaced by [to], for
/// a test that needs one value to differ from production copy. Throws when [from]
/// is missing, so a content edit cannot quietly turn the test into a no-op.
Future<String> realContentWith(String from, String to) async {
  final yaml = await platform.readRealContentYaml();
  if (!yaml.contains(from)) {
    throw StateError('content.yaml no longer contains: $from');
  }
  return yaml.replaceFirst(from, to);
}

/// Reset content state after tests.
///
/// Call this in tearDownAll or tearDown if needed.
void resetTestContent() {
  ContentLoader.reset();
}

/// Load the real content.yaml file for unit tests.
///
/// On native: reads content.yaml from the file system via dart:io.
/// On web: throws — use [initializeTestContentAsync] instead.
void loadRealContent() {
  platform.loadRealContent();
}

// ---------------------------------------------------------------------------
// ContentLoader test-specific content and helpers
// ---------------------------------------------------------------------------

/// Test content YAML for content_loader_test.dart.
///
/// Uses different values than testContentYaml to ensure test assertions
/// are checking the correct content source.
const contentLoaderTestYaml = '''
company:
  name: "Test Company"
  tagline: "Test Tagline"
  copyright: "© 2024 Test"
  founded_year: "2024"
  location:
    city: "Austin"
    region: "Texas"
  contact:
    email: "test@example.com"
    phone: "555-1234"

urls:
  external:
    calendly_demo: "https://calendly.com/test"
    calendly_intro: "https://calendly.com/test-intro"
    status_page: "https://status.test.com"
    linkedin: "https://linkedin.com/test"
    github: "https://github.com/test"
    founder_linkedin: "https://linkedin.com/in/founder"
    deep_dive: "https://calendly.com/test-deep-dive"
    address: "https://www.google.com/maps/search/?api=1&query=Test+Address"
  internal:
    contact: "/test-contact"

cta_text:
  primary:
    start_free_trial: "Start Free Trial"
    get_started: "Get Started"
    schedule_demo: "Schedule Demo"
    request_demo: "Request Demo"
    contact_sales: "Contact Sales"
    learn_more: "Learn More"
  form:
    send_message: "Send Message"

signup:
  tiers:
    starter:
      heading: "Start Your Free Trial"
      description: "Perfect for individual developers getting started with AI observability."
      cta: "Start Free Trial"
      features:
        - "14-day free trial"
        - "No credit card required"
        - "Cancel anytime"
    growth:
      heading: "Create Your Account"
      description: "For growing teams that need advanced monitoring features."
      cta: "Create Account"
      features:
        - "Instant access after signup"
        - "Secure checkout"
        - "Cancel anytime"
    enterprise:
      heading: "Create Your Account"
      description: "Custom solutions with dedicated support and SLAs."
      cta: "Create Account"
      features:
        - "Instant access after signup"
        - "Secure checkout"
        - "Cancel anytime"

trust_indicators:
  current:
    - "Feature A"
    - "Feature B"
    - "Feature C"
  legacy:
    - "Old Feature 1"
    - "Old Feature 2"

platform_metrics:
  uptime: "99.9%"
  uptime_sla: "SLA Guaranteed"
  traces_processed: "10M+"
  traces_processed_period: "Daily"
  ai_teams: "500+"
  setup_time: "5 min"
  setup_time_label: "Average"

pricing_constants:
  annual_discount: "Save 20%"

pricing:
  title: "Test Pricing"
  subtitle: "Test pricing subtitle"
  tiers:
    - name: "Free"
      monthly_price: "\$0"
      annual_price: "\$0"
      description: "For testing"
      features:
        - "Feature 1"
        - "Feature 2"
    - name: "Pro"
      monthly_price: "\$99"
      annual_price: "\$79"
      is_popular: true
      features:
        - "Everything in Free"
        - "Pro Feature"

hero:
  current:
    badge: "Test Badge"
    headline: "Test Headline"
    subheadline: "Test Subheadline"
    primary_cta: "Primary CTA"
    secondary_cta: "Secondary CTA"
  variants:
    alternate:
      badge: "Alt Badge"
      headline: "Alt Headline"
      subheadline: "Alt Subheadline"
      primary_cta: "Alt Primary"
      secondary_cta: "Alt Secondary"

features:
  title: "Features Title"
  subtitle: "Features Subtitle"
  items:
    - icon: "activity"
      title: "Feature 1"
      description: "Description 1"
      bullets:
        - "Bullet 1"
        - "Bullet 2"
    - icon: "shield"
      title: "Feature 2"
      description: "Description 2"

services:
  title: "Services Title"
  subtitle: "Services Subtitle"
  description: "Services Description"
  items:
    - icon: "code"
      title: "Service 1"
      description: "Service description"
      capabilities:
        - "Capability 1"
        - "Capability 2"

cta:
  headline: "CTA Headline"
  subheadline: "CTA Subheadline"

about:
  title: "About Title"
  subtitle: "About Subtitle"
  mission_statement: "Our mission"
  vision_statement: "Our vision"
  story: "Our story"
  values:
    - icon: "eye"
      title: "Transparency"
      description: "Be transparent"
  team:
    - name: "John Doe"
      role: "CEO"
      bio: "Leader"
      linkedin_url: "https://linkedin.com/in/johndoe"

contact:
  title: "Contact Title"
  subtitle: "Contact Subtitle"
  description: "Contact Description"
  hero_headline: "Contact Hero Headline"
  methods_heading: "Contact Methods Heading"
  form:
    fields:
      - name: "email"
        label: "Email"
        placeholder: "your@email.com"
        type: "email"
        required: true
    success_message: "Success!"
    error_message: "Error!"
  contact_methods:
    - icon: "mail"
      label: "Email"
      value: "test@example.com"
      url: "mailto:test@example.com"
      is_primary: true

compliance:
  contact_link_description: "Compliance Contact Link Description"

footer:
  privacy_link: "/privacy"
  terms_link: "/terms"
  cookies_link: "/cookies"
  cookie_settings_label: "Cookie Settings"
  tagline: "Footer Tagline"
  privacy_label: "Privacy Label"
  privacy_label_short: "Privacy Short"
  terms_label: "Terms Label"
  terms_label_short: "Terms Short"
  cookies_label: "Cookies Label"
  cookies_label_short: "Cookies Short"
  accessibility_label: "Accessibility Label"
  link_groups:
    - title: "Product"
      links:
        - label: "Features"
          url: "/features"
        - label: "Pricing"
          url: "#pricing"
          is_external: false

status:
  title: "Status Title"
  subtitle: "Status Subtitle"
  status_badge: "All Operational"
  status_page_cta: "Status Page CTA"
  metrics:
    - label: "Uptime"
      value: "99.9%"
      sublabel: "SLA"
  services:
    - name: "API"
      status: "Operational"

resources:
  title: "Resources Title"
  subtitle: "Resources Subtitle"
  blog_cta_text: "Blog CTA"
  docs_cta_text: "Docs CTA"
  documentation:
    - icon: "book-open"
      title: "Getting Started"
      description: "Quick start"
      url: "/docs/quickstart"
      popular_topics:
        - "Setup"
        - "Configuration"
  featured_posts:
    - title: "Test Post"
      excerpt: "Test excerpt"
      category: "Guide"
      publish_date: "2024-01-01"
      read_time: "5 min"
      slug: "test-post"
      author: "Test Author"
  lead_magnets:
    - icon: "file-text"
      title: "Test Guide"
      description: "A test guide"
      format: "PDF"
      cta_text: "Download"
      url: "/resources/test"
      requires_email: true

social_proof:
  title: "Social Proof Title"
  stats_headline: "Stats Headline"
  logos:
    - name: "Test Logo"
      industry: "Test Industry"
  stats:
    uptime: "99.9%"
    traces: "10M+"
  testimonials:
    - quote: "Great product!"
      author: "Jane Doe"
      role: "CTO"
      company: "Test Corp"

disclaimers:
  eu_ai_act: "EU AI Act disclaimer"
  eu_ai_act_short: "Short disclaimer"
  security: "Security disclaimer"
  general: "General disclaimer"
''';

/// Set up content loader for tests.
///
/// Resets the loader and loads contentLoaderTestYaml.
void setUpContentLoaderTest() {
  ContentLoader.reset();
  ContentLoader.loadFromString(contentLoaderTestYaml);
}

/// Tear down content loader after tests.
void tearDownContentLoaderTest() {
  ContentLoader.reset();
}
