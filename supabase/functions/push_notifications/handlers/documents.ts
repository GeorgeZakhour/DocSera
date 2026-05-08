// Handler: documents.INSERT — notify the patient that a new document was
// added to their medical file.

import type { NotificationIntent, WebhookPayload } from "../types.ts";

export function handleDocuments(
  payload: WebhookPayload,
): NotificationIntent | null {
  if (payload.type !== "INSERT" || !payload.record) return null;
  const record = payload.record;

  if (!record.patient_id) return null;

  // Only fire for doctor-uploaded docs. Patient self-uploads
  // (source='patient') and other sources don't warrant a notification —
  // the patient just performed the action, they don't need a system
  // notification telling them what they did.
  const source = (record.source as string | null) ?? "";
  if (source !== "doctor_added") return null;

  const docName = record.conversation_doctor_name || "الطبيب";
  const docNameEn = record.conversation_doctor_name || "Your doctor";

  const titleAr = "📄 مستند جديد";
  const titleEn = "📄 New document";
  const bodyAr = `أضاف ${docName} مستنداً جديداً لملفك الطبي.`;
  const bodyEn = `${docNameEn} added a new document to your medical file.`;

  return {
    user_ids: [record.patient_id],
    recipient_app: "docsera",
    event_code: "document.new",
    category: "documents",
    title: titleAr,
    body: bodyAr,
    localized: {
      ar: { title: titleAr, body: bodyAr },
      en: { title: titleEn, body: bodyEn },
    },
    deep_link: `document:${record.id}`,
    data: { document_id: record.id },
    importance: "default",
    dedup_key: `doc:${record.id}`,
    locale: "ar",
  };
}
