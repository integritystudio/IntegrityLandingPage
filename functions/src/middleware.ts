import { getRouteMeta } from './route-meta';
import { injectRouteMeta } from './html-injector';
import {
  BASE_URL,
  CACHE_CONTROL_NO_CACHE,
  CONTENT_TYPE_HTML,
  X_ROBOTS_NOINDEX,
} from './constants';

/**
 * Core middleware logic, separated from CF Pages Function for testability.
 *
 * @param request - Incoming request
 * @param response - Upstream response from context.next()
 * @returns Modified or passthrough response
 */
export const handleRequest = async (
  request: Request,
  response: Response,
): Promise<Response> => {
  // Skip non-200 responses (M3)
  if (response.status !== 200) return response;

  // Skip non-HTML responses
  const contentType = response.headers.get('content-type') ?? '';
  if (!contentType.includes(CONTENT_TYPE_HTML)) return response;

  // Extract pathname, ignoring query string and hash (H3)
  const { pathname } = new URL(request.url);

  // Look up route metadata
  const meta = getRouteMeta(pathname);
  if (!meta) return response;

  // Inject meta tags
  const html = await response.text();
  const modified = injectRouteMeta(html, meta, BASE_URL);

  // Build response headers from upstream, adding Cache-Control (H1)
  const headers = new Headers(response.headers);
  headers.set('cache-control', CACHE_CONTROL_NO_CACHE);

  // Set X-Robots-Tag for noindex routes (M2)
  if (meta.noindex) {
    headers.set('x-robots-tag', X_ROBOTS_NOINDEX);
  }

  return new Response(modified, {
    status: response.status,
    headers,
  });
};
