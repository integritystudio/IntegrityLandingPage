# Valibot vs Zod for Cloudflare Workers

> **Research record — not adopted.** Recommendation was NOT taken — workers standardized on Zod v4, not Valibot (no `valibot` dependency in any worker). Condensed from the original proposal; see [changelog 1.3](../changelog/1.3/CHANGELOG.md) "Superseded Design-Doc Reconciliation".

**Original date:** 2026-03-25 · **Domain:** Worker validation library selection

## Context

Runtime validation for Cloudflare Workers (edge functions) is a different cost/performance regime than server-side Node.js: every KB shipped is deployed globally to multiple datacenters, cold starts are frequent, CPU-milliseconds are billed directly, and users feel initialization latency. The analysis compared Valibot against Zod under that lens.

## Performance Comparison

| Metric | Valibot | Zod | Impact |
|--------|---------|-----|--------|
| **Bundle size (gzipped)** | 1.91 KB | 16.57 KB | Valibot ~90% smaller |
| **Startup (initialization)** | 54 μs | ~864 μs | Valibot ~16x faster |
| **Runtime (valid data)** | ~2x Zod v3 speed | baseline | Roughly equivalent |
| **Runtime (invalid data)** | Slower (exception-based) | baseline | Zod slightly faster |
| **Ecosystem** | Small but growing | Very large (112M/week vs 4.3M/week downloads) | Zod dominance |

Bundle-size sample (simple login-form schema): Zod 17.7 KB (esbuild) / 15.18 KB (Rolldown) vs Valibot 1.37 KB — a ~90% reduction. Initialization: Zod v4 ~864 μs vs Valibot 54 μs.

**Zod v4 performance caveat:** benchmarks cited a reported 17x regression in Zod v4 versus v3 for complex-schema throughput (1M validations), which materially widened the gap in Valibot's favor for this comparison. ArkType was noted as 3-4x faster than either, but with a much smaller ecosystem.

## Why the Analysis Favored Valibot

1. **Bundle size** — ~14.66 KB smaller per worker. Smaller bundles parse/initialize faster, directly lowering CPU-ms billed, and this compounds across high-traffic endpoints. Valibot's modular design means only the validators actually used are shipped.
2. **Cold-start performance** — 16x faster initialization matters because Workers have soft execution-time limits and cold starts are frequent (deploys, traffic spikes, regional scaling); faster init leaves more headroom for business logic.
3. **Edge context generally** — unlike Node.js servers where a few extra KB is irrelevant, at the edge every KB is replicated globally, cold starts are more frequent, and CPU time is billed and felt as latency.

## Caveats Noted at the Time

- **Invalid-data path**: Valibot relies on exceptions for failures, so Zod can be faster when input is frequently invalid.
- **Error-message maturity**: Zod's error handling was considered more mature.
- **Ecosystem lock-in**: third-party tooling (e.g., tRPC) primarily supports Zod; API mapping Zod→Valibot is mostly 1:1 (`z.object()`→`v.object()`, `z.infer<>`→`v.infer<>`, etc.) but is still a migration cost.
- Valibot was judged not worth adopting for server-side Node.js contexts, or where validation errors are common, or where deep Zod-ecosystem integration is required.

## Outcome

Despite the bundle-size and cold-start case made here for Valibot, the workers in this repo standardized on **Zod v4** across `workers/lib/http/*` and `workers/lib/validation/*` (see [REFACTOR research record](REFACTOR.md)) — no `valibot` dependency was introduced in any worker.
