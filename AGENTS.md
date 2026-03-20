# AI Agents for Integrity Studio

This directory contains AI-powered agents built with the Claude Agent SDK for analyzing and designing system architecture.

## Payment Processor Research Agent

**Location:** `agents/payment-processor-expert.ts`

Analyzes the billing architecture from `docs/roadmap/payment-processor-research.md` and provides expert guidance on SaaS payment processor design.

### Setup

```bash
cd agents
npm install
```

### Quick Start

```bash
# Ask a question
npm run payment-processor -- "Your question here"

# Or use preset queries
npm run payment-processor:architecture      # Explain the stack
npm run payment-processor:data-model        # Design schema
npm run payment-processor:provisioning      # Detail webhooks
npm run payment-processor:security          # Review threats
npm run payment-processor:rate-limiting     # Design quotas
```

### Capabilities

- **Architecture Analysis** — Multi-tier design with Stripe, Supabase, Cloudflare, Flutter
- **Data Modeling** — Complete Postgres schemas for billing
- **Provisioning Flows** — Webhook integration patterns
- **API Validation** — Contract and error handling design
- **Rate Limiting & Quotas** — Tier models and enforcement
- **Security Review** — Auth, authorization, compliance

### Example Queries

```bash
# Design the schema
npm run payment-processor -- "Create a complete SQL schema for organizations, subscriptions, and entitlements"

# Understand auth
npm run payment-processor -- "Explain the two-layer auth system: Supabase OAuth + API keys"

# Plan implementation
npm run payment-processor -- "Create a detailed Phase 1 implementation plan with tasks and dependencies"

# Security analysis
npm run payment-processor -- "List all security vulnerabilities and recommend mitigations"
```

### Documentation

- **README.md** — Full feature reference and architecture overview
- **QUICKSTART.md** — 2-minute setup and basic usage
- **EXAMPLE_QUERIES.md** — 40+ reference queries organized by topic

## How to Use

### For Architects

Get architectural guidance on component design and integration:

```bash
npm run payment-processor -- "Design a disaster recovery plan for the billing system"
npm run payment-processor -- "What are the trade-offs between Durable Objects vs. Redis for quota?"
```

### For Engineers

Get implementation details and code patterns:

```bash
npm run payment-processor -- "Write the Stripe webhook handler for subscription updates"
npm run payment-processor -- "Show me the TypeScript code for the provisioning worker"
```

### For Security

Get threat analysis and compliance guidance:

```bash
npm run payment-processor -- "Perform a comprehensive security audit of the billing system"
npm run payment-processor -- "What do we need for PCI DSS compliance?"
```

## Technical Details

**Agent Type:** Research and analysis agent using Agent SDK
**Model:** Claude Opus 4.6 with adaptive thinking
**Tools Available:** Read, Grep, Glob (for referencing code and docs)
**Context:** Full payment processor research document + project codebase
**Max Turns:** 10 (prevents runaway queries)

## Architecture Reference

### Core Stack

```
Billing       → Stripe (subscriptions, webhooks)
Auth          → Supabase (OAuth, RLS)
Database      → Postgres (via Supabase)
Edge/Gateway  → Cloudflare Workers (rate limiting, JWT verification)
Quotas        → Cloudflare Durable Objects (strong consistency)
Mobile        → Flutter (companion app)
```

### Key Design Decisions

1. **Two-layer auth:** Supabase OAuth (user identity) + API keys (machine access)
2. **Edge rate limiting:** Cloudflare Workers for fast throttling by tier
3. **Precise quotas:** Durable Objects for strongly-consistent per-org counters
4. **Webhook-driven:** Stripe webhooks for subscription events, Supabase webhooks for user provisioning
5. **Phased rollout:** MVP (Phase 1) → Self-service (Phase 2) → Enterprise (Phase 3)

## Environment

Requires: `ANTHROPIC_API_KEY` environment variable

## Next Steps

1. **Setup:** `cd agents && npm install`
2. **Ask questions:** `npm run payment-processor -- "your question"`
3. **Reference:** See `EXAMPLE_QUERIES.md` for 40+ query templates
4. **Explore:** Check `docs/roadmap/payment-processor-research.md` for full details

## See Also

- `docs/roadmap/payment-processor-research.md` — Research document
- `agents/README.md` — Full documentation
- `agents/QUICKSTART.md` — Quick reference
- `agents/EXAMPLE_QUERIES.md` — Query templates
