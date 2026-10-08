import { describe, it, expect, vi, afterEach, beforeAll } from 'vitest';
import { emailDomain, handleGetTeam, handleJoinTeam } from './team';
import {
  createSupabaseFetchStub,
  httpError,
  okRows,
  createdRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../../lib/test-helpers/supabase-fetch-stub';
import { createAuth0JwtFixture, TEST_AUTH0_OPTS, type Auth0JwtFixture } from '../../../lib/test-helpers/auth0-jwt-stub';
import { resetIdentityRateLimit } from '../lib/rate-limit';

const opts = {
  ...TEST_AUTH0_OPTS,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

const SUB = 'auth0|acme-user';
const USER_ID = 'user-id-1';
const TEAM_ID = 'team-org-1';
const EMAIL = 'dev@acme.com';
/** The Auth0 /userinfo endpoint lands on the stub as this route key (its path is not under /rest/v1). */
const USERINFO_ROUTE = 'GET /userinfo';

let jwt: Auth0JwtFixture;

beforeAll(async () => {
  jwt = await createAuth0JwtFixture();
});

afterEach(() => {
  resetIdentityRateLimit();
  vi.unstubAllGlobals();
});

function makeRequest(method: 'GET' | 'POST', token?: string): Request {
  return new Request('https://api.integritystudio.dev/v1/me/team', {
    method,
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

function stub(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const s = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', jwt.wrap(s.fetch));
  return s;
}

const userinfo = (body: Record<string, unknown>): RouteResponder => () =>
  new Response(JSON.stringify(body), { status: 200, headers: { 'content-type': 'application/json' } });

const verified = userinfo({ sub: SUB, email: EMAIL, email_verified: true });
const userRow = okRows([{ id: USER_ID, email: EMAIL }]);
const teamRow = okRows([{ id: TEAM_ID, name: 'acme.com' }]);

describe('emailDomain', () => {
  it.each([
    ['dev@acme.com', 'acme.com'],
    ['Dev@ACME.com', 'acme.com'],
    ['"a@b"@acme.com', 'acme.com'],
    ['no-at-sign', null],
    ['trailing@', null],
  ])('%s → %s', (email, expected) => {
    expect(emailDomain(email)).toBe(expected);
  });
});

describe('GET /v1/me/team', () => {
  it('returns 401 without a token and makes no database call', async () => {
    const s = stub({});
    const res = await handleGetTeam(makeRequest('GET'), opts);
    expect(res.status).toBe(401);
    expect(s.requests).toHaveLength(0);
  });

  it('finds the team org by type and the domain of users.email', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({
      'GET users': userRow,
      'GET organizations': teamRow,
      'GET organization_memberships': okRows([]),
    });

    const res = await handleGetTeam(makeRequest('GET', token), opts);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ domain: 'acme.com', team: { id: TEAM_ID, name: 'acme.com' }, member: false });
    const org = s.find('GET', 'organizations')!;
    expect(org.url.searchParams.get('type')).toBe('eq.team');
    expect(org.url.searchParams.get('domain')).toBe('eq.acme.com');
    expect(s.unexpected).toHaveLength(0);
  });

  it('reports member: true only for an active membership', async () => {
    const token = await jwt.sign({ sub: SUB });
    stub({
      'GET users': userRow,
      'GET organizations': teamRow,
      'GET organization_memberships': okRows([{ role: 'member', status: 'suspended' }]),
    });

    const res = await handleGetTeam(makeRequest('GET', token), opts);

    expect(((await res.json()) as { member: boolean }).member).toBe(false);
  });

  it('returns team: null when no team org exists for the domain, and never asks Auth0', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({ 'GET users': userRow, 'GET organizations': okRows([]) });

    const res = await handleGetTeam(makeRequest('GET', token), opts);

    expect(await res.json()).toEqual({ domain: 'acme.com', team: null, member: false });
    expect(s.find('GET', '/userinfo')).toBeUndefined();
    expect(s.find('GET', 'organization_memberships')).toBeUndefined();
  });

  it('returns 500 when the team lookup fails', async () => {
    const token = await jwt.sign({ sub: SUB });
    stub({ 'GET users': userRow, 'GET organizations': httpError(500) });
    const res = await handleGetTeam(makeRequest('GET', token), opts);
    expect(res.status).toBe(500);
  });
});

describe('POST /v1/me/team', () => {
  it('joins an existing team org as a member and writes one audit row', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({
      'GET users': userRow,
      [USERINFO_ROUTE]: verified,
      'GET organizations': teamRow,
      'POST organization_memberships': createdRows([{ id: 'm-1' }]),
      'POST audit_log': createdRows([]),
    });

    const res = await handleJoinTeam(makeRequest('POST', token), opts);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ organizationId: TEAM_ID, name: 'acme.com', role: 'member', joined: true });
    const insert = s.find('POST', 'organization_memberships')!;
    expect(insert.body).toEqual([{ organization_id: TEAM_ID, user_id: USER_ID, role: 'member', status: 'active' }]);
    expect(insert.url.searchParams.get('on_conflict')).toBe('organization_id,user_id');
    expect(insert.headers['prefer']).toContain('resolution=ignore-duplicates');
    const audit = s.findAll('POST', 'audit_log');
    expect(audit).toHaveLength(1);
    expect((audit[0].body as unknown[])[0]).toMatchObject({ action: 'org.member_joined', organization_id: TEAM_ID, actor_user_id: USER_ID });
    expect(s.unexpected).toHaveLength(0);
  });

  it('sends the caller\'s own bearer token to Auth0 /userinfo', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({
      'GET users': userRow,
      [USERINFO_ROUTE]: verified,
      'GET organizations': teamRow,
      'POST organization_memberships': createdRows([{ id: 'm-1' }]),
      'POST audit_log': createdRows([]),
    });

    await handleJoinTeam(makeRequest('POST', token), opts);

    const call = s.find('GET', '/userinfo')!;
    expect(call.url.host).toBe(TEST_AUTH0_OPTS.auth0Domain);
    expect(call.headers['authorization']).toBe(`Bearer ${token}`);
  });

  // CR70: a token obtained through the tenant's custom domain carries that host as `iss`, and
  // Auth0 answers /userinfo for it only on that host.
  describe('custom-domain issuer (CR70)', () => {
    const CUSTOM_DOMAIN = 'auth.test.integritystudio.ai';
    const CUSTOM_ISSUER = `https://${CUSTOM_DOMAIN}/`;
    const customOpts = { ...opts, auth0CustomDomain: CUSTOM_DOMAIN };
    const joinRoutes = {
      'GET users': userRow,
      [USERINFO_ROUTE]: verified,
      'GET organizations': teamRow,
      'POST organization_memberships': createdRows([{ id: 'm-1' }]),
      'POST audit_log': createdRows([]),
    };

    it('accepts the token and sends /userinfo to the custom domain, not the tenant', async () => {
      const token = await jwt.sign({ sub: SUB, iss: CUSTOM_ISSUER });
      const s = stub(joinRoutes);

      const res = await handleJoinTeam(makeRequest('POST', token), customOpts);

      expect(res.status).toBe(200);
      const call = s.find('GET', '/userinfo')!;
      expect(call.url.host).toBe(CUSTOM_DOMAIN);
      expect(call.headers['authorization']).toBe(`Bearer ${token}`);
    });

    it('still sends a tenant-issued token to the tenant host when a custom domain is configured', async () => {
      const token = await jwt.sign({ sub: SUB });
      const s = stub(joinRoutes);

      await handleJoinTeam(makeRequest('POST', token), customOpts);

      expect(s.find('GET', '/userinfo')!.url.host).toBe(TEST_AUTH0_OPTS.auth0Domain);
    });

    it('rejects the custom-domain token with 401 when no custom domain is configured', async () => {
      const token = await jwt.sign({ sub: SUB, iss: CUSTOM_ISSUER });
      const s = stub(joinRoutes);

      const res = await handleJoinTeam(makeRequest('POST', token), opts);

      expect(res.status).toBe(401);
      expect(s.find('GET', '/userinfo')).toBeUndefined();
    });
  });

  it.each([
    ['email_verified false', { sub: SUB, email: EMAIL, email_verified: false }],
    ['email_verified missing', { sub: SUB, email: EMAIL }],
    ['email_verified as a string', { sub: SUB, email: EMAIL, email_verified: 'true' }],
  ])('returns 403 and writes nothing when %s', async (_label, body) => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({ 'GET users': userRow, [USERINFO_ROUTE]: userinfo(body) });

    const res = await handleJoinTeam(makeRequest('POST', token), opts);

    expect(res.status).toBe(403);
    expect(s.find('GET', 'organizations')).toBeUndefined();
    expect(s.find('POST', 'organization_memberships')).toBeUndefined();
  });

  it('groups by the domain Auth0 verified, not users.email', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({
      'GET users': okRows([{ id: USER_ID, email: 'old@other.com' }]),
      [USERINFO_ROUTE]: verified,
      'GET organizations': teamRow,
      'POST organization_memberships': createdRows([{ id: 'm-1' }]),
      'POST audit_log': createdRows([]),
    });

    await handleJoinTeam(makeRequest('POST', token), opts);

    expect(s.find('GET', 'organizations')!.url.searchParams.get('domain')).toBe('eq.acme.com');
  });

  it.each([401, 403])('returns 401 when Auth0 /userinfo rejects the token with %i', async status => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({ 'GET users': userRow, [USERINFO_ROUTE]: httpError(status) });

    const res = await handleJoinTeam(makeRequest('POST', token), opts);

    expect(res.status).toBe(401);
    expect(s.find('POST', 'organization_memberships')).toBeUndefined();
  });

  it('returns 503 when Auth0 /userinfo fails', async () => {
    const token = await jwt.sign({ sub: SUB });
    stub({ 'GET users': userRow, [USERINFO_ROUTE]: httpError(502) });
    const res = await handleJoinTeam(makeRequest('POST', token), opts);
    expect(res.status).toBe(503);
  });

  it('returns 404 and creates nothing when no team org exists for the domain', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({ 'GET users': userRow, [USERINFO_ROUTE]: verified, 'GET organizations': okRows([]) });

    const res = await handleJoinTeam(makeRequest('POST', token), opts);

    expect(res.status).toBe(404);
    expect(s.find('POST', 'organizations')).toBeUndefined();
    expect(s.find('POST', 'organization_memberships')).toBeUndefined();
  });

  it('is idempotent for an active member: no audit row, existing role reported', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({
      'GET users': userRow,
      [USERINFO_ROUTE]: verified,
      'GET organizations': teamRow,
      'POST organization_memberships': createdRows([]),
      'GET organization_memberships': okRows([{ role: 'owner', status: 'active' }]),
    });

    const res = await handleJoinTeam(makeRequest('POST', token), opts);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ organizationId: TEAM_ID, name: 'acme.com', role: 'owner', joined: false });
    expect(s.find('POST', 'audit_log')).toBeUndefined();
  });

  it.each(['suspended', 'invited'])('returns 409 and leaves a %s membership alone', async status => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({
      'GET users': userRow,
      [USERINFO_ROUTE]: verified,
      'GET organizations': teamRow,
      'POST organization_memberships': createdRows([]),
      'GET organization_memberships': okRows([{ role: 'member', status }]),
    });

    const res = await handleJoinTeam(makeRequest('POST', token), opts);

    expect(res.status).toBe(409);
    expect(s.find('PATCH', 'organization_memberships')).toBeUndefined();
    expect(s.find('POST', 'audit_log')).toBeUndefined();
  });

  it('returns 500 when the membership insert fails', async () => {
    const token = await jwt.sign({ sub: SUB });
    stub({
      'GET users': userRow,
      [USERINFO_ROUTE]: verified,
      'GET organizations': teamRow,
      'POST organization_memberships': httpError(500),
    });
    const res = await handleJoinTeam(makeRequest('POST', token), opts);
    expect(res.status).toBe(500);
  });

  it('returns 404 for an authentic token with no users row, before asking Auth0', async () => {
    const token = await jwt.sign({ sub: SUB });
    const s = stub({ 'GET users': okRows([]) });

    const res = await handleJoinTeam(makeRequest('POST', token), opts);

    expect(res.status).toBe(404);
    expect(s.find('GET', '/userinfo')).toBeUndefined();
  });
});
