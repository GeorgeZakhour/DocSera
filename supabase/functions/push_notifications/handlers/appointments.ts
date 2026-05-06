// Handler: appointments INSERT and UPDATE.
// Branches preserved verbatim from the previous monolithic index.ts —
// 5 distinct events (booked, rejected, cancelled, confirmed, rescheduled,
// report-added, report-updated) gated by status / is_confirmed / time / report
// transitions on UPDATE.

import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

export function handleAppointments(
  payload: WebhookPayload,
): NotificationIntent | null {
  const { type, record, old_record } = payload;
  if (!record) return null;

  const doctorName = record.doctor_name || "الطبيب";

  if (type === "INSERT") {
    return handleInsert(record, doctorName);
  }

  if (type === "UPDATE" && old_record) {
    return handleUpdate(record, old_record, doctorName);
  }

  return null;
}

function handleInsert(
  record: Record<string, any>,
  doctorName: string,
): NotificationIntent | null {
  // Manual patients (no DocSera account) skipped.
  if (!record.user_id) return null;

  const appointmentDate = record.appointment_date || "";
  const rawTime = record.appointment_time || "";

  // 24h → 12h Arabic display ("17:00:00" → "5:00 م")
  let displayTime = rawTime;
  if (rawTime) {
    const parts = rawTime.split(":");
    let h = parseInt(parts[0], 10);
    const m = parts[1] || "00";
    const period = h >= 12 ? "م" : "ص";
    if (h === 0) h = 12;
    else if (h > 12) h -= 12;
    displayTime = `${h}:${m} ${period}`;
  }

  return {
    user_ids: [record.user_id],
    recipient_app: "docsera",
    event_code: "appointment.booked",
    category: "appointments",
    title: `${LTR}📅 موعد جديد`,
    body:
      `${LTR}تم حجز موعد لك مع ${doctorName} بتاريخ ${appointmentDate} الساعة ${displayTime}.`,
    deep_link: `appointment:${record.id}`,
    data: { appointment_id: record.id },
    importance: "high",
    dedup_key: `apt-booked:${record.id}`,
    locale: "ar",
  };
}

function handleUpdate(
  record: Record<string, any>,
  old_record: Record<string, any>,
  doctorName: string,
): NotificationIntent | null {
  const oldStatus = old_record.status ?? null;
  const newStatus = record.status;
  const oldTime = old_record.timestamp ?? null;
  const newTime = record.timestamp;
  const oldReport = old_record.report ?? null;
  const newReport = record.report ?? null;
  const isConfirmedBool = record.is_confirmed;
  const oldConfirmedBool = old_record.is_confirmed;

  let title = "";
  let body = "";
  let event_code = "";
  let deep_link = `appointment:${record.id}`;
  let dedup_key: string | null = null;

  // 1. Rejected (Pending → Rejected/Cancelled, never confirmed)
  if (
    (newStatus === "rejected" || newStatus === "cancelled" ||
      newStatus === "cancelled_by_doctor") &&
    (oldStatus === "pending" || oldStatus === "not_arrived" ||
      oldStatus === null || oldStatus === "") &&
    oldConfirmedBool !== true
  ) {
    title = `${LTR}⛔ تم رفض طلب الحجز`;
    body =
      `${LTR}نعتذر، لا يمكن للدكتور ${doctorName} قبول طلبك في هذا الوقت.`;
    if (record.rejection_reason) body += ` ${record.rejection_reason}`;
    event_code = "appointment.rejected";
    dedup_key = `apt-rejected:${record.id}`;
  } // 2. Cancelled by doctor (Confirmed → Cancelled)
  else if (
    (newStatus === "cancelled" || newStatus === "rejected" ||
      newStatus === "cancelled_by_doctor") &&
    (oldStatus === "confirmed" || oldConfirmedBool === true)
  ) {
    title = `${LTR}❌ تم إلغاء الموعد`;
    body = `${LTR}تم إلغاء موعدك المؤكد مع ${doctorName}.`;
    if (record.rejection_reason) body += ` السبب: ${record.rejection_reason}`;
    event_code = "appointment.cancelled_by_doctor";
    dedup_key = `apt-cancelled:${record.id}`;
  } // 3. Confirmed
  else if (
    (newStatus === "confirmed" && oldStatus !== "confirmed") ||
    (isConfirmedBool === true && old_record.is_confirmed !== true &&
      newStatus !== "rejected" && newStatus !== "cancelled" &&
      newStatus !== "cancelled_by_doctor")
  ) {
    title = `${LTR}✅ تم تثبيت الحجز`;
    body = `${LTR}تم تأكيد موعدك مع ${doctorName}.`;
    event_code = "appointment.confirmed";
    dedup_key = `apt-confirmed:${record.id}`;
  } // 4. Rescheduled (time changed)
  else if (
    newTime !== oldTime &&
    (newStatus === "pending" || newStatus === "confirmed" ||
      newStatus === "not_arrived" || newStatus === "")
  ) {
    title = `${LTR}🕒 تم تغيير الموعد`;
    body =
      `${LTR}تم تغيير وقت موعدك مع ${doctorName}، يرجى مراجعة التطبيق.`;
    event_code = "appointment.rescheduled";
    // Use the new timestamp in the dedup key so each reschedule notifies once.
    dedup_key = `apt-rescheduled:${record.id}:${newTime}`;
  } // 5. Report added or updated
  else if (JSON.stringify(newReport) !== JSON.stringify(oldReport)) {
    const hasNew = newReport &&
      (typeof newReport === "string"
        ? newReport.trim().length > 0
        : Object.keys(newReport).length > 0);
    const hadOld = oldReport &&
      (typeof oldReport === "string"
        ? oldReport.trim().length > 0
        : Object.keys(oldReport).length > 0);

    if (hasNew && !hadOld) {
      title = `${LTR}📄 تقرير طبي جديد`;
      body = `${LTR}أضاف الدكتور ${doctorName} تقريراً طبياً لموعدك.`;
      event_code = "report.added";
      dedup_key = `apt-report-added:${record.id}`;
    } else if (hasNew && hadOld) {
      title = `${LTR}📝 تحديث التقرير الطبي`;
      body =
        `${LTR}قام الدكتور ${doctorName} بتعديل التقرير الطبي لموعدك.`;
      event_code = "report.edited";
      // Reports can be edited many times — don't dedup or only the first
      // edit notification will fire. NULL = always allow.
      dedup_key = null;
    } else {
      return null; // Report removed or empty change — skip.
    }

    const relId = record.relative_id || "null";
    const patName = record.patient_name || "Patient";
    deep_link = `report:${record.id}:${relId}:${patName}`;
  } else {
    return null; // No relevant transition.
  }

  if (!record.user_id) return null;

  return {
    user_ids: [record.user_id],
    recipient_app: "docsera",
    event_code,
    category: event_code.startsWith("report.") ? "reports" : "appointments",
    title,
    body,
    deep_link,
    data: {
      appointment_id: record.id,
      status: newStatus,
      relative_id: record.relative_id ?? null,
      patient_name: record.patient_name ?? null,
    },
    importance: "high",
    dedup_key,
    locale: "ar",
  };
}
