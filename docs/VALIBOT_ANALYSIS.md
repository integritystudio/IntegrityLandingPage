# Valibot vs Zod for Cloudflare Workers

**Analysis Date:** 2026-03-25
**Project Context:** Cloudflare Workers edge functions with TypeScript validation
**Status:** Recommendation = Migrate to Valibot

## Executive Summary

This project uses Cloudflare Workers (edge functions) for runtime validation. **Valibot is significantly better for edge functions** than Zod because bundle size and startup performance directly impact cold start latency and billing. Unlike server-side Node.js, every KB shipped to the edge costs real money and affects user experience.

---

## Performance Comparison

| Metric | Valibot | Zod | Impact |
|--------|---------|-----|--------|
| **Bundle size (gzipped)** | 1.91 KB | 16.57 KB | **Valibot: 90% smaller** ✅ |
| **Startup (initialization)** | 54 μs | ~864 μs | **Valibot: 16x faster** ✅ |
| **Runtime (valid data)** | ~2x Zod v3 speed | baseline | Roughly equivalent |
| **Runtime (invalid data)** | Slower (exception-based) | baseline | Zod slightly faster |
| **Ecosystem** | Small but growing | Very large | Zod dominance (112M/week vs 4.3M/week) |

---

## Why Valibot Wins for Cloudflare Workers

### 1. Bundle Size (Primary Advantage)
- **Zod:** 16.57 KB gzipped
- **Valibot:** 1.91 KB gzipped
- **Saving:** ~14.66 KB per worker

**Impact:**
- Cloudflare Workers charges by CPU milliseconds used
- Smaller bundle = faster parsing/initialization = lower CPU cost
- For high-traffic endpoints, this compounds across millions of requests
- Modular architecture means you only ship what you use

### 2. Cold Start Performance
- **Valibot:** 54 μs initialization
- **Zod:** ~864 μs initialization (16x slower)

**Impact:**
- Cloudflare Workers have soft limits on execution time
- Cold starts are frequent (code deploys, traffic spikes, regional scaling)
- 16x faster initialization = more headroom for business logic
- TTI (Time to Interactive) for validation-heavy endpoints improves dramatically

### 3. Edge Function Context
Unlike server-side Node.js where bundle size barely matters:
- **Edge:** Every KB is shipped globally to multiple datacenters
- **Edge:** Cold starts happen more frequently
- **Edge:** CPU milliseconds are directly billed
- **Edge:** Users experience latency directly

---

## Performance Benchmarks

### Bundle Size Comparison (simple login form validation)
```
Zod (esbuild):        17.7 KB
Zod (Rolldown):       15.18 KB
Valibot:              1.37 KB  ← 90% reduction
```

### Complex Schema Performance (1M validations)
- **Zod v4:** Baseline (17x slower than v3 regression)
- **Valibot:** Similar or faster than Zod v3
- **ArkType:** 3-4x faster (but smaller ecosystem)

### Initialization Speed
```
Zod v4:    ~864 μs
Valibot:   54 μs  ← 16x faster cold starts
```

---

## Migration Path

### Current State
- Located in: `functions/src/`
- Using Zod for schema validation
- Cloudflare Workers entry point: `functions/_middleware.ts`

### Recommended Steps
1. **Install Valibot:** `npm install valibot`
2. **Identify validation schemas** in `functions/src/` that use Zod
3. **Migrate schemas** to Valibot API (mostly 1:1 mapping)
4. **Run benchmarks** with Wrangler (`wrangler dev`)
5. **Verify cold start times** and bundle size
6. **Update type exports** using `v.infer<typeof schema>`

### API Equivalence
```typescript
// Zod → Valibot (mostly 1:1)
z.object()        → v.object()
z.string()        → v.string()
z.number()        → v.number()
z.array()         → v.array()
z.enum()          → v.enum()
z.optional()      → v.optional()
z.default()       → v.default()

// Type extraction
z.infer<typeof S>  → v.infer<typeof S>
```

---

## Caveats & Trade-offs

### When Valibot Is Slower
- **Invalid data:** Valibot relies on exceptions for failures; Zod may be faster when data is frequently invalid
- **Complex error messages:** Zod's error handling is more mature
- **Ecosystem:** Fewer third-party integrations (tRPC, etc. primarily support Zod)

### When Valibot Is Not Worth It
- Server-side Node.js (this project uses Cloudflare Workers, so NOT applicable)
- If validation errors are extremely common (bad data often)
- If deep ecosystem integration with Zod tools is required

---

## Current Project Fit

✅ **Excellent fit for Valibot** because:
- Cloudflare Workers edge functions (bundle size critical)
- Global deployment (every KB multiplied across regions)
- High-traffic validation endpoints (startup time matters)
- TypeScript-first codebase (Valibot's strength)
- Modular validation schemas (only ship used validators)

❌ **Not a reason to keep Zod:**
- Server-side MCP (different project; Zod is correct there)
- Ecosystem lock-in doesn't apply here
- Performance is the primary constraint

---

## References

- [Valibot Official Comparison](https://valibot.dev/guides/comparison/)
- [2026 Validation Libraries Showdown](https://pockit.tools/blog/zod-valibot-arktype-comparison-2026/)
- [Valibot Cloudflare Workers Guide](https://valibot.dev/)
- [Zod v4 Performance Regression](https://dev.to/dzakh/zod-v4-17x-slower-and-why-you-should-care-1m1)
- [TypeScript Validators at Scale](https://medium.com/@2nick2patel2/typescript-data-validators-at-scale-zod-valibot-superstruct-compared-177581543ac5)

---

## Next Steps

1. Benchmark current `functions/` bundle size: `wrangler publish --dry-run`
2. Create a test branch with Valibot migration
3. Compare bundle sizes and cold start metrics
4. Update BACKLOG.md with migration task if metrics show improvement
5. Plan gradual migration if full switchover is risky

---

**Recommendation:** Prioritize Valibot migration for Cloudflare Workers due to bundle size and cold start advantages. This is a different context than server-side Node.js where Zod remains the better choice.
