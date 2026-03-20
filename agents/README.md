# Payment Processor Research Agent

An AI-powered agent that analyzes Integrity Studio's billing architecture research and provides expert guidance on SaaS payment processor design.

## Features

- **Architecture Analysis** — Explains the Stripe + Supabase + Cloudflare Workers + Flutter stack
- **Data Modeling** — Designs and validates Postgres schemas for billing systems
- **Provisioning Flows** — Details webhook integration patterns and event-driven architecture
- **API Validation** — Reviews API contracts, response payloads, and error handling
- **Rate Limiting & Quotas** — Designs tier models and enforcement strategies
- **Security Review** — Applies defense-in-depth principles and validates auth patterns

## Installation

```bash
npm install
```

## Usage

### Interactive Mode

Ask a custom question about the billing architecture:

```bash
npm run payment-processor -- "How should we handle subscription cancellations?"
```

### Predefined Queries

**Architecture Overview:**
```bash
npm run payment-processor:architecture
# Explains the multi-tier architecture and component interactions
```

**Data Model Design:**
```bash
npm run payment-processor:data-model
# Generates a complete Postgres schema for the billing system
```

**Provisioning Flow:**
```bash
npm run payment-processor:provisioning
# Details webhook integration from Supabase through Cloudflare Workers
```

**Security Review:**
```bash
npm run payment-processor:security
# Reviews all security rules and recommends hardening measures
```

**Rate Limiting Strategy:**
```bash
npm run payment-processor:rate-limiting
# Designs tier models and quota enforcement patterns
```

## Example Queries

```bash
# Data model design
npm run payment-processor -- "Create a detailed SQL schema for the organizations, subscriptions, and entitlements tables"

# API contract review
npm run payment-processor -- "Review the /bootstrap API endpoint and validate its response structure"

# Security analysis
npm run payment-processor -- "List all potential security vulnerabilities in the JWT claims strategy"

# Implementation planning
npm run payment-processor -- "Create a phased implementation plan for Phase 1 of the billing system"

# Troubleshooting
npm run payment-processor -- "How do we handle race conditions in Durable Object quota mutations?"
```

## Agent Capabilities

The agent has access to:

- **Read** — Read project files (schemas, configs, documentation)
- **Grep** — Search codebase for patterns and examples
- **Glob** — Find related files by pattern

The agent analyzes the research document (`docs/roadmap/payment-processor-research.md`) to provide:

1. **Architecture guidance** with specific technology choices and trade-offs
2. **Complete data models** with field definitions and relationships
3. **Integration patterns** for Stripe, Supabase, and Cloudflare Workers
4. **Security best practices** for multi-tenant SaaS systems
5. **Cost optimization** strategies for billing and quota enforcement

## Architecture Reference

### Core Stack

- **Billing**: Stripe (subscriptions, Customer Portal, webhooks)
- **Auth**: Supabase OAuth (user identity) + API keys (machine access)
- **Database**: Supabase/Postgres (users, orgs, entitlements, usage)
- **Edge**: Cloudflare Workers (API gateway, rate limiting, JWT verification)
- **Quota**: Cloudflare Durable Objects (strong consistency, per-org counters)
- **Mobile**: Flutter (companion app, dashboard, usage tracking)

### Key Tables

```
organizations          — Stripe customers, subscription status
users                 — Supabase auth users
organization_memberships — User org relationships
subscriptions         — Stripe subscription state
entitlements          — Feature flags and limits
api_keys              — Integration and mobile keys
usage_events          — Usage metrics for billing
usage_buckets_daily   — Materialized daily rollups
```

## Authentication Model

**Two-layer auth:**

1. **Human Identity** — Supabase OAuth + JWT session (answers "who is the person?")
2. **Machine Access** — API keys scoped to orgs (answers "what client/app is calling?")

## Rate Limiting Strategy

**Two-tier enforcement:**

1. **Cloudflare Edge** — Fast, local throttling per tier (free/growth/enterprise)
2. **Durable Objects** — Precise quota mutations with strong consistency per org

## Implementation Phases

### Phase 1 (MVP)
- Stripe web billing
- Supabase OAuth
- Cloudflare Worker gateway
- One Durable Object per org
- Flutter dashboard with billing status

### Phase 2 (Self-Service)
- Org API key self-service
- Customer Portal integration
- Richer quota families
- Provisioning from Supabase webhooks

### Phase 3 (Enterprise)
- Seat-based billing
- Usage-based add-ons
- Enterprise SSO/SCIM
- Per-integration API key policies

## Environment Variables

```bash
ANTHROPIC_API_KEY=sk-ant-... # Required for agent queries
```

## Notes

- The agent uses Claude Opus 4.6 with adaptive thinking for complex architecture analysis
- Queries are stateless — each invocation is independent
- The agent references the research document directly for accurate guidance
- Use specific questions for more targeted analysis
- For implementation, follow the phased approach recommended in the research

## See Also

- `docs/roadmap/payment-processor-research.md` — Full research document
- `docs/api-provisioning.md` — Provisioning worker architecture
- `README.md` — Project overview
