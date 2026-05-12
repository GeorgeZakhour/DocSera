// Handler: doctor_vacations INSERT — fans out on TWO sides:
//
//   1. Patient app — anyone with an appointment that falls in the
//      vacation window gets "your doctor will be away" so they can
//      rebook proactively.
//   2. Pro app — the doctor's assigned secretaries + the center
//      owner/admins get "Dr. X will be away" so they can coordinate
//      coverage. Sent regardless of whether any patient appointments
//      overlap — staff need the heads-up even on a quiet day.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

/// Returns multiple intents — the dispatcher needs to handle that.
export async function handleDoctorVacations(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent[] | null> {
  if (payload.type !== "INSERT" || !payload.record) return null;
  const r = payload.record;
  if (!r.doctor_id || !r.start_date || !r.end_date) return null;

  const intents: NotificationIntent[] = [];

  // ── Pro side: notify the doctor's team (secretaries + owners) ──
  const proIntents = await buildProVacationIntents(supabase, r);
  if (proIntents.length > 0) intents.push(...proIntents);

  // ── Patient side: only if appointments fall in the window ──
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

  if (error || !appts || appts.length === 0) {
    return intents.length > 0 ? intents : null;
  }

  // Dedup by user_id: a patient with multiple appointments in the
  // vacation window should get ONE "doctor on vacation" notification,
  // not one per appointment. The cancelled_by_doctor notifications fire
  // separately per appointment if the doctor confirmed cancellation.
  const seenUsers = new Map<string, Record<string, any>>();
  for (const a of appts) {
    if (!a.user_id) continue;
    if (!seenUsers.has(a.user_id)) seenUsers.set(a.user_id, a);
  }
  if (seenUsers.size === 0) {
    return intents.length > 0 ? intents : null;
  }

  // Localized date helpers for the vacation window.
  const startStr = String(r.start_date ?? "");
  const endStr = String(r.end_date ?? "");

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

// ---------------------------------------------------------------------------
// Pro-side: notify the doctor's team about the vacation.
// ---------------------------------------------------------------------------
//
// Recipients = the doctor themselves (so a self-set vacation lands on
// their phone as confirmation) + secretaries assigned to this doctor +
// the center owner / admins. Resolved by joining center_members; the
// fn_resolve_recipients function doesn't have a vacation branch yet, so
// we build the list inline (same pattern as pro_team.ts).
async function buildProVacationIntents(
  supabase: SupabaseClient,
  r: Record<string, any>,
): Promise<NotificationIntent[]> {
  const doctorId = r.doctor_id as string;
  if (!doctorId) return [];

  // Look up the doctor's center via their own center_members row.
  const { data: doctorRow } = await supabase
    .from("center_members")
    .select("center_id, user_id")
    .eq("doctor_id", doctorId)
    .eq("is_active", true)
    .is("removed_at", null)
    .order("joined_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (!doctorRow?.center_id) return [];
  const centerId = doctorRow.center_id as string;
  const doctorUserId = (doctorRow.user_id as string | null) ?? null;

  // Build the recipient set:
  //   - the doctor themselves
  //   - any active member with role in (owner, admin)
  //   - any active secretary with this doctor in assigned_doctor_ids
  const { data: members } = await supabase
    .from("center_members")
    .select("user_id, roles, assigned_doctor_ids")
    .eq("center_id", centerId)
    .eq("is_active", true)
    .is("removed_at", null);

  const recipients = new Set<string>();
  if (doctorUserId) recipients.add(doctorUserId);
  for (const m of (members ?? []) as Array<{
    user_id: string;
    roles: string[];
    assigned_doctor_ids: string[];
  }>) {
    if (!m.user_id) continue;
    const roles = m.roles ?? [];
    if (roles.includes("owner") || roles.includes("admin")) {
      recipients.add(m.user_id);
      continue;
    }
    if (
      roles.includes("secretary") &&
      Array.isArray(m.assigned_doctor_ids) &&
      m.assigned_doctor_ids.includes(doctorId)
    ) {
      recipients.add(m.user_id);
    }
  }
  if (recipients.size === 0) return [];

  // Resolve a friendly doctor display name from the doctors table.
  const { data: docInfo } = await supabase
    .from("doctors")
    .select("first_name, last_name, title")
    .eq("id", doctorId)
    .maybeSingle();
  const f = (docInfo?.first_name ?? "").toString().trim();
  const l = (docInfo?.last_name ?? "").toString().trim();
  const t = (docInfo?.title ?? "").toString().trim();
  const fullName = [t, f, l].filter((s) => s.length > 0).join(" ").trim();
  const arName = fullName.length > 0 ? fullName : "أحد الأطباء";
  const enName = fullName.length > 0 ? fullName : "A doctor";

  const startStr = String(r.start_date ?? "");
  const endStr = String(r.end_date ?? "");
  const noteStr = (r.note as string | null)?.toString().trim() ?? "";

  return [
    {
      user_ids: Array.from(recipients),
      recipient_app: "docsera_pro",
      event_code: "pro.calendar.vacation_set",
      category: "clinic_ops",
      title: `${LTR}🌴 إجازة ${arName}`,
      body: noteStr.length > 0
        ? `${LTR}${startStr} → ${endStr} · ${noteStr}`
        : `${LTR}${startStr} → ${endStr}`,
      localized: {
        ar: {
          title: `${LTR}🌴 إجازة ${arName}`,
          body: noteStr.length > 0
            ? `${LTR}${startStr} → ${endStr} · ${noteStr}`
            : `${LTR}${startStr} → ${endStr}`,
        },
        en: {
          title: `${LTR}🌴 ${enName} on vacation`,
          body: noteStr.length > 0
            ? `${LTR}${startStr} → ${endStr} · ${noteStr}`
            : `${LTR}${startStr} → ${endStr}`,
        },
      },
      deep_link: "/calendar",
      data: {
        doctor_id: doctorId,
        doctor_name: fullName,
        center_id: centerId,
        vacation_id: r.id,
        vacation_start: r.start_date,
        vacation_end: r.end_date,
        note: noteStr,
      },
      importance: "default",
      dedup_key: `pro.calendar.vacation_set:${r.id}`,
      locale: "ar",
    },
  ];
}
