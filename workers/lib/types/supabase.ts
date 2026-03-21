import { z } from 'zod';

/**
 * Supabase REST API Types
 * Minimal REST client for edge workers
 */

export const SupabaseRowSchema = z.record(z.unknown());

export type SupabaseRow = z.infer<typeof SupabaseRowSchema>;

export const SupabaseQueryResultSchema = z.object({
  data: z.union([
    z.array(SupabaseRowSchema),
    SupabaseRowSchema,
    z.null(),
  ]),
  error: z.object({
    message: z.string(),
  }).optional(),
});

export type SupabaseQueryResult = z.infer<typeof SupabaseQueryResultSchema>;

export const SupabaseRpcResultSchema = z.object({
  data: z.unknown(),
  error: z.object({
    message: z.string(),
  }).optional(),
});

export type SupabaseRpcResult = z.infer<typeof SupabaseRpcResultSchema>;

/**
 * Internal query result union (ok/error)
 */
export const SupabaseOkResultSchema = <T extends z.ZodTypeAny>(itemSchema: T) =>
  z.object({
    ok: z.literal(true),
    data: itemSchema,
  });

export const SupabaseErrResultSchema = z.object({
  ok: z.literal(false),
  error: z.string().min(1),
});

/**
 * Filter operators supported by Supabase REST API
 */
export const FilterOperatorSchema = z.enum([
  'eq',      // equal
  'neq',     // not equal
  'gt',      // greater than
  'gte',     // greater than or equal
  'lt',      // less than
  'lte',     // less than or equal
  'like',    // LIKE pattern
  'ilike',   // case-insensitive LIKE
  'is',      // IS NULL / IS NOT NULL
  'in',      // IN (val1, val2, ...)
  'cs',      // contains (for arrays/jsonb)
  'cd',      // contained by (for arrays/jsonb)
  'ov',      // overlaps (for arrays/jsonb)
]);

export type FilterOperator = z.infer<typeof FilterOperatorSchema>;

/**
 * Query filter definition
 */
export const QueryFilterSchema = z.object({
  column: z.string().min(1),
  operator: FilterOperatorSchema,
  value: z.unknown(),
});

export type QueryFilter = z.infer<typeof QueryFilterSchema>;

/**
 * Query options for Supabase REST
 */
export const QueryOptionsSchema = z.object({
  select: z.string().optional(),
  filters: z.array(QueryFilterSchema).optional(),
  order: z.object({
    column: z.string().min(1),
    ascending: z.boolean().optional(),
  }).optional(),
  limit: z.number().int().positive().optional(),
  single: z.boolean().optional(),
});

export type QueryOptions = z.infer<typeof QueryOptionsSchema>;

/**
 * Insert options for Supabase REST
 */
export const InsertOptionsSchema = z.object({
  select: z.string().optional(),
  returning: z.enum(['minimal', 'representation']).optional(),
});

export type InsertOptions = z.infer<typeof InsertOptionsSchema>;

/**
 * Update options for Supabase REST
 */
export const UpdateOptionsSchema = z.object({
  select: z.string().optional(),
  returning: z.enum(['minimal', 'representation']).optional(),
});

export type UpdateOptions = z.infer<typeof UpdateOptionsSchema>;

/**
 * RPC (Remote Procedure Call) options
 */
export const RpcOptionsSchema = z.object({
  params: z.record(z.unknown()).optional(),
});

export type RpcOptions = z.infer<typeof RpcOptionsSchema>;
