/**
 * Tests for Supabase integration functions
 *
 * Tests slug generation logic for organization deduplication.
 * Run with: npm test
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  dedupSlug,
  EMAIL_SEPARATOR,
  DOT_TO_HYPHEN_REGEX,
  SLUG_SANITIZE_REGEX,
  SLUG_TRIM_REGEX,
  auth0CreateUser,
  supabaseCreatePersonalOrg,
  supabaseInsertUser,
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
      // Multiple leading/trailing hyphens require multiple replace calls
      // since ^ and $ anchors only match once per string
      let str = '---slug---';
      while (SLUG_TRIM_REGEX.test(str)) {
        str = str.replace(SLUG_TRIM_REGEX, '');
      }
      expect(str).toBe('slug');
    });
  });

  describe('starter tier slug generation', () => {
    it('generates deterministic slug from username + domain', () => {
      const slug1 = dedupSlug('user@example.com', 'starter');
      const slug2 = dedupSlug('user@example.com', 'starter');
      expect(slug1).toBe(slug2);
      expect(slug1).toBe('user-example-com');
    });

    it('converts dots in username to hyphens', () => {
      const slug = dedupSlug('john.doe@example.com', 'starter');
      expect(slug).toBe('john-doe-example-com');
    });

    it('removes special characters from username', () => {
      const slug = dedupSlug('user+tag@example.com', 'starter');
      expect(slug).toBe('user-tag-example-com');
    });

    it('handles emails with multiple dots in username', () => {
      const slug = dedupSlug('john.q.public@example.com', 'starter');
      expect(slug).toBe('john-q-public-example-com');
    });

    it('handles emails with hyphens in username (preserves them)', () => {
      const slug = dedupSlug('john-smith@example.com', 'starter');
      expect(slug).toBe('john-smith-example-com');
    });

    it('handles emails with mixed special characters in username', () => {
      const slug = dedupSlug('user.name+tag@example.com', 'starter');
      expect(slug).toBe('user-name-tag-example-com');
    });

    it('trims leading and trailing hyphens from username', () => {
      const slug = dedupSlug('.user.@example.com', 'starter');
      expect(slug).toBe('user-example-com');
    });

    it('preserves determinism across multiple calls with same email', () => {
      const emails = [
        'john@company.io',
        'jane.doe@enterprise.co.uk',
        'user+label@domain.org',
      ];
      emails.forEach(email => {
        const slug1 = dedupSlug(email, 'starter');
        const slug2 = dedupSlug(email, 'starter');
        const slug3 = dedupSlug(email, 'starter');
        expect(slug1).toBe(slug2);
        expect(slug2).toBe(slug3);
      });
    });

    it('converts uppercase email to lowercase before processing', () => {
      const slug1 = dedupSlug('User@Example.Com', 'starter');
      const slug2 = dedupSlug('user@example.com', 'starter');
      expect(slug1).toBe(slug2);
    });

    it('converts dots in domain to hyphens', () => {
      const slug = dedupSlug('user@example.co.uk', 'starter');
      expect(slug).toBe('user-example-co-uk');
    });
  });

  describe('growth tier slug generation', () => {
    it('generates deterministic slug from username + domain', () => {
      const slug1 = dedupSlug('user@example.com', 'growth');
      const slug2 = dedupSlug('user@example.com', 'growth');
      expect(slug1).toBe(slug2);
      expect(slug1).toBe('user-example-com');
    });

    it('converts dots in username to hyphens', () => {
      const slug = dedupSlug('john.doe@example.com', 'growth');
      expect(slug).toBe('john-doe-example-com');
    });

    it('converts dots in domain to hyphens', () => {
      const slug = dedupSlug('user@example.co.uk', 'growth');
      expect(slug).toBe('user-example-co-uk');
    });

    it('handles usernames with hyphens', () => {
      const slug = dedupSlug('john-smith@example.com', 'growth');
      expect(slug).toBe('john-smith-example-com');
    });

    it('removes special characters from username', () => {
      const slug = dedupSlug('user+tag@example.com', 'growth');
      expect(slug).toBe('user-tag-example-com');
    });

    it('trims leading and trailing hyphens from username', () => {
      const slug = dedupSlug('.user.@example.com', 'growth');
      expect(slug).toBe('user-example-com');
    });

    it('trims leading and trailing hyphens from domain', () => {
      const slug = dedupSlug('user@.example.com.', 'growth');
      expect(slug).toBe('user-example-com');
    });

    it('handles complex domain names', () => {
      const slug = dedupSlug('alice@mail.company.co.uk', 'growth');
      expect(slug).toBe('alice-mail-company-co-uk');
    });

    it('converts uppercase email to lowercase before processing', () => {
      const slug1 = dedupSlug('User@Example.Com', 'growth');
      const slug2 = dedupSlug('user@example.com', 'growth');
      expect(slug1).toBe(slug2);
    });

    it('preserves determinism across multiple calls with same email', () => {
      const emails = [
        'john@company.io',
        'jane.doe@enterprise.co.uk',
        'user+label@domain.org',
      ];
      emails.forEach(email => {
        const slug1 = dedupSlug(email, 'growth');
        const slug2 = dedupSlug(email, 'growth');
        const slug3 = dedupSlug(email, 'growth');
        expect(slug1).toBe(slug2);
        expect(slug2).toBe(slug3);
      });
    });
  });

  describe('enterprise tier slug generation', () => {
    it('generates deterministic slug from username + domain (same as starter)', () => {
      const slug1 = dedupSlug('user@example.com', 'enterprise');
      const slug2 = dedupSlug('user@example.com', 'enterprise');
      expect(slug1).toBe(slug2);
      expect(slug1).toBe('user-example-com');
    });

    it('converts dots in username to hyphens', () => {
      const slug = dedupSlug('john.doe@example.com', 'enterprise');
      expect(slug).toBe('john-doe-example-com');
    });

    it('preserves determinism across multiple calls', () => {
      const slug1 = dedupSlug('user@example.com', 'enterprise');
      const slug2 = dedupSlug('user@example.com', 'enterprise');
      const slug3 = dedupSlug('user@example.com', 'enterprise');
      expect(slug1).toBe(slug2);
      expect(slug2).toBe(slug3);
    });
  });

  describe('unknown tier handling', () => {
    it('generates deterministic slug from username + domain for unknown tier', () => {
      const slug1 = dedupSlug('user@example.com', 'unknown-tier');
      const slug2 = dedupSlug('user@example.com', 'unknown-tier');
      expect(slug1).toBe(slug2);
      expect(slug1).toBe('user-example-com');
    });

    it('includes domain in slug for unknown tier', () => {
      const slug = dedupSlug('user@example.co.uk', 'unknown-tier');
      expect(slug).toBe('user-example-co-uk');
    });
  });

  describe('edge cases', () => {
    it('handles single character usernames', () => {
      const slug = dedupSlug('a@example.com', 'starter');
      expect(slug).toBe('a-example-com');
    });

    it('handles single character domains', () => {
      const slug = dedupSlug('user@x.com', 'growth');
      expect(slug).toBe('user-x-com');
    });

    it('handles very long usernames', () => {
      const longUser = 'verylongemailaddresswithlotsofcharacters@example.com';
      const slug = dedupSlug(longUser, 'starter');
      expect(slug).toBe('verylongemailaddresswithlotsofcharacters-example-com');
    });

    it('handles very long domains', () => {
      const longDomain = 'user@very.long.domain.with.many.subdomains.com';
      const slug = dedupSlug(longDomain, 'growth');
      expect(slug).toBe('user-very-long-domain-with-many-subdomains-com');
    });

    it('handles emails with consecutive special characters', () => {
      const slug = dedupSlug('user@@example.com', 'growth');
      // The second @ will be treated as a special character and removed/replaced
      expect(slug).toContain('user');
    });

    it('handles emails with numbers in username', () => {
      const slug = dedupSlug('user123@example.com', 'growth');
      expect(slug).toBe('user123-example-com');
    });

    it('handles emails with numbers in domain', () => {
      const slug = dedupSlug('user@example123.com', 'growth');
      expect(slug).toBe('user-example123-com');
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
        const slug = dedupSlug(email, 'growth');
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
        const slug = dedupSlug(email, 'growth');
        expect(slug[0]).not.toBe('-');
      });
    });

    it('generated slugs do not end with hyphen', () => {
      const testEmails = [
        'user@example.com',
        'john.doe@example.com',
        'user@.example.com.',
      ];
      testEmails.forEach(email => {
        const slug = dedupSlug(email, 'growth');
        expect(slug[slug.length - 1]).not.toBe('-');
      });
    });

    it('generated slugs follow username-domain pattern', () => {
      const slug = dedupSlug('user@example.com', 'starter');
      const parts = slug.split('-');
      expect(parts.length).toBeGreaterThanOrEqual(2);
      expect(parts[parts.length - 1]).toBe('com');
    });
  });
});

describe('auth0CreateUser()', () => {
  it('throws when the Management API response contains no user_id', async () => {
    const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
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
    const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
      new Response('conflict', { status: 409 }),
    );

    await expect(
      supabaseCreatePersonalOrg('https://supabase.test', 'svc-key', 'My Org', 'starter', 'user@example.com'),
    ).rejects.toThrow('Supabase org creation failed');

    fetchSpy.mockRestore();
  });

  it('throws when the response returns no id', async () => {
    const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
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
    const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
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
    const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
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
    const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
      new Response('unauthorized', { status: 401 }),
    );

    await expect(
      auth0UserSignIn('domain.auth0.com', 'client-id', 'client-secret', 'https://audience', 'user@example.com', 'pass'),
    ).rejects.toThrow('Auth0 user signin failed');

    fetchSpy.mockRestore();
  });

  it('throws when the ROPC response contains no access_token', async () => {
    const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
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
