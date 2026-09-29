# Auth0 Actions

Source for the Actions deployed to the production tenant (`dev-68gg87ow4mg4kzyo`). Auth0 runs the code
as uploaded; these files are the reviewed copy, so change them here first and deploy from them.

| File | Action | Trigger | Secrets |
|---|---|---|---|
| `provision-user-and-enrich-token.cjs` | Provision User and Enrich Token (`e5a1e2ee-bffa-4a80-8559-8fdb81a4bba6`) | `post-login` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` |

`.cjs` because Actions use CommonJS (`exports.onExecutePostLogin`) and this repo's root package is ESM.
Every production login runs the post-login Action, so a broken version stops logins: run
`npm run test:auth0-actions` before deploying, and keep the previous version number for a rollback
(`POST /api/v2/actions/actions/{id}/versions/{versionId}/deploy`).
