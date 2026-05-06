// Handler: documents.INSERT — notify the patient that a new document was
// added to their medical file.

import type { NotificationIntent, WebhookPayload } from "../types.ts";

export function handleDocuments(
  payload: WebhookPayload,
): NotificationIntent | null {
  if (payload.type !== "INSERT" || !payload.record) return null;
  const record = payload.record;

  if (!record.patient_id) return null;

  const docName = record.conversation_doctor_name || "الطبيب";

  return {
    user_ids: [record.patient_id],
    recipient_app: "docsera",
    event_code: "document.new",
    category: "documents",
    title: "📄 مستند جديد",
    body: `أضاف ${docName} مستنداً جديداً لملفك الطبي.`,
    deep_link: `document:${record.id}`,
    data: { document_id: record.id },
    importance: "default",
    dedup_key: `doc:${record.id}`,
    locale: "ar",
  };
}
