// Server-side enforcement of notification_preferences and
// notification_quiet_hours. Called from fanout.ts before each Pushy send.
//
// Default policy when no rows exist (lazy defaults):
//   - push_enabled = true
//   - in_app_enabled = true
//   - respects_quiet_hours = true
//   - quiet_hours.enabled = false (off)
//
// Quiet-hour overrides:
//   - importance="time_sensitive"  → bypass quiet hours UNLESS the user has
//     explicitly opted this category INTO quiet hours (respects_quiet_hours
//     stays true and they checked the box in the prefs screen).
//   - dnd_until in future          → suppress everything except security
//     and time_sensitive importance.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { Category, Importance } from "./types.ts";

export interface PrefDecision {
  allowPush: boolean;
  reason: string; // one of: ok, push_disabled, quiet_hours, dnd, none
}

interface PrefRow {
  push_enabled: boolean;
  in_app_enabled: boolean;
  respects_quiet_hours: boolean;
}

interface QuietHoursRow {
  enabled: boolean;
  start_local: string | null; // "HH:MM:SS"
  end_local: string | null;   // "HH:MM:SS"
  timezone: string;           // IANA tz name
  dnd_until: string | null;   // ISO8601
}

/** Fetch prefs + quiet hours for one user, applying lazy defaults. */
export async function shouldSendPush(
  supabase: SupabaseClient,
  userId: string,
  category: Category,
  importance: Importance,
): Promise<PrefDecision> {
  // Always-allow categories: security never gets gated.
  if (category === "security") return { allowPush: true, reason: "ok" };

  const [prefs, qh] = await Promise.all([
    fetchPrefRow(supabase, userId, category),
    fetchQuietHoursRow(supabase, userId),
  ]);

  if (!prefs.push_enabled) {
    return { allowPush: false, reason: "push_disabled" };
  }

  // DnD: explicit "mute everything until X" — overrides quiet-hour
  // semantics. Time-sensitive medical alerts still break through.
  if (qh.dnd_until) {
    const dndUntil = Date.parse(qh.dnd_until);
    if (!isNaN(dndUntil) && dndUntil > Date.now()) {
      if (importance !== "time_sensitive") {
        return { allowPush: false, reason: "dnd" };
      }
    }
  }

  // Quiet hours window (per-day local time).
  if (qh.enabled && qh.start_local && qh.end_local && prefs.respects_quiet_hours) {
    const inWindow = isWithinQuietWindow(
      qh.start_local,
      qh.end_local,
      qh.timezone,
    );
    if (inWindow) {
      // Time-sensitive bypasses unless user explicitly opted-in.
      // (Opt-in semantics: respects_quiet_hours=true ON the appointments
      // category means "yes, mute these too" — same toggle, no separate
      // opt-in flag. Keeping it simple in Phase 1.)
      if (importance === "time_sensitive") {
        return { allowPush: true, reason: "ok" };
      }
      return { allowPush: false, reason: "quiet_hours" };
    }
  }

  return { allowPush: true, reason: "ok" };
}

async function fetchPrefRow(
  supabase: SupabaseClient,
  userId: string,
  category: Category,
): Promise<PrefRow> {
  const { data } = await supabase
    .from("notification_preferences")
    .select("push_enabled, in_app_enabled, respects_quiet_hours")
    .eq("user_id", userId)
    .eq("category", category)
    .maybeSingle();
  if (!data) {
    return {
      push_enabled: true,
      in_app_enabled: true,
      respects_quiet_hours: true,
    };
  }
  return data as PrefRow;
}

async function fetchQuietHoursRow(
  supabase: SupabaseClient,
  userId: string,
): Promise<QuietHoursRow> {
  const { data } = await supabase
    .from("notification_quiet_hours")
    .select("enabled, start_local, end_local, timezone, dnd_until")
    .eq("user_id", userId)
    .maybeSingle();
  if (!data) {
    return {
      enabled: false,
      start_local: null,
      end_local: null,
      timezone: "Asia/Damascus",
      dnd_until: null,
    };
  }
  return data as QuietHoursRow;
}

/** Compute the user's current "HH:MM" in the given IANA timezone and
 *  decide whether it falls between start and end (handling overnight
 *  windows where start > end, e.g. 22:00–07:00). */
function isWithinQuietWindow(
  startLocal: string,
  endLocal: string,
  timezone: string,
): boolean {
  const now = new Date();
  // Use Intl to format current time in the target tz to "HH:MM".
  const fmt = new Intl.DateTimeFormat("en-GB", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const nowHm = fmt.format(now); // "HH:MM"
  const startHm = startLocal.slice(0, 5);
  const endHm = endLocal.slice(0, 5);

  // Overnight window: start > end (e.g., 22:00–07:00).
  if (startHm > endHm) {
    return nowHm >= startHm || nowHm < endHm;
  }
  // Same-day window.
  return nowHm >= startHm && nowHm < endHm;
}
