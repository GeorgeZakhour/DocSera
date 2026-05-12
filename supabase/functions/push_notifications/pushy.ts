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
  // Our notification row id — echoed back to the client in the
  // Pushy data dict so the client can POST a delivery confirmation
  // to /functions/v1/notification_received with this id. Without
  // this we have no way to correlate a Pushy delivery to one of
  // our rows. Optional for backward compat.
  notificationId?: string,
  importance?: string,
): Promise<PushyResult> {
  const payload = {
    to: tokens,
    data: {
      title,
      body,
      payload: payloadData,
      sound,
      // Custom fields the Pro/patient client reads from the push:
      ...(notificationId ? { notification_id: notificationId } : {}),
      ...(importance ? { importance } : {}),
    },
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
