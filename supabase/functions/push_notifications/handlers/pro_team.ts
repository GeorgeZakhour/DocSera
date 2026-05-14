// Handler: team / membership events on DocSera-Pro.
//
// Covers Phase 2 catalog rows 10–17:
//
//   10  pro.team.invitation_received      center_invitations INSERT
//   11  pro.team.invitation_accepted      center_invitations UPDATE
//                                          accepted_user_id IS NULL → set
//   12  pro.team.invitation_declined      center_invitations UPDATE
//                                          declined_at set
//   13  pro.team.member_added             center_members INSERT
//   14  pro.team.member_removed           center_members UPDATE
//                                          removed_at IS NULL → set
//   15  pro.team.role_changed             center_members UPDATE roles
//   16  pro.team.permissions_changed      center_members UPDATE perms
//   17  pro.team.assigned_doctor_changed  center_members UPDATE
//                                          assigned_doctor_ids
//
// Unlike pro_appointments.ts these events compute recipients from the
// changing row itself (invitee, inviter, the removed member). The SQL
// resolver's pro.team.* branch is used only for fanouts that want
// "owner + admins of the center" (e.g. an audit copy when a member is
// removed). Otherwise the handler builds user_ids[] inline.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import type { NotificationIntent, WebhookPayload } from "../types.ts";

const LTR = "‎";

export async function handleProTeam(
  supabase: SupabaseClient,
  payload: WebhookPayload,
): Promise<NotificationIntent[]> {
  const { table, type, record, old_record } = payload;
  if (table === "center_invitations") {
    return handleInvitations(supabase, type, record, old_record);
  }
  if (table === "center_members") {
    return handleMembers(supabase, type, record, old_record);
  }
  return [];
}

// ---------------------------------------------------------------------------
// center_invitations
// ---------------------------------------------------------------------------

async function handleInvitations(
  supabase: SupabaseClient,
  type: WebhookPayload["type"],
  record: Record<string, any> | null,
  old_record: Record<string, any> | null,
): Promise<NotificationIntent[]> {
  if (!record) return [];

  // Invitation received — INSERT. Recipient is the invitee, resolved
  // by phone or email. If no auth user exists yet (most realistic
  // case at this stage), skip — they'll see it in the SMS/email path
  // and create an account first.
  if (type === "INSERT") {
    const inviteeUserId = await lookupAuthUserByPhoneOrEmail(
      supabase,
      record.phone,
      record.email,
    );
    if (!inviteeUserId) return [];
    const centerName = await lookupCenterName(supabase, record.center_id);
    return [
      {
        user_ids: [inviteeUserId],
        recipient_app: "docsera_pro",
        event_code: "pro.team.invitation_received",
        category: "team",
        title: `${LTR}✉️ دعوة جديدة`,
        body: `${LTR}تمت دعوتك للانضمام إلى ${centerName} كـ${roleLabel(record.role)}.`,
        localized: {
          ar: {
            title: `${LTR}✉️ دعوة جديدة`,
            body:
              `${LTR}تمت دعوتك للانضمام إلى ${centerName} كـ${roleLabel(record.role)}.`,
          },
          en: {
            title: `${LTR}✉️ New invitation`,
            body:
              `${LTR}You've been invited to join ${centerName} as ${roleLabelEn(
                record.role,
              )}.`,
          },
        },
        deep_link: `team_invite:${record.id}`,
        data: { invitation_id: record.id, center_id: record.center_id },
        importance: "high",
        dedup_key: `pro.team.invitation_received:${record.id}`,
        locale: "ar",
      },
    ];
  }

  if (type !== "UPDATE" || !old_record) return [];

  // Invitation accepted — accepted_user_id transitioned null → uuid.
  if (
    old_record.accepted_user_id == null && record.accepted_user_id != null
  ) {
    const recipients = await collectOwnersAndInviter(
      supabase,
      record.center_id,
      record.created_by,
    );
    if (recipients.length === 0) return [];
    const inviteeName = await lookupAuthName(
      supabase,
      record.accepted_user_id,
    );
    return [
      {
        user_ids: recipients,
        recipient_app: "docsera_pro",
        event_code: "pro.team.invitation_accepted",
        category: "team",
        title: `${LTR}✅ تمت قبول الدعوة`,
        body: `${LTR}${inviteeName} انضم/ت إلى الفريق.`,
        localized: {
          ar: {
            title: `${LTR}✅ تمت قبول الدعوة`,
            body: `${LTR}${inviteeName} انضم/ت إلى الفريق.`,
          },
          en: {
            title: `${LTR}✅ Invitation accepted`,
            body: `${LTR}${inviteeName} joined the team.`,
          },
        },
        deep_link: `team:`,
        data: { invitation_id: record.id, member_user_id: record.accepted_user_id },
        importance: "default",
        dedup_key: `pro.team.invitation_accepted:${record.id}`,
        locale: "ar",
      },
    ];
  }

  // Invitation declined — declined_at transitioned null → timestamp.
  if (old_record.declined_at == null && record.declined_at != null) {
    const recipients = await collectOwnersAndInviter(
      supabase,
      record.center_id,
      record.created_by,
    );
    if (recipients.length === 0) return [];
    const inviteeLabel = (record.name_hint as string | null) ??
      (record.email as string | null) ?? (record.phone as string | null) ??
      "الشخص المدعو";
    return [
      {
        user_ids: recipients,
        recipient_app: "docsera_pro",
        event_code: "pro.team.invitation_declined",
        category: "team",
        title: `${LTR}↩️ تم رفض الدعوة`,
        body: `${LTR}${inviteeLabel} رفض/ت الانضمام.`,
        localized: {
          ar: {
            title: `${LTR}↩️ تم رفض الدعوة`,
            body: `${LTR}${inviteeLabel} رفض/ت الانضمام.`,
          },
          en: {
            title: `${LTR}↩️ Invitation declined`,
            body: `${LTR}${inviteeLabel} declined to join.`,
          },
        },
        deep_link: `team:`,
        data: { invitation_id: record.id },
        importance: "default",
        dedup_key: `pro.team.invitation_declined:${record.id}`,
        locale: "ar",
      },
    ];
  }

  return [];
}

