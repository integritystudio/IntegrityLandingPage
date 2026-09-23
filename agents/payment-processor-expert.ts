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
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

// Resolve relative to this file, not process.cwd(). The npm scripts run from
// agents/, but a bare `tsx agents/payment-processor-expert.ts` from the repo
// root resolved the doc one directory too high and failed.
const here = dirname(fileURLToPath(import.meta.url));

/**
 * Where the research document may live, current location first. It moved from
 * docs/roadmap/ to docs/research/ in 175c9d3 and the hardcoded path was never
 * updated, so every script here failed with an ENOENT at import — before main()
 * ran, and with a stack trace instead of an explanation.
 */
const RESEARCH_DOC_CANDIDATES = [
  join(here, "../docs/research/payment-processor-research.md"),
  join(here, "../docs/roadmap/payment-processor-research.md"),
];

/** The research document, or a clear exit naming every path that was tried. */
function loadResearchDoc(): { path: string; text: string } {
  for (const candidate of RESEARCH_DOC_CANDIDATES) {
    if (!existsSync(candidate)) continue;
    const text = readFileSync(candidate, "utf-8");
    if (text.trim() === "") {
      console.error(`❌ Research document is empty: ${relative(process.cwd(), candidate)}`);
      process.exit(1);
    }
    return { path: candidate, text };
  }

  console.error("❌ Could not find the payment processor research document.\n");
  console.error("   Looked in:");
  for (const candidate of RESEARCH_DOC_CANDIDATES) {
    console.error(`     - ${relative(process.cwd(), candidate)}`);
  }
  console.error("\n   If it moved again, add the new path to RESEARCH_DOC_CANDIDATES.");
  process.exit(1);
}

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

  // Loaded here rather than at module scope so a missing document reports the
  // paths it tried instead of throwing an ENOENT stack before main() runs.
  const research = loadResearchDoc();

  console.log(`\n🏗️  Payment Processor Research Agent\n`);
  console.log(`📋 Query: ${userPrompt}\n`);
  console.log(`📄 Research: ${relative(process.cwd(), research.path)}\n`);
  console.log(`${"─".repeat(60)}\n`);

  // The document is ~10 KB, so inline it rather than relying on the agent's
  // Read tool finding it — that resolves against cwd, which varies by caller.
  const systemPromptWithResearch = `${systemPrompt}

<research_document path="${relative(process.cwd(), research.path)}">
${research.text}
</research_document>`;

  try {
    for await (const message of query({
      prompt: userPrompt,
      options: {
        cwd: process.cwd(),
        allowedTools: ["Read", "Grep", "Glob"],
        systemPrompt: systemPromptWithResearch,
        maxTurns: 10,
        model: "claude-opus-5",
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
