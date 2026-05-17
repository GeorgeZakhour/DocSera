// Fanout: takes the persisted notification rows and delivers them.
//
// Per-device routing: each user_devices row carries a 'provider' column
// ('pushy' or 'fcm') set by the client at registration time. Fanout
// splits the device list per recipient by provider and sends each group
// through the corresponding API:
//   provider='pushy' → api.pushy.me
//   provider='fcm'   → fcm.googleapis.com
//
// A user can have devices on both providers simultaneously (e.g. an
// FCM-registered phone + a Pushy-registered Huawei tablet). Both
// providers are called in parallel, and the per-device event log
// captures per-provider outcomes independently.
//
// Per-recipient enforcement order:
//   1. shouldSendPush()  — pref + quiet-hours + DnD gating
//   2. user_devices      — must have a registered device for the app
//   3. user_devices.locale → re-render title/body if intent has both
//      AR + EN variants (handlers may attach a `localized` map; if not,
//      we fall back to intent.title/body as-is)
//   4. Split by provider → call each one
//
// Pre-flight provider checks happen lazily inside each sender:
//   - Pushy: per-app API keys (PUSHY_API_KEY for patient,
//            PUSHY_API_KEY_PRO for Pro) — looked up inside sendViaPushy
//   - FCM:   one service account JSON for the whole project — looked
//            up inside fcm.ts on first send (with token caching)

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent } from "./types.ts";
import type { PersistedNotification } from "./persist.ts";
import { sendPushyNotification } from "./pushy.ts";
import { sendFcmNotification } from "./fcm.ts";
import { shouldSendPush } from "./prefs.ts";

export async function fanoutNotifications(
  supabase: SupabaseClient,
  intent: NotificationIntent,
  persisted: PersistedNotification[],
): Promise<void> {
  if (persisted.length === 0) {
    console.log("No persisted rows for fanout");
    return;
  }

  // Fan out per recipient — one user_id per persisted row, since prefs
  // and locale are per-user. This costs an extra query per recipient but
  // keeps gating logic uncomplicated.
  for (const row of persisted) {
    await fanoutOne(supabase, intent, row);
  }
}

