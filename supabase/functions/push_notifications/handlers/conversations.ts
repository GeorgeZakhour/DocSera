// Handler: conversations.UPDATE — fires when is_closed flips.
// Notifies the patient (and any relative on the conversation) so they
// know the doctor closed or reopened the thread.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

export function handleConversations(
  payload: WebhookPayload,
): NotificationIntent | null {
  if (payload.type !== "UPDATE" || !payload.record || !payload.old_record) {
    return null;
  }
  const r = payload.record;
  const o = payload.old_record;

  if (r.is_closed === o.is_closed) return null;

  const user_ids: string[] = [];
  if (r.patient_id) user_ids.push(r.patient_id);
  if (r.relative_id) user_ids.push(r.relative_id);
  if (user_ids.length === 0) return null;

  // doctor_name on conversations already carries the "د." prefix.
  // Don't double it. Fall back to "الطبيب" / "your doctor" only if missing.
  const rawName = (r.doctor_name as string | null)?.trim() ?? "";
  const doctorName = rawName.length > 0 ? rawName : "الطبيب";
  // For EN, strip the Arabic "د. " title and use "Dr." prefix for English copy.
  const enRaw = rawName.replace(/^د\.\s*/, "").trim();
  const doctorNameEn = enRaw.length > 0 ? `Dr. ${enRaw}` : "your doctor";
  const conversationId = r.id as string;

  if (r.is_closed === true && o.is_closed === false) {
    // Closed
    const titleAr = "تم إغلاق المحادثة";
    const titleEn = "Conversation closed";
    const bodyAr = `أغلق ${doctorName} هذه المحادثة. يمكنك بدء محادثة جديدة عند الحاجة.`;
    const bodyEn = `${doctorNameEn} closed this conversation. You can start a new one when needed.`;
    return {
      user_ids,
      recipient_app: "docsera",
      event_code: "conversation.closed_by_doctor",
      category: "messages",
      title: titleAr,
      body: bodyAr,
      localized: {
        ar: { title: titleAr, body: bodyAr },
        en: { title: titleEn, body: bodyEn },
      },
      deep_link: `conversation:${conversationId}`,
      data: { conversation_id: conversationId },
      importance: "default",
      dedup_key: `conv-closed:${conversationId}`,
      locale: "ar",
    };
  }

  if (r.is_closed === false && o.is_closed === true) {
    // Reopened
    const titleAr = "تم إعادة فتح المحادثة";
    const titleEn = "Conversation reopened";
    const bodyAr = `أعاد ${doctorName} فتح المحادثة. يمكنك إكمال الحديث الآن.`;
    const bodyEn = `${doctorNameEn} reopened the conversation. You can continue chatting now.`;
    return {
      user_ids,
      recipient_app: "docsera",
      event_code: "conversation.reopened_by_doctor",
      category: "messages",
      title: titleAr,
      body: bodyAr,
      localized: {
        ar: { title: titleAr, body: bodyAr },
        en: { title: titleEn, body: bodyEn },
      },
      deep_link: `conversation:${conversationId}`,
      data: { conversation_id: conversationId },
      importance: "high",
      dedup_key: `conv-reopened:${conversationId}:${r.updated_at ?? Date.now()}`,
      locale: "ar",
    };
  }

  return null;
}
