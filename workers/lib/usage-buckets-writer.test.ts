/**
 * CR43: `usage_buckets_daily` has exactly one writer — the AFTER INSERT trigger on
 * `usage_events` (`upsert_daily_usage_bucket`). A Worker that also writes the table
 * races the trigger on the same row, and the last Worker-side writer overwrote the
 * trigger's total with a recount capped at 10 000 events.
 *
 * Worker source may only read the table. This scans every package rather than one
 * route, because the defect was a second writer added somewhere nobody was looking.
 */

// Reads source files off disk, so it needs Node's types; see deploy-environments.test.ts.
/// <reference types="node" />
import { describe, it, expect } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const WORKERS_ROOT = join(__dirname, '..');
const SKIPPED_DIRS = new Set(['node_modules', 'dist', '.wrangler']);
const TABLE_REFERENCE = /(['"])usage_buckets_daily\1/g;
/** The one permitted form: the table name as the first argument of a `.query(` read. */
const READ_CALL_BEFORE = /\.query(<[^>]*>)?\(\s*$/;
const LOOKBEHIND_CHARS = 80;

function workerSourceFiles(): string[] {
  return (readdirSync(WORKERS_ROOT, { recursive: true }) as string[])
    .filter((path) => path.endsWith('.ts') && !path.endsWith('.test.ts') && !path.endsWith('.d.ts'))
    .filter((path) => !path.split('/').some((segment) => SKIPPED_DIRS.has(segment)));
}

function nonReadReferences(path: string): string[] {
  const source = readFileSync(join(WORKERS_ROOT, path), 'utf8');
  return [...source.matchAll(TABLE_REFERENCE)]
    .filter((match) => !READ_CALL_BEFORE.test(source.slice(Math.max(0, match.index - LOOKBEHIND_CHARS), match.index)))
    .map((match) => `${path}:${source.slice(0, match.index).split('\n').length}`);
}

describe('usage_buckets_daily writers (CR43)', () => {
  it('scans worker source at all', () => {
    expect(workerSourceFiles().length).toBeGreaterThan(0);
  });

  it('is only ever read by Worker code; the ledger trigger is its only writer', () => {
    expect(workerSourceFiles().flatMap(nonReadReferences)).toEqual([]);
  });
});
