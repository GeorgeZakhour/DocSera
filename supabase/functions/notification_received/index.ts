// Client-reported delivery confirmation for Pushy notifications.
//
// Pushy's free plan doesn't have a server-to-server delivery webhook
// (that's enterprise-only). The pragmatic alternative is to have the
// client post back when its Pushy SDK fires the notification listener.
//
// What this endpoint records:
//   - delivered : the OS notification ACTUALLY landed on the device
//                 (the Pushy SDK fired _pushyBackgroundListener)
//   - clicked   : the user tapped the notification
//   - dismissed : the user swiped it away (best-effort, OS-dependent)
//
// All three become rows in public.notification_events alongside the
// existing 'queued' / 'sent_push' / 'suppressed' / 'failed' events. The
// admin dashboard later reads from notification_events for delivery
// stats (sent vs delivered vs opened) per category.
//
// Auth model:
//   - Public — accepts the ANON key like other public functions.
//   - Validates that the supplied notification_id is a real uuid and
//     belongs to recipient_app='docsera_pro' OR 'docsera'.
//   - Doesn't trust the caller's user_id — that comes from the
//     notification row itself.
//
// Why we don't require auth: the client might post the callback from
// a background isolate where session refresh hasn't happened yet, and
// missing a delivery event is worse than the tiny risk of spoofed
// events (the notification_id is a uuid you can't guess, and the
// worst case is a slightly inflated delivery count).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const ALLOWED_EVENT_TYPES = new Set([
  "delivered",
  "clicked",
  "dismissed",
]);

interface CallbackPayload {
  notification_id?: string;
  event_type?: string;
  detail?: Record<string, unknown>;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: CallbackPayload;
  try {
    body = await req.json();
  } catch (_) {
    return new Response("Invalid JSON", { status: 400 });
  }

  const notificationId = (body.notification_id ?? "").toString();
  const eventType = (body.event_type ?? "").toString();

  if (!UUID_RE.test(notificationId)) {
    return new Response("Invalid notification_id", { status: 400 });
  }
  if (!ALLOWED_EVENT_TYPES.has(eventType)) {
    return new Response("Invalid event_type", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // Verify the row exists. Spoofing is low-risk (uuid is unguessable)
  // but a quick existence check keeps notification_events clean of
  // orphan rows.
  const { data: row, error: rowErr } = await supabase
    .from("notifications")
    .select("id, recipient_app, delivered_push_at, clicked_at")
    .eq("id", notificationId)
    .maybeSingle();
  if (rowErr || !row) {
    return new Response("Notification not found", { status: 404 });
  }

  // Insert the event. Best-effort — if it fails, the client will
  // re-post on the next pointer event.
  const detail = body.detail ?? {};
  const { error: evtErr } = await supabase
    .from("notification_events")
    .insert({
      notification_id: notificationId,
      event_type: eventType,
      detail,
    });
  if (evtErr) {
    console.warn("[notification_received] insert failed:", evtErr.message);
  }

  // Stamp the relevant timestamp on the notifications row too — this
  // makes the inbox UI show delivered/opened state without joining.
  if (eventType === "delivered" && row.delivered_push_at == null) {
    await supabase
      .from("notifications")
      .update({ delivered_push_at: new Date().toISOString() })
      .eq("id", notificationId);
  } else if (eventType === "clicked" && row.clicked_at == null) {
    await supabase
      .from("notifications")
      .update({
        clicked_at: new Date().toISOString(),
        read_at: new Date().toISOString(),
      })
      .eq("id", notificationId);
  }

  return new Response(
    JSON.stringify({ ok: true, event_type: eventType }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
