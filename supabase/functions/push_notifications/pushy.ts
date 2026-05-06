// Pushy HTTP client. The only file that calls api.pushy.me.
// Centralizing it here means future channel additions (email, SMS) plug
// into fanout.ts at the same level — Pushy is just one of many.

export interface PushyResult {
  ok: boolean;
  status: number;
  body: unknown;
}

export async function sendPushyNotification(
  apiKey: string,
  tokens: string[],
  title: string,
  body: string,
  payloadData: string,
  sound: string = "default",
): Promise<PushyResult> {
  const payload = {
    to: tokens,
    data: { title, body, payload: payloadData, sound },
    notification: { title, body, sound },
  };

  const res = await fetch(
    `https://api.pushy.me/push?api_key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    },
  );

  let parsed: unknown = null;
  try {
    parsed = await res.json();
  } catch (_e) {
    parsed = { raw: await res.text() };
  }

  return { ok: res.ok, status: res.status, body: parsed };
}
