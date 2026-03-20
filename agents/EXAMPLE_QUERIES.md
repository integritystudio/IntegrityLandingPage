# Example Queries — Payment Processor Agent

Reference queries for the payment processor research agent. Copy and paste into your terminal.

## Architecture & Design

### High-Level Overview
```bash
npm run payment-processor -- "Explain why we chose Stripe + Supabase + Cloudflare Workers instead of other SaaS billing platforms"
```

### Component Interactions
```bash
npm run payment-processor -- "Draw a detailed sequence diagram showing how a user signup flows through Supabase Auth → Cloudflare Workers → Provisioning → Entitlements"
```

### Technology Trade-offs
```bash
npm run payment-processor -- "What are the trade-offs between using Cloudflare Workers for API gateway vs. a traditional backend service?"
```

## Data Modeling

### Schema Design
```bash
npm run payment-processor -- "Create a complete SQL schema for organizations, users, memberships, subscriptions, and entitlements with indexes and constraints"
```

### Relationships
```bash
npm run payment-processor -- "Map out all the foreign key relationships and explain why each one is necessary for billing integrity"
```

### Query Optimization
```bash
npm run payment-processor -- "Design efficient SQL queries for: 1) Get a user's active subscription, 2) Check monthly usage, 3) List all orgs in a given plan tier"
```

### Usage Tracking
```bash
npm run payment-processor -- "Design the usage_events and usage_buckets_daily tables with proper partitioning for billing-grade accuracy"
```

## Authentication & Authorization

### OAuth Flow
```bash
npm run payment-processor -- "Detail the complete Supabase OAuth signin flow from Flutter app through JWT issuance and session validation"
```

### API Key Strategy
```bash
npm run payment-processor -- "Design the complete API key lifecycle: generation, storage, rotation, revocation, and security best practices"
```

### Multi-Org Authorization
```bash
npm run payment-processor -- "Explain how to enforce per-user org membership in Postgres RLS policies"
```

### JWT Claims
```bash
npm run payment-processor -- "Design the JWT claims structure using Supabase Custom Access Token Hook. What should be in the JWT vs. fetched server-side?"
```

## Provisioning & Webhooks

### Supabase Webhook Integration
```bash
npm run payment-processor -- "Design the Supabase Database Webhook flow for: 1) User created, 2) Profile updated, 3) Membership changed"
```

### Cloudflare Worker Provisioning
```bash
npm run payment-processor -- "Write the TypeScript code for the provisioning worker that handles user creation: idempotent upsert, org mapping, default entitlements, audit logging"
```

### Stripe Webhook Handler
```bash
npm run payment-processor -- "Implement the Stripe webhook handler for: checkout.session.completed, invoice.paid, customer.subscription.updated, customer.subscription.deleted"
```

### Idempotent Requests
```bash
npm run payment-processor -- "Design an idempotency key system for webhook handlers to prevent duplicate processing"
```

## Rate Limiting & Quotas

### Tier Model
```bash
npm run payment-processor -- "Design a 5-tier pricing model (free, starter, growth, professional, enterprise) with appropriate rate limits and monthly units"
```

### Cloudflare Rate Limiting
```bash
npm run payment-processor -- "Write the Cloudflare Worker code for applying rate limits at the edge based on user tier"
```

### Durable Object Quota
```bash
npm run payment-processor -- "Implement the Durable Object logic for precise, strongly-consistent quota enforcement per organization"
```

### Quota Mutations
```bash
npm run payment-processor -- "Design the quota mutation logic: check current usage, enforce soft limit warning, enforce hard limit rejection"
```

### Monthly Reset
```bash
npm run payment-processor -- "How do we safely reset monthly quotas at the end of the billing period across all organizations?"
```

## API Design

### Bootstrap Endpoint
```bash
npm run payment-processor -- "Validate the /bootstrap endpoint design. What should it return? How should errors be handled? What about caching?"
```

