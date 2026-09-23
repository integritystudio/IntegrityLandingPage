#!/usr/bin/env node
/**
 * Payment Processor Research Agent
 *
 * Analyzes the billing architecture from docs/roadmap/payment-processor-research.md
 * and provides expert guidance on:
 * - Architecture design (Stripe + Supabase + Cloudflare + Flutter)
 * - Data model design
 * - Provisioning flows and webhook integrations
 * - API contract validation
 * - Rate limiting and quota enforcement
 * - Security best practices
 */

import { query } from "@anthropic-ai/claude-agent-sdk";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const researchDoc = readFileSync(
  join(process.cwd(), "../docs/roadmap/payment-processor-research.md"),
  "utf-8"
);

const systemPrompt = `You are an expert payment processor architect specializing in SaaS billing systems.

You have access to Integrity Studio's detailed payment processor research document which covers:
- Recommended architecture (Stripe + Supabase + Cloudflare Workers + Flutter)
- Complete data model with core tables (organizations, users, subscriptions, entitlements, API keys, usage, etc.)
- Auth flows (Supabase OAuth + API key strategies)
- Provisioning architecture using Cloudflare Workers
- Rate limiting and quota enforcement patterns
- Security best practices and compliance

Your expertise includes:
1. **Architecture Design**: Explain the multi-tier architecture, justify design choices, identify trade-offs
2. **Data Modeling**: Design schemas, define relationships, optimize for queries and billing
3. **Provisioning Flows**: Design webhook integration patterns, idempotent upserts, event-driven architecture
4. **API Contracts**: Review and validate API designs, response payloads, error handling
5. **Rate Limiting & Quotas**: Design tier models, enforce limits at edge (Cloudflare), implement precise quota via Durable Objects
6. **Security**: Apply defense-in-depth, validate auth/authz patterns, review sensitive data handling

When answering questions:
- Reference specific sections from the research document
- Provide concrete examples and code patterns
- Suggest implementation phases (Phase 1, 2, 3)
- Call out security implications
- Identify architectural trade-offs

Reference the research document to provide specific guidance on implementation details.`;

async function main() {
  const userPrompt = process.argv.slice(2).join(" ") ||
    "Summarize the recommended billing architecture for Integrity Studio";

  console.log(`\n🏗️  Payment Processor Research Agent\n`);
  console.log(`📋 Query: ${userPrompt}\n`);
  console.log(`${"─".repeat(60)}\n`);

  try {
    for await (const message of query({
      prompt: userPrompt,
      options: {
        cwd: process.cwd(),
        allowedTools: ["Read", "Grep", "Glob"],
        systemPrompt,
        maxTurns: 10,
        model: "claude-opus-4-6",
        thinking: { type: "adaptive" },
      },
    })) {
      if ("result" in message) {
        console.log(message.result);
        console.log(`\n${"─".repeat(60)}`);
        console.log("✅ Analysis complete");
      } else if (message.type === "system") {
        if (message.subtype === "init") {
          console.log(`📌 Session: ${message.session_id}\n`);
        }
      }
    }
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

main();
