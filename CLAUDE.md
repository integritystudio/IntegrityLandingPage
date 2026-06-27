[README.md](README.md)

## Current Status

**Phase**: Testing Infrastructure & Error Handling ✅ COMPLETE
**Last Updated**: 2026-04-07
**Build Status**: ✅ Web build successful, running on localhost:8080
**Test Status**: ✅ 2,982 Flutter tests passing (~94% coverage); 892 worker tests passing

See [docs/changelog/1.2/CHANGELOG.md](docs/changelog/1.2/CHANGELOG.md) for recent changes.

### Recent Improvements (2026-04-07)
- **Sender-Worker Refactor**: Extracted forwardToReceiver, parseJsonBody, ErrorCode type, named constants; added sign_in action with Auth0 ROPC forwarding
- **Zod v4 Migration**: Bumped zod to v4 across all workers; updated schemas for v4 API compatibility
- **ESM & Vitest**: Added ESM type to workers, bumped vitest to v4
- **Auth0 Consolidation**: Single AUTH0_CLIENT_* credentials for both auth flows
- **Model Extraction**: Extracted dashboard_models.dart and provisioning_models.dart from services into dedicated model files
- **UI Polish**: Applied GradientPageShell to signup_page
- **Domain Normalization**: Sender-worker omits org_name default so receiver handles domain normalization
- **Error Handling**: request_failure page detects "user already exists" errors and auto-redirects to /login

### Known Issues
- Contact form CORS blocks localhost (by design, needs config update for dev testing)
- Analytics tracking warnings in browser console (CSP/Facebook pixel, not critical)

---

## Project Structure

```
lib/
├── config/content/   # Static content definitions (content.yaml models)
├── controllers/      # Business logic controllers
├── models/           # Data models
├── pages/            # Page widgets (40 pages)
├── routing/          # GoRouter configuration (43 routes)
├── services/         # External integrations (analytics, consent, contact, dashboard, provisioning)
├── theme/            # Design system (colors, decorations, spacing, typography)
├── utils/            # Utility functions
├── widgets/          # Reusable components
│   ├── common/       # Shared widgets
│   ├── consent/      # Cookie consent UI
│   ├── decorative/   # Visual elements
│   ├── docs/         # Documentation components
│   ├── modals/       # Dialog components
│   ├── navigation/   # Navigation components
│   └── sections/     # Page sections
├── app.dart          # Main App widget
└── main.dart         # Entry point

workers/
├── lib/              # Shared constants, HTTP utilities, validation, schemas
│   ├── constants.ts  # Time constants (MS_PER_DAY)
│   ├── http/         # CORS, request parsing, responses, error handling
│   ├── types/        # Zod schemas (usage, OTEL, audit, provisioning, Supabase)
│   └── validation/   # Validation helpers, error formatting
├── contact-form/     # Contact form worker (Resend email, KV rate limiting, CSRF)
├── api-gateway/      # API Gateway worker (ingest, usage aggregation, auth, quota)
├── sender-worker/    # Provisioning sender (HMAC-SHA256 auth)
├── receiver-worker/  # Provisioning receiver (signature verification, replay protection)
└── stripe-webhook/   # Stripe event handler (subscription lifecycle, checkout, dead-letter, Supabase sync)

scripts/              # Build/dev tooling, repomix generation
docs/                 # Architecture, routes, changelog, backlog
test/                 # Unit + widget tests (2,982 passing, ~94% coverage)
```

## Workers

**Shared Library**
- [workers/lib/](workers/lib/) — Shared HTTP, validation, and constants (shared test suite)
  - `constants.ts` — Shared time constants (MS_PER_DAY)
  - `http/` — CORS, request parsing (JSON, bearer token, query params, method assertion), response factories, error handling
  - `types/` — Zod schemas (usage events, OTEL spans, audit logs, provisioning, Supabase)
  - `validation/` — Typed validation helpers, formatted error responses

**Workers**
- [workers/contact-form/](workers/contact-form/) — Cloudflare Worker handling contact form submissions (Resend email, KV rate limiting, CSRF, idempotency)
- [workers/sender-worker/](workers/sender-worker/) — Cloudflare Worker that signs and forwards provisioning/sign-in events to the production receiver `api-provisioning-receiver` via a `[[services]]` binding (HMAC-SHA256 auth, Auth0 ROPC, Zod v4 validation)
- [workers/receiver-worker/](workers/receiver-worker/) — **Local stub / test double only** (signature verification + replay protection, returns mock responses). The production receiver is `api-provisioning-receiver`, which lives in the separate `observability-toolkit` repo and persists to Supabase. Nothing binds to this stub in production.
- [workers/stripe-webhook/](workers/stripe-webhook/) — Cloudflare Worker handling Stripe events (subscription lifecycle, checkout sessions, dead-letter queue, Supabase sync)

## Testing Strategy

**Hybrid Testing for ProvisioningService** — Three layers without duplicating test maintenance:
1. **Unit Tests** (48 tests) — Mock HTTP via `MockProvisioningDio`, test retry logic and error handling
2. **Contract Tests** (25 tests) — Verify Dart shapes match TypeScript Zod schemas, no live calls, runs in standard CI
3. **Live Integration Tests** (7 tests) — Real HTTP calls to staging, guarded by `LIVE_TESTS` dart-define, optional CI job

