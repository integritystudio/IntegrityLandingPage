# User Provisioning Workflow

Full data flow for user creation and API key provisioning by tier.

---

## Starter (free, no payment)

```
SignupPage (/signup?tier=starter)
  └─→ POST /signup (sender-worker)
        ├─ auth0CreateUser (M2M client credentials → POST /api/v2/users)
        ├─ supabaseCreatePersonalOrg (POST /rest/v1/organizations, current_plan: "starter")
        ├─ supabaseInsertUser (POST /rest/v1/users, auth0_id = auth0Sub)
        ├─ supabaseAddOrgOwner (POST /rest/v1/organization_memberships, role: "owner")
        └─ auth0UserSignIn (ROPC → POST /oauth/token, grant_type: password)
             └─ returns { jwt, auth0Sub, userId, email } 201
  └─→ AuthSuccess(jwt, email) → GoRouter /provision
        └─ ProvisionPage: AuthStorage.saveJwt(jwt)
        └─ POST /send (sender-worker)
              ├─ validates SendRequestSchema {action, jwt, name, email, tier}
              ├─ HMAC-SHA256 signs {x-timestamp}.{body} with SHARED_SECRET
              └─ POST receiver-worker /inbox
                    ├─ verifies x-timestamp (±5 min) + x-signature constant-time
                    ├─ Auth0 /userinfo (validates JWT live)
                    ├─ Supabase GET /rest/v1/users?auth0_id=eq.{sub} → Supabase UUID
                    ├─ Supabase POST /rest/v1/organizations {domain, type:"team", current_plan:tier}
                    ├─ Supabase POST /rest/v1/organization_memberships
                    └─ Supabase Edge Fn POST /functions/v1/api-keys-create
                         └─ returns { token: /obtk_[0-9a-f]{64}/, keyId, prefix, tier }
  └─→ "Go to Dashboard" → window.open(integritystudio.dev?access_token=<jwt>)
```

---

## Growth (paid, Stripe checkout)

```
SignupPage (/signup?tier=growth)
  └─→ POST /signup (sender-worker) — same Auth0 + Supabase steps as starter
        └─ returns { jwt, auth0Sub, userId, email } 201
  └─→ AuthSuccess → GoRouter /checkout (CheckoutArgs{email, tier})
        └─ CheckoutPage: POST /create-checkout-session (sender-worker)
              ├─ validates CreateCheckoutSessionSchema {email, tier}
              ├─ looks up priceId from STRIPE_PLAN_TO_PRICE_JSON[tier]
              └─ POST https://api.stripe.com/v1/checkout/sessions
                    mode: subscription, line_items[0][price]: priceId
                    success_url: {APP_BASE_URL}/checkout-success?email=...&tier=...
                    cancel_url:  {APP_BASE_URL}/signup?tier=...
                    └─ returns { checkoutUrl }
        └─ window.location.href = checkoutUrl (browser leaves app → Stripe hosted page)
  └─→ Stripe payment complete → /checkout-success?email=&tier=
        └─ CheckoutSuccessPage: "Sign In to Activate" → /signin
  └─→ User signs in → /provision → same provision flow as starter
        (Stripe webhook separately: checkout.session.completed + customer.subscription.updated
         → updateOrgBillingStatus(org, "active", "growth", bumpQuota=true)
         → quota_version bumped → Quota DO resets limits to growth tier on next API request)
```

---

## Enterprise (contact sales, no provisioning)

```
SignupPage (/signup?tier=enterprise)
  └─→ ContactService.submitForm() → POST contact-form worker
        ├─ CSRF validation, KV rate limiting, idempotency check
        └─ Resend API → sends email to sales team
  └─→ GoRouter /request_success (no Auth0 user, no Supabase row, no API key)
```

---

## Key Boundaries

| Concern | Where |
|---|---|
| Auth0 user creation | sender-worker `auth0CreateUser` (M2M grant) |
| Supabase provisioning (signup) | sender-worker `handleSignup` (inline, pre-webhook) |
| JWT issuance | sender-worker `auth0UserSignIn` (ROPC) |
| JWT persistence | `AuthStorage.saveJwt` → `localStorage['auth_jwt']` |
| API key creation | receiver-worker → Supabase Edge Fn `api-keys-create` |
| Plan upgrade (Stripe → Supabase) | stripe-webhook worker `updateOrgBillingStatus` |
| Quota enforcement | api-gateway `enforceOrgQuota` + Quota Durable Object |
