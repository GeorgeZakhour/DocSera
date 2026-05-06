// Fanout: takes the persisted notification rows and delivers them.
// In Phase 1 the only channel is Pushy. Email/SMS plug in here later.
//
// Pref/quiet-hour enforcement is intentionally NOT implemented yet —
// rolling that out behind the inbox-first foundation lets us validate
// the new pipeline without changing user-visible delivery in any way.
// Once shadow-mode validation passes, prefs gating moves into this file
// (one place to change, applies to all categories).

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent } from "./types.ts";
import type { PersistedNotification } from "./persist.ts";
import { sendPushyNotification } from "./pushy.ts";

export async function fanoutNotifications(
  supabase: SupabaseClient,
  intent: NotificationIntent,
  persisted: PersistedNotification[],
): Promise<void> {
  const targetUserIds = persisted.length > 0
    ? persisted.map((p) => p.user_id)
    : intent.user_ids;

  if (targetUserIds.length === 0) {
    console.log("No target users for fanout");
    return;
  }

  const { data: devices, error: devicesError } = await supabase
    .from("user_devices")
    .select("token, user_id")
    .in("user_id", targetUserIds)
    .eq("app", intent.recipient_app);

  if (devicesError) {
    console.error("❌ Error fetching devices:", devicesError);
    await markFailed(supabase, persisted, { reason: "devices_fetch_error" });
    return;
  }

  if (!devices || devices.length === 0) {
    console.log("No devices found for targets");
    await markEvents(supabase, persisted, "suppressed", { reason: "no_devices" });
    return;
  }

  const pushyApiKey = Deno.env.get("PUSHY_API_KEY");
  if (!pushyApiKey) {
    console.error("❌ PUSHY_API_KEY not configured");
    await markFailed(supabase, persisted, { reason: "pushy_key_missing" });
    return;
  }

  const tokens = devices.map((d) => d.token);
  const result = await sendPushyNotification(
    pushyApiKey,
    tokens,
    intent.title,
    intent.body,
    intent.deep_link,
  );

  console.log("Pushy Result:", JSON.stringify(result.body));

  if (result.ok) {
    await markEvents(supabase, persisted, "sent_push", {
      pushy_status: result.status,
      device_count: tokens.length,
    });
    if (persisted.length > 0) {
      const ids = persisted.map((p) => p.id);
      await supabase
        .from("notifications")
        .update({ delivered_push_at: new Date().toISOString() })
        .in("id", ids);
    }
  } else {
    await markFailed(supabase, persisted, {
      pushy_status: result.status,
      pushy_body: result.body,
    });
  }
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

async function markFailed(
  supabase: SupabaseClient,
  persisted: PersistedNotification[],
  detail: Record<string, unknown>,
): Promise<void> {
  await markEvents(supabase, persisted, "failed", detail);
}
