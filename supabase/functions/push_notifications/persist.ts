// Persists a NotificationIntent into public.notifications, one row per
// recipient. Returns the inserted row IDs (one per user_id). Dedup is
// enforced by the partial UNIQUE index on (user_id, event_code, dedup_key)
// — if a duplicate row would be inserted, ON CONFLICT DO NOTHING swallows
// it and that user_id is omitted from the returned array.
//
// This is what gives the bell icon something to read. Every push that
// goes out also leaves a persistent inbox row.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent } from "./types.ts";

export interface PersistedNotification {
  id: string;
  user_id: string;
}

export async function persistNotifications(
  supabase: SupabaseClient,
  intent: NotificationIntent,
): Promise<PersistedNotification[]> {
  const rows = intent.user_ids.map((user_id) => ({
    user_id,
    recipient_app: intent.recipient_app,
    event_code: intent.event_code,
    category: intent.category,
    locale: intent.locale ?? "ar",
    title: intent.title,
    body: intent.body,
    deep_link: intent.deep_link,
    data: intent.data ?? {},
    importance: intent.importance ?? "default",
    dedup_key: intent.dedup_key ?? null,
  }));

  if (rows.length === 0) return [];

  // ON CONFLICT DO NOTHING handles dedup. We use upsert with ignoreDuplicates
  // so the partial unique index does the work.
  const { data, error } = await supabase
    .from("notifications")
    .upsert(rows, {
      onConflict: "user_id,event_code,dedup_key",
      ignoreDuplicates: true,
    })
    .select("id, user_id");

  if (error) {
    console.error("❌ persistNotifications error:", error);
    return [];
  }

  // Log a 'queued' event for each successful insert.
  if (data && data.length > 0) {
    const events = data.map((row) => ({
      notification_id: row.id,
      event_type: "queued",
      detail: { event_code: intent.event_code, recipient_app: intent.recipient_app },
    }));
    const { error: evtErr } = await supabase
      .from("notification_events")
      .insert(events);
    if (evtErr) {
      console.warn("⚠️  notification_events insert failed:", evtErr.message);
    }
  }

  return (data ?? []) as PersistedNotification[];
}
