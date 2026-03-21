import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createSupabaseAdmin } from './supabase';

const { mockQuery } = vi.hoisted(() => ({ mockQuery: vi.fn() }));

vi.mock('../../lib/supabase', () => ({
  createSupabaseClient: () => ({
    query: mockQuery,
    insert: vi.fn(),
    update: vi.fn(),
    upsert: vi.fn(),
    rpc: vi.fn(),
  }),
}));

describe('fetchPendingDeadLetters', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('DB error → console.error logged, empty array returned', async () => {
    mockQuery.mockResolvedValue({ ok: false, error: 'Connection timeout' });
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    const result = await db.fetchPendingDeadLetters();

    expect(result).toEqual([]);
    expect(consoleSpy).toHaveBeenCalledWith(
      'fetchPendingDeadLetters DB error:',
      'Connection timeout',
    );
    consoleSpy.mockRestore();
  });

  it('non-array data → returns empty array without error', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: null });
    const result = await db.fetchPendingDeadLetters();
    expect(result).toEqual([]);
  });
});

describe('isEventProcessed', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('returns { ok: true, processed: true } when event exists in log', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: { id: 'evt_123' } });
    const result = await db.isEventProcessed('evt_123');
    expect(result).toEqual({ ok: true, processed: true });
  });

  it('returns { ok: true, processed: false } when event not in log', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: null });
    const result = await db.isEventProcessed('evt_456');
    expect(result).toEqual({ ok: true, processed: false });
  });

  it('returns { ok: false, error } on DB query failure', async () => {
    mockQuery.mockResolvedValue({ ok: false, error: 'Connection timeout' });
    const result = await db.isEventProcessed('evt_789');
    expect(result).toEqual({ ok: false, error: 'Connection timeout' });
  });
});
