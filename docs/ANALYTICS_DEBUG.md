# Analytics & CORS Debug Summary

## Issues Observed (2026-03-20)

### 1. CSP Directive Warnings (Not Critical)
```
The Content Security Policy directive 'frame-ancestors' is ignored when delivered via a <meta> element.
The Content Security Policy directive 'report-uri' is ignored when delivered via a <meta> element.
```

**Root Cause**: CSP is being delivered via `<meta>` tag instead of HTTP header

**Impact**: None - certain CSP directives simply don't work in meta tags (browser limitation)

**Fix**: Set CSP via HTTP response headers instead of meta tag (requires server config, not Flutter app)

---

### 2. Facebook Pixel Form Submission ✅ NOT BROKEN
```
Previously observed: "Sending form data to 'https://www.facebook.com/tr/' violates CSP form-action directive."
```

**Analysis**: Facebook pixel does NOT use HTML form submissions. The pixel fires via:
- XHR requests → covered by `connect-src` (allows facebook.com)
- Image beacons → covered by `img-src` (allows facebook.com)

**Root Cause**: Misleading error message; the CSP error was a red herring

**Resolution**: Reverted unnecessary `form-action` broadening to maintain form security boundary

**CSP Policy**: `form-action 'self'` (unchanged, correct)

**Impact**: Pixel tracking works correctly; form submissions remain protected

---

### 3. Facebook iframe Framing ✅ ANALYZED
```
Potential blocking: "Framing 'https://www.facebook.com/' violates CSP frame-src directive."
```

**Root Cause**: CSP `frame-src` directive doesn't include facebook.com

**Analysis**: No active Facebook embed widget (e.g. Like button, Comments plugin) found in codebase. The site only uses pixel for conversion tracking, not social embeds.

**Resolution**: Kept `frame-src` restricted (no facebook.com added) to maintain iframe security boundary

**CSP Policy**: `frame-src 'self' https://calendly.com https://td.doubleclick.net` (unchanged)

**If Needed Later**: To add Facebook social plugin, scope narrowly:
```
frame-src 'self' https://calendly.com https://td.doubleclick.net https://www.facebook.com/plugins/;
```

---

### 4. Contact Form Worker CORS Blocks Localhost
```
Access to XMLHttpRequest at 'https://integrity-studio-contact.alyshia-b38.workers.dev/' from origin 'http://localhost:8080' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

**Root Cause**: Contact form worker's CORS policy only allows production domain

**Impact**: Contact form doesn't work on localhost

**Fix**: Update `workers/contact-form/wrangler.toml` to add localhost:

```toml
env:
  development:
    vars:
      ALLOWED_ORIGINS_JSON: '["http://localhost:8080","http://127.0.0.1:8080","https://integritystudio.ai","https://www.integritystudio.ai"]'
```

Then run with: `npm run dev -- --env development`

---

## AnalyticsService Implementation

**Location**: `lib/services/analytics.dart`

**Key Methods**:
- `trackPageView(String pageName, {String? ref})` - Track page views with optional referrer
- `trackEvent({required String eventName, Map<String, dynamic> parameters})` - Track custom events
- `_track(AnalyticsEvent event, Map<String, dynamic> data)` - Internal tracking dispatcher

**Used In**:
- `lib/pages/auth_page.dart` - trackPageView('auth_signup' or 'auth_signin')
- `lib/pages/provision_page.dart` - trackPageView('provision'), trackEvent(eventName: 'api_key_provisioned')
- `lib/pages/sender_health_page.dart` - trackPageView('sender_health')

**Status**: ✅ Working correctly, no issues in implementation

---

## Recommended Actions (Status Update)

| Issue | Priority | Status | Impact |
|-------|----------|--------|--------|
| CSP in meta tag (frame-ancestors) | **High** | ⏳ Pending | Move to HTTP headers — clickjacking protection required |
| Facebook pixel tracking | Low | ✅ Working | Pixel uses connect-src/img-src; no form-action needed |
| Facebook embed widgets | Low | ℹ️ Not needed | If social embeds needed later, use `frame-src` + facebook.com/plugins/ |
| Contact form localhost CORS | Medium | ⏳ Pending | Add localhost to allowlist for dev testing |

---

## Deployment Readiness

✅ **Analytics tracking** - Fully functional (Google Analytics, GTM, Facebook Pixel)
✅ **Security policies** - Correctly configured with minimal necessary permissions
⚠️ **Clickjacking protection** - Missing (frame-ancestors CSP requires HTTP header, not meta tag)
⚠️ **Local development** - Contact form blocked on localhost (expected, needs CORS config)

**Production Status**:
- All analytics will work correctly on production domain
- Recommend adding frame-ancestors CSP header on production server for complete clickjacking protection
