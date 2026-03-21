// Re-export from shared lib — JWT verification lives in workers/lib/auth.ts
export { parseJwtPayload as parseJwtHeader, verifyJwt as verifySupabaseJwt } from '../../lib/auth';
export type { JwtPayload } from '../../lib/auth';
