/**
 * Fetch Mock Helper
 *
 * Provides injectable fetch mocking without global spies.
 * Allows tests to define request handlers and verify calls without vi.spyOn.
 */

export interface FetchHandler {
  (url: string | Request, init?: RequestInit): Promise<Response> | Response;
}

export class FetchMock {
  private handlers: Array<[pattern: RegExp | string, handler: FetchHandler]> = [];
  private calls: Array<{ url: string; init?: RequestInit }> = [];
  private originalFetch: typeof global.fetch;
  private spy: ReturnType<typeof vi.spyOn> | null = null;

  constructor() {
    this.originalFetch = global.fetch;
  }

  /**
   * Register a handler for URLs matching a pattern or string.
   * Handlers are checked in order; first match wins.
   */
  when(pattern: RegExp | string, handler: FetchHandler): this {
    this.handlers.push([pattern, handler]);
    return this;
  }

  /**
   * Register a handler for Auth0 token endpoint.
   */
  whenAuth0Token(response: Record<string, unknown> = { access_token: 'test-token' }): this {
    return this.when(/\/oauth\/token/, async () =>
      new Response(JSON.stringify(response), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      })
    );
  }

  /**
   * Register a handler for Auth0 Management API user creation.
   */
  whenAuth0CreateUser(userId = 'auth0|test-user'): this {
    return this.when(/\/api\/v2\/users/, async () =>
      new Response(JSON.stringify({ user_id: userId }), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );
  }

  /**
   * Register a handler for Supabase organizations endpoint.
   */
  whenSupabaseOrganization(orgId = 'org-uuid-1234'): this {
    return this.when(/\/rest\/v1\/organizations/, async () =>
      new Response(JSON.stringify([{ id: orgId }]), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );
  }

  /**
   * Register a handler for Supabase users endpoint.
   */
  whenSupabaseUser(): this {
    return this.when(/\/rest\/v1\/users/, async () =>
      new Response(JSON.stringify({}), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );
  }

  /**
   * Register a handler for Supabase organization_memberships endpoint.
   */
  whenSupabaseOrgMembership(): this {
    return this.when(/\/rest\/v1\/organization_memberships/, async () =>
      new Response(JSON.stringify({}), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );
  }

  /**
   * Register a handler that always returns a 500 error.
   */
  whenError(status = 500, message = 'Internal Server Error'): this {
    return this.when(/.*/, async () =>
      new Response(message, { status, headers: { 'content-type': 'text/plain' } })
    );
  }

  /**
   * Activate the mock by replacing global.fetch.
   * Must call `restore()` to clean up.
   */
  activate(): this {
    const self = this;
    this.spy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
      const urlStr = typeof url === 'string' ? url : url.url;
      self.calls.push({ url: urlStr, init });

      for (const [pattern, handler] of self.handlers) {
        const isMatch =
          pattern instanceof RegExp ? pattern.test(urlStr) : urlStr.includes(pattern);
        if (isMatch) {
          return handler(urlStr, init);
        }
      }

      throw new Error(`No handler registered for fetch: ${urlStr}`);
    });
    return this;
  }

  /**
   * Get all fetch calls made during test.
   */
  getCalls(): Array<{ url: string; init?: RequestInit }> {
    return this.calls;
  }

  /**
   * Assert that a URL was called.
   */
  assertCalled(pattern: RegExp | string): boolean {
    return this.calls.some((call) => {
      const isMatch =
        pattern instanceof RegExp ? pattern.test(call.url) : call.url.includes(pattern);
      return isMatch;
    });
  }

  /**
   * Get call count for a pattern.
   */
  getCallCount(pattern: RegExp | string): number {
    return this.calls.filter((call) => {
      const isMatch =
        pattern instanceof RegExp ? pattern.test(call.url) : call.url.includes(pattern);
      return isMatch;
    }).length;
  }

  /**
   * Clear all handlers and calls.
   */
  reset(): this {
    this.handlers = [];
    this.calls = [];
    return this;
  }

  /**
   * Restore original global.fetch.
   */
  restore(): void {
    if (this.spy) {
      this.spy.mockRestore();
      this.spy = null;
    }
    global.fetch = this.originalFetch;
  }
}

// Import vi at the top level to avoid issues
import { vi } from 'vitest';