async function fanoutOne(
  supabase: SupabaseClient,
  intent: NotificationIntent,
  row: PersistedNotification,
): Promise<void> {
  // 1. Prefs gate.
  const decision = await shouldSendPush(
    supabase,
    row.user_id,
    intent.category,
    intent.importance ?? "default",
  );
  if (!decision.allowPush) {
    console.log(
      `⤵️ ${intent.event_code} suppressed for ${row.user_id} (${decision.reason})`,
    );
    await markEvents(supabase, [row], "suppressed", {
      reason: decision.reason,
    });
    return;
  }

  // 2. Devices for this user × this app. Now includes 'provider' so we
  // can split per-provider below.
  const { data: devices, error: devicesError } = await supabase
    .from("user_devices")
    .select("token, provider, locale, app_version")
    .eq("user_id", row.user_id)
    .eq("app", intent.recipient_app);

  if (devicesError) {
    console.error("❌ Error fetching devices:", devicesError);
    await markEvents(supabase, [row], "failed", {
      reason: "devices_fetch_error",
    });
    return;
  }
  if (!devices || devices.length === 0) {
    await markEvents(supabase, [row], "suppressed", {
      reason: "no_devices",
    });
    return;
  }

  // 3. Locale — pick the first device's locale as the representative.
  // Handlers don't yet support per-device locale rendering (would
  // require separate send calls per locale group). Multi-locale-per-user
  // is an edge case; first-device-wins is acceptable.
  const deviceLocale = (devices[0].locale as string | null) ?? intent.locale ?? "ar";
  const { title, body } = pickLocalized(intent, deviceLocale);

  // 4. Split devices by provider.
  const fcmTokens = devices
    .filter((d) => d.provider === "fcm")
    .map((d) => d.token as string);
  const pushyTokens = devices
    .filter((d) => d.provider === "pushy")
    .map((d) => d.token as string);

  // 5. Send via each provider in parallel. Each branch handles its own
  // pre-flight checks and reports independent results. Promise.all
  // settles when both have completed (or errored).
  const [fcmResult, pushyResult] = await Promise.all([
    fcmTokens.length > 0
      ? sendViaFcm(fcmTokens, title, body, intent, row)
      : Promise.resolve(null),
    pushyTokens.length > 0
      ? sendViaPushy(pushyTokens, title, body, intent, row)
      : Promise.resolve(null),
  ]);

  // 6. Log one line per provider used. Keeps the existing log format
  // so existing log-scraping (if any) stays compatible.
  if (fcmResult) {
    console.log(
      `📤 ${intent.event_code} → ${row.user_id} (provider=fcm, locale=${deviceLocale}, devices=${fcmTokens.length}, http=${fcmResult.status})`,
    );
  }
  if (pushyResult) {
    console.log(
      `📤 ${intent.event_code} → ${row.user_id} (provider=pushy, locale=${deviceLocale}, devices=${pushyTokens.length}, http=${pushyResult.status})`,
    );
  }

  // 7. Write one notification_events row per provider used. Each
  // provider's success/failure is tracked independently, so analytics
  // can see e.g. "FCM delivery rate" vs "Pushy delivery rate". For a
  // user on both providers, this produces 2 rows per notification;
  // existing event consumers already tolerate multiple events per
  // notification (delivered_push, clicked, etc. are separate too).
  if (fcmResult) {
    await markEvents(
      supabase,
      [row],
      fcmResult.ok ? "sent_push" : "failed",
      {
        provider: "fcm",
        fcm_status: fcmResult.status,
        device_count: fcmTokens.length,
        sent: fcmResult.sent,
        failed: fcmResult.failed,
        locale: deviceLocale,
        ...(fcmResult.ok ? {} : { fcm_bodies: fcmResult.bodies }),
      },
    );
  }
  if (pushyResult) {
    await markEvents(
      supabase,
      [row],
      pushyResult.ok ? "sent_push" : "failed",
      {
        provider: "pushy",
        pushy_status: pushyResult.status,
        device_count: pushyTokens.length,
        locale: deviceLocale,
        ...(pushyResult.ok ? {} : { pushy_body: pushyResult.body }),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Per-provider senders
// ---------------------------------------------------------------------------

interface FcmDispatchResult {
  ok: boolean;
  status: number;
  sent: number;
  failed: number;
  bodies: unknown[];
}

async function sendViaFcm(
  tokens: string[],
  title: string,
  body: string,
  intent: NotificationIntent,
  row: PersistedNotification,
): Promise<FcmDispatchResult> {
  return await sendFcmNotification(
    tokens,
    title,
    body,
    intent.deep_link,
    row.id,
    intent.importance ?? "default",
  );
}

interface PushyDispatchResult {
  ok: boolean;
  status: number;
  body: unknown;
}

async function sendViaPushy(
  tokens: string[],
  title: string,
  body: string,
  intent: NotificationIntent,
  row: PersistedNotification,
): Promise<PushyDispatchResult> {
  // Pushy app keys are per-bundle-id: the patient app and the Pro app
  // each have their own Pushy app in the pushy.me dashboard with
  // distinct API keys. Pick the right one based on recipient_app.
  const apiKey = intent.recipient_app === "docsera_pro"
    ? Deno.env.get("PUSHY_API_KEY_PRO")
    : Deno.env.get("PUSHY_API_KEY");
  if (!apiKey) {
    const which = intent.recipient_app === "docsera_pro"
      ? "PUSHY_API_KEY_PRO"
      : "PUSHY_API_KEY";
    console.error(`❌ ${which} not configured for ${intent.recipient_app}`);
    return {
      ok: false,
      status: 500,
      body: { error: `${which.toLowerCase()}_missing` },
    };
  }
  return await sendPushyNotification(
    apiKey,
    tokens,
    title,
    body,
    intent.deep_link,
    "default",
    row.id,
    intent.importance ?? "default",
  );
}

// ---------------------------------------------------------------------------
// Helpers (unchanged from previous version)
// ---------------------------------------------------------------------------

interface LocalizedCopy {
  title: string;
  body: string;
}

function pickLocalized(
  intent: NotificationIntent,
  locale: string,
): LocalizedCopy {
  const localized = (intent as unknown as {
    localized?: Record<string, LocalizedCopy>;
  }).localized;
  if (localized && localized[locale]) return localized[locale];
  if (localized && localized["ar"]) return localized["ar"];
  return { title: intent.title, body: intent.body };
}

async function markEvents(
  supabase: SupabaseClient,
  persisted: PersistedNotification[],
  event_type: string,
  detail: Record<string, unknown>,
): Promise<void> {
  if (persisted.length === 0) return;
  const events = persisted.map((p) => ({
    notification_id: p.id,
    event_type,
    detail,
  }));
  const { error } = await supabase.from("notification_events").insert(events);
  if (error) console.warn("⚠️  notification_events mark failed:", error.message);
}
