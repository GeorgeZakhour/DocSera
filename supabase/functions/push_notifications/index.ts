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

import type { NotificationIntent, WebhookPayload } from "./types.ts";
import { handleMessages } from "./handlers/messages.ts";
import { handleAppointments } from "./handlers/appointments.ts";
import { handleProAppointments } from "./handlers/pro_appointments.ts";
import { handleProTeam } from "./handlers/pro_team.ts";
import { handleProVerifications } from "./handlers/pro_verifications.ts";
import { handleProSubscriptions } from "./handlers/pro_subscriptions.ts";
import { handleDocuments } from "./handlers/documents.ts";
import { handleDocumentsDeletion } from "./handlers/documents_deletion.ts";
import { handleConversations } from "./handlers/conversations.ts";
import { handleDoctorVacations } from "./handlers/doctor_vacations.ts";
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

    // For INSERT/UPDATE webhooks the row of interest is in `record`. For
    // DELETE webhooks Supabase puts it in `old_record` and `record` is
    // null. Accept either.
    if (!payload.record && !payload.old_record) {
      return new Response("No record found", { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // EMIT router: SQL-side fn_emit_notification already inserted the row
    // and pinged us. We just need to fan out via Pushy. The record carries
    // {id} only — we read the rest from the notifications table.
    if (payload.type === "EMIT" || payload.table === "_emit") {
      const id = payload.record?.id as string | undefined;
      if (!id) {
        return new Response("EMIT missing id", { status: 400 });
      }
      const { data: row, error } = await supabase
        .from("notifications")
        .select(
          "id, user_id, recipient_app, event_code, category, title, body, deep_link, data, importance, dedup_key, locale",
        )
        .eq("id", id)
        .maybeSingle();
      if (error || !row) {
        return new Response("EMIT row not found", { status: 200 });
      }
      const intent: NotificationIntent = {
        user_ids: [row.user_id],
        recipient_app: row.recipient_app,
        event_code: row.event_code,
        category: row.category,
        title: row.title,
        body: row.body,
        deep_link: row.deep_link ?? "",
        data: (row.data as Record<string, unknown>) ?? {},
        importance: row.importance ?? "default",
        dedup_key: row.dedup_key,
        locale: (row.locale as "ar" | "en") ?? "ar",
      };
      await fanoutNotifications(supabase, intent, [
        { id: row.id, user_id: row.user_id },
      ]);
      return new Response(
        JSON.stringify({ ok: true, event_code: row.event_code, source: "emit" }),
        { headers: { "Content-Type": "application/json" }, status: 200 },
      );
    }

    // Route to per-table handler. Most return a single intent or null;
    // doctor_vacations may return an array (one intent per affected
    // patient appointment).
    let intents: NotificationIntent[] = [];
    let intent: NotificationIntent | null = null;
    switch (payload.table) {
      case "messages":
        intent = await handleMessages(supabase, payload);
        break;
      case "appointments": {
        // Patient-side intent (existing — unchanged): tells the patient
        // about confirmations, cancellations, reschedules, reports.
        const patientIntent = handleAppointments(payload);
        if (patientIntent) intents.push(patientIntent);
        // Pro-side intents (Phase 2): tells the doctor + assigned
        // secretaries about the same lifecycle moments. Returns an
        // array because role-aware fanout collapses to one batched
        // intent (engine then writes one row per user_id).
        const proIntents = await handleProAppointments(supabase, payload);
        if (proIntents.length > 0) intents.push(...proIntents);
        break;
      }
      case "documents":
        if (payload.type === "DELETE") {
          intent = handleDocumentsDeletion(payload);
        } else {
          intent = handleDocuments(payload);
        }
        break;
      case "conversations":
        intent = handleConversations(payload);
        break;
      case "doctor_vacations": {
        const arr = await handleDoctorVacations(supabase, payload);
        if (arr) intents = arr;
        break;
      }
      case "patient_gift_sends":
        intent = await handleGifts(supabase, payload);
        break;
      case "todo_tasks":
        intent = await handleTodoTasks(supabase, payload);
        break;
      case "center_invitations":
      case "center_members": {
        const teamIntents = await handleProTeam(supabase, payload);
        if (teamIntents.length > 0) intents.push(...teamIntents);
        break;
      }
      case "doctor_verifications": {
        const verifIntents = await handleProVerifications(supabase, payload);
        if (verifIntents.length > 0) intents.push(...verifIntents);
        break;
      }
      case "subscriptions": {
        const subIntents = await handleProSubscriptions(supabase, payload);
        if (subIntents.length > 0) intents.push(...subIntents);
        break;
      }
      default:
        return new Response(
          `Table ${payload.table} not handled`,
          { status: 200 },
        );
    }

    if (intent) intents = [intent];
    if (intents.length === 0) {
      return new Response("No notification produced", { status: 200 });
    }

    let totalPersisted = 0;
    for (const it of intents) {
      if (it.user_ids.length === 0) continue;
      const persisted = await persistNotifications(supabase, it);
      totalPersisted += persisted.length;
      if (persisted.length > 0) {
        await fanoutNotifications(supabase, it, persisted);
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        intents: intents.length,
        persisted: totalPersisted,
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
