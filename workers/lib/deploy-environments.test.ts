/**
 * Deploy-safety invariants for every worker's wrangler.toml (BACKLOG.md CR02).
 *
 * Before this, `deploy` and `deploy:prd` both ran a plain `wrangler deploy`
 * against a single-name config, so a local `npm run deploy` published straight
 * over the worker production uses. The fix is structural — top-level config is
 * production, `[env.dev]` is a separately-named worker — and structural fixes
 * rot silently. These tests fail the build if the separation is undone.
 *
 * The rules encoded here:
 *   1. Every deployable worker has an [env.dev] whose worker name differs from
 *      the production name. A shared name is the original bug.
 *   2. `deploy` targets --env dev; `deploy:prd` stays on the top-level config.
 *      Switching prd to a named environment would rename the production
 *      workers and orphan their DO namespaces, routes, and crons.
 *   3. [env.dev] declares no routes. Wrangler would happily point a production
 *      hostname at a dev deploy.
 *   4. Non-inheritable keys present at the top level are repeated under
 *      [env.dev]. Wrangler does not inherit these into named environments, so
 *      omitting one yields a dev worker silently missing a binding.
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/** Keys wrangler does NOT inherit into a named environment. */
const NON_INHERITABLE = ['durable_objects', 'services', 'vars', 'kv_namespaces', 'r2_buckets', 'd1_databases', 'queues'] as const;

const WORKERS = ['api-gateway', 'sender-worker', 'stripe-webhook', 'contact-form', 'bootstrap-worker', 'receiver-worker'] as const;

const WORKERS_ROOT = join(__dirname, '..');

/**
 * Minimal TOML reader for the subset these configs use: top-level key/values,
 * `[section]` / `[env.dev]` tables, and `[[array.of.tables]]`. Avoids adding a
 * TOML dependency to the shared lib for one test file. Node's own parser is
 * not available, and the configs are hand-written and small.
 */
function parseToml(src: string): Record<string, unknown> {
  const root: Record<string, unknown> = {};
  let cursor: Record<string, unknown> = root;

  const descend = (path: string[], asArrayElement: boolean): Record<string, unknown> => {
    let node: Record<string, unknown> = root;
    path.forEach((key, i) => {
      const last = i === path.length - 1;
      if (last && asArrayElement) {
        const arr = (node[key] ??= []) as Record<string, unknown>[];
        const entry: Record<string, unknown> = {};
        arr.push(entry);
        node = entry;
        return;
      }
      const existing = node[key];
      // A path segment may already be an array of tables ([[a.b]] then [a.b.c]).
      node = Array.isArray(existing)
        ? (existing[existing.length - 1] as Record<string, unknown>)
        : ((node[key] ??= {}) as Record<string, unknown>);
    });
    return node;
  };

  for (const raw of src.split('\n')) {
    const line = raw.replace(/(^|\s)#.*$/, '').trim();
    if (!line) continue;

    const arrayTable = line.match(/^\[\[(.+)\]\]$/);
    if (arrayTable) { cursor = descend(arrayTable[1].split('.'), true); continue; }

    const table = line.match(/^\[(.+)\]$/);
    if (table) { cursor = descend(table[1].split('.'), false); continue; }

    const kv = line.match(/^([\w-]+)\s*=\s*(.+)$/);
    if (kv) {
      const [, key, rawValue] = kv;
      const value = rawValue.trim();
      cursor[key] = value.startsWith('"') ? value.slice(1, -1)
        : value.startsWith('[') ? value
        : value === 'true' ? true
        : value === 'false' ? false
        : value;
    }
  }
  return root;
}

interface WranglerConfig extends Record<string, unknown> {
  name?: string;
  env?: Record<string, Record<string, unknown>>;
}

function loadConfig(worker: string): WranglerConfig {
  return parseToml(readFileSync(join(WORKERS_ROOT, worker, 'wrangler.toml'), 'utf8'));
}

function loadScripts(worker: string): Record<string, string> {
  const pkg = JSON.parse(readFileSync(join(WORKERS_ROOT, worker, 'package.json'), 'utf8'));
  return pkg.scripts ?? {};
}

describe('worker deploy environments (CR02)', () => {
  it.each(WORKERS)('%s: dev deploys to a worker distinct from production', (worker) => {
    const config = loadConfig(worker);
    const dev = config.env?.dev;

    expect(dev, `${worker} has no [env.dev]; npm run deploy would target production`).toBeDefined();
    expect(dev!.name, `${worker} [env.dev] must set an explicit name`).toBeTruthy();
    expect(dev!.name).not.toBe(config.name);
  });

  it.each(WORKERS)('%s: deploy targets --env dev, deploy:prd stays on top-level config', (worker) => {
    const scripts = loadScripts(worker);

    expect(scripts.deploy).toContain('--env dev');
    // deploy:prd must NOT pass --env: a named environment would rename the
    // production worker and orphan its DO namespaces, routes, and crons.
    expect(scripts['deploy:prd']).not.toContain('--env');
  });

  it.each(WORKERS)('%s: [env.dev] declares no routes', (worker) => {
    const dev = loadConfig(worker).env?.dev ?? {};

    expect(dev.routes, `${worker} dev would attach a production hostname`).toBeUndefined();
    expect(dev.route).toBeUndefined();
  });

  it.each(WORKERS)('%s: [env.dev] repeats every non-inheritable top-level binding', (worker) => {
    const config = loadConfig(worker);
    const dev = config.env?.dev ?? {};

    for (const key of NON_INHERITABLE) {
      if (!(key in config)) continue;
      // contact-form deliberately omits kv_namespaces in dev so a dev deploy
      // cannot evict production rate-limit and idempotency keys; the limiter
      // degrades to in-memory. Documented in its wrangler.toml.
      if (worker === 'contact-form' && key === 'kv_namespaces') {
        expect(dev[key], 'contact-form dev must not bind the production KV namespace').toBeUndefined();
        continue;
      }
      expect(dev[key], `${worker} [env.dev] is missing ${key}, which wrangler does not inherit`).toBeDefined();
    }
  });

  it('stripe-webhook dev does not run the dead-letter cron', () => {
    // Two workers draining webhook_dead_letters against one Supabase project
    // would race over production rows every 15 minutes.
    const config = loadConfig('stripe-webhook');

    expect((config.triggers as Record<string, unknown>).crons).toBeTruthy();
    expect((config.env!.dev.triggers as Record<string, unknown>).crons).toBe('[]');
  });
});
