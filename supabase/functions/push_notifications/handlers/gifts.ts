// Handler: patient_gift_sends.INSERT (channel='in_app').
// Doctors send personal gifts to patients — surfaces in their wallet.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

export async function handleGifts(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent | null> {
  if (payload.type !== "INSERT" || !payload.record) return null;
  const record = payload.record;

  if (record.channel !== "in_app" || !record.patient_id) return null;

  const { data: doctorRow } = await supabase
    .from("doctors")
    .select("first_name, last_name")
    .eq("id", record.doctor_id)
    .single();

  const fullName = doctorRow
    ? `${doctorRow.first_name ?? ""} ${doctorRow.last_name ?? ""}`.trim()
    : "";
  const namePart = fullName.length > 0 ? `د. ${fullName}` : "طبيبك";

  return {
    user_ids: [record.patient_id],
    recipient_app: "docsera",
    event_code: "gift.received",
    category: "loyalty",
    title: `🎁 هدية من ${namePart}`,
    body: "أُضيفت قسيمة جديدة إلى محفظتك. اضغط لعرض التفاصيل.",
    deep_link: `voucher:${record.claim_id}`,
    data: { gift_send_id: record.id, claim_id: record.claim_id },
    importance: "high",
    dedup_key: `gift:${record.id}`,
    locale: "ar",
  };
}
