import { describe, it, expect } from 'vitest';
import {
  SupabaseRowSchema,
  SupabaseQueryResultSchema,
  SupabaseRpcResultSchema,
  SupabaseOkResultSchema,
  SupabaseErrResultSchema,
  FilterOperatorSchema,
  QueryFilterSchema,
  QueryOptionsSchema,
  InsertOptionsSchema,
  UpdateOptionsSchema,
  RpcOptionsSchema,
} from './supabase';
import { z } from 'zod';

describe('SupabaseRowSchema', () => {
  it('accepts an arbitrary record', () => {
    expect(SupabaseRowSchema.safeParse({ id: 1, name: 'Alice', active: true }).success).toBe(true);
  });

  it('accepts empty record', () => {
    expect(SupabaseRowSchema.safeParse({}).success).toBe(true);
  });
});

describe('SupabaseQueryResultSchema', () => {
  it('accepts data as an array', () => {
    expect(SupabaseQueryResultSchema.safeParse({ data: [{ id: 1 }] }).success).toBe(true);
  });

  it('accepts data as a single row', () => {
    expect(SupabaseQueryResultSchema.safeParse({ data: { id: 1 } }).success).toBe(true);
  });

  it('accepts data as null', () => {
    expect(SupabaseQueryResultSchema.safeParse({ data: null }).success).toBe(true);
  });

  it('accepts result with error', () => {
    expect(SupabaseQueryResultSchema.safeParse({
      data: null,
      error: { message: 'Not found' },
    }).success).toBe(true);
  });

  it('rejects error without message', () => {
    expect(SupabaseQueryResultSchema.safeParse({ data: null, error: {} }).success).toBe(false);
  });
});

describe('SupabaseRpcResultSchema', () => {
  it('accepts any data value', () => {
    expect(SupabaseRpcResultSchema.safeParse({ data: 42 }).success).toBe(true);
  });

  it('accepts null data', () => {
    expect(SupabaseRpcResultSchema.safeParse({ data: null }).success).toBe(true);
  });

  it('accepts complex data', () => {
    expect(SupabaseRpcResultSchema.safeParse({ data: { key: 'val', nested: [1, 2] } }).success).toBe(true);
  });

  it('accepts result with error', () => {
    expect(SupabaseRpcResultSchema.safeParse({
      data: null,
      error: { message: 'RPC failed' },
    }).success).toBe(true);
  });
});

describe('SupabaseOkResultSchema', () => {
  const ItemSchema = z.object({ id: z.string().uuid() });
  const OkSchema = SupabaseOkResultSchema(ItemSchema);

  it('accepts a valid ok result', () => {
    expect(OkSchema.safeParse({ ok: true, data: { id: '550e8400-e29b-41d4-a716-446655440001' } }).success).toBe(true);
  });

  it('rejects ok: false', () => {
    expect(OkSchema.safeParse({ ok: false, data: { id: '550e8400-e29b-41d4-a716-446655440001' } }).success).toBe(false);
  });

  it('rejects invalid data shape', () => {
    expect(OkSchema.safeParse({ ok: true, data: { id: 'not-uuid' } }).success).toBe(false);
  });
});

describe('SupabaseErrResultSchema', () => {
  it('accepts valid error result', () => {
    expect(SupabaseErrResultSchema.safeParse({ ok: false, error: 'Not found' }).success).toBe(true);
  });

  it('rejects ok: true', () => {
    expect(SupabaseErrResultSchema.safeParse({ ok: true, error: 'Something' }).success).toBe(false);
  });

  it('rejects empty error string', () => {
    expect(SupabaseErrResultSchema.safeParse({ ok: false, error: '' }).success).toBe(false);
  });
});

describe('FilterOperatorSchema', () => {
  const validOps = ['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'like', 'ilike', 'is', 'in', 'cs', 'cd', 'ov'];

  it('accepts all valid operators', () => {
    for (const op of validOps) {
      expect(FilterOperatorSchema.safeParse(op).success).toBe(true);
    }
  });

  it('rejects unknown operator', () => {
    expect(FilterOperatorSchema.safeParse('contains').success).toBe(false);
  });
});

describe('QueryFilterSchema', () => {
  it('accepts a valid filter', () => {
    expect(QueryFilterSchema.safeParse({ column: 'status', operator: 'eq', value: 'active' }).success).toBe(true);
  });

  it('rejects empty column', () => {
    expect(QueryFilterSchema.safeParse({ column: '', operator: 'eq', value: 'active' }).success).toBe(false);
  });

  it('rejects invalid operator', () => {
    expect(QueryFilterSchema.safeParse({ column: 'status', operator: 'between', value: 'active' }).success).toBe(false);
  });

  it('accepts null value', () => {
    expect(QueryFilterSchema.safeParse({ column: 'deleted_at', operator: 'is', value: null }).success).toBe(true);
  });
});

describe('QueryOptionsSchema', () => {
  it('accepts empty options', () => {
    expect(QueryOptionsSchema.safeParse({}).success).toBe(true);
  });

  it('accepts full options', () => {
    expect(QueryOptionsSchema.safeParse({
      select: 'id,name',
      filters: [{ column: 'status', operator: 'eq', value: 'active' }],
      order: { column: 'created_at', ascending: false },
      limit: 10,
      single: true,
    }).success).toBe(true);
  });

  it('rejects negative limit', () => {
    expect(QueryOptionsSchema.safeParse({ limit: 0 }).success).toBe(false);
  });

  it('rejects empty order column', () => {
    expect(QueryOptionsSchema.safeParse({ order: { column: '' } }).success).toBe(false);
  });
});

describe('InsertOptionsSchema', () => {
  it('accepts empty options', () => {
    expect(InsertOptionsSchema.safeParse({}).success).toBe(true);
  });

  it('accepts representation returning', () => {
    expect(InsertOptionsSchema.safeParse({ returning: 'representation', select: 'id' }).success).toBe(true);
  });

  it('accepts minimal returning', () => {
    expect(InsertOptionsSchema.safeParse({ returning: 'minimal' }).success).toBe(true);
  });

  it('rejects unknown returning value', () => {
    expect(InsertOptionsSchema.safeParse({ returning: 'all' }).success).toBe(false);
  });
});

describe('UpdateOptionsSchema', () => {
  it('accepts empty options', () => {
    expect(UpdateOptionsSchema.safeParse({}).success).toBe(true);
  });

  it('accepts returning and select', () => {
    expect(UpdateOptionsSchema.safeParse({ returning: 'representation', select: 'id,name' }).success).toBe(true);
  });

  it('rejects invalid returning', () => {
    expect(UpdateOptionsSchema.safeParse({ returning: 'nothing' }).success).toBe(false);
  });
});

describe('RpcOptionsSchema', () => {
  it('accepts empty options', () => {
    expect(RpcOptionsSchema.safeParse({}).success).toBe(true);
  });

  it('accepts params record', () => {
    expect(RpcOptionsSchema.safeParse({ params: { org_id: 'abc', limit: 10 } }).success).toBe(true);
  });
});
