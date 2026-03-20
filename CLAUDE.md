[README.md](README.md)

## Current Status

**Phase**: Sender-Worker UI Implementation ✅ COMPLETE
**Last Updated**: 2026-03-20
**Build Status**: ✅ Web build successful, running on localhost:8080
**Test Status**: ✅ All tests passing (2440+ tests, ~94% coverage)

### Recent Work (See [SESSION_HISTORY.md](docs/SESSION_HISTORY.md) for details)
- Implemented AuthPage, ProvisionPage, SenderHealthPage
- Added JWT authentication flow (signUp/signIn)
- Fixed widget API incompatibilities
- Fixed GoRouter query parameter handling
- All changes committed and web build verified

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
├── pages/            # Page widgets (29 pages)
├── routing/          # GoRouter configuration (33 routes)
├── services/         # External integrations (analytics, consent, contact)
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
├── lib/              # Shared HTTP + validation utilities (79 tests)
│   ├── http/         # CORS, request parsing, responses, error handling
│   └── validation/   # Zod schemas, requireValidJson, zodValidationError
├── contact-form/     # Contact form worker (Resend email, KV rate limiting, CSRF)
├── sender-worker/    # Provisioning sender (HMAC-SHA256 auth)
└── receiver-worker/  # Provisioning receiver (signature verification, replay protection)

scripts/              # Build/dev tooling, repomix generation
docs/                 # Architecture, routes, changelog, backlog
test/                 # Unit + widget tests (2440+ passing, ~94% coverage)
```
## Guidelines
No magic numbers or string
Use DRY principles

## Workers

**Shared Library**
- [workers/lib/](workers/lib/) — Shared HTTP and validation utilities (79 tests, ~94% coverage)
  - `http/` — CORS, request parsing (JSON, bearer token, query params, method assertion), response factories, error handling
  - `validation/` — Zod-based validation with typed result unions, formatted error responses

**Workers**
- [workers/contact-form/](workers/contact-form/) — Cloudflare Worker handling contact form submissions (Resend email, KV rate limiting, CSRF, idempotency)
- [workers/sender-worker/](workers/sender-worker/) — Cloudflare Worker that signs and forwards provisioning events to receiver-worker (HMAC-SHA256 inter-service auth, TDD-tested)
- [workers/receiver-worker/](workers/receiver-worker/) — Cloudflare Worker that verifies signed requests and stores provisioning data (signature verification, replay protection)

## Flutter Canvas Limitations (E2E Testing)

Flutter Web renders to `<canvas>` via CanvasKit — DOM selectors cannot reach widget content. Workaround: wrap widgets with `Semantics(label: '...', button: true)` to expose ARIA labels, then use `page.getByLabel()` in Playwright. `SemanticsBinding.instance.ensureSemantics()` in `main.dart` enables the tree at startup. E2e tests must call `enableFlutterSemantics()` and gracefully skip on Flutter [#151929](https://github.com/flutter/flutter/issues/151929) when the tree fails to materialise. See `e2e/tests/docs-content.spec.ts` for the reference pattern.

**Applied in:** #111 (doc components), #114 (404 recovery), #117 (mobile hamburger menu)

## Repomix Context (docs/repomix/)

Choose the appropriate file based on the task:

- [token-tree.txt](docs/repomix/token-tree.txt) — file tree with token counts; use for navigation, finding files, estimating scope
- [docs-compressed.xml](docs/repomix/docs-compressed.xml) — compressed docs, CLAUDE.md, README (~11K tokens); use for broad docs understanding and search
- [repomix.xml](docs/repomix/repomix.xml) — full lossless source; use only when exact code detail is needed (e.g. line-level edits, debugging)
