// Handler: doctor_verifications table — DocSera-Pro only.
//
// Covers Phase 2 catalog rows 30-33:
//
//   30  pro.verification.submitted         status → submitted
//   31  pro.verification.approved          status → verified
//   32  pro.verification.rejected          status → rejected
//   33  pro.verification.partial_doc_rejected
//                                          license_status or id_status
//                                          flipped to 'rejected' while
//                                          the overall status hasn't
//
// All four events target the doctor whose verification row changed.
// Resolved via center_members.doctor_id = record.doctor_id (the same
// pattern used by pro_appointments).

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

export async function handleProVerifications(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent[]> {
  const { type, record, old_record } = payload;
  if (!record || !record.doctor_id) return [];

  const evt = classify(type, record, old_record);
  if (!evt) return [];

  const userId = await lookupUserIdForDoctor(supabase, record.doctor_id);
  if (!userId) return [];

  const copy = renderCopy(evt.code, record);

  return [
    {
      user_ids: [userId],
      recipient_app: "docsera_pro",
      event_code: evt.code,
      category: "verification",
      title: copy.ar.title,
      body: copy.ar.body,
      localized: copy,
      deep_link: "verification:",
      data: {
        verification_id: record.id,
        doctor_id: record.doctor_id,
        status: record.status,
        license_status: record.license_status,
        id_status: record.id_status,
        rejection_reason: record.rejection_reason,
      },
      importance: evt.importance,
      // verification.submitted dedup-keyed by record.id keeps the
      // toggle of "submit → review → re-submit" from spamming. The
      // approved / rejected events use status as the discriminator so
      // a re-review can re-emit.
      dedup_key: `${evt.code}:${record.id}:${record.status ?? ""}`,
      locale: "ar",
    },
  ];
}

// ---------------------------------------------------------------------------
// Classifier
// ---------------------------------------------------------------------------

function classify(
  type: WebhookPayload["type"],
  record: Record<string, any>,
  old_record: Record<string, any> | null,
): { code: string; importance: "low" | "default" | "high" | "time_sensitive" } | null {
  const oldStatus = old_record?.status ?? null;
  const newStatus = record.status ?? null;

  if (type === "INSERT") {
    if (newStatus === "submitted") {
      return { code: "pro.verification.submitted", importance: "default" };
    }
    return null;
  }

  if (type !== "UPDATE" || !old_record) return null;

  if (newStatus !== oldStatus) {
    if (newStatus === "submitted") {
      return { code: "pro.verification.submitted", importance: "default" };
    }
    if (newStatus === "verified") {
      return { code: "pro.verification.approved", importance: "high" };
    }
    if (newStatus === "rejected") {
      return { code: "pro.verification.rejected", importance: "high" };
    }
  }

  // Partial-doc rejection — granular field flipped to rejected while
  // overall is still pending. The doctor needs to know which doc was
  // the problem so they can re-upload one of the two.
  const oldLicense = old_record.license_status ?? null;
  const newLicense = record.license_status ?? null;
  const oldId = old_record.id_status ?? null;
  const newId = record.id_status ?? null;
  const overallStillPending = newStatus === "submitted" ||
    newStatus === "pending";

  if (overallStillPending) {
    if (newLicense === "rejected" && oldLicense !== "rejected") {
      return {
        code: "pro.verification.partial_doc_rejected",
        importance: "high",
      };
    }
    if (newId === "rejected" && oldId !== "rejected") {
      return {
        code: "pro.verification.partial_doc_rejected",
        importance: "high",
      };
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// Copy registry
// ---------------------------------------------------------------------------

function renderCopy(
  eventCode: string,
  record: Record<string, any>,
): { ar: { title: string; body: string }; en: { title: string; body: string } } {
  switch (eventCode) {
    case "pro.verification.submitted":
      return {
        ar: {
          title: `${LTR}🔎 طلب التحقق قيد المراجعة`,
          body:
            `${LTR}تم استلام مستنداتك — سنُعلمك بمجرد اكتمال المراجعة.`,
        },
        en: {
          title: `${LTR}🔎 Verification under review`,
          body:
            `${LTR}We've received your documents — you'll be notified once review completes.`,
        },
      };
    case "pro.verification.approved":
      return {
        ar: {
          title: `${LTR}✅ تم التحقق من حسابك`,
          body:
            `${LTR}مبروك! يمكنك الآن استخدام جميع ميزات DocSera Pro.`,
        },
        en: {
          title: `${LTR}✅ Your account is verified`,
          body:
            `${LTR}You're all set — every DocSera Pro feature is unlocked.`,
        },
      };
    case "pro.verification.rejected": {
      const reason = (record.rejection_reason ?? "").toString().trim();
      const arBody = reason.length > 0
        ? `${LTR}سبب الرفض: ${reason}`
        : `${LTR}يرجى مراجعة طلب التحقق وإعادة الإرسال.`;
      const enBody = reason.length > 0
        ? `${LTR}Reason: ${reason}`
        : `${LTR}Please review your verification request and resubmit.`;
      return {
        ar: {
          title: `${LTR}❌ طلب التحقق مرفوض`,
          body: arBody,
        },
        en: {
          title: `${LTR}❌ Verification rejected`,
          body: enBody,
        },
      };
    }
    case "pro.verification.partial_doc_rejected": {
      const which =
        record.license_status === "rejected" ? "license" : "id";
      const arWhich = which === "license"
        ? "وثيقة الترخيص"
        : "وثيقة الهوية";
      const enWhich = which === "license"
        ? "your license document"
        : "your ID document";
      const note = (which === "license"
        ? record.license_note
        : record.id_note) ?? "";
      const arNote = note ? ` — ${note}` : "";
      const enNote = note ? ` — ${note}` : "";
      return {
        ar: {
          title: `${LTR}⚠️ يحتاج إعادة رفع`,
          body: `${LTR}${arWhich} مرفوضة${arNote}.`,
        },
        en: {
          title: `${LTR}⚠️ Re-upload required`,
          body: `${LTR}${enWhich} was rejected${enNote}.`,
        },
      };
    }
    default:
      return {
        ar: { title: `${LTR}🔎 تحديث التحقق`, body: `${LTR}—` },
        en: { title: `${LTR}🔎 Verification update`, body: `${LTR}—` },
      };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function lookupUserIdForDoctor(
  supabase: SupabaseClient,
  doctorId: string,
): Promise<string | null> {
  const { data } = await supabase
    .from("center_members")
    .select("user_id")
    .eq("doctor_id", doctorId)
    .eq("is_active", true)
    .is("removed_at", null)
    .order("joined_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  return (data?.user_id as string | null) ?? null;
}
