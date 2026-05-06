// Push notifications dispatcher.
//
// Receives DB webhook payloads from Supabase, routes to a per-table handler,
// persists a row in public.notifications (which feeds the in-app inbox + bell),
// then fans out to Pushy. The previous monolithic version of this file lived
// in this same path; the new layered structure is:
//
//   index.ts          ← serve() + dispatcher (this file)
//   types.ts          ← shared interfaces
//   decrypt.ts        ← AES helper for ENC: messages
//   pushy.ts          ← only file that calls api.pushy.me
//   persist.ts        ← INSERT into notifications + queued event
//   fanout.ts         ← devices fetch → Pushy → events log
//   handlers/
//     messages.ts
//     appointments.ts
//     documents.ts
//     todo_tasks.ts
//     gifts.ts
//
// Behavior preserved from the previous version: same recipients, same copy,
// same deep links. New behavior: every push also writes an inbox row, and
// dedup keys collapse flapping events.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

import type { WebhookPayload } from "./types.ts";
import { handleMessages } from "./handlers/messages.ts";
import { handleAppointments } from "./handlers/appointments.ts";
import { handleDocuments } from "./handlers/documents.ts";
import { handleGifts } from "./handlers/gifts.ts";
import { handleTodoTasks } from "./handlers/todo_tasks.ts";
import { persistNotifications } from "./persist.ts";
import { fanoutNotifications } from "./fanout.ts";

console.log("Push Notification Function Initialized");

serve(async (req) => {
  try {
    const payload = await req.json() as WebhookPayload;

    console.log(
      `🔔 Webhook received! Type: ${payload.type}, Table: ${payload.table}, Schema: ${payload.schema}`,
    );

    if (!payload.record) {
      return new Response("No record found", { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Route to per-table handler.
    let intent = null;
    switch (payload.table) {
      case "messages":
        intent = await handleMessages(supabase, payload);
        break;
      case "appointments":
        intent = handleAppointments(payload);
        break;
      case "documents":
        intent = handleDocuments(payload);
        break;
      case "patient_gift_sends":
        intent = await handleGifts(supabase, payload);
        break;
      case "todo_tasks":
        intent = await handleTodoTasks(supabase, payload);
        break;
      default:
        return new Response(
          `Table ${payload.table} not handled`,
          { status: 200 },
        );
    }

    if (!intent) {
      return new Response("No notification produced", { status: 200 });
    }

    if (intent.user_ids.length === 0) {
      return new Response("No target users", { status: 200 });
    }

    // 1) Persist (idempotent — duplicates collapse via partial unique index).
    const persisted = await persistNotifications(supabase, intent);

    // 2) Fanout via Pushy. Even if persist returned 0 rows (all deduped),
    // we still respect the original intent for shadow-mode comparability,
    // but in steady state we'd skip fanout when nothing was inserted.
    // For now: skip Pushy if everything deduped — that's the desired
    // dedup behavior end-to-end.
    if (persisted.length > 0) {
      await fanoutNotifications(supabase, intent, persisted);
    } else {
      console.log("All recipients deduped — skipping Pushy fanout");
    }

    return new Response(
      JSON.stringify({
        ok: true,
        event_code: intent.event_code,
        persisted: persisted.length,
        users: intent.user_ids.length,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    console.error("Error processing request:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      {
        headers: { "Content-Type": "application/json" },
        status: 400,
      },
    );
  }
});
