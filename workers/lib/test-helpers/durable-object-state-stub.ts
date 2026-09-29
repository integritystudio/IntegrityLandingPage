/**
 * In-memory Durable Object storage and state for driving a real Durable Object class
 * in tests, as `supabase-fetch-stub.ts` does for the Supabase client. It covers the
 * calls the quota DO makes: `get`, `put`, `delete` and `setAlarm`.
 */
export class MockStorage {
  private store: Map<string, unknown> = new Map();
  scheduledAlarmAt: number | null = null;

  async get<T>(key: string): Promise<T | undefined> {
    return this.store.get(key) as T | undefined;
  }

  async put(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }

  async delete(key: string): Promise<boolean> {
    return this.store.delete(key);
  }

  async setAlarm(timestamp: number): Promise<void> {
    // Cloudflare's setAlarm replaces any alarm already scheduled.
    this.scheduledAlarmAt = timestamp;
  }
}

/** A `DurableObjectState` over `storage`; `blockConcurrencyWhile` runs its callback inline. */
export function stubDurableObjectState(storage: MockStorage): DurableObjectState {
  return {
    storage,
    blockConcurrencyWhile: async <T>(fn: () => Promise<T>) => fn(),
    waitUntil: (_p: Promise<unknown>) => undefined,
  } as unknown as DurableObjectState;
}
