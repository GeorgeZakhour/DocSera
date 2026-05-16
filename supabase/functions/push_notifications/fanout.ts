// Fanout: takes the persisted notification rows and delivers them.
// Channel set: Pushy (legacy) + FCM (new), one-or-the-other per call
// via the USE_FCM env var. Email/SMS would plug in here as additional
// alternatives at the same level.
//
// Per-recipient enforcement order:
//   1. shouldSendPush()  — pref + quiet-hours + DnD gating
//   2. user_devices      — must have a registered device for the app
//   3. user_devices.locale → re-render title/body if intent has both
//      AR + EN variants (handlers may attach a `localized` map; if not,
//      we fall back to intent.title/body as-is)
//   4. Pushy OR FCM (depending on USE_FCM flag)
//
// USE_FCM=true switches the send call to fcm.ts (Firebase Cloud
// Messaging HTTP v1). Unset / "false" / anything else keeps the legacy
// Pushy path. Pushy code stays in the repo as a fallback — flipping
// the flag back to false instantly restores Pushy delivery without a
// code change.

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

  // Provider switch. USE_FCM=true routes through fcm.ts; anything else
  // keeps the legacy Pushy path. Pre-flight provider config checks differ:
  //   - Pushy: per-app API keys (PUSHY_API_KEY / PUSHY_API_KEY_PRO)
  //   - FCM:   one service account JSON for the whole project; the key
  //            check happens inside fcm.ts on first send.
  const useFcm = Deno.env.get("USE_FCM") === "true";

  let pushyApiKey: string | undefined;
  if (!useFcm) {
    // Pushy app keys are per-bundle-id, so the patient app and the Pro
    // app each have their own Pushy app in the pushy.me dashboard with
    // distinct API keys. Pick the right one based on recipient_app.
    // Falls back to PUSHY_API_KEY for `docsera` (backward compat) and
    // requires PUSHY_API_KEY_PRO for `docsera_pro`.
    pushyApiKey = intent.recipient_app === "docsera_pro"
      ? Deno.env.get("PUSHY_API_KEY_PRO")
      : Deno.env.get("PUSHY_API_KEY");
    if (!pushyApiKey) {
      const which = intent.recipient_app === "docsera_pro"
        ? "PUSHY_API_KEY_PRO"
        : "PUSHY_API_KEY";
      console.error(`❌ ${which} not configured for ${intent.recipient_app}`);
      await markEvents(supabase, persisted, "failed", {
        reason: "pushy_key_missing",
        missing_key: which,
      });
      return;
    }
  }

  // Fan out per recipient — one user_id per persisted row, since prefs
  // and locale are per-user. This costs an extra query per recipient but
  // keeps gating logic uncomplicated.
  for (const row of persisted) {
    await fanoutOne(supabase, intent, row, pushyApiKey, useFcm);
  }
}

async function fanoutOne(
  supabase: SupabaseClient,
  intent: NotificationIntent,
  row: PersistedNotification,
  pushyApiKey: string | undefined,
  useFcm: boolean,
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

  // 2. Devices for this user × this app.
  const { data: devices, error: devicesError } = await supabase
    .from("user_devices")
    .select("token, locale, app_version")
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

  // 3. Locale per device — pick title/body for the device's locale.
  // For now intent.localized is optional; if present, use it. Otherwise
  // fall back to intent.title/body. Handlers will start populating
  // `localized` per-locale as we migrate them.
  const tokens = devices.map((d) => d.token);
  const deviceLocale = (devices[0].locale as string | null) ?? intent.locale ?? "ar";
  const { title, body } = pickLocalized(intent, deviceLocale);

  // 4. Send. Notification row id + importance are echoed in the data
  // dict so the client can post back a delivery confirmation and so the
  // OS notification rendering knows whether to use the TS channel
  // without a separate lookup.
  //
  // NOTE on `delivered_push_at`: we used to stamp it here, which
  // conflated "provider API accepted the request" with "device actually
  // got the push". Those are different things, and a 200 from
  // Pushy/FCM doesn't mean the OS notification ever appeared. The
  // column is now stamped only by /functions/notification_received
  // when the client SDK confirms delivery on-device. The `sent_push`
  // event below is the durable record of the API call.
  const providerLabel = useFcm ? "fcm" : "pushy";
  let resultOk: boolean;
  let resultStatus: number;
  let successDetail: Record<string, unknown>;
  let failureDetail: Record<string, unknown>;

  if (useFcm) {
    const fcm = await sendFcmNotification(
      tokens,
      title,
      body,
      intent.deep_link,
      row.id,
      intent.importance ?? "default",
    );
    resultOk = fcm.ok;
    resultStatus = fcm.status;
    successDetail = {
      provider: "fcm",
      fcm_status: fcm.status,
      device_count: tokens.length,
      sent: fcm.sent,
      failed: fcm.failed,
      locale: deviceLocale,
    };
    failureDetail = {
      provider: "fcm",
      fcm_status: fcm.status,
      sent: fcm.sent,
      failed: fcm.failed,
      fcm_bodies: fcm.bodies,
    };
  } else {
    const pushy = await sendPushyNotification(
      pushyApiKey!,
      tokens,
      title,
      body,
      intent.deep_link,
      "default",
      row.id,
      intent.importance ?? "default",
    );
    resultOk = pushy.ok;
    resultStatus = pushy.status;
    successDetail = {
      provider: "pushy",
      pushy_status: pushy.status,
      device_count: tokens.length,
      locale: deviceLocale,
    };
    failureDetail = {
      provider: "pushy",
      pushy_status: pushy.status,
      pushy_body: pushy.body,
    };
  }

  console.log(
    `📤 ${intent.event_code} → ${row.user_id} (provider=${providerLabel}, locale=${deviceLocale}, devices=${tokens.length}, http=${resultStatus})`,
  );

  if (resultOk) {
    await markEvents(supabase, [row], "sent_push", successDetail);
  } else {
    await markEvents(supabase, [row], "failed", failureDetail);
  }
}

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