**Key Pattern**: Extract mock to `test/helpers/mock_provisioning_dio.dart` for reuse across unit + contract tests. Type preservation: always create `Response<dynamic>` before casting to `Response<T>` to preserve runtime type info (fixes CI environment issues).

**Mock Dependency Injection**: Use `setDioForTesting()` seam to inject test Dio instance (see provisioning_service.dart:~230).

## Flutter Canvas Limitations (E2E Testing)

Flutter Web renders to `<canvas>` via CanvasKit — DOM selectors cannot reach widget content. Workaround: wrap widgets with `Semantics(label: '...', button: true)` to expose ARIA labels, then use `page.getByLabel()` in Playwright. `SemanticsBinding.instance.ensureSemantics()` in `main.dart` enables the tree at startup. E2e tests must call `enableFlutterSemantics()` and gracefully skip on Flutter [#151929](https://github.com/flutter/flutter/issues/151929) when the tree fails to materialise. See `e2e/tests/docs-content.spec.ts` for the reference pattern.

**Applied in:** #111 (doc components), #114 (404 recovery), #117 (mobile hamburger menu)

## Repomix Context (docs/repomix/)

Choose the appropriate file based on the task:

- [token-tree.txt](docs/repomix/token-tree.txt) — file tree with token counts; use for navigation, finding files, estimating scope
- [docs-compressed.xml](docs/repomix/docs-compressed.xml) — compressed docs, CLAUDE.md, README (~11K tokens); use for broad docs understanding and search
- [repomix.xml](docs/repomix/repomix.xml) — full lossless source; use only when exact code detail is needed (e.g. line-level edits, debugging)
- [tests-compressed.xml](docs/repomix/tests-compressed.xml) — compressed test suite (Flutter + Workers); use when writing or reviewing tests

## Deployment Strategy

### Worker Deployment

All Cloudflare Workers use **Doppler for secret management**. Each worker has two deployment scripts:

**Development (Local)**
```bash
npm run deploy    # Uses --config dev, deploys to dev environment
```

**Production (CI/CD)**
```bash
npm run deploy:prd  # Uses --config prd, requires CI/CD context and Doppler token
```

#### Doppler Configuration
- **Project**: `integrity-studio`
- **Dev Config** (`--config dev`): Local development, testing, E2E tests
- **Prd Config** (`--config prd`): Production deployments, secret rotation, sensitive operations

#### Worker Deployment Overview

| Worker | Purpose | Dev Deploy | Prd Deploy | CI/CD Enabled |
|--------|---------|-----------|-----------|--------------|
| **sender-worker** | Forwards provisioning events (HMAC auth) | ✓ doppler dev | ✓ doppler prd | ✓ Yes (main) |
| **api-provisioning-receiver** | Verifies signed requests, persists to Supabase (production receiver) | — | ✓ doppler prd | ✓ Yes (separate repo) |
| **stripe-webhook** | Handles Stripe subscription events | ✓ wrangler | ✓ doppler prd | — |
| **contact-form** | Processes contact form (Resend, KV rate limit) | ✓ wrangler | ✓ doppler prd | — |
| **api-gateway** | API gateway (aggregation, quota) | ✓ wrangler | ✓ doppler prd | — |
| **bootstrap-worker** | Bootstrap operations | ✓ wrangler | ✓ doppler prd | — |

**Note:** `sender-worker` reaches the receiver via a service binding — `service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml` (the source of truth). The production receiver `api-provisioning-receiver` lives in the separate `observability-toolkit` repo (`services/api-provisioning-receiver/`) and is deployed from there. `workers/receiver-worker/` in this repo is a **local stub / test double** — it is not deployed and nothing binds to it.

### GitHub Actions CI/CD

**Main branch deployments** (`.github/workflows/ci.yml`):
- Runs on `push` to `refs/heads/main`
- Requires all tests to pass
- Deploys **sender-worker only** (other workers deploy manually with `npm run deploy:prd`)
- Environment: `production`
- Secrets: `DOPPLER_TOKEN`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`

**Deployment Safety**:
- ✅ Production secrets managed via GitHub Secrets + Doppler
- ✅ `deploy:prd` uses `--config prd` (never `dev`)
- ✅ All workers have `deploy:prd` for emergency hotfixes
- ✅ E2E tests use `--config dev` (isolated from prod)
- ✅ No hardcoded secrets in package.json or workflows

### Deployment Checklist

**Before `npm run deploy:prd`**:
1. Verify branch: `git status` (should be on a feature branch or main)
2. Run tests: `npm test` or targeted test suite
3. Set Doppler token: export `DOPPLER_TOKEN=$(doppler --project integrity-studio --config prd token)`

**After deploy**:
1. Verify in Cloudflare Workers dashboard
2. Run E2E tests: `cd workers/sender-worker && npm run test:e2e`
3. Check worker logs: `npm run tail` (if available)

### Secret Rotation

**Dev secrets** expire as per Doppler project policy.  
**Prd secrets** are rotated on a schedule; always use `doppler run --project integrity-studio --config prd`.

See `.github/workflows/ci.yml` for the current production deployment configuration and secret injection.
