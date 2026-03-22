export async function onRequest({ request }: { request: Request }): Promise<Response> {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204 });
  }

  const url = new URL(request.url);
  const target = new URL('https://api.anthropic.com/v1/organizations/usage_report/messages');
  target.search = url.search;

  const headers = new Headers();
  headers.set('Content-Type', 'application/json');

  const apiKey = request.headers.get('x-api-key');
  if (apiKey) headers.set('x-api-key', apiKey);

  const anthropicVersion = request.headers.get('anthropic-version');
  if (anthropicVersion) headers.set('anthropic-version', anthropicVersion);

  const upstream = await fetch(target.toString(), {
    method: request.method,
    headers,
    body: request.method === 'POST' ? await request.text() : undefined,
  });

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: upstream.headers,
  });
}
