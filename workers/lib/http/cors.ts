export type CorsOptions = {
  origin?: string;
  methods?: string[];
  headers?: string[];
  credentials?: boolean;
  maxAge?: number;
};

export function corsHeaders(options: CorsOptions = {}): Headers {
  const {
    origin = '*',
    methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    headers = ['content-type', 'authorization'],
    credentials = false,
    maxAge = 86400,
  } = options;

  if (credentials && origin === '*') {
    throw new Error('CORS: credentials: true requires a specific origin, not "*"');
  }

  const result = new Headers();
  result.set('access-control-allow-origin', origin);
  result.set('access-control-allow-methods', methods.join(', '));
  result.set('access-control-allow-headers', headers.join(', '));
  result.set('access-control-max-age', String(maxAge));
  if (credentials) result.set('access-control-allow-credentials', 'true');
  return result;
}

export function withCors(response: Response, options: CorsOptions = {}): Response {
  const headers = new Headers(response.headers);
  const cors = corsHeaders(options);
  cors.forEach((value, key) => headers.set(key, value));
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

export function handleOptions(request: Request, options: CorsOptions = {}): Response | null {
  if (request.method !== 'OPTIONS') return null;
  return new Response(null, { status: 204, headers: corsHeaders(options) });
}
