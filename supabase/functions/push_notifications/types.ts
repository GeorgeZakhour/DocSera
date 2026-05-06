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
  | "relatives";

// What a handler returns. The dispatcher takes this and (a) inserts a
// notifications row per user, (b) sends Pushy. Returning null means
// "this webhook event doesn't produce a notification" (skip path).
export interface NotificationIntent {
  user_ids: string[];
  recipient_app: RecipientApp;
  event_code: string;
  category: Category;
  title: string;
  body: string;
  deep_link: string;
  data?: Record<string, unknown>;
  importance?: Importance;
  // Idempotency key. If two webhook firings produce the same dedup_key for
  // the same (user_id, event_code), only the first row is created.
  dedup_key?: string | null;
  locale?: "ar" | "en";
}

// What the DB webhook delivers.
export interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: Record<string, any> | null;
  old_record: Record<string, any> | null;
}
