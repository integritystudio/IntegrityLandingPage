/**
 * Minimal Supabase REST client for edge workers.
 * Uses native fetch API - no npm dependencies.
 */

import type {
  InsertOptions,
  QueryFilter,
  QueryOptions,
  SupabaseReturning,
  SupabaseRow,
  UpdateOptions,
} from './types/supabase';

export type {
  SupabaseQueryResult,
  SupabaseRow,
  SupabaseRpcResult,
} from './types/supabase';

/** Mirrors DEFAULT_RETURNING in ./types/supabase, declared as a local literal so
 * this module stays type-only against the schemas and does not pull Zod into
 * workers that need nothing but REST calls. */
const REPRESENTATION: SupabaseReturning = 'representation';

type OkResult<T> = { ok: true; data: T };
type ErrResult = { ok: false; error: string };

function serializeFilters(
  url: URL,
  filters: QueryFilter[],
): void {
  for (const { column, operator, value } of filters) {
    let serialized: string;
    if (Array.isArray(value)) {
      serialized = `(${value.join(',')})`;
    } else if (typeof value === 'string') {
      serialized = value;
    } else {
      serialized = JSON.stringify(value);
    }
    url.searchParams.set(column, `${operator}.${serialized}`);
  }
}

async function extractHttpError(response: Response): Promise<ErrResult> {
  const text = await response.text();
  return { ok: false, error: `HTTP ${response.status}: ${text}` };
}

export function createSupabaseClient(
  supabaseUrl: string,
  serviceRoleKey: string,
) {
  const headers = {
    'authorization': `Bearer ${serviceRoleKey}`,
    'apikey': serviceRoleKey,
    'content-type': 'application/json',
  };

  async function query<T extends SupabaseRow = SupabaseRow>(
    table: string,
    options?: QueryOptions,
  ): Promise<OkResult<T[] | T | null> | ErrResult> {
    try {
      const url = new URL(`${supabaseUrl}/rest/v1/${table}`);

      if (options?.select) {
        url.searchParams.set('select', options.select);
      }

      if (options?.filters) {
        serializeFilters(url, options.filters);
      }

      if (options?.order) {
        const direction = options.order.ascending !== false ? 'asc' : 'desc';
        url.searchParams.set('order', `${options.order.column}.${direction}`);
      }

      if (options?.single) {
        url.searchParams.set('limit', '1');
      } else if (options?.limit) {
        url.searchParams.set('limit', options.limit.toString());
      }

      const response = await fetch(url, { method: 'GET', headers });

      if (!response.ok) {
        return extractHttpError(response);
      }

      const data = await response.json();

      if (options?.single) {
        return { ok: true, data: Array.isArray(data) ? (data[0] ?? null) : data };
      }

      return { ok: true, data: Array.isArray(data) ? data : [data] };
    } catch (err) {
      return { ok: false, error: String(err) };
    }
  }

  async function insert<T extends SupabaseRow = SupabaseRow>(
    table: string,
    records: T | T[],
    options?: InsertOptions,
  ): Promise<OkResult<T[] | null> | ErrResult> {
    try {
      const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
      const returning = options?.returning ?? REPRESENTATION;

      const response = await fetch(url, {
        method: 'POST',
        headers: { ...headers, 'prefer': `return=${returning}` },
        body: JSON.stringify(Array.isArray(records) ? records : [records]),
      });

      if (!response.ok) {
        return extractHttpError(response);
      }

      if (returning === REPRESENTATION && response.status === 201) {
        const data = await response.json();
        return { ok: true, data: Array.isArray(data) ? data : [data] };
      }

      return { ok: true, data: null };
    } catch (err) {
      return { ok: false, error: String(err) };
    }
  }

  async function update<T extends SupabaseRow = SupabaseRow>(
    table: string,
    updates: Partial<T>,
    filters: QueryFilter[],
    options?: UpdateOptions,
  ): Promise<OkResult<T[] | null> | ErrResult> {
    try {
      const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
      const returning = options?.returning ?? REPRESENTATION;

      serializeFilters(url, filters);

      const response = await fetch(url, {
        method: 'PATCH',
        headers: { ...headers, 'prefer': `return=${returning}` },
        body: JSON.stringify(updates),
      });

      if (!response.ok) {
        return extractHttpError(response);
      }

      if (returning === REPRESENTATION && response.status === 200) {
        const data = await response.json();
        return { ok: true, data: Array.isArray(data) ? data : [data] };
      }

      return { ok: true, data: null };
    } catch (err) {
      return { ok: false, error: String(err) };
    }
  }

  async function upsert<T extends SupabaseRow = SupabaseRow>(
    table: string,
    records: T | T[],
    conflictColumns: string,
  ): Promise<OkResult<T[] | null> | ErrResult> {
    try {
      const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
      url.searchParams.set('on_conflict', conflictColumns);

      const upsertHeaders = {
        ...headers,
        'prefer': 'resolution=merge-duplicates,return=representation',
      };

      const response = await fetch(url, {
        method: 'POST',
        headers: upsertHeaders,
        body: JSON.stringify(Array.isArray(records) ? records : [records]),
      });

      if (!response.ok) {
        return extractHttpError(response);
      }

      const data = await response.json();
      return { ok: true, data: Array.isArray(data) ? data : [data] };
    } catch (err) {
      return { ok: false, error: String(err) };
    }
  }

  async function rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): Promise<OkResult<unknown> | ErrResult> {
    try {
      const response = await fetch(
        `${supabaseUrl}/rest/v1/rpc/${functionName}`,
        { method: 'POST', headers, body: JSON.stringify(args) },
      );

      if (!response.ok) {
        return extractHttpError(response);
      }

      const data = await response.json();
      return { ok: true, data };
    } catch (err) {
      return { ok: false, error: String(err) };
    }
  }

  return { query, insert, update, upsert, rpc };
}

export type SupabaseClient = ReturnType<typeof createSupabaseClient>;
