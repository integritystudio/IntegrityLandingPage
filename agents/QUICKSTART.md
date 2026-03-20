# Quick Start — Payment Processor Agent

Get started with the payment processor research agent in 2 minutes.

## Setup

```bash
cd agents
npm install
```

Requires: `ANTHROPIC_API_KEY` environment variable set (when running as subprocess) or use within Claude Code session.

## Run

**Ask a question:**
```bash
npm run payment-processor -- "Your question here"
```

**Use a preset query:**
```bash
npm run payment-processor:architecture
npm run payment-processor:data-model
npm run payment-processor:provisioning
npm run payment-processor:security
npm run payment-processor:rate-limiting
```

## Example Session

```bash
export ANTHROPIC_API_KEY="sk-..."

# 1. Understand the architecture
npm run payment-processor:architecture

# 2. Design the schema
npm run payment-processor:data-model

# 3. Plan provisioning
npm run payment-processor:provisioning

# 4. Review security
npm run payment-processor:security

# 5. Ask follow-ups
npm run payment-processor -- "How do we migrate existing customers to this new system?"
```

## What It Does

The agent:
1. Reads the payment processor research document (`../docs/roadmap/payment-processor-research.md`)
2. Analyzes your questions using Claude Opus 4.6
3. References specific architecture patterns and code examples
4. Provides implementation guidance with phase-by-phase breakdowns
5. Validates design decisions against security best practices

## Output

Each query produces:
- **Architecture insights** with diagrams and rationale
- **Code examples** (SQL, TypeScript, bash)
- **Implementation guidance** with Phase 1/2/3 breakdowns
- **Security review** and hardening recommendations
- **Trade-offs** and alternative approaches

## Common Queries

**For architects:**
```bash
npm run payment-processor -- "Design a disaster recovery plan for the billing system"
npm run payment-processor -- "How do we handle currency conversion across regions?"
```

**For engineers:**
```bash
npm run payment-processor -- "Write the Stripe webhook handler for subscription updates"
npm run payment-processor -- "Design the Durable Object quota enforcement logic"
```

**For security:**
```bash
npm run payment-processor -- "List all potential security vulnerabilities and mitigations"
npm run payment-processor -- "Review the JWT claims strategy for compliance"
```

## Tips

- Be specific — narrow questions get better answers
- Ask follow-ups to dive deeper
- Reference the research document for context
- Check the full README for architecture reference

## Help

```bash
npm run payment-processor -- "Help me understand the two-layer auth system"
```

See `README.md` for complete documentation.
