// Handler: messages.INSERT
// Decrypts the body if encrypted, picks recipients per direction, and
// produces a NotificationIntent. The patient-direction path is
// unchanged (notify patient + any relative on the convo). The
// doctor-direction path (patient → doctor side) is now role-aware via
// fn_resolve_recipients — instead of only the doctor's own auth row,
// it notifies the doctor + secretaries assigned to that doctor with
// viewMessages permission. Same encrypt/decrypt path, same template.

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
    // Patient sent message → notify doctor + assigned secretaries via
    // the role-aware resolver. The conversation carries doctors.id;
    // we look up the center via center_members to feed the resolver.
    if (!conversation.doctor_id) return null;
    const centerId = await lookupCenterForDoctor(
      supabase,
      conversation.doctor_id as string,
    );
    if (!centerId) {
      // Fallback to single-recipient when the doctor isn't in a team
      // center (solo doctor still on the legacy doctor_accounts path).
      user_ids = [conversation.doctor_id as string];
    } else {
      const { data: recipientRows, error: rErr } = await supabase
        .rpc("fn_resolve_recipients", {
          p_event_code: "pro.message.received",
          p_ctx: {
            center_id: centerId,
            doctor_id: conversation.doctor_id,
          },
        });
      if (rErr) {
        console.error("[messages] resolver error:", rErr);
        return null;
      }
      user_ids = normalizeUuidList(recipientRows);
      // Resolver-empty centers (rare) still need the doctor notified
      // as a safety net.
      if (user_ids.length === 0 && conversation.doctor_id) {
        user_ids = [conversation.doctor_id as string];
      }
    }
    recipient_app = "docsera_pro";
  } else {
    // Doctor sent message → notify patient on DocSera (and any
    // relative on the convo). Unchanged from the patient-only path.
    user_ids = [];
    if (conversation.patient_id) user_ids.push(conversation.patient_id);
    if (conversation.relative_id) user_ids.push(conversation.relative_id);
    recipient_app = "docsera";
  }

  if (user_ids.length === 0) return null;

  const senderName = record.sender_name || "DocSera";
  const title = `${LTR}💬 ${senderName}`;

  let rawBody = record.text as string | null | undefined;

  // Decrypt if the body uses either of our encryption prefixes:
  //   "ENC:"   → AES-256-CBC (legacy, decrypt-only)
  //   "ENCv2:" → AES-256-GCM (current format from MessageEncryptionService
  //              after the 2026-05-13 migration in commit 1a76e28)
  //
  // decryptMessage() handles both formats internally; calling it on a
  // plain-text rawBody is also safe — it returns the input unchanged.
  // We still gate on a prefix check to avoid an unnecessary RPC call
  // (rpc_get_encryption_key_service) for the plain-text path.
  if (rawBody &&
      (rawBody.startsWith("ENC:") || rawBody.startsWith("ENCv2:"))) {
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

  // Distinct event codes per direction so each side can have its own
  // template, prefs, and analytics: `message.new` is patient-app
  // legacy (kept for backward compat); `pro.message.received` is the
  // doctor-side equivalent.
  const eventCode = recipient_app === "docsera_pro"
    ? "pro.message.received"
    : "message.new";

  return {
    user_ids,
    recipient_app,
    event_code: eventCode,
    category: "messages",
    title,
    body: bodyAr,
    localized: {
      ar: { title, body: bodyAr },
      en: { title, body: bodyEn },
    },
    deep_link: `conversation:${conversationId}`,
    data: {
      conversation_id: conversationId,
      message_id: record.id,
      // doctor_id is required by the Pro inbox to render the per-doctor
      // pill and the doctor-scope filter chip. Always include it on the
      // Pro side; harmless on the patient side (patient inbox ignores
      // the field). Solo conversations (no convo.doctor_id) skip it.
      ...(conversation.doctor_id
        ? { doctor_id: conversation.doctor_id as string }
        : {}),
    },
    importance: "high",
    // Per-message dedup key — uses the message ID so retried webhooks don't
    // double-notify, but two separate messages aren't collapsed.
    dedup_key: `msg:${record.id}`,
    locale: "ar",
  };
}

/// Resolves the center_id for a doctor by inspecting their
/// center_members row. Returns null if the doctor isn't on a team
/// (legacy doctor_accounts solo flow — handler then falls back to a
/// single-user intent).
async function lookupCenterForDoctor(
  supabase: SupabaseClient,
  doctorId: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("center_members")
    .select("center_id")
    .eq("doctor_id", doctorId)
    .eq("is_active", true)
    .is("removed_at", null)
    .limit(1)
    .maybeSingle();
  if (error || !data) return null;
  return (data as { center_id: string }).center_id;
}

/// Normalizes the shape returned by .rpc('fn_resolve_recipients'):
/// older supabase-js versions return [{fn_resolve_recipients: uuid}],
/// newer ones return a flat string[]. Accept either.
function normalizeUuidList(rows: unknown): string[] {
  if (!rows) return [];
  if (Array.isArray(rows)) {
    return rows
      .map((r) => {
        if (typeof r === "string") return r;
        if (r && typeof r === "object" && "fn_resolve_recipients" in r) {
          return (r as Record<string, string>).fn_resolve_recipients;
        }
        return null;
      })
      .filter((r): r is string => typeof r === "string" && r.length > 0);
  }
  return [];
}
