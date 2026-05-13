// Handler: appointments table → DocSera-Pro side (doctor + assigned
// secretaries). Mirrors the patient app's appointments.ts in scope
// but its recipients come from fn_resolve_recipients, so the same
// event routes to the doctor + the right secretaries with no
// hard-coded "for each member" logic in TypeScript.
//
// Events produced (per the Phase 2 plan catalog rows 1-7):
//
//   1  pro.appointment.booked_pending       INSERT, is_confirmed=false
//   2  pro.appointment.booked_confirmed     INSERT, is_confirmed=true
//   3  pro.appointment.cancelled_by_patient UPDATE status→cancelled,
//                                           booked_via!='clinic'
//   4  pro.appointment.rescheduled_by_pat   UPDATE timestamp changed,
//                                           booked_via!='clinic'
//   5  pro.appointment.patient_arrived      UPDATE entered_at set
//   6  pro.appointment.no_show_auto         UPDATE status→never_arrived
//   7  pro.appointment.report_overdue       (cron-driven; not in this
//                                           handler — handled elsewhere)
//
// The patient-side handler (`appointments.ts`) is preserved
// unchanged; the dispatcher fans an `appointments` webhook into
// BOTH handlers and merges intents.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

export async function handleProAppointments(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent[]> {
  const { type, record, old_record } = payload;
  if (!record) return [];

  // Manual patients (no DocSera account, booked by clinic) — still
  // notify the doctor + secretary; the patient_name field carries the
  // human label.
  const doctorId: string | null = record.doctor_id ?? null;
  if (!doctorId) return [];

  // center_id on the appointments row is the cheap path. When it's
  // null (the patient-app booking flow doesn't always set it), fall
  // back to looking up the center via center_members.doctor_id — the
  // doctor's own row carries the center_id. This is the same pattern
  // messages.ts uses for the same reason.
  let centerId: string | null = record.center_id ?? null;
  if (!centerId) {
    centerId = await lookupCenterForDoctor(supabase, doctorId);
    if (!centerId) {
      // Genuinely solo doctor (no team) — Pro handler has nothing to
      // do. Patient-side handler still fires.
      return [];
    }
  }

  // Decide which event fired.
  const evt = classify(type, record, old_record);
  if (!evt) return [];

  // Resolve recipients via the role-aware SQL helper. Pass the
  // actor's user_id so we don't notify the person who caused the
  // event (e.g. a doctor cancelling his own appointment).
  const actorUserId = inferActorUserId(record, old_record);
  const { data: recipientRows, error: rErr } = await supabase
    .rpc("fn_resolve_recipients", {
      p_event_code: evt.code,
      p_ctx: {
        center_id: centerId,
        doctor_id: doctorId,
        actor_user_id: actorUserId,
      },
    });
  if (rErr) {
    console.error("[pro_appointments] resolver error:", rErr);
    return [];
  }
  // The RPC returns setof uuid — supabase-js gives us an array of
  // { fn_resolve_recipients: uuid } objects OR a flat string array
  // depending on the client version. Normalize.
  const recipientIds: string[] = normalizeUuidList(recipientRows);
  if (recipientIds.length === 0) return [];

  const time12 = format12h(record.appointment_time);
  const dateStr = record.appointment_date || "";
  const patientName = record.patient_name || (
    record.is_docsera_user ? "the patient" : "a patient"
  );

  // Build one intent per recipient. We could batch into a single
  // intent with all user_ids — but the engine's persist layer already
  // produces one row per element in user_ids[], so this is mostly
  // bookkeeping. We keep it as one batched intent to match the
  // existing engine contract.
  // Old appointment time if this is a reschedule (so we can show
  // "from <old> to <new>" instead of just the new slot).
  const oldTs = record.rescheduled_from_timestamp ?? null;
  const oldDateStr = oldTs
    ? new Date(oldTs as string).toISOString().slice(0, 10)
    : null;
  const oldTime12 = oldTs ? format12hFromIso(oldTs as string) : null;

  const localized = renderCopy(
    evt.code,
    patientName,
    dateStr,
    time12,
    oldDateStr,
    oldTime12,
  );

  return [
    {
      user_ids: recipientIds,
      recipient_app: "docsera_pro",
      event_code: evt.code,
      category: "appointments",
      title: localized.ar.title,
      body: localized.ar.body,
      localized,
      deep_link: `appointment:${record.id}`,
      data: {
        appointment_id: record.id,
        center_id: centerId,
        doctor_id: doctorId,
        patient_name: patientName,
        appointment_date: dateStr,
        appointment_time: record.appointment_time,
        status: record.status ?? null,
        // Reschedule lineage — surfaced in the detail pane via the
        // metadata grid so the doctor sees "موعد سابق: <old>".
        ...(record.rescheduled_from_id
          ? {
              rescheduled_from_id: record.rescheduled_from_id,
              rescheduled_from_date: oldDateStr,
              rescheduled_from_time: oldTime12?.ar,
            }
          : {}),
      },
      importance: evt.importance,
      dedup_key: `${evt.code}:${record.id}`,
      locale: "ar",
    },
  ];
}

// ---------------------------------------------------------------------------
// Classifier — maps webhook (type, record, old_record) → event code
// ---------------------------------------------------------------------------

function classify(
  type: WebhookPayload["type"],
  record: Record<string, any>,
  old_record: Record<string, any> | null,
): { code: string; importance: "low" | "default" | "high" | "time_sensitive" } | null {
  if (type === "INSERT") {
    // Reschedule lineage: the patient-side RPC sets these columns
    // when the new row replaces an existing appointment. From the
    // doctor's POV this is a reschedule, NOT a fresh booking — emit
    // the correct event so the body reads "X rescheduled their
    // appointment to <new time>" rather than "X requested a new
    // appointment".
    if (record.rescheduled_from_id) {
      return {
        code: "pro.appointment.rescheduled_by_patient",
        importance: "high",
      };
    }
    if (record.is_confirmed === true) {
      return { code: "pro.appointment.booked_confirmed", importance: "default" };
    }
    return { code: "pro.appointment.booked_pending", importance: "high" };
  }

  if (type !== "UPDATE" || !old_record) return null;

  const oldStatus = old_record.status ?? null;
  const newStatus = record.status ?? null;
  const oldTime = old_record.timestamp ?? null;
  const newTime = record.timestamp ?? null;
  const oldEnteredAt = old_record.entered_at ?? null;
  const newEnteredAt = record.entered_at ?? null;
  const bookedVia = (record.booked_via ?? "").toString();

  // Cancellation initiated by the patient (booked via patient app /
  // web, status flipped to 'cancelled'). The clinic-initiated path
  // (status='cancelled_by_doctor') is the doctor's OWN action and
  // doesn't need to ping the doctor — it's handled at UI level.
  if (
    newStatus === "cancelled" &&
    oldStatus !== "cancelled" &&
    bookedVia !== "clinic"
  ) {
    // Same-day cancellation → time-sensitive (the doctor's free slot
    // just opened up and they may want to triage). Future-day → high.
    const isSameDay = isAppointmentToday(record);
    return {
      code: "pro.appointment.cancelled_by_patient",
      importance: isSameDay ? "time_sensitive" : "high",
    };
  }

  // Reschedule: timestamp changed AND status is not a terminal one.
  if (
    newTime !== oldTime &&
    (newStatus === "pending" || newStatus === "confirmed" ||
      newStatus === "not_arrived" || newStatus === "" || newStatus === null)
  ) {
    return { code: "pro.appointment.rescheduled_by_patient", importance: "default" };
  }

  // Patient arrived — entered_at went from null → non-null. The
  // secretary just marked the patient as in the waiting room.
  if (oldEnteredAt == null && newEnteredAt != null) {
    return { code: "pro.appointment.patient_arrived", importance: "time_sensitive" };
  }

  // Automated no-show transition.
  if (
    (newStatus === "never_arrived_cancelled" ||
      newStatus === "not_arrived") &&
    oldStatus !== newStatus
  ) {
    return { code: "pro.appointment.no_show_auto", importance: "default" };
  }

  return null;
}

// ---------------------------------------------------------------------------
// Actor inference — who caused the event, so the resolver excludes them
// ---------------------------------------------------------------------------

function inferActorUserId(
  record: Record<string, any>,
  old_record: Record<string, any> | null,
): string | null {
  // The appointments row doesn't carry an explicit actor field. We
  // infer:
  //
  //   - cancellation/reschedule by patient: actor is the patient's
  //     user_id (record.user_id). Doctor + secretaries are notified;
  //     patient is on the other app and doesn't get the doctor-side
  //     push.
  //   - patient arrived: actor is the secretary/doctor who tapped
  //     "patient arrived". We don't know which member tapped it from
  //     the webhook row alone. Best-effort: skip this filter for
  //     patient_arrived — the doctor gets the push regardless, and
  //     the secretary already knows.
  //
  // Returning null disables actor exclusion for the resolver call.

  const bookedVia = (record.booked_via ?? "").toString();
  const oldStatus = old_record?.status ?? null;
  const newStatus = record.status ?? null;

  if (
    newStatus === "cancelled" &&
    oldStatus !== "cancelled" &&
    bookedVia !== "clinic" &&
    typeof record.user_id === "string"
  ) {
    return record.user_id;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Copy registry — Pro-side appointment events
// ---------------------------------------------------------------------------

function renderCopy(
  eventCode: string,
  patientName: string,
  dateStr: string,
  time12: { ar: string; en: string },
  oldDateStr?: string | null,
  oldTime12?: { ar: string; en: string } | null,
): { ar: { title: string; body: string }; en: { title: string; body: string } } {
  switch (eventCode) {
    case "pro.appointment.booked_pending":
      return {
        ar: {
          title: `${LTR}📨 طلب حجز جديد`,
          body: `${LTR}${patientName} طلب موعداً بتاريخ ${dateStr} الساعة ${time12.ar} — بانتظار تأكيدك.`,
        },
        en: {
          title: `${LTR}📨 New booking request`,
          body: `${LTR}${patientName} requested an appointment on ${dateStr} at ${time12.en} — awaiting your confirmation.`,
        },
      };
    case "pro.appointment.booked_confirmed":
      return {
        ar: {
          title: `${LTR}✅ موعد جديد`,
          body: `${LTR}موعد مؤكد مع ${patientName} بتاريخ ${dateStr} الساعة ${time12.ar}.`,
        },
        en: {
          title: `${LTR}✅ New appointment`,
          body: `${LTR}Confirmed appointment with ${patientName} on ${dateStr} at ${time12.en}.`,
        },
      };
    case "pro.appointment.cancelled_by_patient":
      return {
        ar: {
          title: `${LTR}❌ تم إلغاء الموعد`,
          body: `${LTR}${patientName} ألغى موعده بتاريخ ${dateStr} الساعة ${time12.ar}.`,
        },
        en: {
          title: `${LTR}❌ Appointment cancelled`,
          body: `${LTR}${patientName} cancelled their appointment on ${dateStr} at ${time12.en}.`,
        },
      };
    case "pro.appointment.rescheduled_by_patient": {
      // Two flavors:
      //   - We know the OLD slot (reschedule_from_timestamp present)
      //     → render "from <old> to <new>" so the doctor sees both
      //   - Old slot unknown (legacy UPDATE-only flow)
      //     → just "rescheduled to <new>"
      if (oldDateStr && oldTime12) {
        return {
          ar: {
            title: `${LTR}🕒 تم تغيير الموعد`,
            body:
              `${LTR}${patientName} غيّر موعده من ${oldDateStr} الساعة ${oldTime12.ar} ` +
              `إلى ${dateStr} الساعة ${time12.ar}.`,
          },
          en: {
            title: `${LTR}🕒 Appointment rescheduled`,
            body:
              `${LTR}${patientName} moved their appointment from ${oldDateStr} at ${oldTime12.en} ` +
              `to ${dateStr} at ${time12.en}.`,
          },
        };
      }
      return {
        ar: {
          title: `${LTR}🕒 تم تغيير الموعد`,
          body: `${LTR}${patientName} غيّر موعده إلى ${dateStr} الساعة ${time12.ar}.`,
        },
        en: {
          title: `${LTR}🕒 Appointment rescheduled`,
          body: `${LTR}${patientName} rescheduled to ${dateStr} at ${time12.en}.`,
        },
      };
    }
    case "pro.appointment.patient_arrived":
      return {
        ar: {
          title: `${LTR}🚪 وصل المريض`,
          body: `${LTR}${patientName} في غرفة الانتظار.`,
        },
        en: {
          title: `${LTR}🚪 Patient arrived`,
          body: `${LTR}${patientName} is in the waiting room.`,
        },
      };
    case "pro.appointment.no_show_auto":
      return {
        ar: {
          title: `${LTR}⏰ لم يحضر المريض`,
          body: `${LTR}${patientName} لم يحضر لموعده.`,
        },
        en: {
          title: `${LTR}⏰ Patient did not arrive`,
          body: `${LTR}${patientName} did not attend their appointment.`,
        },
      };
    default:
      return {
        ar: { title: `${LTR}📅 تحديث موعد`, body: `${LTR}${patientName}` },
        en: { title: `${LTR}📅 Appointment update`, body: `${LTR}${patientName}` },
      };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function format12h(rawTime: string | null | undefined): { ar: string; en: string } {
  if (!rawTime) return { ar: "", en: "" };
  const parts = rawTime.toString().split(":");
  let h = parseInt(parts[0], 10);
  const mm = parts[1] || "00";
  const isPm = h >= 12;
  if (h === 0) h = 12;
  else if (h > 12) h -= 12;
  return {
    ar: `${h}:${mm} ${isPm ? "م" : "ص"}`,
    en: `${h}:${mm} ${isPm ? "PM" : "AM"}`,
  };
}

/// Same shape as format12h but takes a full ISO timestamp instead of
/// a HH:MM string. Used for reschedule lineage — the old row's
/// timestamp is a timestamptz, not a time-of-day string.
function format12hFromIso(iso: string): { ar: string; en: string } {
  try {
    const d = new Date(iso);
    let h = d.getUTCHours();
    const mm = d.getUTCMinutes().toString().padStart(2, "0");
    const isPm = h >= 12;
    if (h === 0) h = 12;
    else if (h > 12) h -= 12;
    return {
      ar: `${h}:${mm} ${isPm ? "م" : "ص"}`,
      en: `${h}:${mm} ${isPm ? "PM" : "AM"}`,
    };
  } catch (_) {
    return { ar: "", en: "" };
  }
}

function isAppointmentToday(record: Record<string, any>): boolean {
  const dateStr = record.appointment_date as string | undefined;
  if (!dateStr) return false;
  const today = new Date();
  const y = today.getUTCFullYear().toString().padStart(4, "0");
  const m = (today.getUTCMonth() + 1).toString().padStart(2, "0");
  const d = today.getUTCDate().toString().padStart(2, "0");
  return dateStr === `${y}-${m}-${d}`;
}

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

/// Resolve a doctor's center_id from center_members when the
/// appointments row's center_id is null (booking flows don't always
/// populate it). Returns null when the doctor isn't on a team —
/// in which case the handler skips and the patient-side flow handles
/// notifications for that booking.
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
    .order("joined_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error || !data) return null;
  return (data as { center_id: string }).center_id;
}
