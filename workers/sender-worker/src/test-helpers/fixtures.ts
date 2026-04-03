/**
 * Test Fixtures and Factories
 *
 * Provides reusable test data and scenario builders.
 */

import { FetchMock } from './fetch-mock';

export const fixtures = {
  auth0: {
    domain: 'test.auth0.com',
    clientId: 'test-client-id',
    clientSecret: 'test-client-secret',
    audience: 'https://api.test',
    cliId: 'test-cli-id',
    cliSecret: 'test-cli-secret',
    cliAudience: 'https://test.auth0.com/api/v2/',
    managementToken: 'test-mgmt-token',
    userJwt: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c',
    sub: 'auth0|test-user-id',
  },
  supabase: {
    url: 'https://supabase.test',
    serviceRoleKey: 'test-service-role-key',
    orgId: 'org-uuid-1234',
    userId: 'user-uuid-5678',
  },
  stripe: {
    secretKey: 'sk_test_123456',
    priceId: 'price_test_123',
  },
  user: {
    email: 'test@example.com',
    password: 'TestPassword123!',
    name: 'Test User',
  },
};

export class SignupScenarioBuilder {
  private fetchMock = new FetchMock();
  private tokenCount = 0;

  /**
   * Build a successful signup scenario with all mocked services.
   */
  successful(): FetchMock {
    this.fetchMock.reset();

    // Auth0: Management token exchange (M2M)
    this.fetchMock.when(/\/oauth\/token/, async (url) => {
      this.tokenCount++;
      const isManagementFlow = this.tokenCount === 1;
      const token = isManagementFlow
        ? fixtures.auth0.managementToken
        : fixtures.auth0.userJwt;
      return new Response(JSON.stringify({ access_token: token }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    });

    // Auth0: Create user
    this.fetchMock.when(/\/api\/v2\/users/, async () =>
      new Response(JSON.stringify({ user_id: fixtures.auth0.sub }), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );

    // Supabase: Create organization
    this.fetchMock.when(/\/rest\/v1\/organizations/, async () =>
      new Response(JSON.stringify([{ id: fixtures.supabase.orgId }]), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );

    // Supabase: Insert user
    this.fetchMock.when(/\/rest\/v1\/users/, async () =>
      new Response(JSON.stringify({}), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );

    // Supabase: Add org owner
    this.fetchMock.when(/\/rest\/v1\/organization_memberships/, async () =>
      new Response(JSON.stringify({}), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      })
    );

    return this.fetchMock;
  }

  /**
   * Build a scenario where Auth0 token exchange fails.
   */
  auth0TokenExchangeFails(): FetchMock {
    this.fetchMock.reset();
    this.fetchMock.when(/\/oauth\/token/, async () =>
      new Response('Unauthorized', { status: 401 })
    );
    return this.fetchMock;
  }

  /**
   * Build a scenario where Supabase organization creation fails.
   */
  supabaseOrgCreationFails(): FetchMock {
    this.fetchMock.reset();
    this.fetchMock.whenAuth0Token();
    this.fetchMock.whenAuth0CreateUser();
    this.fetchMock.when(/\/rest\/v1\/organizations/, async () =>
      new Response('Conflict', { status: 409 })
    );
    return this.fetchMock;
  }

  /**
   * Reset the token counter (useful for multi-step flows).
   */
  resetTokenCounter(): this {
    this.tokenCount = 0;
    return this;
  }
}

export class SendScenarioBuilder {
  private fetchMock = new FetchMock();

  /**
   * Build a successful send scenario.
   */
  successful(): FetchMock {
    this.fetchMock.reset();
    // Receiver is mocked separately via service binding, not via fetch
    return this.fetchMock;
  }
}

export class CreateCheckoutSessionScenarioBuilder {
  private fetchMock = new FetchMock();

  /**
   * Build a successful Stripe checkout session scenario.
   */
  successful(): FetchMock {
    this.fetchMock.reset();
    this.fetchMock.when(/stripe\.com/, async () =>
      new Response(
        JSON.stringify({
          id: 'cs_test_123',
          url: 'https://checkout.stripe.com/pay/cs_test_123',
        }),
        {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }
      )
    );
    return this.fetchMock;
  }
}
