/**
 * Tests for Supabase integration functions
 *
 * Tests slug generation logic for organization deduplication.
 * Run with: npm test
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  dedupSlug,
  fnv1aHex,
  EMAIL_SEPARATOR,
  DOT_TO_HYPHEN_REGEX,
  SLUG_SANITIZE_REGEX,
  SLUG_TRIM_REGEX,
  auth0CreateUser,
  auth0DeleteUser,
  supabaseCreatePersonalOrg,
  supabaseDeleteOrg,
  supabaseInsertUser,
  supabaseDeleteUser,
  supabaseAddOrgOwner,
  auth0UserSignIn,
} from './supabase';

describe('dedupSlug', () => {
  describe('constant regex patterns', () => {
    it('EMAIL_SEPARATOR matches @ character', () => {
      expect(EMAIL_SEPARATOR.test('@')).toBe(true);
      expect('user@example.com'.split(EMAIL_SEPARATOR)).toEqual(['user', 'example.com']);
    });

    it('DOT_TO_HYPHEN_REGEX matches dots', () => {
      expect('example.co.uk'.replace(DOT_TO_HYPHEN_REGEX, '-')).toBe('example-co-uk');
    });

    it('SLUG_SANITIZE_REGEX removes special characters but preserves hyphens', () => {
      expect('user@name!'.replace(SLUG_SANITIZE_REGEX, '-')).toBe('user-name-');
      expect('user-name'.replace(SLUG_SANITIZE_REGEX, '-')).toBe('user-name');
    });

    it('SLUG_TRIM_REGEX removes leading and trailing hyphens', () => {
      expect('-slug-with-hyphens-'.replace(SLUG_TRIM_REGEX, '')).toBe('slug-with-hyphens');
      let str = '---slug---';
      while (SLUG_TRIM_REGEX.test(str)) {
        str = str.replace(SLUG_TRIM_REGEX, '');
      }
      expect(str).toBe('slug');
    });
  });

  describe('fnv1aHex()', () => {
    it('returns an 8-char lowercase hex string', () => {
      expect(fnv1aHex('any string')).toMatch(/^[0-9a-f]{8}$/);
    });

    it('is deterministic', () => {
      expect(fnv1aHex('user@example.com')).toBe(fnv1aHex('user@example.com'));
    });

    it('distinguishes inputs that differ only by . vs -', () => {
      expect(fnv1aHex('a.b@example.com')).not.toBe(fnv1aHex('a-b@example.com'));
    });

    it('distinguishes inputs that differ only by case', () => {
      // canonical email is lowercased before hashing, so case should not matter
      expect(fnv1aHex('user@example.com')).toBe(fnv1aHex('user@example.com'));
      expect(fnv1aHex('User@Example.Com')).not.toBe(fnv1aHex('user@example.com'));
    });
  });

  describe('slug generation', () => {
    it('generates deterministic slug', () => {
      const slug1 = dedupSlug('user@example.com');
      const slug2 = dedupSlug('user@example.com');
      expect(slug1).toBe(slug2);
      expect(slug1).toBe(`user-example-com-${fnv1aHex('user@example.com')}`);
    });

    it('converts dots in username to hyphens', () => {
      const slug = dedupSlug('john.doe@example.com');
      expect(slug).toBe(`john-doe-example-com-${fnv1aHex('john.doe@example.com')}`);
    });

    it('removes special characters from username', () => {
      const slug = dedupSlug('user+tag@example.com');
      expect(slug).toBe(`user-tag-example-com-${fnv1aHex('user+tag@example.com')}`);
    });

    it('handles emails with multiple dots in username', () => {
      const slug = dedupSlug('john.q.public@example.com');
      expect(slug).toBe(`john-q-public-example-com-${fnv1aHex('john.q.public@example.com')}`);
    });

    it('handles emails with hyphens in username (preserves them)', () => {
      const slug = dedupSlug('john-smith@example.com');
      expect(slug).toBe(`john-smith-example-com-${fnv1aHex('john-smith@example.com')}`);
    });

    it('handles emails with mixed special characters in username', () => {
      const slug = dedupSlug('user.name+tag@example.com');
      expect(slug).toBe(`user-name-tag-example-com-${fnv1aHex('user.name+tag@example.com')}`);
    });

    it('trims leading and trailing hyphens from username', () => {
      const slug = dedupSlug('.user.@example.com');
      expect(slug).toBe(`user-example-com-${fnv1aHex('.user.@example.com')}`);
    });

    it('converts uppercase email to lowercase before processing', () => {
      const slug1 = dedupSlug('User@Example.Com');
      const slug2 = dedupSlug('user@example.com');
      expect(slug1).toBe(slug2);
    });

    it('converts dots in domain to hyphens', () => {
      const slug = dedupSlug('user@example.co.uk');
      expect(slug).toBe(`user-example-co-uk-${fnv1aHex('user@example.co.uk')}`);
    });

    it('trims leading and trailing hyphens from domain', () => {
      const slug = dedupSlug('user@.example.com.');
      expect(slug).toBe(`user-example-com-${fnv1aHex('user@.example.com.')}`);
    });

    it('handles complex domain names', () => {
      const slug = dedupSlug('alice@mail.company.co.uk');
      expect(slug).toBe(`alice-mail-company-co-uk-${fnv1aHex('alice@mail.company.co.uk')}`);
    });

    it('preserves determinism across multiple calls with same email', () => {
      const emails = ['john@company.io', 'jane.doe@enterprise.co.uk', 'user+label@domain.org'];
      emails.forEach(email => {
        const slug1 = dedupSlug(email);
        const slug2 = dedupSlug(email);
        const slug3 = dedupSlug(email);
        expect(slug1).toBe(slug2);
        expect(slug2).toBe(slug3);
      });
    });

    it('handles single character usernames', () => {
      const slug = dedupSlug('a@example.com');
      expect(slug).toBe(`a-example-com-${fnv1aHex('a@example.com')}`);
    });

    it('handles single character domains', () => {
      const slug = dedupSlug('user@x.com');
      expect(slug).toBe(`user-x-com-${fnv1aHex('user@x.com')}`);
    });

    it('handles very long usernames', () => {
      const email = 'verylongemailaddresswithlotsofcharacters@example.com';
      const slug = dedupSlug(email);
      expect(slug).toBe(`verylongemailaddresswithlotsofcharacters-example-com-${fnv1aHex(email)}`);
    });

    it('handles very long domains', () => {
      const email = 'user@very.long.domain.with.many.subdomains.com';
      const slug = dedupSlug(email);
      expect(slug).toBe(`user-very-long-domain-with-many-subdomains-com-${fnv1aHex(email)}`);
    });

    it('handles emails with consecutive special characters', () => {
      const slug = dedupSlug('user@@example.com');
      expect(slug).toContain('user');
    });

    it('handles emails with numbers in username', () => {
      const slug = dedupSlug('user123@example.com');
      expect(slug).toBe(`user123-example-com-${fnv1aHex('user123@example.com')}`);
    });

    it('handles emails with numbers in domain', () => {
      const slug = dedupSlug('user@example123.com');
      expect(slug).toBe(`user-example123-com-${fnv1aHex('user@example123.com')}`);
    });
  });

  describe('collision prevention', () => {
    it('a.b@ and a-b@ produce different slugs despite identical human-readable base', () => {
      // Both normalize to "a-b-example-com" before the hash suffix, but the hash
      // is computed from the canonical email so they produce distinct final slugs.
      const slug1 = dedupSlug('a.b@example.com');
      const slug2 = dedupSlug('a-b@example.com');
      expect(slug1).not.toBe(slug2);
    });

    it('a+b@ and a-b@ produce different slugs', () => {
      const slug1 = dedupSlug('a+b@example.com');
      const slug2 = dedupSlug('a-b@example.com');
      expect(slug1).not.toBe(slug2);
    });

    it('a.b@ and a+b@ produce different slugs', () => {
      const slug1 = dedupSlug('a.b@example.com');
      const slug2 = dedupSlug('a+b@example.com');
      expect(slug1).not.toBe(slug2);
    });

    it('different emails with same normalized form all get unique slugs', () => {
      const emails = ['a.b@example.com', 'a-b@example.com', 'a+b@example.com'];
      const slugs = emails.map(dedupSlug);
      const unique = new Set(slugs);
      expect(unique.size).toBe(emails.length);
    });
  });

  describe('slug format validation', () => {
    it('generated slugs contain only lowercase, hyphens, and numbers', () => {
      const testEmails = [
        'User.Name@Example.Com',
        'john+doe@company.co.uk',
        'alice-smith@enterprise.io',
        'Test123@Domain.Org',
      ];
      testEmails.forEach(email => {
        const slug = dedupSlug(email);
        expect(slug).toMatch(/^[a-z0-9-]+$/);
      });
    });

    it('generated slugs do not start with hyphen', () => {
      const testEmails = [
        'user@example.com',
        'john.doe@example.com',
        '.user.@example.com',
      ];
      testEmails.forEach(email => {
        const slug = dedupSlug(email);
        expect(slug[0]).not.toBe('-');
      });
    });

    it('generated slugs end with an 8-char hex hash suffix', () => {
      const slug = dedupSlug('user@example.com');
      expect(slug).toMatch(/-[0-9a-f]{8}$/);
    });

    it('generated slugs contain at least username and domain parts', () => {
      const slug = dedupSlug('user@example.com');
      expect(slug.startsWith('user-example-com-')).toBe(true);
    });
  });
});

describe('auth0CreateUser()', () => {
  it('throws when the Management API response contains no user_id', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (url) => {
      const urlStr = String(url);
      if (urlStr.includes('/oauth/token')) {
        return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      }
      if (urlStr.includes('/api/v2/users')) {
        return new Response(JSON.stringify({}), {
          status: 201,
          headers: { 'content-type': 'application/json' },
        });
      }
      return new Response('', { status: 201 });
    });

    await expect(
      auth0CreateUser('domain.auth0.com', 'cli-id', 'cli-secret', 'https://audience', 'user@example.com', 'pass'),
    ).rejects.toThrow('no user_id');

    fetchSpy.mockRestore();
  });
});

describe('supabaseCreatePersonalOrg()', () => {
  it('throws when the HTTP response is not ok', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response('conflict', { status: 409 }),
    );

    await expect(
      supabaseCreatePersonalOrg('https://supabase.test', 'svc-key', 'My Org', 'starter', 'user@example.com'),
    ).rejects.toThrow('Supabase org creation failed');

    fetchSpy.mockRestore();
  });

  it('throws when the response returns no id', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(JSON.stringify([{}]), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      }),
    );

    await expect(
      supabaseCreatePersonalOrg('https://supabase.test', 'svc-key', 'My Org', 'starter', 'user@example.com'),
    ).rejects.toThrow('no id');

    fetchSpy.mockRestore();
  });
});

describe('supabaseInsertUser()', () => {
  it('throws when the HTTP response is not ok', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response('forbidden', { status: 403 }),
    );

    await expect(
      supabaseInsertUser('https://supabase.test', 'svc-key', 'user-id', 'auth0|abc', 'user@example.com'),
    ).rejects.toThrow('Supabase user insert failed');

    fetchSpy.mockRestore();
  });
});

describe('supabaseAddOrgOwner()', () => {
  it('throws when the HTTP response is not ok', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response('forbidden', { status: 403 }),
    );

    await expect(
      supabaseAddOrgOwner('https://supabase.test', 'svc-key', 'org-id', 'user-id'),
    ).rejects.toThrow('Supabase org membership insert failed');

    fetchSpy.mockRestore();
  });
});

describe('auth0UserSignIn()', () => {
  it('throws when the ROPC token endpoint returns an error', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response('unauthorized', { status: 401 }),
    );

    await expect(
      auth0UserSignIn('domain.auth0.com', 'client-id', 'client-secret', 'https://audience', 'user@example.com', 'pass'),
    ).rejects.toThrow('Auth0 user signin failed');

    fetchSpy.mockRestore();
  });

  it('throws when the ROPC response contains no access_token', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(JSON.stringify({}), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );

    await expect(
      auth0UserSignIn('domain.auth0.com', 'client-id', 'client-secret', 'https://audience', 'user@example.com', 'pass'),
    ).rejects.toThrow('no access_token');

    fetchSpy.mockRestore();
  });
});

describe('signup rollback helpers', () => {
  beforeEach(() => { vi.restoreAllMocks(); });

  describe('auth0DeleteUser', () => {
    it('calls Management API DELETE with correct URL and swallows errors', async () => {
      const auth0Sub = 'auth0|rollback-test';
      let deletedUrl = '';
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        deletedUrl = urlStr;
        return new Response('', { status: 204 });
      });

      await expect(
        auth0DeleteUser('domain.auth0.com', 'cli-id', 'cli-secret', auth0Sub),
      ).resolves.toBeUndefined();
      expect(deletedUrl).toContain(`/api/v2/users/${encodeURIComponent(auth0Sub)}`);
      fetchSpy.mockRestore();
    });

    it('swallows errors so they do not mask the original failure', async () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('network error'));
      await expect(
        auth0DeleteUser('domain.auth0.com', 'cli-id', 'cli-secret', 'auth0|x'),
      ).resolves.toBeUndefined();
      fetchSpy.mockRestore();
    });
  });

  describe('supabaseDeleteOrg', () => {
    it('calls DELETE with id filter', async () => {
      const orgId = 'org-uuid-to-delete';
      let deletedUrl = '';
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (url) => {
        deletedUrl = String(url);
        return new Response('', { status: 204 });
      });

      await expect(
        supabaseDeleteOrg('https://supabase.test', 'service-key', orgId),
      ).resolves.toBeUndefined();
      expect(deletedUrl).toContain('/organizations');
      expect(deletedUrl).toContain(`id=eq.${encodeURIComponent(orgId)}`);
      fetchSpy.mockRestore();
    });

    it('swallows errors so they do not mask the original failure', async () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('db down'));
      await expect(
        supabaseDeleteOrg('https://supabase.test', 'service-key', 'org-id'),
      ).resolves.toBeUndefined();
      fetchSpy.mockRestore();
    });
  });

  describe('supabaseDeleteUser', () => {
    it('calls DELETE with id filter', async () => {
      const userId = 'user-uuid-to-delete';
      let deletedUrl = '';
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (url) => {
        deletedUrl = String(url);
        return new Response('', { status: 204 });
      });

      await expect(
        supabaseDeleteUser('https://supabase.test', 'service-key', userId),
      ).resolves.toBeUndefined();
      expect(deletedUrl).toContain('/users');
      expect(deletedUrl).toContain(`id=eq.${encodeURIComponent(userId)}`);
      fetchSpy.mockRestore();
    });

    it('swallows errors so they do not mask the original failure', async () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('db down'));
      await expect(
        supabaseDeleteUser('https://supabase.test', 'service-key', 'user-id'),
      ).resolves.toBeUndefined();
      fetchSpy.mockRestore();
    });
  });
});
