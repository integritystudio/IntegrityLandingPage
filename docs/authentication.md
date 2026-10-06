# Authentication

**Last Updated:** 2026-10-06 — rewritten for Auth0 Universal Login ([CR48](BACKLOG.md#cr48), live 2026-09-29). Earlier versions described the `AuthMode` enum and the server-side password flow (sender `/signup` and `/signin` over ROPC); both were removed from the app by CR48, and the sender routes are slated for deletion by [CR49](BACKLOG.md#cr49).

## Overview

- **Credentials never touch this site.** Sign-in, sign-up and password reset all happen on Auth0's Universal Login page, reached by a top-level redirect (authorization code + PKCE S256, RFC 7636).
- **One session for two sites.** The app signs in with the same SPA client integritystudio.dev uses (`integritystudio-dashboard`), so an Auth0 session started on either site is reused by the other: the dashboard's Observability card opens integritystudio.dev without a second login.
- **The access token is the only credential the app sends.** It is minted for the audience `https://api.integritystudio.dev`; api-gateway verifies it against the tenant's JWKS, and sender `/send` forwards it to the receiver, which checks it against Auth0.

## Components

| File | Role |
|---|---|
| `lib/services/auth0_config.dart` | Tenant domain, client id, audience and scope; compile-time defaults are production |
| `lib/services/auth0_service.dart` | `login`, `handleCallback`, `currentSession` (refresh), `clearSession`, `logout`; `Auth0Session`, `SignupIntent`, `Auth0Exception` |
| `lib/services/auth0_browser{,_web,_stub}.dart` | Storage and navigation seam: the web build wraps `window`, other platforms are inert, tests inject their own |
| `lib/pages/auth_page.dart` | `/login`: a "Continue to Sign In" hand-off to Auth0 |
| `lib/pages/signup_page.dart` | `/signup?tier=`: tier, email, company (enterprise only) and terms, then Auth0's sign-up screen |
| `lib/pages/callback_page.dart` | `CallbackPage` (`/callback`), `SessionRestorePage` (`/dashboard` without route args) and the shared `AuthProgress` spinner |
| `lib/pages/provision_page.dart` | `/provision`: the first API key, which creates the org; a paid tier continues to checkout |
| `lib/pages/dashboard_page.dart` | The **Sign out** button (`Auth0Service.logout`) |
| `auth0/actions/provision-user-and-enrich-token.cjs` | The post-login Action on both tenants: the `public.users` row and the token claims ([README](../auth0/actions/README.md)) |

## Configuration

`Auth0Config` reads four values. The defaults ship in every build that passes no `--dart-define` (including `ci.yml`'s):

| Value | `--dart-define` | Default (production) |
|---|---|---|
| Tenant domain | `AUTH0_DOMAIN` | `dev-68gg87ow4mg4kzyo.us.auth0.com` — the production tenant despite the `dev-` name (a custom domain is [CR32](BACKLOG.md#cr32)) |
| SPA client id | `AUTH0_CLIENT_ID` | `CNfd6xPPr2aLmvNyiearhmaLknAYvtnq` (`integritystudio-dashboard`) |
| Audience | `AUTH0_AUDIENCE` | `https://api.integritystudio.dev` |
| Scope | — | `openid profile email offline_access` (`offline_access` returns the refresh token) |

- **Running against the dev tenant:** use the command in CLAUDE.md, "Pointing the Flutter app at the dev workers". The Auth0 pair must move together with the Worker URLs: `api-gateway-dev` trusts only the dev tenant, so a production-tenant token gets 401 there. The dev SPA client (`integritystudio-dashboard-dev`) allows only `http://localhost:8080` (and `:5173` for the dashboard repo), which is why the port is fixed. Use `--release`, because debug mode injects inline scripts the CSP blocks.
- **CSP:** `connect-src` in `web/index.html` allows both tenants' domains, since the token exchange is a `fetch` from the page.
- **Adding an origin** (a new hostname, a preview): list it on the SPA client as a callback URL (`<origin>/callback`), a logout URL (`<origin>/`) and an allowed web origin. Web origins must have **no trailing slash**: `/oauth/token` matches the `Origin` header exactly, and the production client's original `https://integritystudio.ai/` entries never matched (CR48).

## Sign-in

```
/login (AuthPage) ── "Continue to Sign In" ──▶ Auth0Service.login()
   sessionStorage ← auth0_code_verifier, auth0_state   (32 random bytes each, base64url)
   navigate ──▶ https://<tenant>/authorize
                  ?response_type=code&client_id&redirect_uri=<origin>/callback
                  &audience&scope&state&code_challenge=S256(verifier)&code_challenge_method=S256

Auth0 Universal Login (password, reset)  ── post-login Action runs ──
   302 ──▶ <origin>/callback?code=…&state=…

/callback (CallbackPage) ──▶ Auth0Service.handleCallback(uri)
   read, then delete, auth0_state / auth0_code_verifier / auth0_signup_intent   (single use)
   compare state in constant time; a missing or mismatched value fails
   POST https://<tenant>/oauth/token   (form-encoded: authorization_code, code, code_verifier, redirect_uri)
      access token + email + expiry ──▶ sessionStorage auth0_session
      refresh token                ──▶ localStorage   auth0_refresh_token
   GET <api-gateway>/v1/orgs   (Authorization: Bearer <access token>)
      no orgs     ──▶ /provision   extra: ProvisionArgs(session, signup)
      any org     ──▶ /dashboard   extra: DashboardArgs(jwt)
      error       ──▶ inline error and a "Sign in again" button
```

- **The post-login Action** finds the `public.users` row by `auth0_id`, re-links by email only when Auth0 says the email is verified ([CR51](changelog/1.3/CHANGELOG.md#cr51)), otherwise inserts one, and writes the profile columns. It adds namespaced `roles`, `permissions` and `app_user_id` claims. The bare `role = authenticated` claim Supabase needs goes on the **ID** token only, and only for the clients in the Action's `SUPABASE_TPA_CLIENT_IDS` secret. The Action also runs on refresh-token exchanges, which it does not count as logins.
- **The email comes from the ID token's `email` claim**, read without signature verification: the token came straight from Auth0's token endpoint over TLS, and nothing authorises on it. It is kept exactly as Auth0 returned it, because the receiver compares it byte for byte.

## Sign-up

1. `/signup?tier=` (`SignupPage`) validates the email (`ContactService.isValidEmail`) and the terms checkbox. There is no password field.
2. `Auth0Service.login(loginHint: email, signup: SignupIntent(tier, orgName))` stores the intent in sessionStorage (`auth0_signup_intent`) and adds `screen_hint=signup` and **`prompt=login`** to `/authorize`. Without `prompt=login` an existing Auth0 session answers silently, ignores both hints, and signs in the browser's current account instead of creating a new one.
3. The user sets a password on Auth0's sign-up screen, and Auth0 returns to `/callback`. A new account has no org, so it goes to `/provision`; the signup analytics (`signup_form` submission, Facebook lead) fire here, once the account exists, not when the form was submitted.
4. `/provision` sends `provision_api_key` to sender `POST /send` with the email as Auth0 returned it and, for enterprise, the company as `org_name`. The access token travels base64-encoded in the `x-session-data` header. The sender HMAC-signs the event and forwards it to the receiver over the `RECEIVER` service binding. The receiver checks the token against Auth0's `/userinfo`, requires the email to match byte for byte, creates the org at `starter` (CR37: no route takes a plan from the caller), and mints an `obtk_` key, shown once.
5. A paid tier then offers **Continue to Checkout** (`CheckoutArgs(email, tier)`). Checkout runs after provisioning on purpose: a checkout session opened before the org existed could not be attributed to it.

## Session lifetime

- **`currentSession()`** returns the stored session while it has more than a minute left, and otherwise exchanges the refresh token (`grant_type=refresh_token`). Refresh tokens rotate, so only one refresh runs at a time; a second request with the same token would count as reuse and revoke the whole token family.
- **Refused versus unreachable.** When Auth0 answers and refuses (revoked or expired refresh token), the session is cleared and the user is signed out locally. A network failure returns no session but keeps the stored tokens.
- **Reload, bookmark or new tab:** `/dashboard` without route args renders `SessionRestorePage`, which calls `currentSession()` and opens the dashboard or sends the user to `/login`. `/billing`, `/usage`, `/entitlements` and `/quota` without args redirect to `/dashboard`, so they restore the same way.
- **Tokens never go in a URL** ([CR04](changelog/1.3/CHANGELOG.md#cr04)). They move between pages in GoRouter `extra` only, and `/provision` refuses to read one from the query string: accepting `?jwt=` allowed login-CSRF.
- **Known limit (CR48):** refresh-token rotation `leeway` is 0 on both SPA clients, so two tabs refreshing at the same instant count as reuse and both are signed out. In-tab refreshes are serialised; cross-tab ones are not. A small `leeway` would absorb it, but the client is shared with integritystudio.dev, so that decision belongs there.
- The pre-CR48 `auth_jwt` localStorage key is no longer read or written, and is not cleared; it expires with its token.

## Sign-out

**Sign out** on the dashboard calls `Auth0Service.logout()`: it clears both stored tokens and navigates to `https://<tenant>/v2/logout?client_id=…&returnTo=<origin>/`. That ends the Auth0 session itself, so it also signs the user out of integritystudio.dev. `clearSession()` alone forgets the tokens in this browser without leaving the page.

## How the Workers check the token

| Worker | Check |
|---|---|
| `api-gateway` | `verifyJwt` (`workers/lib/auth.ts`) against `https://<AUTH0_DOMAIN>/.well-known/jwks.json`, issuer `https://<AUTH0_DOMAIN>/`, audience `AUTH0_AUDIENCE`. Both are checked-in `vars`: production's tenant at the top level, the dev tenant under `[env.dev.vars]`. The `sub` claim is the caller, resolved through `users.auth0_id`. A bearer token that parses as an API key (`obtk_` or `int_live_`) is verified as a key instead. |
| `sender-worker` `/send` | Reads the token from `x-session-data` (base64), else the body's `jwt`, else `Authorization: Bearer`, and checks only that it is JWT-shaped. The receiver does the real check. |
| `api-provisioning-receiver` (observability-toolkit) | Checks the token against Auth0's `/userinfo` and compares the email byte for byte. |
| integritystudio.dev (dashboard repo) | Reads Supabase directly with the Auth0 **ID** token through Supabase Third-Party Auth ([CR62](changelog/1.3/CHANGELOG.md#cr62)), which is what the Action's `role` claim is for. |

**`SUPABASE_JWT_SECRET` is deliberately unbound on api-gateway.** These tokens are Auth0-issued; verifying them against Supabase is what produced the original `401 Invalid JWT signature` (CR26). Do not bind it to fix a 401.

## Testing

- `test/services/auth0_service_test.dart` covers the authorize URL, PKCE, state handling, the refresh memo and refused-versus-network handling. Dropping the memo, the state comparison or that distinction each fails its own test (mutation-checked, CR48).
- `test/pages/auth_page_test.dart`, `signup_page_test.dart`, `callback_page_test.dart` and `provision_page_test.dart` cover the pages.
- **Test seam:** `Auth0Service.setForTesting(dio:, browser:, now:, random:)` and `resetForTesting()`. Inject an `Auth0Browser` to control storage and capture navigation; there is no real browser in `flutter test`.
- **End to end:** run the release build against the dev tenant and dev Workers (above), then sign up, provision, sign out, sign in and reload `/dashboard`. No Flutter test reaches Auth0. The one automated suite that does is sender-worker's `npm run test:live`, which calls the **production** tenant's Management API for the legacy routes below (CLAUDE.md, Commands).

## Legacy: sender-worker password routes

`sender-worker` still serves the pre-CR48 routes, and **nothing in this app calls them**:

| Route | What it does |
|---|---|
| `POST /signup` | Creates the Auth0 user through the Management API (M2M client `AUTH0_CLI_*`, `client_credentials`), creates the Supabase org, user and owner membership, then signs in over ROPC and returns `{jwt, auth0Sub, userId, email}` |
| `POST /signin` | Auth0 ROPC (`grant_type=password`, client `AUTH0_CLIENT_*`, "My App"): `{email, password}` → `{jwt, email}` |
| `POST /forgot-password` | Auth0 `dbconnections/change_password`; the same 200 whether or not the account exists |

All three share a per-IP rate limit. [CR49](BACKLOG.md#cr49) deletes them, and then removes the `password` grant from "My App", once a week with no production traffic is confirmed. Until CR49 step 3, do not strip `password` from "My App" (CLAUDE.md, Auth0). Do not build anything new on these routes.

**Removed from the app by CR48 (2026-09-29):** `AuthMode` and its extension, `ProvisioningService.signIn/signUp/forgotPassword`, `AuthSuccess`/`AuthError`, `AuthStorage` and `PasswordPolicy`.
