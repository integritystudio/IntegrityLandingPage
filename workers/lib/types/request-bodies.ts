import { z } from 'zod';

// API Key Management
export const CreateApiKeyBodySchema = z.object({
  name: z.string().min(1).max(255).optional(),
  expires_at: z.string().datetime().optional(),
}).strict();

export type CreateApiKeyBody = z.infer<typeof CreateApiKeyBodySchema>;

// Query parameters
export const OrgIdParamSchema = z.object({
  orgId: z.string().uuid('Invalid organization ID format'),
});

export type OrgIdParam = z.infer<typeof OrgIdParamSchema>;

export const ApiKeyIdParamSchema = z.object({
  orgId: z.string().uuid('Invalid organization ID format'),
  keyId: z.string().uuid('Invalid API key ID format'),
});

export type ApiKeyIdParam = z.infer<typeof ApiKeyIdParamSchema>;

// Pagination
export const PaginationParamsSchema = z.object({
  limit: z.coerce.number().int().positive().max(1000).optional().default(50),
  offset: z.coerce.number().int().nonnegative().optional().default(0),
});

export type PaginationParams = z.infer<typeof PaginationParamsSchema>;

// Stripe Event (webhook)
export const StripeEventBodySchema = z.object({
  id: z.string(),
  type: z.string(),
  created: z.number(),
  data: z.object({
    object: z.record(z.unknown()),
    previous_attributes: z.record(z.unknown()).optional(),
  }),
});

export type StripeEventBody = z.infer<typeof StripeEventBodySchema>;
