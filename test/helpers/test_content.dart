/// Test content for widget tests.
///
/// This provides a minimal YAML content structure that allows widgets
/// to render without requiring actual asset loading.
library;

import 'dart:io';
import 'package:integrity_studio_ai/services/content_loader.dart';

/// Minimal test content YAML that satisfies all Content getters.
const testContentYaml = '''
company:
  name: "Test Company"
  tagline: "Test Tagline"
  copyright: "© 2024 Test Company"
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
    status_page: "https://status.test.com"
    linkedin: "https://linkedin.com/test"
    x: "https://x.com/test"
    github: "https://github.com/test"
    founder_linkedin: "https://linkedin.com/in/founder"
    founder_x: "https://x.com/founder"

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

trust_indicators:
  current:
    - "EU AI Act Ready"
    - "Enterprise Security"
    - "99.9% Uptime"
    - "5-min Setup"
  legacy:
    - "No credit card required"
    - "14-day free trial"

platform_metrics:
  uptime: "99.9%"
  traces_processed: "10M+"
  ai_teams: "500+"
  setup_time: "5 min"

pricing_constants:
  annual_discount: "Save 20%"

pricing:
  title: "Simple, Transparent Pricing"
  subtitle: "Start free, scale as you grow"
  tiers:
    - name: "Starter"
      monthly_price: "Free"
      annual_price: "Free"
      description: "For individual developers"
      cta_text: "Get Started"
      features:
        - "50K traces/month"
        - "7-day retention"
        - "Basic dashboards"
    - name: "Team"
      monthly_price: "\$99"
      annual_price: "\$79"
      period: "/month"
      description: "For growing teams"
      is_popular: true
      cta_text: "Start Free Trial"
      features:
        - "500K traces/month"
        - "30-day retention"
        - "Advanced analytics"
    - name: "Enterprise"
      monthly_price: "Custom"
      annual_price: "Custom"
      description: "For large organizations"
      cta_text: "Contact Sales"
      features:
        - "Unlimited traces"
        - "1-year retention"
        - "SSO/SAML"

hero:
  current:
    badge: "EU AI Act Ready"
    headline: "AI Observability That\\nProves Compliance"
    subheadline: "Full traceability for every LLM decision."
    primary_cta: "Start Free Trial"
    secondary_cta: "Request Demo"
  variants:
    agent_first:
      badge: "AI Observability Platform"
      headline: "See Every Decision"
      subheadline: "End-to-end visibility"
      primary_cta: "Start Free Trial"
      secondary_cta: "Request Demo"

features:
  title: "Platform Capabilities"
  subtitle: "Comprehensive tools for AI application observability"
  items:
    - icon: "activity"
      title: "LLM Monitoring"
      description: "Track every LLM call with detailed metrics."
      bullets:
        - "Token usage tracking"
        - "Latency monitoring"
    - icon: "git-branch"
      title: "Distributed Tracing"
      description: "End-to-end visibility across your AI application."
      bullets:
        - "Request correlation"
        - "Service mapping"
    - icon: "shield"
      title: "Compliance Reporting"
      description: "Automated documentation for EU AI Act."
      bullets:
        - "Audit trails"
        - "Risk classification"

services:
  title: "Platform Services"
  subtitle: "Comprehensive AI Observability"
  description: "From real-time LLM monitoring to compliance reporting."
  items:
    - icon: "activity"
      title: "LLM Monitoring & Tracing"
      description: "Track every LLM call with sub-100ms latency."
      cta_text: "View Docs"
      cta_url: "/docs/tracing"
      capabilities:
        - "Full request/response capture"
        - "Cost tracking per request"
    - icon: "shield"
      title: "Compliance & Governance"
      description: "Built-in EU AI Act templates."
      cta_text: "EU AI Act Guide"
      cta_url: "/eu-ai-act"
      disclaimer: "Tools to support compliance efforts."
      capabilities:
        - "Article 12 traceability"
        - "Audit trail generation"

cta:
  headline: "Ready to Gain Visibility Into Your AI?"
  subheadline: "Join teams who trust us for AI observability."

about:
  title: "About Integrity Studio"
  subtitle: "Building Trust in AI Systems"
  mission_statement: "Empower enterprises to build trustworthy AI systems."
  vision_statement: "To be the standard for enterprise AI observability."
  story: "Integrity Studio was founded to solve the visibility problem."
  values:
    - icon: "eye"
      title: "Transparency"
      description: "We believe AI systems should be observable."
    - icon: "shield-check"
      title: "Trust"
      description: "Trust is earned through reliability."
  team:
    - name: "Test Person"
      role: "CEO"
      bio: "Test bio"
      linkedin_url: "https://linkedin.com/in/test"

contact:
  title: "Get in Touch"
  subtitle: "Let's discuss how we can help"
  description: "Our team is here to help with demos and questions."
  calendly_cta_text: "Schedule a Demo"
  form:
    submit_text: "Send Message"
    fields:
      - name: "firstName"
        label: "First Name"
        placeholder: "John"
        type: "text"
        required: true
      - name: "lastName"
        label: "Last Name"
        placeholder: "Doe"
        type: "text"
        required: true
      - name: "email"
        label: "Email"
        placeholder: "your@email.com"
        type: "email"
        required: true
      - name: "company"
        label: "Company"
        placeholder: "Acme Inc."
        type: "text"
        required: true
      - name: "companySize"
        label: "Company Size"
        placeholder: "Select..."
        type: "select"
        required: false
        options:
          - "1-10"
          - "11-50"
          - "51-200"
          - "201-1,000"
          - "1,000+"
      - name: "useCase"
        label: "Use Case"
        placeholder: "Select..."
        type: "select"
        required: false
        options:
          - "LLM Monitoring"
          - "Compliance"
          - "Cost Optimization"
          - "Other"
      - name: "message"
        label: "Message"
        placeholder: "Your message"
        type: "textarea"
        required: false
    success_message: "Thank you for reaching out! We'll be in touch soon."
    error_message: "Something went wrong. Please email us directly."
  contact_methods:
    - icon: "mail"
      label: "Email"
      value: "test@example.com"
      url: "mailto:test@example.com"
      is_primary: true
    - icon: "calendar"
      label: "Schedule a Demo"
      value: "Book a call"
      url: "https://calendly.com/test"
      is_primary: true
    - icon: "map-pin"
      label: "Location"
      value: "Austin, TX"
      is_primary: false
    - icon: "linkedin"
      label: "LinkedIn"
      value: "@integritystudio"
      url: "https://linkedin.com/company/test"
      is_primary: false
    - icon: "x"
      label: "X"
      value: "@integritystudio"
      url: "https://x.com/test"
      is_primary: false
    - icon: "github"
      label: "GitHub"
      value: "integrity-studio"
      url: "https://github.com/test"
      is_primary: false

footer:
  privacy_link: "/privacy"
  terms_link: "/terms"
  cookies_link: "/cookies"
  link_groups:
    - title: "Product"
      links:
        - label: "Features"
          url: "#features"
        - label: "Pricing"
          url: "#pricing"
    - title: "Company"
      links:
        - label: "About"
          url: "/about"
        - label: "Contact"
          url: "/contact"

status:
  title: "Platform Status"
  subtitle: "Real-time operational health"
  status_badge: "All Systems Operational"
  metrics:
    - label: "Uptime"
      value: "99.9%"
      sublabel: "SLA Guaranteed"
    - label: "Traces"
      value: "10M+"
      sublabel: "Daily"
  services:
    - name: "Trace Ingestion API"
      status: "Operational"
    - name: "Dashboard"
      status: "Operational"

resources:
  title: "Resources"
  subtitle: "Guides, Documentation & Insights"
  blog_cta_text: "View All Posts"
  blog_cta_url: "/blog"
  docs_cta_text: "Browse Documentation"
  docs_cta_url: "/docs"
  documentation:
    - icon: "book-open"
      title: "Getting Started"
      description: "Quick start in under 5 minutes."
      url: "/docs/quickstart"
      popular_topics:
        - "Python SDK"
        - "TypeScript SDK"
        - "OpenTelemetry"
    - icon: "code"
      title: "API Reference"
      description: "Complete API documentation."
      url: "/docs/api"
      popular_topics:
        - "REST API"
        - "GraphQL"
        - "Webhooks"
    - icon: "shield"
      title: "Compliance Guides"
      description: "Regulatory compliance documentation."
      url: "/docs/compliance"
      popular_topics:
        - "EU AI Act"
        - "SOC 2"
        - "GDPR"
    - icon: "plug"
      title: "Integrations"
      description: "Third-party integrations."
      url: "/docs/integrations"
      popular_topics:
        - "LangChain"
        - "OpenAI"
        - "Anthropic"
  featured_posts:
    - title: "Best LLM Monitoring Tools"
      excerpt: "A comprehensive guide."
      category: "Guide"
      publish_date: "2024-12-24"
      read_time: "18 min"
      slug: "best-llm-monitoring"
      author: "Test Author"
  lead_magnets:
    - icon: "clipboard-check"
      title: "EU AI Act Checklist"
      description: "A comprehensive checklist."
      format: "PDF"
      cta_text: "Download"
      url: "/resources/checklist"
      requires_email: true

social_proof:
  title: "Trusted by AI Teams"
  stats:
    traces_processed: "10M+"
    uptime: "99.9%"
    setup_time: "< 5 min"
  testimonials:
    - quote: "Integrity Studio reduced our LLM debugging time by 73%. We now catch issues before our users do."
      author: "Joey Rahman"
      role: "VP of Engineering"
      company: "granica.ai"
      metric: "73% faster"
      metric_context: "issue resolution"
    - quote: "The EU AI Act compliance tools saved us months of preparation. Audit-ready documentation out of the box."
      author: "Matthew Gregory"
      role: "Director, Hines Development Company"
      company: "Hines Financial Group"
      metric: "3 months"
      metric_context: "compliance prep saved"
    - quote: "We cut our LLM costs by 40% within the first month. The cost tracking alone pays for itself."
      author: "Aaron Bryson"
      role: "Head of AI"
      company: "DataDriven Labs"
      metric: "40%"
      metric_context: "cost reduction"

disclaimers:
  eu_ai_act: "Tools to support EU AI Act compliance efforts."
  eu_ai_act_short: "EU AI Act support tools."
  security: "Security certifications in progress."
  general: "This platform provides AI governance tools."

promo_codes:
  whylabs_migration:
    code: "WHYLABS2025"
    description: "Get 3 months free on Team tier."

statistics:
  industry:
    market_size:
      value: "\$8.1B"
      label: "market by 2034"
      source: "Market.us, LLM Observability Platform Market Report 2025"
      source_url: "https://market.us/report/llm-observability-platform-market/"
    market_growth:
      value: "44%"
      label: "YoY AI spending growth"
      source: "Gartner AI Spending Forecast, January 2026"
      source_url: "https://www.gartner.com/en/newsroom/press-releases/2026-1-15-gartner-says-worldwide-ai-spending-will-total-2-point-5-trillion-dollars-in-2026"
    enterprise_budgets:
      value: "98%"
      label: "enterprises increasing AI budgets"
      source: "Gartner CIO Survey 2024"
      source_url: "https://www.gartner.com/en/information-technology/insights/cio-agenda"
  customer_data:
    debugging_improvement:
      value: "73%"
      label: "faster debugging"
      source: "Aggregated customer data, Q4 2025"
    cost_reduction:
      value: "30-50%"
      label: "LLM cost reduction"
      source: "Customer-reported savings, 2025"
  platform:
    traces_processed:
      value: "10M+"
      label: "traces processed"
      source: "Platform metrics, December 2025"
    setup_time:
      value: "5min"
      label: "setup time"
      source: "Median onboarding time, 2025"
    uptime_target:
      value: "99.9%"
      label: "uptime SLA"
      source: "Service Level Agreement target"
  source_disclaimer: "Statistics from customer data are aggregated and anonymized."
''';

/// Initialize test content before running widget tests.
///
/// Loads from the real content.yaml file to ensure tests use actual values.
/// Call this in setUpAll or setUp for test files that use Content.
void initializeTestContent() {
  loadRealContent();
}

/// Reset content state after tests.
///
/// Call this in tearDownAll or tearDown if needed.
void resetTestContent() {
  Content.reset();
}

/// Load the real content.yaml file for unit tests.
///
/// This reads content.yaml directly from the file system.
void loadRealContent() {
  final file = File('content.yaml');
  if (!file.existsSync()) {
    throw StateError(
      'content.yaml not found. Run tests from the project root directory.',
    );
  }
  final yamlString = file.readAsStringSync();
  Content.loadFromString(yamlString);
}

/// Initialize with minimal test content (for isolated widget tests).
///
/// Use this when you need deterministic test values that don't depend on
/// the real content.yaml file.
void initializeMinimalTestContent() {
  Content.loadFromString(testContentYaml);
}
