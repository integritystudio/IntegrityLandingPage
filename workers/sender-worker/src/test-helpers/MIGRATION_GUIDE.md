# Migrating from Global Fetch Mocks to FetchMock Helper

This guide explains how to replace `vi.spyOn(global, 'fetch')` mocks with the injectable `FetchMock` helper to reduce mock complexity and improve test readability.

## Why Migrate?

**Before (Global Spy Pattern):**
```typescript
const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
  const urlStr = String(url);
  if (urlStr.includes('/oauth/token')) {
    // ... handler
  }
  if (urlStr.includes('/api/v2/users')) {
    // ... handler
  }
  // ... many more if statements
});
// ... test code ...
fetchSpy.mockRestore();
```

**After (FetchMock Pattern):**
```typescript
let fetchMock: FetchMock;

afterEach(() => {
  fetchMock?.restore();
});

it('...', async () => {
  fetchMock = new FetchMock()
    .whenAuth0Token()
    .whenAuth0CreateUser()
    .activate();
  
  // ... test code ...
});
```

**Benefits:**
- ✅ No global state/spies — cleaner, less surprising
- ✅ Fluent builder API — more readable setup
- ✅ Call tracking — `getCalls()`, `assertCalled()`, `getCallCount()`
- ✅ Reusable scenarios — `SignupScenarioBuilder`, `SendScenarioBuilder`
- ✅ Type-safe — proper TS support for handlers

## Quick Reference

### Basic Usage

```typescript
import { FetchMock } from './test-helpers/fetch-mock';

let fetchMock: FetchMock;

afterEach(() => {
  fetchMock?.restore();
});

it('calls Auth0', async () => {
  fetchMock = new FetchMock()
    .when(/\/oauth\/token/, async () => 
      new Response(JSON.stringify({ access_token: 'test' }), { status: 200 })
    )
    .activate();

  // ... make request ...

  expect(fetchMock.assertCalled(/\/oauth\/token/)).toBe(true);
});
```

### Using Built-in Handlers

```typescript
fetchMock = new FetchMock()
  .whenAuth0Token()
  .whenAuth0CreateUser()
  .whenSupabaseOrganization()
  .whenSupabaseUser()
  .whenSupabaseOrgMembership()
  .activate();
```

### Using Scenario Builders

For complex flows like signup:

```typescript
import { SignupScenarioBuilder } from './test-helpers/fixtures';

it('successful signup', async () => {
  fetchMock = new SignupScenarioBuilder().successful();
  fetchMock.activate();

  // ... test code ...
});
```

### Customizing Responses

```typescript
fetchMock = new FetchMock()
  .whenAuth0Token({ access_token: 'custom-token' })
  .whenAuth0CreateUser('auth0|custom-id')
  .activate();
```

### Call Tracking

```typescript
// Get all calls
const calls = fetchMock.getCalls();
// → [{ url: 'https://test.auth0.com/oauth/token', init: {...} }, ...]

// Check if URL was called
expect(fetchMock.assertCalled(/\/oauth\/token/)).toBe(true);

// Count calls to endpoint
expect(fetchMock.getCallCount(/\/oauth\/token/)).toBe(2);
```

### Testing Error Cases

```typescript
it('handles Auth0 failure', async () => {
  fetchMock = new FetchMock()
    .when(/\/oauth\/token/, async () => 
      new Response('Unauthorized', { status: 401 })
    )
    .activate();

  // ... test code expects error ...
});
```

## Migration Checklist

For each test using global fetch spies:

- [ ] Add `import { FetchMock } from './test-helpers/fetch-mock';`
- [ ] Add `let fetchMock: FetchMock;` at describe level
- [ ] Add `afterEach(() => { fetchMock?.restore(); });`
- [ ] Replace `vi.spyOn(global, 'fetch').mockImplementation(async (url) => { ... })` with:
  ```typescript
  fetchMock = new FetchMock()
    .when(/pattern/, handler)
    .activate();
  ```
- [ ] Replace call assertions like `expect(capturedUrl).toBe(...)` with:
  ```typescript
  const calls = fetchMock.getCalls();
  expect(calls.some(c => c.url.includes('...'))).toBe(true);
  ```
- [ ] Remove `fetchSpy.mockRestore()` calls (handled by `afterEach`)
- [ ] Run `npm test` to verify

## Common Patterns

### Capturing Request Details

**Before:**
```typescript
let capturedTokenUrl = '';
const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
  const urlStr = String(url);
  if (urlStr.includes('/oauth/token')) {
    capturedTokenUrl = urlStr;
    return new Response(...);
  }
  // ...
});
// ... test ...
expect(capturedTokenUrl).toBe('https://test.auth0.com/oauth/token');
```

**After:**
```typescript
fetchMock = new FetchMock()
  .whenAuth0Token()
  .activate();
// ... test ...
const calls = fetchMock.getCalls();
const tokenCall = calls.find(c => c.url.includes('/oauth/token'));
expect(tokenCall?.url).toContain('test.auth0.com');
```

### Multiple Handlers for Same Endpoint

**Before:**
```typescript
let callCount = 0;
const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
  if (url.includes('/oauth/token')) {
    callCount++;
    if (callCount === 1) return new Response(JSON.stringify({ access_token: 'mgmt' }), ...);
    return new Response(JSON.stringify({ access_token: 'user' }), ...);
  }
  // ...
});
```

**After:**
```typescript
let tokenCallCount = 0;
fetchMock = new FetchMock()
  .when(/\/oauth\/token/, async () => {
    tokenCallCount++;
    const token = tokenCallCount === 1 ? 'mgmt' : 'user';
    return new Response(JSON.stringify({ access_token: token }), { status: 200 });
  })
  .activate();
```

### Conditional Response Logic

**Before:**
```typescript
const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
  if (url.includes('/api/v2/users')) {
    const body = JSON.parse(init?.body as string);
    if (body.email === 'existing@example.com') {
      return new Response('Conflict', { status: 409 });
    }
    return new Response(JSON.stringify({ user_id: 'new-id' }), { status: 201 });
  }
  // ...
});
```

**After:**
```typescript
fetchMock = new FetchMock()
  .when(/\/api\/v2\/users/, async (url, init) => {
    const body = JSON.parse(init?.body as string);
    if (body.email === 'existing@example.com') {
      return new Response('Conflict', { status: 409 });
    }
    return new Response(JSON.stringify({ user_id: 'new-id' }), { status: 201 });
  })
  .activate();
```

## Running Migrated Tests

All migrations should maintain test coverage and assertions. Run:

```bash
npm test
```

To verify no regressions were introduced.

## Future Work

Potential enhancements to consider:

- [ ] Add MSW (Mock Service Worker) support for even cleaner mocks
- [ ] Extract more scenario builders for common flows
- [ ] Add request body validation helpers
- [ ] Add response timing/delay simulation
