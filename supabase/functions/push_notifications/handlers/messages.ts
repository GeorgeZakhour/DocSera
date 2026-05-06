// Handler: messages.INSERT
// Decrypts the body if encrypted, picks the recipient based on is_user,
// and produces a NotificationIntent. Behavior preserved byte-for-byte
// from the previous monolithic index.ts.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";
import { decryptMessage } from "../decrypt.ts";

const LTR = "‎";

export async function handleMessages(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent | null> {
  if (payload.type !== "INSERT" || !payload.record) return null;
  const record = payload.record;

  const conversationId = record.conversation_id;

  const { data: conversation, error: convoError } = await supabase
    .from("conversations")
    .select("doctor_id, patient_id, relative_id")
    .eq("id", conversationId)
    .single();

  if (convoError || !conversation) {
    console.error("Error fetching conversation:", convoError);
    return null;
  }

  let user_ids: string[];
  let recipient_app: "docsera" | "docsera_pro";

  if (record.is_user) {
    // Patient sent message → notify doctor on DocSera-Pro
    user_ids = conversation.doctor_id ? [conversation.doctor_id] : [];
    recipient_app = "docsera_pro";
  } else {
    // Doctor sent message → notify patient on DocSera (and any relative on the convo)
    user_ids = [];
    if (conversation.patient_id) user_ids.push(conversation.patient_id);
    if (conversation.relative_id) user_ids.push(conversation.relative_id);
    recipient_app = "docsera";
  }

  if (user_ids.length === 0) return null;

  const senderName = record.sender_name || "DocSera";
  const title = `${LTR}💬 ${senderName}`;

  let rawBody = record.text as string | null | undefined;

  if (rawBody && rawBody.startsWith("ENC:")) {
    const decrypted = await decryptMessage(supabase, rawBody);
    rawBody = decrypted ?? null;
  }

  let bodyAr: string;
  let bodyEn: string;
  if (!rawBody || rawBody.trim() === "") {
    if (record.attachments && record.attachments.length > 0) {
      const t = record.attachments[0].type;
      if (t === "image") {
        bodyAr = `${LTR}أرسل صورة 📷`;
        bodyEn = `${LTR}Sent a photo 📷`;
      } else if (t === "pdf") {
        bodyAr = `${LTR}أرسل مستند 📄`;
        bodyEn = `${LTR}Sent a document 📄`;
      } else {
        bodyAr = `${LTR}أرسل مرفق 📎`;
        bodyEn = `${LTR}Sent an attachment 📎`;
      }
    } else {
      bodyAr = `${LTR}أرسل رسالة`;
      bodyEn = `${LTR}New message`;
    }
  } else {
    bodyAr = `${LTR}${rawBody}`;
    bodyEn = `${LTR}${rawBody}`;
  }

  return {
    user_ids,
    recipient_app,
    event_code: "message.new",
    category: "messages",
    title,
    body: bodyAr,
    localized: {
      ar: { title, body: bodyAr },
      en: { title, body: bodyEn },
    },
    deep_link: `conversation:${conversationId}`,
    data: { conversation_id: conversationId, message_id: record.id },
    importance: "high",
    // Per-message dedup key — uses the message ID so retried webhooks don't
    // double-notify, but two separate messages aren't collapsed.
    dedup_key: `msg:${record.id}`,
    locale: "ar",
  };
}
