// Fanout: takes the persisted notification rows and delivers them.
// Phase 1 channel set: Pushy only. Email/SMS plug in alongside the
// existing tokens fetch + send block.
//
// Per-recipient enforcement order:
//   1. shouldSendPush()  — pref + quiet-hours + DnD gating
//   2. user_devices      — must have a registered device for the app
//   3. user_devices.locale → re-render title/body if intent has both
//      AR + EN variants (handlers may attach a `localized` map; if not,
//      we fall back to intent.title/body as-is)
//   4. Pushy

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent } from "./types.ts";
import type { PersistedNotification } from "./persist.ts";
import { sendPushyNotification } from "./pushy.ts";
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

  // Pushy app keys are per-bundle-id, so the patient app and the Pro
  // app each have their own Pushy app in the pushy.me dashboard with
  // distinct API keys. Pick the right one based on recipient_app.
  // Falls back to PUSHY_API_KEY for `docsera` (backward compat) and
  // requires PUSHY_API_KEY_PRO for `docsera_pro`.
  const pushyApiKey = intent.recipient_app === "docsera_pro"
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

  // Fan out per recipient — one user_id per persisted row, since prefs
  // and locale are per-user. This costs an extra query per recipient but
  // keeps gating logic uncomplicated.
  for (const row of persisted) {
    await fanoutOne(supabase, intent, row, pushyApiKey);
  }
}

async function fanoutOne(
  supabase: SupabaseClient,
  intent: NotificationIntent,
  row: PersistedNotification,
  pushyApiKey: string,
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

  // 4. Send. Notification row id + importance are echoed in the Pushy
  // data dict so the client can post back a delivery confirmation
  // and so the OS notification rendering knows whether to use the TS
  // channel without a separate lookup.
  const result = await sendPushyNotification(
    pushyApiKey,
    tokens,
    title,
    body,
    intent.deep_link,
    "default",
    row.id,
    intent.importance ?? "default",
  );

  console.log(
    `📤 ${intent.event_code} → ${row.user_id} (locale=${deviceLocale}, devices=${tokens.length}, http=${result.status})`,
  );

  if (result.ok) {
    await markEvents(supabase, [row], "sent_push", {
      pushy_status: result.status,
      device_count: tokens.length,
      locale: deviceLocale,
    });
    // NOTE: we used to stamp `delivered_push_at` here, which conflated
    // "Pushy API accepted the request" with "device actually got the
    // push". Those are different things, and a 200 from Pushy doesn't
    // mean the OS notification ever appeared. The column is now
    // stamped only by /functions/notification_received when the client
    // SDK confirms delivery on-device. The `sent_push` event above is
    // the durable record of the API call.
  } else {
    await markEvents(supabase, [row], "failed", {
      pushy_status: result.status,
      pushy_body: result.body,
    });
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
