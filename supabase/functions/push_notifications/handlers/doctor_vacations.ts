// Handler: doctor_vacations INSERT — when a doctor adds a vacation that
// overlaps any patient's booked future appointment, notify each affected
// patient. We fan out one intent per patient since each appointment_id
// (and dedup_key) differs.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

/// Returns multiple intents — the dispatcher needs to handle that.
export async function handleDoctorVacations(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent[] | null> {
  if (payload.type !== "INSERT" || !payload.record) return null;
  const r = payload.record;
  if (!r.doctor_id || !r.start_date || !r.end_date) return null;

  // Find appointments that overlap the vacation window.
  const { data: appts, error } = await supabase
    .from("appointments")
    .select("id, user_id, doctor_name, appointment_date, appointment_time, timestamp")
    .eq("doctor_id", r.doctor_id)
    .gte("appointment_date", r.start_date)
    .lte("appointment_date", r.end_date)
    .neq("status", "cancelled")
    .neq("status", "cancelled_by_doctor")
    .neq("status", "rejected")
    .neq("status", "done");

  if (error || !appts || appts.length === 0) return null;

  const intents: NotificationIntent[] = [];
  for (const a of appts) {
    if (!a.user_id) continue;
    const docName = (a.doctor_name as string | null) ?? "الطبيب";
    const docNameEn = (a.doctor_name as string | null) ?? "your doctor";
    const titleAr = "الطبيب في إجازة";
    const titleEn = "Your doctor will be away";
    const bodyAr = `سيكون د. ${docName} في إجازة خلال موعدك المحجوز. يُنصح بإعادة الجدولة.`;
    const bodyEn = `${docNameEn} will be on vacation during your booked appointment. Consider rescheduling.`;
    intents.push({
      user_ids: [a.user_id],
      recipient_app: "docsera",
      event_code: "doctor.vacation_overlap",
      category: "appointments",
      title: titleAr,
      body: bodyAr,
      localized: {
        ar: { title: titleAr, body: bodyAr },
        en: { title: titleEn, body: bodyEn },
      },
      deep_link: `appointment:${a.id}`,
      data: {
        appointment_id: a.id,
        vacation_id: r.id,
        vacation_start: r.start_date,
        vacation_end: r.end_date,
      },
      importance: "high",
      dedup_key: `vac-overlap:${r.id}:${a.id}`,
      locale: "ar",
    });
  }
  return intents.length > 0 ? intents : null;
}
