// FCM HTTP v1 client. The only file that calls fcm.googleapis.com.
// Designed as a drop-in alternative to pushy.ts, controlled by the
// USE_FCM env var (see fanout.ts). When USE_FCM=true, fanout calls
// sendFcmNotification instead of sendPushyNotification.
//
// Both Pushy and FCM coexist in this codebase intentionally — Pushy
// remains a one-flag-flip fallback if FCM ever has trouble.
//
// Auth: OAuth2 bearer token derived from a Google service account JSON,
// provided via the FCM_SERVICE_ACCOUNT_JSON env var (accepts raw JSON
// OR base64-encoded JSON — base64 is recommended to survive shell
// escaping of the newlines in private_key). Access tokens are cached
// for ~59 minutes (Google access tokens live 60 minutes).
//
// Unlike Pushy, FCM v1 is one-token-per-call. We fan out tokens with
// Promise.all so latency stays comparable to a single Pushy batch send.

interface ServiceAccount {
  type: string;
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface FcmResult {
  ok: boolean;
  status: number;
  sent: number;
  failed: number;
  bodies: unknown[];
}

// ---------------------------------------------------------------------------
// Service account loading
// ---------------------------------------------------------------------------

function loadServiceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  try {
    const trimmed = raw.trim();
    const json = trimmed.startsWith("{")
      ? trimmed
      : new TextDecoder().decode(b64decode(trimmed));
    const sa = JSON.parse(json) as ServiceAccount;
    if (!sa.client_email || !sa.private_key || !sa.project_id) {
      console.error("[fcm] service account JSON missing required fields");
      return null;
    }
    return sa;
  } catch (e) {
    console.error("[fcm] failed to parse FCM_SERVICE_ACCOUNT_JSON:", e);
    return null;
  }
}

function b64decode(s: string): Uint8Array {
  const clean = s.replace(/\s+/g, "");
  const bin = atob(clean);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64urlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlEncodeString(s: string): string {
  return b64urlEncode(new TextEncoder().encode(s));
}

// ---------------------------------------------------------------------------
// Access token minting (JWT-bearer flow)
// ---------------------------------------------------------------------------

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 60_000) {
    return cachedToken.token;
  }

  const iat = Math.floor(now / 1000);
  const exp = iat + 3600;
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri || "https://oauth2.googleapis.com/token",
    iat,
    exp,
  };

  const unsigned = `${b64urlEncodeString(JSON.stringify(header))}.${
    b64urlEncodeString(JSON.stringify(claim))
  }`;

  // Import the PKCS#8 private key into a CryptoKey for signing.
  const pkBody = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const pkBytes = b64decode(pkBody);

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pkBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const sigB64 = b64urlEncode(new Uint8Array(sigBuf));
  const jwt = `${unsigned}.${sigB64}`;

  const tokenUri = sa.token_uri || "https://oauth2.googleapis.com/token";
  const res = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!res.ok) {
    const errBody = await res.text().catch(() => "");
    throw new Error(`[fcm] token exchange failed: ${res.status} ${errBody}`);
  }

  const data = await res.json() as {
    access_token?: string;
    expires_in?: number;
  };
  if (!data.access_token) {
    throw new Error("[fcm] token exchange returned no access_token");
  }

  cachedToken = {
    token: data.access_token,
    expiresAt: now + ((data.expires_in ?? 3600) - 60) * 1000,
  };
  return cachedToken.token;
}

// ---------------------------------------------------------------------------
// Send
// ---------------------------------------------------------------------------

export async function sendFcmNotification(
  tokens: string[],
  title: string,
  body: string,
  payloadData: string,
  notificationId?: string,
  importance?: string,
): Promise<FcmResult> {
  if (tokens.length === 0) {
    return { ok: true, status: 200, sent: 0, failed: 0, bodies: [] };
  }

  const sa = loadServiceAccount();
  if (!sa) {
    return {
      ok: false,
      status: 500,
      sent: 0,
      failed: tokens.length,
      bodies: [{ error: "FCM_SERVICE_ACCOUNT_JSON missing or invalid" }],
    };
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
  } catch (e) {
    console.error("[fcm] token mint error:", e);
    return {
      ok: false,
      status: 500,
      sent: 0,
      failed: tokens.length,
      bodies: [{ error: String(e) }],
    };
  }

  // FCM v1 is one-token-per-call. Run in parallel; latency tracks the
  // slowest call, which is comparable to a single Pushy batch send.
  // Data values MUST be strings — coerce any non-string fields.
  const results = await Promise.all(tokens.map(async (token) => {
    const messagePayload = {
      message: {
        token,
        notification: { title, body },
        data: {
          title,
          body,
          payload: payloadData,
          sound: "default",
          ...(notificationId ? { notification_id: notificationId } : {}),
          ...(importance ? { importance } : {}),
        },
      },
    };

    try {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(messagePayload),
        },
      );
      let parsed: unknown = null;
      try {
        parsed = await res.json();
      } catch {
        parsed = { raw: await res.text() };
      }
      return { ok: res.ok, status: res.status, body: parsed };
    } catch (e) {
      return { ok: false, status: 0, body: { error: String(e) } };
    }
  }));

  const sent = results.filter((r) => r.ok).length;
  const failed = results.length - sent;
  const bodies = results.map((r) => r.body);
  const status = failed === 0
    ? 200
    : (sent > 0 ? 207 : (results[0]?.status ?? 500));

  return { ok: failed === 0, status, sent, failed, bodies };
}
