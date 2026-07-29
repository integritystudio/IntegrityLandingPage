// Re-export from shared lib — JWT verification lives in workers/lib/auth.ts
export { parseJwtPayload as parseJwtHeader, verifyJwt as verifySupabaseJwt, supabaseJwtKey } from '../../lib/auth';
export type { JwtPayload, JwtVerificationKey } from '../../lib/auth';
