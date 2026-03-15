import { handleRequest } from './src/middleware';

/**
 * CF Pages Function middleware for per-route SEO meta tag injection.
 *
 * Auto-discovered by CF Pages from `functions/_middleware.ts`.
 * Runs on all requests; static assets (JS, WASM, images) are skipped by
 * CF Pages before reaching Functions, so this only processes HTML responses.
 */
export const onRequest: PagesFunction = async (context) => {
  const response = await context.next();
  return handleRequest(context.request, response);
};
