// Handler: subscriptions table — DocSera-Pro only.
//
// One single event today: pro.subscription.renewed — when `paid_until`
// is moved forward (i.e. an owner / admin renewed the subscription).
// The other subscription lifecycle moments (trial_ending_soon,
// expiring_soon, expired_grace, expired_blocked) are cron-driven by
// fn_cron_pro_subscription_warnings — see the matching migration.
//
// Recipients: owner + admins of the center, resolved via
// fn_resolve_recipients('pro.subscription.*', { center_id }).

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

export async function handleProSubscriptions(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent[]> {
  const { type, record, old_record } = payload;
  if (type !== "UPDATE" || !record || !old_record) return [];

  const oldPaidUntil = old_record.paid_until ?? null;
  const newPaidUntil = record.paid_until ?? null;

  // Renewal == paid_until moved forward.
  const renewed = oldPaidUntil && newPaidUntil &&
    new Date(newPaidUntil) > new Date(oldPaidUntil);
  if (!renewed) return [];

  const centerId = record.center_id;
  if (!centerId) return [];

  const { data: recipients, error } = await supabase
    .rpc("fn_resolve_recipients", {
      p_event_code: "pro.subscription.renewed",
      p_ctx: { center_id: centerId },
    });
  if (error) {
    console.error("[pro_subscriptions] resolver error:", error);
    return [];
  }
  const userIds = normalizeUuidList(recipients);
  if (userIds.length === 0) return [];

  const paidUntilDate = new Date(newPaidUntil).toISOString().slice(0, 10);

  return [
    {
      user_ids: userIds,
      recipient_app: "docsera_pro",
      event_code: "pro.subscription.renewed",
      category: "subscription",
      title: `${LTR}🎉 تم تجديد الاشتراك`,
      body: `${LTR}اشتراكك ساري حتى ${paidUntilDate}.`,
      localized: {
        ar: {
          title: `${LTR}🎉 تم تجديد الاشتراك`,
          body: `${LTR}اشتراكك ساري حتى ${paidUntilDate}.`,
        },
        en: {
          title: `${LTR}🎉 Subscription renewed`,
          body: `${LTR}You're paid through ${paidUntilDate}.`,
        },
      },
      deep_link: "subscription:",
      data: {
        subscription_id: record.id,
        center_id: centerId,
        paid_until: newPaidUntil,
      },
      importance: "default",
      // Dedup on the new paid_until — a second click won't fire twice.
      dedup_key: `pro.subscription.renewed:${record.id}:${newPaidUntil}`,
      locale: "ar",
    },
  ];
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
