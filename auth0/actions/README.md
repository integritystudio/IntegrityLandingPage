# Auth0 Actions

Source for the Actions deployed to both tenants. Auth0 runs the code as uploaded; these files are
the reviewed copy, so change them here first and deploy from them.

| File | Action | Trigger | Secrets |
|---|---|---|---|
| `provision-user-and-enrich-token.cjs` | Provision User and Enrich Token — production `dev-68gg87ow4mg4kzyo`: `e5a1e2ee-bffa-4a80-8559-8fdb81a4bba6`; dev `dev-njjmghdzm23uy0p7`: `ff3ac594-3296-4549-939b-3a3dd837402a` (created and bound 2026-10-06, CR62) | `post-login` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_TPA_CLIENT_IDS` |

`SUPABASE_TPA_CLIENT_IDS` is the comma-separated list of client ids whose **ID tokens** get the
bare `role = authenticated` claim Supabase Third-Party Auth requires (CR62). It is per tenant, so
each tenant lists its own clients: dev holds `integrity-dev-ropc` (the e2e suites' password-grant
client) and `integritystudio-dashboard-dev`; production holds `integritystudio-dashboard` since version 12. A
client not listed gets an ordinary OIDC ID token that Supabase rejects with 401, which is the
point — the integration being on does not make every login a database credential. The `role`
claim never goes on the access token: Auth0 strips non-namespaced claims there, and the
Workers that verify access tokens do not read it.

**Deploying rebinds every secret.** `PATCH /api/v2/actions/actions/{id}` *replaces* the `secrets`
list rather than merging it (measured on the dev tenant 2026-10-06: a PATCH carrying one secret left
the draft with that one secret), and bound values cannot be read back. So any deploy that touches
secrets must resend all of them, which means the Action's `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` are rebound from Doppler's values of the same names on every deploy —
prove that pair answers against the right project first (a `GET /rest/v1/users?limit=1` with the
key; PostgREST returns 206 to a ranged read, not 200). Production's current version is 12
(2026-10-06, CR62: the `role` gate with `SUPABASE_TPA_CLIENT_IDS` = the dashboard SPA
`CNfd6xPPr2aLmvNyiearhmaLknAYvtnq`); 11 holds the same code with the gate closed, 10 predates it.

`.cjs` because Actions use CommonJS (`exports.onExecutePostLogin`) and this repo's root package is ESM.
Every production login runs the post-login Action, so a broken version stops logins: run
`npm run test:auth0-actions` before deploying, and keep the previous version number for a rollback
(`POST /api/v2/actions/actions/{id}/versions/{versionId}/deploy`).
CI runs the same suite on any change under `auth0/` (`.github/workflows/auth0-action-tests.yml`); it
does not deploy.
