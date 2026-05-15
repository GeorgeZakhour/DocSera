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
        // doctor_id scopes the inbox doctor-filter chip on the Pro side.
        ...(record.doctor_id ? { doctor_id: record.doctor_id } : {}),
      },
      importance: "high",
      dedup_key: `todo-assigned:${record.id}`,
      locale: "ar",
    };
  }

  if (type === "UPDATE" && old_record) {
    // CASE B: Reassigned via UPDATE. Extra guards on top of the
    // assigned_to-changed check:
    //   - Skip if the new assignee IS the actor (self-reassignment
    //     should never wake the assignee — they just did it).
    //   - Skip if the new assignee is also the creator (you can't
    //     "reassign a task to yourself" semantically).
    // These two extra checks defend against weird UPDATE patterns
    // where the same row gets edited multiple times in quick
    // succession (e.g. the client retries on a network blip) —
    // each genuine reassign still produces exactly one row, but
    // toggle-back UPDATEs don't.
    if (
      record.assigned_to &&
      record.assigned_to !== old_record.assigned_to &&
      record.assigned_to !== record.created_by
    ) {
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
          ...(record.doctor_id ? { doctor_id: record.doctor_id } : {}),
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
          ...(record.doctor_id ? { doctor_id: record.doctor_id } : {}),
        },
        importance: "default",
        dedup_key: `todo-completed:${record.id}`,
        locale: "ar",
      };
    }
  }

  return null;
}

/// Resolve a display name for any Pro team member. Names live in
/// THREE places depending on the role:
///   - Clinicians (doctor/owner/specialist) → public.doctors.first_name
///   - Staff (secretary/admin) → public.team_profiles via center_members
///   - Patient-side users → public.users.first_name
/// Previous version only queried public.users, which is empty for
/// almost every Pro member, so every secretary action surfaced as
/// "Someone …" (the bug behind the iPhone notification storm).
///
/// The full chain lives server-side in fn_user_display_name(uuid)
/// so handlers + SQL triggers share one source of truth.
async function lookupUserName(
  supabase: SupabaseClient,
  userId: string | null | undefined,
): Promise<string> {
  if (!userId) return "Someone";
  try {
    const { data } = await supabase.rpc("fn_user_display_name", {
      p_user_id: userId,
    });
    if (typeof data === "string" && data.trim().length > 0) {
      return data.trim();
    }
  } catch (e) {
    console.warn("[todo_tasks] fn_user_display_name rpc failed:", e);
  }
  return "Someone";
}
