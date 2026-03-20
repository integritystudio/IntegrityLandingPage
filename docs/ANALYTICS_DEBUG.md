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

### 2. Facebook Pixel Form Submission ✅ FIXED
```
Previously blocked: "Sending form data to 'https://www.facebook.com/tr/' violates the following Content Security Policy directive: form-action 'self'."
```

**Root Cause**: CSP policy `form-action 'self'` prevented form submissions to external domains

**Resolution**: Added `https://www.facebook.com` to `form-action` directive

**Updated CSP**: `form-action 'self' https://www.facebook.com;`

**Impact**: Facebook pixel now receives conversion tracking data

---

### 3. Facebook iframe Framing ✅ FIXED
```
Previously blocked: "Framing 'https://www.facebook.com/' violates the following Content Security Policy directive: frame-src 'self' https://calendly.com https://td.doubleclick.net".
```

**Root Cause**: CSP `frame-src` directive didn't include facebook.com

**Resolution**: Added `https://www.facebook.com` to `frame-src` directive

**Updated CSP**: `frame-src 'self' https://calendly.com https://td.doubleclick.net https://www.facebook.com;`

**Impact**: Facebook embeds and social plugins can now load in iframes

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
| CSP in meta tag | Low | ⏳ Pending | Move to HTTP headers for cleaner security model |
| Facebook pixel blocked | Low | ✅ Fixed | Form submissions to Facebook pixel now allowed |
| Facebook iframe blocked | Low | ✅ Fixed | Social embeds and iframes can now load |
| Contact form localhost CORS | Medium | ⏳ Pending | Add localhost to allowlist for dev testing |

---

## Deployment Readiness

✅ **Analytics tracking** - Fully functional with Facebook pixel enabled
✅ **Facebook integration** - Pixel tracking and iframe embeds now supported
✅ **Security policies** - Working as intended
⚠️ **Local development** - Contact form blocked on localhost (expected, needs config for dev)

**Production Status**: All analytics including Facebook pixel will work on production domain
