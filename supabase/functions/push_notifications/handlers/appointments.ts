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

  // Always fire — the patient gets either the "request received,
  // awaiting confirmation" copy (when pending) or the "appointment
  // confirmed" copy (when auto-confirmed at booking time). The
  // distinction is on is_confirmed below.

  const appointmentDate = record.appointment_date || "";
  const rawTime = record.appointment_time || "";

  // 24h → 12h display. Same digits, locale-specific period suffix.
  let h12 = "";
  let mm = "00";
  let isPm = false;
  if (rawTime) {
    const parts = rawTime.split(":");
    let h = parseInt(parts[0], 10);
    mm = parts[1] || "00";
    isPm = h >= 12;
    if (h === 0) h = 12;
    else if (h > 12) h -= 12;
    h12 = String(h);
  }
  const displayTimeAr = h12 ? `${h12}:${mm} ${isPm ? "م" : "ص"}` : "";
  const displayTimeEn = h12 ? `${h12}:${mm} ${isPm ? "PM" : "AM"}` : "";

  // Differentiate by is_confirmed at creation time. Auto-confirmed
  // bookings (e.g. clinic staff books on patient's behalf and confirms
  // in the same flow) get the "appointment confirmed" copy. Pending
  // bookings get the "request received, awaiting confirmation" copy.
  const isConfirmed = record.is_confirmed === true;
  const eventCode = isConfirmed
    ? "appointment.confirmed"
    : "appointment.pending_received";

  let titleAr: string;
  let titleEn: string;
  let bodyAr: string;
  let bodyEn: string;

  if (isConfirmed) {
    titleAr = `${LTR}✅ موعد جديد مؤكد`;
    titleEn = `${LTR}✅ New confirmed appointment`;
    bodyAr =
      `${LTR}تم تأكيد موعدك مع ${doctorName} بتاريخ ${appointmentDate} الساعة ${displayTimeAr}.`;
    bodyEn =
      `${LTR}Your appointment with ${doctorName} on ${appointmentDate} at ${displayTimeEn} is confirmed.`;
  } else {
    titleAr = `${LTR}📨 تم استلام طلب الحجز`;
    titleEn = `${LTR}📨 Booking request received`;
    bodyAr =
      `${LTR}طلب موعد مع ${doctorName} بتاريخ ${appointmentDate} الساعة ${displayTimeAr} — بانتظار تأكيد الطبيب.`;
    bodyEn =
      `${LTR}A booking request was sent to ${doctorName} for ${appointmentDate} at ${displayTimeEn} — awaiting doctor confirmation.`;
  }

  return {
    user_ids: [record.user_id],
    recipient_app: "docsera",
    event_code: eventCode,
    category: "appointments",
    title: titleAr,
    body: bodyAr,
    localized: {
      ar: { title: titleAr, body: bodyAr },
      en: { title: titleEn, body: bodyEn },
    },
    deep_link: `appointment:${record.id}`,
    data: { appointment_id: record.id },
    importance: "high",
    dedup_key: `apt-${eventCode}:${record.id}`,
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

  let titleAr = "";
  let titleEn = "";
  let bodyAr = "";
  let bodyEn = "";
  let event_code = "";
  let deep_link = `appointment:${record.id}`;
  let dedup_key: string | null = null;

  // 1. Doctor explicitly REJECTED a request (newStatus = 'rejected').
  // This is the "doctor said no" case — only fires when the doctor
  // chose to reject the request specifically, not when an appointment
  // gets cancelled for an external reason like a vacation.
  if (newStatus === "rejected" && oldStatus !== "rejected") {
    titleAr = `${LTR}⛔ تم رفض طلب الحجز`;
    titleEn = `${LTR}⛔ Booking declined`;
    bodyAr =
      `${LTR}نعتذر، لا يمكن للدكتور ${doctorName} قبول طلبك في هذا الوقت.`;
    bodyEn =
      `${LTR}Dr. ${doctorName} could not accept your booking at this time.`;
    if (record.rejection_reason) {
      bodyAr += ` ${record.rejection_reason}`;
      bodyEn += ` ${record.rejection_reason}`;
    }
    event_code = "appointment.rejected";
    dedup_key = `apt-rejected:${record.id}`;
  } // 2. Cancelled by doctor — covers BOTH pending cancellations and
  // confirmed cancellations. Triggered by status='cancelled' or
  // 'cancelled_by_doctor' (from the bulk-cancel-on-vacation flow or
  // any explicit doctor-side cancellation). Copy is consistent
  // regardless of the appointment's prior confirmed/pending state.
  else if (
    (newStatus === "cancelled" || newStatus === "cancelled_by_doctor") &&
    oldStatus !== "cancelled" && oldStatus !== "cancelled_by_doctor"
  ) {
    titleAr = `${LTR}❌ تم إلغاء الموعد`;
    titleEn = `${LTR}❌ Appointment cancelled`;
    bodyAr = `${LTR}تم إلغاء موعدك مع ${doctorName}.`;
    bodyEn = `${LTR}Your appointment with Dr. ${doctorName} has been cancelled.`;
    if (record.rejection_reason) {
      bodyAr += ` السبب: ${record.rejection_reason}`;
      bodyEn += ` Reason: ${record.rejection_reason}`;
    }
    event_code = "appointment.cancelled_by_doctor";
    dedup_key = `apt-cancelled:${record.id}`;
  } // 3. Confirmed
  else if (
    (newStatus === "confirmed" && oldStatus !== "confirmed") ||
    (isConfirmedBool === true && old_record.is_confirmed !== true &&
      newStatus !== "rejected" && newStatus !== "cancelled" &&
      newStatus !== "cancelled_by_doctor")
  ) {
    titleAr = `${LTR}✅ تم تثبيت الحجز`;
    titleEn = `${LTR}✅ Appointment confirmed`;
    bodyAr = `${LTR}تم تأكيد موعدك مع ${doctorName}.`;
    bodyEn = `${LTR}Your appointment with Dr. ${doctorName} has been confirmed.`;
    event_code = "appointment.confirmed";
    dedup_key = `apt-confirmed:${record.id}`;
  } // 4. Rescheduled (time changed)
  else if (
    newTime !== oldTime &&
    (newStatus === "pending" || newStatus === "confirmed" ||
      newStatus === "not_arrived" || newStatus === "")
  ) {
    titleAr = `${LTR}🕒 تم تغيير الموعد`;
    titleEn = `${LTR}🕒 Appointment rescheduled`;
    bodyAr =
      `${LTR}تم تغيير وقت موعدك مع ${doctorName}، يرجى مراجعة التطبيق.`;
    bodyEn =
      `${LTR}Your appointment with Dr. ${doctorName} has been rescheduled. Open the app for the new time.`;
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
      titleAr = `${LTR}📄 تقرير طبي جديد`;
      titleEn = `${LTR}📄 New medical report`;
      bodyAr = `${LTR}أضاف الدكتور ${doctorName} تقريراً طبياً لموعدك.`;
      bodyEn = `${LTR}Dr. ${doctorName} added a medical report to your visit.`;
      event_code = "report.added";
      dedup_key = `apt-report-added:${record.id}`;
    } else if (hasNew && hadOld) {
      titleAr = `${LTR}📝 تحديث التقرير الطبي`;
      titleEn = `${LTR}📝 Medical report updated`;
      bodyAr =
        `${LTR}قام الدكتور ${doctorName} بتعديل التقرير الطبي لموعدك.`;
      bodyEn =
        `${LTR}Dr. ${doctorName} updated the medical report for your visit.`;
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
    title: titleAr,
    body: bodyAr,
    localized: {
      ar: { title: titleAr, body: bodyAr },
      en: { title: titleEn, body: bodyEn },
    },
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
