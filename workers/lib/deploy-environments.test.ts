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
 *   3. [env.dev] sets `routes = []` EXPLICITLY when production declares routes.
 *      `routes` is inheritable: omitting it inherits the production routes and
 *      binds them to the dev worker. On 2026-07-27 that put a secret-less
 *      api-gateway-dev on api.integritystudio.ai/v1/* for ~14 hours, while an
 *      earlier version of rule 3 — asserting `routes` was absent — passed.
 *   4. Non-inheritable keys present at the top level are repeated under
 *      [env.dev]. Wrangler does not inherit these into named environments, so
 *      omitting one yields a dev worker silently missing a binding.
 *   5. Workers holding secrets set `preview_urls = false`. Otherwise every
 *      retained version stays publicly callable with the current secrets bound.
 *
 * Rules 3 and 4 point in opposite directions, which is what makes the mistake
 * easy: repeat bindings, but explicitly empty routes and triggers.
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

  it.each(WORKERS)('%s: [env.dev] disclaims routes EXPLICITLY when production has them', (worker) => {
    // `routes` is an INHERITABLE key. A named environment that omits it inherits
    // the top-level routes and binds them to the dev Worker. On 2026-07-27 this
    // handed `api.integritystudio.ai/v1/*` to the secret-less `api-gateway-dev`
    // for ~14 hours. An earlier version of this test asserted `routes` was
    // *absent* and passed the whole time — absence is the bug, not the fix.
    // Only an explicit empty list detaches a named environment from production
    // routes, so that is what this asserts.
    const config = loadConfig(worker);
    const dev = config.env?.dev ?? {};
    const prodHasRoutes = Boolean(config.routes || config.route);

    if (prodHasRoutes) {
      expect(dev.routes, `${worker} [env.dev] omits routes, so it INHERITS the production route`).toBe('[]');
    }
    // A dev environment must never name a route of its own either way.
    expect(dev.route).toBeUndefined();
    if (dev.routes !== undefined) expect(dev.routes).toBe('[]');
  });

  // Workers that hold secrets in production. Preview URLs publish every retained
  // version at a public URL with the CURRENT secrets bound, so superseded code
  // stays callable — verified 2026-07-27, when a 2026-04-20 sender-worker version
  // answered 200 with all 13 secrets. See BACKLOG.md CR14.
  const SECRET_BEARING = ['sender-worker', 'contact-form'] as const;

  it.each(SECRET_BEARING)('%s: disables per-version preview URLs', (worker) => {
    const config = loadConfig(worker);

    expect(config.preview_urls, `${worker} binds secrets; preview URLs would keep superseded versions callable with them`).toBe(false);
  });

  it('inheritable-key trap is documented where it bites', () => {
    // The two rules pull in opposite directions — bindings must be repeated,
    // routes and triggers must be explicitly emptied — so the reasoning lives
    // next to the config rather than only in a commit message.
    const gateway = readFileSync(join(WORKERS_ROOT, 'api-gateway', 'wrangler.toml'), 'utf8');
    expect(gateway).toMatch(/INHERITABLE/);
  });

  it.each(WORKERS)('%s: [env.dev] repeats every non-inheritable top-level binding', (worker) => {
    const config = loadConfig(worker);
    const dev = config.env?.dev ?? {};

    for (const key of NON_INHERITABLE) {
      if (!(key in config)) continue;
      expect(dev[key], `${worker} [env.dev] is missing ${key}, which wrangler does not inherit`).toBeDefined();
    }
  });

  it.each(WORKERS)('%s: dev never shares a KV namespace with production', (worker) => {
    // Sharing one would let a dev deploy evict live rate-limit and idempotency
    // keys. Each worker that binds KV has a dedicated dev namespace.
    const config = loadConfig(worker);
    const prodNamespaces = (config.kv_namespaces ?? []) as Record<string, string>[];
    const devNamespaces = (config.env?.dev?.kv_namespaces ?? []) as Record<string, string>[];
    if (!prodNamespaces.length || !devNamespaces.length) return;

    const prodIds = new Set(prodNamespaces.map((n) => n.id));
    for (const namespace of devNamespaces) {
      expect(prodIds.has(namespace.id), `${worker} dev binds ${namespace.binding} to the production namespace ${namespace.id}`).toBe(false);
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
