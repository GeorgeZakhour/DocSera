// Shared types for the push_notifications edge function.

export type RecipientApp = "docsera" | "docsera_pro";

export type Importance = "low" | "default" | "high" | "time_sensitive";

export type Category =
  | "appointments"
  | "messages"
  | "documents"
  | "reports"
  | "loyalty"
  | "security"
  | "marketing"
  | "system"
  | "health"
  | "relatives"
  // Pro additions (Phase 2):
  | "team"
  | "clinic_ops"
  | "subscription"
  | "verification"
  | "tasks";

// What a handler returns. The dispatcher takes this and (a) inserts a
// notifications row per user, (b) sends Pushy. Returning null means
// "this webhook event doesn't produce a notification" (skip path).
export interface NotificationIntent {
  user_ids: string[];
  recipient_app: RecipientApp;
  event_code: string;
  category: Category;
  // Default copy (used for the persisted row + as fallback when no
  // localized variant is registered for the device's locale).
  title: string;
  body: string;
  // Optional per-locale variants. If present, fanout picks the variant
  // matching the device's user_devices.locale; otherwise falls back to
  // title/body. This is the migration path away from AR-only copy.
  localized?: Record<"ar" | "en", { title: string; body: string }>;
  deep_link: string;
  data?: Record<string, unknown>;
  importance?: Importance;
  // Idempotency key. If two webhook firings produce the same dedup_key for
  // the same (user_id, event_code), only the first row is created.
  dedup_key?: string | null;
  locale?: "ar" | "en";
}

// What the DB webhook delivers, plus a synthetic "EMIT" type from
// fn_emit_notification (SQL-side helper) that signals "row already
// persisted, just fanout".
export interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE" | "EMIT";
  table: string;
  schema: string;
  record: Record<string, any> | null;
  old_record: Record<string, any> | null;
}
