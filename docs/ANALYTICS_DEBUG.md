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

### 2. Facebook Pixel Form Submission Blocked
```
Sending form data to 'https://www.facebook.com/tr/' violates the following Content Security Policy directive: "form-action 'self'".
The request has been blocked.
```

**Root Cause**: CSP policy `form-action 'self'` prevents form submissions to external domains

**Impact**: Facebook pixel doesn't receive conversion data (intentional security policy)

**Solution Options**:
1. Remove `form-action 'self'` from CSP (reduces security)
2. Add `https://www.facebook.com` to `form-action` directive
3. Keep as-is (recommended - prioritize security over Facebook tracking)

**Current**: Intentional block, security-first approach

---

### 3. Facebook iframe Framing Blocked
```
Framing 'https://www.facebook.com/' violates the following Content Security Policy directive: "frame-src 'self' https://calendly.com https://td.doubleclick.net".
The request has been blocked.
```

**Root Cause**: CSP `frame-src` directive doesn't include facebook.com

**Impact**: Facebook embed/iframe doesn't load

**Solution**: Add `https://www.facebook.com` to `frame-src` directive if needed

**Current**: Intentional block, only Calendly and DoubleClick allowed

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

## Recommended Actions (Non-Blocking)

| Issue | Priority | Action | Impact |
|-------|----------|--------|--------|
| CSP in meta tag | Low | Move CSP to HTTP headers | Cleaner security model |
| Facebook pixel blocked | Low | Add to form-action if needed | Optional tracking |
| Facebook iframe blocked | Low | Add to frame-src if needed | Optional embeds |
| Contact form localhost CORS | Medium | Add localhost to allowlist | Enables dev testing |

---

## Deployment Readiness

✅ **Analytics tracking** - Fully functional, no code issues
✅ **Security policies** - Working as intended
⚠️ **Local development** - Contact form blocked (expected, needs config)

**Production Status**: All analytics will work correctly on production domain
