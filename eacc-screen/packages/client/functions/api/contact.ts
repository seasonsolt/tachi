type Env = {
  RESEND_API_KEY?: string;
  CONTACT_TO?: string;
  CONTACT_FROM?: string;
};

type ContactPayload = {
  email?: string;
  message?: string;
  context?: Record<string, unknown>;
};

function json(data: unknown, init?: ResponseInit) {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });
}

function isEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

export async function onRequestPost({ request, env }: { request: Request; env: Env }): Promise<Response> {
  let payload: ContactPayload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: 'Invalid payload.' }, { status: 400 });
  }

  const email = String(payload.email ?? '').trim();
  const message = String(payload.message ?? '').trim();

  if (!isEmail(email)) {
    return json({ error: 'A valid email is required.' }, { status: 400 });
  }

  if (!env.RESEND_API_KEY) {
    return json({ error: 'Email service is not configured. Set RESEND_API_KEY in Cloudflare Pages.' }, { status: 503 });
  }

  const to = env.CONTACT_TO || 'contact@e-acc.ai';
  const from = env.CONTACT_FROM || 'EACC <onboarding@resend.dev>';
  const context = payload.context ? JSON.stringify(payload.context, null, 2) : '{}';

  const resendResponse = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to,
      reply_to: email,
      subject: 'EACC early access request',
      text: [
        `Email: ${email}`,
        '',
        'Message:',
        message || '(none)',
        '',
        'Local altar context:',
        context,
      ].join('\n'),
    }),
  });

  const result = await resendResponse.json().catch(() => ({}));
  if (!resendResponse.ok) {
    return json({ error: result?.message || 'Email delivery failed.' }, { status: 502 });
  }

  return json({ ok: true, id: result?.id ?? null });
}

export async function onRequestOptions(): Promise<Response> {
  return new Response(null, { status: 204 });
}