### Usage Endpoints
```bash
npm run payment-processor -- "Design the API endpoints for: GET /v1/usage/summary, POST /v1/usage/events, GET /v1/usage/details?period=month"
```

### API Key Endpoints
```bash
npm run payment-processor -- "Design the API endpoints for creating, listing, rotating, and revoking organization API keys with proper authorization"
```

### Billing Portal
```bash
npm run payment-processor -- "Design the web billing portal endpoints for: subscription management, invoice retrieval, payment method updates, usage analytics"
```

### Error Handling
```bash
npm run payment-processor -- "Design a comprehensive error handling strategy with error codes, HTTP status codes, and user-facing messages"
```

## Security & Compliance

### Security Checklist
```bash
npm run payment-processor -- "Create a comprehensive security checklist for the billing system covering: authentication, authorization, data protection, audit logging"
```

### Secret Management
```bash
npm run payment-processor -- "How should we manage secrets? Stripe API keys, database passwords, JWT signing keys, shared secrets for webhooks?"
```

### PCI DSS Compliance
```bash
npm run payment-processor -- "Explain how using Stripe + Customer Portal keeps us PCI DSS compliant without storing payment methods"
```

### Audit Logging
```bash
npm run payment-processor -- "Design the audit_log table schema and what events should be logged for compliance and security"
```

### Rate Limit Attacks
```bash
npm run payment-processor -- "How do we detect and prevent abuse of the rate limiting system itself?"
```

## Implementation Planning

### Phase 1 Execution
```bash
npm run payment-processor -- "Create a detailed implementation plan for Phase 1: Stripe, Supabase OAuth, Cloudflare gateway, Flutter dashboard. Include tasks, dependencies, and timeline estimates"
```

### Phase 2 Planning
```bash
npm run payment-processor -- "What should Phase 2 include? Self-service API keys, richer quotas, provisioning webhooks. In what order and why?"
```

### Testing Strategy
```bash
npm run payment-processor -- "Design a comprehensive testing strategy for the billing system: unit tests, integration tests, E2E tests, load tests"
```

### Monitoring & Alerting
```bash
npm run payment-processor -- "What metrics should we monitor? Billing accuracy, quota enforcement, API performance, webhook delivery, fraud detection"
```

## Migration & Scaling

### Customer Migration
```bash
npm run payment-processor -- "How do we migrate existing customers from our old billing system to Stripe + Supabase without downtime or data loss?"
```

### Regional Expansion
```bash
npm run payment-processor -- "How does the architecture scale to multiple regions? Currency handling, tax compliance, regional data residency?"
```

### High Availability
```bash
npm run payment-processor -- "Design a high-availability billing system. What are the failure modes? How do we handle Stripe outages, database failures, webhook delivery failures?"
```

### Performance Optimization
```bash
npm run payment-processor -- "What are the performance bottlenecks in billing? How do we optimize quota checks, usage queries, webhook processing?"
```

## Troubleshooting

### Common Issues
```bash
npm run payment-processor -- "What are common billing system issues and how do we debug them? Stuck subscriptions, quota inconsistencies, webhook failures?"
```

### Edge Cases
```bash
npm run payment-processor -- "List edge cases we need to handle: subscription cancellation during trial, refunds after usage, plan downgrades mid-month, org deletion with active subscription"
```

### Race Conditions
```bash
npm run payment-processor -- "Where are the race conditions in the billing system? How do we prevent them? Usage increments, subscription updates, quota resets?"
```

## Custom Questions

Ask anything specific to your implementation:

```bash
npm run payment-processor -- "Your custom question here..."
```

Examples:
- Feature-specific: "How do we implement per-seat billing?"
- Integration: "How does the Flutter app authenticate with the API?"
- Operations: "How do we run billing reports and reconciliation?"
- Compliance: "What's required for SOC 2 Type II certification?"
- Cost: "How do we optimize infrastructure costs?"
