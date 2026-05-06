// Handler: todo_tasks INSERT and UPDATE — DocSera-Pro only.
// Three sub-events: assigned-on-create, reassigned-on-update, completed.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

export async function handleTodoTasks(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent | null> {
  const { type, record, old_record } = payload;
  if (!record) return null;

  // CASE A: New task assigned at INSERT (not self-assigned).
  if (
    type === "INSERT" && record.assigned_to &&
    record.created_by !== record.assigned_to
  ) {
    const creatorName = await fetchMemberName(supabase, record.created_by);
    return {
      user_ids: [record.assigned_to],
      recipient_app: "docsera_pro",
      event_code: "todo_task.assigned",
      category: "system",
      title: `${LTR}📋 ${creatorName}`,
      body: record.text || "New task",
      deep_link: `todo_task:${record.id}`,
      data: { todo_task_id: record.id },
      importance: "high",
      dedup_key: `todo-assigned:${record.id}`,
      locale: "ar",
    };
  }

  if (type === "UPDATE" && old_record) {
    // CASE B: Reassigned via UPDATE.
    if (record.assigned_to && record.assigned_to !== old_record.assigned_to) {
      const assignerName = await fetchMemberName(supabase, record.created_by);
      return {
        user_ids: [record.assigned_to],
        recipient_app: "docsera_pro",
        event_code: "todo_task.reassigned",
        category: "system",
        title: `${LTR}📋 ${assignerName}`,
        body: record.text || "New task",
        deep_link: `todo_task:${record.id}`,
        data: { todo_task_id: record.id },
        importance: "high",
        dedup_key: `todo-reassigned:${record.id}:${record.assigned_to}`,
        locale: "ar",
      };
    }

    // CASE C: Marked done by someone other than creator → notify creator.
    if (
      record.done === true && old_record.done === false &&
      record.completed_by && record.created_by &&
      record.completed_by !== record.created_by
    ) {
      const completerName = await fetchMemberName(supabase, record.completed_by);
      return {
        user_ids: [record.created_by],
        recipient_app: "docsera_pro",
        event_code: "todo_task.completed",
        category: "system",
        title: `${LTR}✅ ${completerName}`,
        body: record.text || "Task completed",
        deep_link: `todo_task:${record.id}`,
        data: { todo_task_id: record.id },
        importance: "default",
        dedup_key: `todo-completed:${record.id}`,
        locale: "ar",
      };
    }
  }

  return null;
}

async function fetchMemberName(
  supabase: SupabaseClient,
  user_id: string,
): Promise<string> {
  const { data } = await supabase
    .from("center_members")
    .select("first_name, last_name")
    .eq("user_id", user_id)
    .limit(1)
    .single();
  return data ? `${data.first_name} ${data.last_name}` : "Someone";
}
