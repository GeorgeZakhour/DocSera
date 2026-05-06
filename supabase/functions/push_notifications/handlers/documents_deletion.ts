// Handler: documents.DELETE — notifies the patient that a document was
// removed by the doctor. The deleted row info comes via `old_record` in
// Supabase webhook DELETE payloads.

import type { NotificationIntent, WebhookPayload } from "../types.ts";

export function handleDocumentsDeletion(
  payload: WebhookPayload,
): NotificationIntent | null {
  if (payload.type !== "DELETE" || !payload.old_record) return null;
  const o = payload.old_record;
  if (!o.patient_id) return null;

  const docName = (o.conversation_doctor_name as string | null) ?? "الطبيب";
  const docNameEn = (o.conversation_doctor_name as string | null) ?? "Your doctor";

  const titleAr = "تم حذف مستند من ملفك";
  const titleEn = "A document was removed from your file";
  const bodyAr = `حذف ${docName} مستندًا من ملفك الطبي.`;
  const bodyEn = `${docNameEn} removed a document from your medical file.`;

  return {
    user_ids: [o.patient_id],
    recipient_app: "docsera",
    event_code: "document.deleted_by_doctor",
    category: "documents",
    title: titleAr,
    body: bodyAr,
    localized: {
      ar: { title: titleAr, body: bodyAr },
      en: { title: titleEn, body: bodyEn },
    },
    deep_link: "document:home",
    data: { document_id: o.id },
    importance: "default",
    dedup_key: `doc-del:${o.id}`,
    locale: "ar",
  };
}
