export async function onRequest({ request }: { request: Request }): Promise<Response> {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204 });
  }

  const url = new URL(request.url);
  const target = new URL('https://api.openai.com/v1/organization/usage/completions');
  target.search = url.search;

  const headers = new Headers();
  headers.set('Content-Type', 'application/json');

  const auth = request.headers.get('Authorization');
  if (auth) headers.set('Authorization', auth);

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
