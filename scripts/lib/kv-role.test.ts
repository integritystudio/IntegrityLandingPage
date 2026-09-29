import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { describe, it, expect } from 'vitest';

// TS35: drives the verdict functions check-env-isolation.sh sources, with made-up
// digests standing in for the AUTH pins, which this public repo does not hold.
const LIB = fileURLToPath(new URL('./kv-role.sh', import.meta.url));
const EMPTY_HASH = 'da39a3ee5e6b4b0d3255bfef95601890afd80709';
const DEV_PIN = 'd'.repeat(40);
const PRD_PIN = 'p'.repeat(40);
const OTHER = 'o'.repeat(40);

/** This config's AUTH pin, then the other config and its pin, as the script passes them. */
const pins = (config: string): [string, string, string] =>
  config === 'prd' ? [PRD_PIN, 'dev', DEV_PIN] : [DEV_PIN, 'prd', PRD_PIN];

/** Runs one function from kv-role.sh; returns its verdict and whether it counts as a failure. */
function verdict(fn: string, ...args: string[]): { text: string; fails: boolean } {
  const run = spawnSync('bash', ['-c', `source "${LIB}"; ${fn} "$@"`, fn, ...args], {
    env: { PATH: process.env.PATH, EMPTY_HASH },
    encoding: 'utf8',
  });
  if (run.status !== 0 && run.status !== 1) throw new Error(`${fn} exited ${run.status}: ${run.stderr}`);
  return { text: run.stdout.trim(), fails: run.status === 1 };
}

describe('kv_auth_verdict', () => {
  it.each([
    ['its own AUTH id', 'prd', PRD_PIN, 'ok (AUTH)', false],
    ['nothing', 'prd', EMPTY_HASH, 'missing', true],
    ["the other config's AUTH id", 'prd', DEV_PIN, "holds dev's AUTH id", true],
    ['some other namespace', 'prd', OTHER, 'NOT the AUTH namespace', true],
  ])('%s in %s', (_case, config, hash, text, fails) => {
    const [ownPin, otherConfig, otherPin] = pins(config);

    expect(verdict('kv_auth_verdict', hash, ownPin, otherConfig, otherPin)).toEqual({ text, fails });
  });
});

describe('kv_dashboard_verdict', () => {
  it.each([
    ['prd', 'KV_NAMESPACE_ID', OTHER, 'ok (not AUTH)', false],
    // The gap TS35 found: each name was compared with its own config's pin only.
    ['prd', 'KV_NAMESPACE_ID', DEV_PIN, "POINTS AT dev's AUTH: the dashboard sync would write into it", true],
    ['prd', 'KV_NAMESPACE_ID', PRD_PIN, 'POINTS AT AUTH: the dashboard sync would write into it', true],
    ['prd', 'CLOUDFLARE_KV_NAMESPACE_ID', PRD_PIN, 'POINTS AT AUTH: the dashboard sync would write into it', true],
    // Absent is reported as such, no longer as "ok (not AUTH)".
    ['prd', 'KV_NAMESPACE_ID', EMPTY_HASH, 'missing (not checked)', false],
    // dev:KV_NAMESPACE_ID is AUTH_DEV on purpose; the exemption covers dev's own AUTH only.
    ['dev', 'KV_NAMESPACE_ID', DEV_PIN, 'KNOWN GAP (UA03): AUTH, so a dashboard sync here writes into it', false],
    ['dev', 'KV_NAMESPACE_ID', PRD_PIN, "POINTS AT prd's AUTH: the dashboard sync would write into it", true],
    ['dev', 'CLOUDFLARE_KV_NAMESPACE_ID', DEV_PIN, 'POINTS AT AUTH: the dashboard sync would write into it', true],
  ])('%s %s holding %s', (config, name, hash, text, fails) => {
    const [ownPin, otherConfig, otherPin] = pins(config);

    expect(verdict('kv_dashboard_verdict', config, name, hash, ownPin, otherConfig, otherPin)).toEqual({ text, fails });
  });
});
