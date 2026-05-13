// Handler: todo_tasks INSERT and UPDATE — DocSera-Pro only.
// Three sub-events: assigned-on-create, reassigned-on-update, completed.
//
// Names: center_members does NOT carry first_name/last_name (those live
// on the users row). lookupUserName joins via users.id and falls back
// to phone/email if a name isn't set yet. The earlier version queried
// center_members.first_name and silently returned "Someone" for every
// task, which is the bug behind the "✅ Someone" titles in production.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

export async function handleTodoTasks(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent | null> {
  const { type, record, old_record } = payload;
  if (!record) return null;

  const taskText = (record.text ?? "").toString().trim();

  // CASE A: New task assigned at INSERT (not self-assigned).
  if (
    type === "INSERT" && record.assigned_to &&
    record.created_by !== record.assigned_to
  ) {
    const creatorName = await lookupUserName(supabase, record.created_by);
    return {
      user_ids: [record.assigned_to],
      recipient_app: "docsera_pro",
      event_code: "todo_task.assigned",
      category: "tasks",
      title: `${LTR}📋 مهمة جديدة من ${creatorName}`,
      body: taskText.length > 0 ? taskText : "تم تعيين مهمة لك.",
      localized: {
        ar: {
          title: `${LTR}📋 مهمة جديدة من ${creatorName}`,
          body: taskText.length > 0 ? taskText : "تم تعيين مهمة لك.",
        },
        en: {
          title: `${LTR}📋 New task from ${creatorName}`,
          body: taskText.length > 0 ? taskText : "You have a new task.",
        },
      },
      deep_link: `todo_task:${record.id}`,
      data: {
        todo_task_id: record.id,
        creator_user_id: record.created_by,
        creator_name: creatorName,
      },
      importance: "high",
      dedup_key: `todo-assigned:${record.id}`,
      locale: "ar",
    };
  }

  if (type === "UPDATE" && old_record) {
    // CASE B: Reassigned via UPDATE.
    if (record.assigned_to && record.assigned_to !== old_record.assigned_to) {
      const assignerName = await lookupUserName(supabase, record.created_by);
      return {
        user_ids: [record.assigned_to],
        recipient_app: "docsera_pro",
        event_code: "todo_task.reassigned",
        category: "tasks",
        title: `${LTR}📋 مهمة مُعاد إسنادها من ${assignerName}`,
        body: taskText.length > 0 ? taskText : "تم إسناد مهمة لك.",
        localized: {
          ar: {
            title: `${LTR}📋 مهمة مُعاد إسنادها من ${assignerName}`,
            body: taskText.length > 0 ? taskText : "تم إسناد مهمة لك.",
          },
          en: {
            title: `${LTR}📋 Task reassigned by ${assignerName}`,
            body: taskText.length > 0 ? taskText : "You have a new task.",
          },
        },
        deep_link: `todo_task:${record.id}`,
        data: {
          todo_task_id: record.id,
          creator_user_id: record.created_by,
          creator_name: assignerName,
        },
        importance: "high",
        dedup_key: `todo-reassigned:${record.id}:${record.assigned_to}`,
        locale: "ar",
      };
    }

    // CASE C: Marked done by someone other than creator → notify creator.
    if (
      record.done === true && old_record.done !== true &&
      record.completed_by && record.created_by &&
      record.completed_by !== record.created_by
    ) {
      const completerName =
        await lookupUserName(supabase, record.completed_by);
      const taskFragment = taskText.length > 0
        ? `: ${taskText}`
        : "";
      return {
        user_ids: [record.created_by],
        recipient_app: "docsera_pro",
        event_code: "todo_task.completed",
        category: "tasks",
        title: `${LTR}✅ ${completerName} أنجز المهمة`,
        body: taskText.length > 0
          ? taskText
          : "تم إكمال المهمة المُسندة.",
        localized: {
          ar: {
            title: `${LTR}✅ ${completerName} أنجز المهمة`,
            body: taskText.length > 0
              ? taskText
              : "تم إكمال المهمة المُسندة.",
          },
          en: {
            title: `${LTR}✅ ${completerName} completed a task`,
            body: taskText.length > 0
              ? `Done${taskFragment}`
              : "The assigned task is now complete.",
          },
        },
        deep_link: `todo_task:${record.id}`,
        data: {
          todo_task_id: record.id,
          completer_user_id: record.completed_by,
          completer_name: completerName,
        },
        importance: "default",
        dedup_key: `todo-completed:${record.id}`,
        locale: "ar",
      };
    }
  }

  return null;
}

/// Resolve a display name for an auth user via the `users` table,
/// which is where first_name/last_name actually live. center_members
/// only carries (user_id, doctor_id, role…) — no name columns — so
/// the previous lookup against center_members silently returned null
/// for every member. Falls back to phone/email/"Someone" so the body
/// never ends up empty.
async function lookupUserName(
  supabase: SupabaseClient,
  userId: string | null | undefined,
): Promise<string> {
  if (!userId) return "Someone";
  // The patient users table column is `phone_number`, not `phone`.
  // An earlier version of this function queried `phone` and silently
  // failed (PostgREST returns null for the row when the column is
  // unknown), which is what produced "✅ Someone" titles in
  // production for every todo_task notification.
  const { data } = await supabase
    .from("users")
    .select("first_name, last_name, phone_number, email")
    .eq("id", userId)
    .maybeSingle();
  if (!data) return "Someone";
  const f = (data.first_name ?? "").toString().trim();
  const l = (data.last_name ?? "").toString().trim();
  const name = `${f} ${l}`.trim();
  if (name.length > 0) return name;
  const phone = (data.phone_number ?? "").toString().trim();
  if (phone.length > 0) return phone;
  const email = (data.email ?? "").toString().trim();
  if (email.length > 0) return email;
  return "Someone";
}
