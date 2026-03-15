import { BASE_URL } from './constants';

export interface RouteMeta {
  /** Page title (30-70 chars). */
  title: string;
  /** Meta description (50-160 chars). */
  description: string;
  /** Canonical URL (absolute). */
  canonical: string;
  /** OG/X title override. Falls back to title when omitted. */
  ogTitle?: string;
  /** OG image URL (absolute). Omit to preserve existing. */
  ogImage?: string;
  /** When true, sets robots to noindex, nofollow. */
  noindex?: boolean;
}

/**
 * Builds canonical URL following trailing-slash policy:
 * - Homepage `/` keeps trailing slash
 * - All other routes have no trailing slash
 */
const canonical = (path: string): string =>
  path === '/' ? `${BASE_URL}/` : `${BASE_URL}${path}`;

export const ROUTE_META: Record<string, RouteMeta> = {
  '/': {
    title: 'AI Observability Platform for LLM Monitoring | Integrity Studio',
    description: 'Enterprise AI observability platform. Monitor LLMs, track costs, debug issues with distributed tracing. Trusted AI trust platform for production apps.',
    canonical: canonical('/'),
    ogTitle: 'AI Observability Platform for LLM Monitoring',
  },
  '/about': {
    title: 'About Integrity Studio | AI Observability Team',
    description: 'Meet the team building enterprise AI observability. Our mission is to make AI systems transparent, trustworthy, and compliant.',
    canonical: canonical('/about'),
  },
  '/features': {
    title: 'AI Observability Features | Integrity Studio',
    description: 'LLM monitoring, distributed tracing, cost attribution, anomaly detection, and compliance tools for production AI applications.',
    canonical: canonical('/features'),
  },
  '/pricing': {
    title: 'Pricing Plans for AI Observability | Integrity Studio',
    description: 'Flexible AI observability pricing. Free tier for development, Pro for production teams, Enterprise for scale with dedicated support.',
    canonical: canonical('/pricing'),
  },
  '/contact': {
    title: 'Contact Integrity Studio | AI Observability Sales',
    description: 'Get in touch with the Integrity Studio team. Request a demo, ask about enterprise pricing, or get technical support.',
    canonical: canonical('/contact'),
  },
  '/docs': {
    title: 'Documentation | Integrity Studio AI Observability',
    description: 'Technical documentation for Integrity Studio. Integration guides, API reference, and best practices for AI observability.',
    canonical: canonical('/docs'),
  },
  '/compliance': {
    title: 'AI Compliance and Governance | Integrity Studio',
    description: 'Enterprise compliance solutions for AI systems. Meet SOC 2, GDPR, and EU AI Act requirements with automated audit trails.',
    canonical: canonical('/compliance'),
  },
  '/eu-ai-act': {
    title: 'EU AI Act Compliance Guide | Integrity Studio',
    description: 'Comprehensive guide to EU AI Act observability requirements. GPAI obligations, high-risk AI requirements, and OTel mapping.',
    canonical: canonical('/eu-ai-act'),
  },
  '/security': {
    title: 'Enterprise Security and Data Protection | Integrity Studio',
    description: 'SOC 2 Type II compliance, encryption at rest and in transit, and enterprise security controls for AI observability data.',
    canonical: canonical('/security'),
  },
  '/blog': {
    title: 'AI Observability Blog | Integrity Studio Insights',
    description: 'Expert insights on AI observability, LLM monitoring, EU AI Act compliance, and building trustworthy AI systems.',
    canonical: canonical('/blog'),
  },
  '/careers': {
    title: 'Careers at Integrity Studio | Join Our AI Team',
    description: 'Join the team building the future of AI observability. Open positions in engineering, data science, and compliance.',
    canonical: canonical('/careers'),
  },
  // Tier 3: noindex routes
  '/signup': {
    title: 'Sign Up for Integrity Studio | AI Observability',
    description: 'Create your free Integrity Studio account. Get started with AI observability for LLM monitoring and compliance.',
    canonical: canonical('/signup'),
    noindex: true,
  },
  '/request_success': {
    title: 'Request Received | Integrity Studio',
    description: 'Thank you for your request. Our team will review it and get back to you within one business day.',
    canonical: canonical('/request_success'),
    noindex: true,
  },
  '/request_failure': {
    title: 'Request Error | Integrity Studio',
    description: 'Something went wrong with your request. Please try again or contact us directly for assistance.',
    canonical: canonical('/request_failure'),
    noindex: true,
  },
  '/oauth/callback': {
    title: 'Authentication | Integrity Studio',
    description: 'Processing your authentication request. You will be redirected to the Integrity Studio dashboard shortly.',
    canonical: canonical('/oauth/callback'),
    noindex: true,
  },
};

/** Look up route metadata by pathname. Returns undefined for unmapped routes. */
export const getRouteMeta = (pathname: string): RouteMeta | undefined =>
  ROUTE_META[pathname];
