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

  // Dedup by user_id: a patient with multiple appointments in the
  // vacation window should get ONE "doctor on vacation" notification,
  // not one per appointment. The cancelled_by_doctor notifications fire
  // separately per appointment if the doctor confirmed cancellation.
  const seenUsers = new Map<string, Record<string, any>>();
  for (const a of appts) {
    if (!a.user_id) continue;
    if (!seenUsers.has(a.user_id)) seenUsers.set(a.user_id, a);
  }
  if (seenUsers.size === 0) return null;

  // Localized date helpers for the vacation window.
  const startStr = String(r.start_date ?? "");
  const endStr = String(r.end_date ?? "");

  const intents: NotificationIntent[] = [];
  for (const [userId, a] of seenUsers) {
    // Strip the "د. " prefix if doctor_name already carries it.
    const rawName = (a.doctor_name as string | null)?.trim() ?? "";
    const arName = rawName.length > 0 ? rawName : "الطبيب";
    const enRaw = rawName.replace(/^د\.\s*/, "").trim();
    const enName = enRaw.length > 0 ? `Dr. ${enRaw}` : "your doctor";

    const titleAr = "الطبيب في إجازة";
    const titleEn = "Your doctor will be away";
    const bodyAr =
      `سيكون ${arName} في إجازة من ${startStr} إلى ${endStr}. اطلع على مواعيدك.`;
    const bodyEn =
      `${enName} will be on vacation from ${startStr} to ${endStr}. Check your appointments.`;

    intents.push({
      user_ids: [userId],
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
        vacation_id: r.id,
        vacation_start: r.start_date,
        vacation_end: r.end_date,
        affected_count: appts.filter((x) => x.user_id === userId).length,
      },
      importance: "high",
      // One per (vacation, user) — covers all that user's appointments
      // in the window with a single notification.
      dedup_key: `vac-overlap:${r.id}:${userId}`,
      locale: "ar",
    });
  }
  return intents.length > 0 ? intents : null;
}
