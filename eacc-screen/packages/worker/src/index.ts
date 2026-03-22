const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-api-key, Authorization, anthropic-version',
  'Access-Control-Max-Age': '86400',
};

function corsResponse(body: string | null, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  for (const [k, v] of Object.entries(CORS_HEADERS)) {
    headers.set(k, v);
  }
  return new Response(body, { ...init, headers });
}

async function forwardRequest(
  request: Request,
  targetUrl: string,
  headersToCopy: string[],
): Promise<Response> {
  const url = new URL(request.url);
  const target = new URL(targetUrl);
  target.search = url.search;

  const headers = new Headers();
  headers.set('Content-Type', 'application/json');
  for (const h of headersToCopy) {
    const val = request.headers.get(h);
    if (val) headers.set(h, val);
  }

  const upstream = await fetch(target.toString(), {
    method: request.method,
    headers,
    body: request.method === 'POST' ? await request.text() : undefined,
  });

  const responseHeaders = new Headers(upstream.headers);
  for (const [k, v] of Object.entries(CORS_HEADERS)) {
    responseHeaders.set(k, v);
  }

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: responseHeaders,
  });
}

export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return corsResponse(null, { status: 204 });
    }

    if (url.pathname === '/' && request.method === 'GET') {
      return corsResponse(
        JSON.stringify({ status: 'ok', service: 'eacc-proxy' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    if (url.pathname === '/api/anthropic/usage') {
      return forwardRequest(
        request,
        'https://api.anthropic.com/v1/organizations/usage_report/messages',
        ['x-api-key', 'anthropic-version'],
      );
    }

    if (url.pathname === '/api/openai/usage') {
      return forwardRequest(
        request,
        'https://api.openai.com/v1/organization/usage/completions',
        ['Authorization'],
      );
    }

    return corsResponse(
      JSON.stringify({ error: 'Not found' }),
      { status: 404, headers: { 'Content-Type': 'application/json' } },
    );
  },
};