// ---------------------------------------------------------------------------
// center_members
// ---------------------------------------------------------------------------

async function handleMembers(
  supabase: SupabaseClient,
  type: WebhookPayload["type"],
  record: Record<string, any> | null,
  old_record: Record<string, any> | null,
): Promise<NotificationIntent[]> {
  if (!record) return [];

  // Member added — welcome the new member.
  if (type === "INSERT") {
    if (!record.user_id) return [];
    const centerName = await lookupCenterName(supabase, record.center_id);
    return [
      {
        user_ids: [record.user_id],
        recipient_app: "docsera_pro",
        event_code: "pro.team.member_added",
        category: "team",
        title: `${LTR}👋 أهلاً بك`,
        body: `${LTR}انضممت إلى ${centerName} كـ${roleLabel(record.role)}.`,
        localized: {
          ar: {
            title: `${LTR}👋 أهلاً بك`,
            body:
              `${LTR}انضممت إلى ${centerName} كـ${roleLabel(record.role)}.`,
          },
          en: {
            title: `${LTR}👋 Welcome`,
            body:
              `${LTR}You joined ${centerName} as ${roleLabelEn(record.role)}.`,
          },
        },
        deep_link: `team:`,
        data: { center_id: record.center_id, role: record.role },
        importance: "default",
        dedup_key: `pro.team.member_added:${record.id}`,
        locale: "ar",
      },
    ];
  }

  if (type !== "UPDATE" || !old_record) return [];

  // Member removed — removed_at transitioned null → set.
  if (old_record.removed_at == null && record.removed_at != null) {
    if (!record.user_id) return [];
    const centerName = await lookupCenterName(supabase, record.center_id);
    return [
      {
        user_ids: [record.user_id],
        recipient_app: "docsera_pro",
        event_code: "pro.team.member_removed",
        category: "team",
        title: `${LTR}🚪 تم إزالتك`,
        body:
          `${LTR}لم تعد عضواً في ${centerName}.`,
        localized: {
          ar: {
            title: `${LTR}🚪 تم إزالتك`,
            body: `${LTR}لم تعد عضواً في ${centerName}.`,
          },
          en: {
            title: `${LTR}🚪 You've been removed`,
            body: `${LTR}You're no longer a member of ${centerName}.`,
          },
        },
        // No deep link — the user is being signed out; just an inbox row.
        deep_link: "",
        data: { center_id: record.center_id, removal_reason: record.removal_reason },
        importance: "high",
        dedup_key: `pro.team.member_removed:${record.id}`,
        locale: "ar",
      },
    ];
  }

  // Role array changed.
  const rolesChanged = !arraysEqual(record.roles, old_record.roles);
  if (rolesChanged) {
    if (!record.user_id) return [];
    return [
      {
        user_ids: [record.user_id],
        recipient_app: "docsera_pro",
        event_code: "pro.team.role_changed",
        category: "team",
        title: `${LTR}🔄 تم تحديث دورك`,
        body: `${LTR}دورك الجديد: ${rolesLabel(record.roles)}.`,
        localized: {
          ar: {
            title: `${LTR}🔄 تم تحديث دورك`,
            body: `${LTR}دورك الجديد: ${rolesLabel(record.roles)}.`,
          },
          en: {
            title: `${LTR}🔄 Your role was updated`,
            body: `${LTR}New role: ${rolesLabelEn(record.roles)}.`,
          },
        },
        deep_link: `team:`,
        data: { center_id: record.center_id, roles: record.roles },
        importance: "default",
        dedup_key: `pro.team.role_changed:${record.id}:${(record.updated_at ?? "").toString()}`,
        locale: "ar",
      },
    ];
  }

  // Permissions changed — inbox-only (low importance, no push).
  if (!deepEqual(record.permissions, old_record.permissions)) {
    if (!record.user_id) return [];
    return [
      {
        user_ids: [record.user_id],
        recipient_app: "docsera_pro",
        event_code: "pro.team.permissions_changed",
        category: "team",
        title: `${LTR}⚙️ تحديث الصلاحيات`,
        body: `${LTR}تم تحديث صلاحياتك في الفريق.`,
        localized: {
          ar: {
            title: `${LTR}⚙️ تحديث الصلاحيات`,
            body: `${LTR}تم تحديث صلاحياتك في الفريق.`,
          },
          en: {
            title: `${LTR}⚙️ Permissions updated`,
            body: `${LTR}Your team permissions were updated.`,
          },
        },
        deep_link: `team:`,
        data: { center_id: record.center_id },
        importance: "low",
        dedup_key:
          `pro.team.permissions_changed:${record.id}:${(record.updated_at ?? "").toString()}`,
        locale: "ar",
      },
    ];
  }

  // assigned_doctor_ids changed — notify the secretary AND each newly
  // assigned doctor (they want to know "I have a new secretary").
  const oldAssigned: string[] = Array.isArray(old_record.assigned_doctor_ids)
    ? old_record.assigned_doctor_ids
    : [];
  const newAssigned: string[] = Array.isArray(record.assigned_doctor_ids)
    ? record.assigned_doctor_ids
    : [];
  if (!arraysEqual(oldAssigned, newAssigned)) {
    const addedDoctorIds = newAssigned.filter((d) => !oldAssigned.includes(d));
    const intents: NotificationIntent[] = [];

    // Secretary intent
    if (record.user_id) {
      intents.push({
        user_ids: [record.user_id],
        recipient_app: "docsera_pro",
        event_code: "pro.team.assigned_doctor_changed",
        category: "team",
        title: `${LTR}👥 تحديث التعيينات`,
        body: `${LTR}تم تحديث الأطباء المخصصين لك.`,
        localized: {
          ar: {
            title: `${LTR}👥 تحديث التعيينات`,
            body: `${LTR}تم تحديث الأطباء المخصصين لك.`,
          },
          en: {
            title: `${LTR}👥 Assignments updated`,
            body: `${LTR}Your assigned doctors were updated.`,
          },
        },
        deep_link: `team:`,
        data: { center_id: record.center_id, assigned_doctor_ids: newAssigned },
        importance: "default",
        dedup_key:
          `pro.team.assigned_doctor_changed:${record.id}:${(record.updated_at ?? "").toString()}`,
        locale: "ar",
      });
    }

    // Per-doctor intent (for each NEWLY assigned doctor)
    for (const newDocId of addedDoctorIds) {
      const docUserId = await lookupUserIdForDoctor(
        supabase,
        record.center_id,
        newDocId,
      );
      if (!docUserId) continue;
      const secretaryName = await lookupAuthName(supabase, record.user_id);
      intents.push({
        user_ids: [docUserId],
        recipient_app: "docsera_pro",
        event_code: "pro.team.assigned_doctor_changed",
        category: "team",
        title: `${LTR}👥 سكرتير(ة) جديد(ة)`,
        body: `${LTR}${secretaryName} تم تعيينه/ا لمساعدتك.`,
        localized: {
          ar: {
            title: `${LTR}👥 سكرتير(ة) جديد(ة)`,
            body: `${LTR}${secretaryName} تم تعيينه/ا لمساعدتك.`,
          },
          en: {
            title: `${LTR}👥 New secretary assigned`,
            body: `${LTR}${secretaryName} was assigned to assist you.`,
          },
        },
        deep_link: `team:`,
        data: { center_id: record.center_id, secretary_user_id: record.user_id },
        importance: "default",
        dedup_key:
          `pro.team.assigned_doctor_changed:doctor:${record.id}:${newDocId}:${(record.updated_at ?? "").toString()}`,
        locale: "ar",
      });
    }

    return intents;
  }

  return [];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function lookupAuthUserByPhoneOrEmail(
  supabase: SupabaseClient,
  phone?: string | null,
  email?: string | null,
): Promise<string | null> {
  // Prefer phone (it's the primary auth method in Syria). Fall back to email.
  // NOTE: the users column is `phone_number`, not `phone` (the earlier
  // version of this query silently returned no match every time).
  const tryColumn = async (
    column: "phone_number" | "email",
    value: string,
  ) => {
    const { data } = await supabase
      .from("users")
      .select("id")
      .eq(column, value)
      .limit(1)
      .maybeSingle();
    return data?.id ?? null;
  };
  if (phone) {
    const id = await tryColumn("phone_number", phone);
    if (id) return id;
  }
  if (email) {
    const id = await tryColumn("email", email);
    if (id) return id;
  }
  return null;
}

async function lookupAuthName(
  supabase: SupabaseClient,
  userId: string | null | undefined,
): Promise<string> {
  if (!userId) return "شخص";
  // Use the shared fn_user_display_name RPC which walks doctors →
  // team_profiles → users → phone/email. Previous direct query
  // against public.users.first_name returned empty for every
  // secretary (their names live in team_profiles), surfacing
  // "شخص" / "Someone" on every team event.
  try {
    const { data } = await supabase.rpc("fn_user_display_name", {
      p_user_id: userId,
    });
    if (typeof data === "string" && data.trim().length > 0) {
      return data.trim();
    }
  } catch (e) {
    console.warn("[pro_team] fn_user_display_name rpc failed:", e);
  }
  return "شخص";
}

async function lookupCenterName(
  supabase: SupabaseClient,
  centerId: string,
): Promise<string> {
  if (!centerId) return "العيادة";
  const { data } = await supabase
    .from("centers")
    .select("name")
    .eq("id", centerId)
    .maybeSingle();
  return (data?.name as string | null) ?? "العيادة";
}

async function lookupUserIdForDoctor(
  supabase: SupabaseClient,
  centerId: string,
  doctorId: string,
): Promise<string | null> {
  const { data } = await supabase
    .from("center_members")
    .select("user_id")
    .eq("center_id", centerId)
    .eq("doctor_id", doctorId)
    .eq("is_active", true)
    .is("removed_at", null)
    .limit(1)
    .maybeSingle();
  return (data?.user_id as string | null) ?? null;
}

/// Owner(s) + admins of a center, optionally including the inviter
/// (created_by). Deduped.
async function collectOwnersAndInviter(
  supabase: SupabaseClient,
  centerId: string,
  inviterId: string | null,
): Promise<string[]> {
  const set = new Set<string>();
  if (inviterId) set.add(inviterId);
  const { data } = await supabase
    .from("center_members")
    .select("user_id, roles")
    .eq("center_id", centerId)
    .eq("is_active", true)
    .is("removed_at", null);
  for (const row of (data ?? []) as Array<{ user_id: string; roles: string[] }>) {
    const roles = row.roles ?? [];
    if (roles.includes("owner") || roles.includes("admin")) {
      set.add(row.user_id);
    }
  }
  return Array.from(set);
}

function roleLabel(role: string | null | undefined): string {
  switch (role) {
    case "owner":
      return "مالك";
    case "admin":
      return "مشرف";
    case "doctor":
      return "طبيب";
    case "specialist":
      return "اختصاصي";
    case "secretary":
      return "سكرتير(ة)";
    default:
      return role ?? "عضو";
  }
}

function roleLabelEn(role: string | null | undefined): string {
  switch (role) {
    case "owner":
      return "owner";
    case "admin":
      return "admin";
    case "doctor":
      return "doctor";
    case "specialist":
      return "specialist";
    case "secretary":
      return "secretary";
    default:
      return role ?? "member";
  }
}

function rolesLabel(roles: unknown): string {
  if (!Array.isArray(roles) || roles.length === 0) return "—";
  return (roles as string[]).map(roleLabel).join("، ");
}

function rolesLabelEn(roles: unknown): string {
  if (!Array.isArray(roles) || roles.length === 0) return "—";
  return (roles as string[]).map(roleLabelEn).join(", ");
}

function arraysEqual(a: unknown, b: unknown): boolean {
  if (!Array.isArray(a) || !Array.isArray(b)) return a === b;
  if (a.length !== b.length) return false;
  const sa = [...a].map(String).sort();
  const sb = [...b].map(String).sort();
  for (let i = 0; i < sa.length; i++) {
    if (sa[i] !== sb[i]) return false;
  }
  return true;
}

function deepEqual(a: unknown, b: unknown): boolean {
  return JSON.stringify(a ?? null) === JSON.stringify(b ?? null);
}
