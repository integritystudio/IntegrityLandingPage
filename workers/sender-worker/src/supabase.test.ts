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
    it('generates slug from username with random UUID suffix', () => {
      const slug = dedupSlug('user@example.com', 'starter');
      expect(slug).toMatch(/^user-[a-f0-9]{8}$/);
    });

    it('converts dots in username to hyphens', () => {
      const slug = dedupSlug('john.doe@example.com', 'starter');
      expect(slug).toMatch(/^john-doe-[a-f0-9]{8}$/);
    });

    it('removes special characters from username', () => {
      const slug = dedupSlug('user+tag@example.com', 'starter');
      expect(slug).toMatch(/^user-tag-[a-f0-9]{8}$/);
    });

    it('handles emails with multiple dots in username', () => {
      const slug = dedupSlug('john.q.public@example.com', 'starter');
      expect(slug).toMatch(/^john-q-public-[a-f0-9]{8}$/);
    });

    it('handles emails with hyphens in username (preserves them)', () => {
      const slug = dedupSlug('john-smith@example.com', 'starter');
      expect(slug).toMatch(/^john-smith-[a-f0-9]{8}$/);
    });

    it('handles emails with mixed special characters in username', () => {
      const slug = dedupSlug('user.name+tag@example.com', 'starter');
      expect(slug).toMatch(/^user-name-tag-[a-f0-9]{8}$/);
    });

    it('trims leading and trailing hyphens from username', () => {
      const slug = dedupSlug('.user.@example.com', 'starter');
      expect(slug).toMatch(/^user-[a-f0-9]{8}$/);
    });

    it('generates different UUIDs for same email on multiple calls', () => {
      const slug1 = dedupSlug('user@example.com', 'starter');
      const slug2 = dedupSlug('user@example.com', 'starter');
      expect(slug1).not.toBe(slug2);
      // Both should have same username prefix
      expect(slug1.split('-').slice(0, -1).join('-')).toBe(slug2.split('-').slice(0, -1).join('-'));
    });

    it('converts uppercase email to lowercase before processing', () => {
      const slug1 = dedupSlug('User@Example.Com', 'starter');
      const slug2 = dedupSlug('user@example.com', 'starter');
      // Same base slug (username only, without UUID suffix)
      expect(slug1.split('-').slice(0, -1).join('-')).toBe(slug2.split('-').slice(0, -1).join('-'));
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
    it('generates slug with UUID suffix (same as starter)', () => {
      const slug = dedupSlug('user@example.com', 'enterprise');
      expect(slug).toMatch(/^user-[a-f0-9]{8}$/);
    });

    it('converts dots in username to hyphens', () => {
      const slug = dedupSlug('john.doe@example.com', 'enterprise');
      expect(slug).toMatch(/^john-doe-[a-f0-9]{8}$/);
    });

    it('generates different UUIDs on multiple calls', () => {
      const slug1 = dedupSlug('user@example.com', 'enterprise');
      const slug2 = dedupSlug('user@example.com', 'enterprise');
      expect(slug1).not.toBe(slug2);
    });
  });

  describe('unknown tier handling', () => {
    it('defaults to random UUID suffix for unknown tier', () => {
      const slug = dedupSlug('user@example.com', 'unknown-tier');
      expect(slug).toMatch(/^user-[a-f0-9]{8}$/);
    });

    it('does not use domain for unknown tier', () => {
      const slug = dedupSlug('user@example.co.uk', 'unknown-tier');
      expect(slug).not.toContain('example');
      expect(slug).toMatch(/^user-[a-f0-9]{8}$/);
    });
  });

  describe('edge cases', () => {
    it('handles single character usernames', () => {
      const slug = dedupSlug('a@example.com', 'starter');
      expect(slug).toMatch(/^a-[a-f0-9]{8}$/);
    });

    it('handles single character domains', () => {
      const slug = dedupSlug('user@x.com', 'growth');
      expect(slug).toBe('user-x-com');
    });

    it('handles very long usernames', () => {
      const longUser = 'verylongemailaddresswithlotsofcharacters@example.com';
      const slug = dedupSlug(longUser, 'starter');
      expect(slug).toMatch(/^verylongemailaddresswithlotsofcharacters-[a-f0-9]{8}$/);
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

    it('generated starter tier slugs have exactly 8 character UUID suffix', () => {
      for (let i = 0; i < 10; i++) {
        const slug = dedupSlug('user@example.com', 'starter');
        const parts = slug.split('-');
        const uuidPart = parts[parts.length - 1];
        expect(uuidPart).toMatch(/^[a-f0-9]{8}$/);
      }
    });
  });
});
