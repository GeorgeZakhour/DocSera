// Handler: documents.DELETE — notifies the patient that a doctor removed
// a document from their file. We only notify for source='doctor_added'
// docs — patients deleting their own files don't need a notification
// telling them what they just did.

import type { NotificationIntent, WebhookPayload } from "../types.ts";

export function handleDocumentsDeletion(
  payload: WebhookPayload,
): NotificationIntent | null {
  if (payload.type !== "DELETE" || !payload.old_record) {
    console.log('document.deletion: skip (not a DELETE or no old_record)');
    return null;
  }
  const o = payload.old_record;
  if (!o.patient_id) {
    console.log('document.deletion: skip (no patient_id)');
    return null;
  }

  // Only fire for doctor-uploaded docs. Patient self-uploads (source='patient')
  // and other sources don't warrant a notification on delete.
  const source = (o.source as string | null) ?? "";
  if (source !== "doctor_added") {
    console.log(`document.deletion: skip (source=${source}, not doctor_added)`);
    return null;
  }

  const docName = (o.conversation_doctor_name as string | null)?.trim() ?? "";
  const titleAr = "تم حذف مستند من ملفك";
  const titleEn = "A document was removed from your file";
  const bodyAr = docName.length > 0
    ? `حذف د. ${docName} مستندًا من ملفك الطبي.`
    : `حذف الطبيب مستندًا من ملفك الطبي.`;
  const bodyEn = docName.length > 0
    ? `Dr. ${docName} removed a document from your medical file.`
    : `Your doctor removed a document from your medical file.`;

  console.log(`document.deletion: emitting for patient=${o.patient_id} doc=${o.id}`);

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
