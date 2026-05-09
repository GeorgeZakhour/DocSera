# 15 — Notifications platform (Phase 1 + 1.1 + 1.2 + 1.3)

**Status:** ✅ Done — end-to-end tested on iOS device
**Score after:** 9.85 / 10
**Owners:** patient app, DocSera-Pro (badge only), shared Supabase backend

## Summary

Replaced fire-and-forget Pushy pushes with a full notifications platform: a `notifications` system-of-record table, a single refactored Edge Function dispatcher (routers / handlers / engine layers), a per-category × per-channel preferences matrix with quiet hours, locale-per-device routing (fixes the long-standing English-users-get-Arabic regression), an in-app inbox + bell badge, and a server-driven appointment-reminder cron that fires via Pushy regardless of whether the patient app is open.

While building this we redesigned the account-deletion lifecycle. The original 30-day pseudonymization approach treated the doctor like a third party who shouldn't have the data, but the doctor is the patient's actual care provider with a clinical retention obligation. New behavior: at day 30 the patient is **forked into one manual-patient record per doctor** (using the existing `doctor_patients` table) carrying a `was_docsera_user` badge. Clinical history is preserved exactly as it would have been if the doctor had originally added the patient manually; the central account is fully removed; year-7 hard-purge cron seals the loop.

## What changed

### Schema

| Table | Change |
|---|---|
| `notifications` | NEW — system-of-record. user_id, recipient_app, event_code, category, locale, title, body, deep_link, data, importance, dedup_key (unique with user_id+event_code), created_at, read_at, archived_at, delivered_push_at, clicked_at |
| `notification_templates` | NEW — versioned (event_code, locale, version) copy registry. Seeded with all current copy. |
| `notification_preferences` | NEW — per-user × per-category × push/in-app/email + respects_quiet_hours flag |
| `notification_quiet_hours` | NEW — start/end local times + DnD-until |
| `notification_events` | NEW — append-only audit (queued, sent_push, delivered_push, opened, clicked, failed, suppressed) |
| `notification_campaigns` | NEW — empty schema, forward-compat for the future admin panel |
| `user_devices` | ALTER — added `locale`, `last_seen_at`, `app_version` |
| `doctor_patients` | ALTER — added `was_docsera_user`, `docsera_account_deleted_at`, `prior_user_id` for the deletion-fork flow |

All new tables have RLS enabled and forced. Owner can SELECT/UPDATE on `notifications` for read/archive; INSERT/DELETE service-role only.

### Edge Function (`supabase/functions/push_notifications/`)

Refactored from a single `index.ts` into a layered structure:

```
push_notifications/
  index.ts                 ← serve() + dispatcher
  types.ts
  decrypt.ts               ← AES helper for ENC: messages
  pushy.ts                 ← only file that talks to api.pushy.me
  persist.ts               ← INSERT into notifications + queued event
  fanout.ts                ← devices fetch → Pushy → events log
  handlers/
    messages.ts            ← decrypts ENC: messages
    appointments.ts        ← booked/confirmed/rejected/cancelled/rescheduled/report
    documents.ts           ← doctor-added only
    documents_deletion.ts  ← doctor-removed only
    conversations.ts       ← closed/reopened with timestamp dedup
    doctor_vacations.ts    ← vacation_overlap, dedup per affected user
    todo_tasks.ts          ← Pro-only
    gifts.ts
```

The dispatcher accepts an additional `EMIT` payload type so SQL-side `fn_emit_notification` calls (used by triggers + crons) can fan out via the same Pushy code path without re-implementing it.

### DB-side helpers

| Function | Purpose |
|---|---|
| `fn_emit_notification(...)` | Inserts a notifications row, then `pg_net.http_post` to the EMIT route. Vault secrets `edge_function_anon_key` + `edge_function_base_url` MUST be set (we seed both in the install). |
| `fn_dispatch_notification_webhook(...)` | Generic helper used by the 3 DB-trigger webhooks (replaces Studio webhook config). |

### DB triggers (15+ events)

| Trigger | Table / event | Notification |
|---|---|---|
| `trg_notify_new_device_login` | user_devices INSERT | `security.new_device_login` |
| `trg_notify_auth_change` | users UPDATE | `account.email_changed` / `phone_changed` / `password_changed` |
| `trg_notify_deletion_state` | users UPDATE | `account.deletion_scheduled` / `cancelled` |
| `trg_notify_conversation_state` | conversations UPDATE | `conversation.closed` / `reopened` (only when is_closed transitions) |
| `trg_notify_document_deletion` | documents DELETE | `document.removed` |
| `trg_notify_doctor_vacation` | doctor_vacations INSERT | `appointment.vacation_overlap` |

### pg_cron jobs (8 active)

| Job | Schedule | Function | Purpose |
|---|---|---|---|
| `notif_appointment_reminders` | every minute | `fn_cron_appointment_reminders` | Fires T-{24h, 2h, 30m, 0} appointment reminders via Pushy regardless of app state |
| `notif_message_long_unread` | configured | `fn_cron_message_long_unread` | Nudges patient about doctor messages unread for ≥48h |
| `notif_voucher_expiring_7d` | configured | `fn_cron_voucher_expiring_7d` | Loyalty voucher expiring in 7 days |
| `notif_voucher_expiring_1d` | configured | `fn_cron_voucher_expiring_1d` | Loyalty voucher expiring in 1 day |
| `notif_deletion_warning_t7d` | 06:00 UTC daily | `fn_cron_deletion_warning_t7d` | "7 days left to cancel deletion" |
| `notif_deletion_warning_t1d` | 06:05 UTC daily | `fn_cron_deletion_warning_t1d` | "your account will be deleted tomorrow" |
| `notif_account_deletion_finalize` | 02:00 UTC daily | `fn_cron_account_deletion_finalize` | Day-30: forks user into per-doctor manual patients, drops auth.users |
| `notif_account_deletion_hard_purge` | 02:30 UTC daily | `fn_cron_account_deletion_hard_purge` | Year-7: purges public.users tombstone + audit |
| `notif_notifications_retention_90d` | configured | `fn_cron_notifications_retention_90d` | 90-day inbox retention; preserves notification_events audit |

### Patient app

| File | Change |
|---|---|
| `lib/screens/home/notifications/notifications_inbox_page.dart` | NEW — glass-styled inbox, swipe-to-delete, mark-all-read pill, retention banner, per-category unread tint, chevron back arrow auto-mirrored |
| `lib/screens/home/notifications/widgets/notification_bell_button.dart` | NEW — bell + realtime badge in home AppBar |
| `lib/screens/home/account/notification_preferences_page.dart` | NEW — per-category × push/in-app + quiet hours + DnD |
| `lib/screens/home/account/pending_deletion_page.dart` | NEW — days-remaining badge + cancel button. Pre-flight currentUser check + auto-bounce when no pending deletion. Cairo/Montserrat font on the cancel button. |
| `lib/Business_Logic/Notifications_page/notifications_cubit.dart` | NEW — realtime subscription + bell badge counter |
| `lib/services/notifications/in_app_notification_banner.dart` | NEW — glass banner overlay; works around Pushy's iOS UNUserNotificationCenterDelegate suppression of foreground notifications |
| `lib/services/notifications/notification_service.dart` | scheduleAppointmentReminders is now a no-op apart from clearing leftover OS-scheduled notifications — server cron supersedes |
| `lib/services/notifications/appointment_reminder_scheduler.dart` | Bridge AppointmentsCubit → reminder cleanup (scheduling delegated to server cron) |
| `lib/screens/auth/login/login_page.dart` | Login allowed during 30-day deletion grace window → routes to PendingDeletionPage. Phone-only users (no email) routed through synthetic-email shim via `signInWithPhonePassword`. |
| `lib/services/supabase/user/account_danger_service.dart` | `deleteMyAccount` now calls Tier 2 `rpc_request_account_deletion` (was incorrectly calling Tier 1 deactivate, trapping users without a deletion timestamp). Tier 1 preserved as `deactivateMyAccount`. |
| `lib/services/supabase/user/account_security_service.dart` | Phone-change flow migrated off the legacy `rpc_request_phone_change` (which leaked OTP to client) onto the unified `send_sms_otp` edge function shared with DocSera-Pro. |

### DocSera-Pro

| File | Change |
|---|---|
| `lib/features/patients/widgets/sections/patient_info_section.dart` | New "Former DocSera user" badge above patient info when `was_docsera_user=true`, showing the deletion date and explaining clinical history is preserved + DocSera-side messaging is no longer available |
| `lib/core/services/supabase/supabase_appointments_service.dart` | Pending-stream filter excludes closed statuses (cancelled, cancelled_by_doctor, rejected, done, no_show) so vacation-cancelled appointments stop showing in the dashboard's "needs confirm or reject" list |
| `lib/features/account/pages/appointments_availability/availability_settings_page.dart` | Vacation flow shows an affected-appointments dialog before bulk-cancel; insertion order ensures `vacation_overlap` notification fires before `cancelled_by_doctor` per appointment |
| `lib/l10n/app_en.arb` + `app_ar.arb` | New keys for the badge + dialog + footnote |

## Notification catalog (everything that fires)

End-to-end tested on iOS device unless noted. Test outcomes column reads ✅ for "delivered + visible in inbox + Pushy push received".

### Appointments

| Event code | Trigger | AR title | EN title | Importance | Tested |
|---|---|---|---|---|---|
| `appointment.pending_received` | INSERT (booked, !is_confirmed) | 📨 تم استلام طلب الحجز | 📨 Booking request received | high | ✅ |
| `appointment.confirmed` | INSERT auto-confirmed OR UPDATE is_confirmed→true | ✅ تم تثبيت الحجز | ✅ Appointment confirmed | high | ✅ |
| `appointment.rejected` | UPDATE status='rejected' | ⛔ تم رفض طلب الحجز | ⛔ Booking declined | high | ✅ |
| `appointment.cancelled_by_doctor` | UPDATE status='cancelled' or 'cancelled_by_doctor' | ❌ تم إلغاء الموعد | ❌ Appointment cancelled | high | ✅ |
| `appointment.rescheduled` | UPDATE timestamp change | 🕒 تم تغيير الموعد | 🕒 Appointment rescheduled | high | ✅ |
| `appointment.vacation_overlap` | doctor_vacations INSERT | ⛱️ موعدك أُلغي بسبب إجازة الطبيب | ⛱️ Your appointment was cancelled due to doctor's vacation | high | ✅ |
| `appointment.reminder_t24h` | cron T-24h | موعدك غدًا | Your appointment is tomorrow | high | ✅ |
| `appointment.reminder_t2h` | cron T-2h | موعدك بعد ساعتين | Your appointment is in 2 hours | high | ✅ |
| `appointment.reminder_t30m` | cron T-30m | موعدك بعد نصف ساعة | Your appointment is in 30 minutes | time_sensitive | ✅ |
| `appointment.reminder_t0` | cron T-0 | حان وقت موعدك | It's appointment time | time_sensitive | ✅ |

### Reports / Documents

| Event code | Trigger | Tested |
|---|---|---|
| `report.added` | UPDATE appointments.report null→non-null | ✅ |
| `report.edited` | UPDATE appointments.report non-null→non-null | ✅ |
| `document.new` | documents INSERT (source='doctor_added' only) | ✅ |
| `document.removed` | documents DELETE (source='doctor_added' only) | ✅ |

### Messages

| Event code | Trigger | Tested |
|---|---|---|
| `message.new` | messages INSERT (decrypted via engine/decrypt.ts) | ✅ |
| `message.long_unread` | cron, doctor messages unread ≥48h, ≤14d | ✅ Pushy delivery confirmed |

### Conversations

| Event code | Trigger | Tested |
|---|---|---|
| `conversation.closed` | UPDATE is_closed false→true | ✅ |
| `conversation.reopened` | UPDATE is_closed true→false | ✅ |

### Loyalty

| Event code | Trigger | Tested |
|---|---|---|
| `gift.received` | patient_gift_sends INSERT | ✅ |
| `voucher.expiring_t7d` | cron, expiry within 6.5–7.5 days | ✅ Plumbing OK (no eligible row in test) |
| `voucher.expiring_t1d` | cron, expiry within 0.5–1.5 days | ✅ Plumbing OK |

### Security / Account

| Event code | Trigger | Tested |
|---|---|---|
| `security.new_device_login` | user_devices INSERT (when not first device) | ⚠️ Same-device sign-in does not fire (correctly) |
| `account.email_changed` | users UPDATE email | ✅ |
| `account.phone_changed` | users UPDATE phone_number | Wired (now via unified send_sms_otp infra) |
| `account.password_changed` | users UPDATE encrypted_password | ✅ |
| `account.deletion_scheduled` | users UPDATE deletion_requested_at IS NOT NULL | ✅ |
| `account.deletion_cancelled` | users UPDATE deletion_requested_at→NULL | ✅ |
| `account.deletion_warning_t7d` | cron, deletion_cancellable_until in 6.5–7.5 days | ✅ (manual fire test) |
| `account.deletion_warning_t1d` | cron, deletion_cancellable_until in 0.5–1.5 days | ✅ (manual fire test) |

### System (Pro-only)

`todo_tasks.assigned`, `todo_tasks.done` — preserved intact from prior implementation.

## Account deletion lifecycle (redesigned)

| Phase | Day | What happens |
|---|---|---|
| Request | 0 | `rpc_request_account_deletion` sets is_active=false, deletion_requested_at=now, deletion_cancellable_until=now+30d. Future appointments cancelled. Conversations closed. `account.deletion_scheduled` notification fires. |
| Warnings | 23, 29 | T-7d and T-1d cron warnings fire via Pushy. Patient can still log in (login flow allows the grace-window state) and reach `PendingDeletionPage`. |
| Finalize | 30 | `fn_cron_account_deletion_finalize` runs at 02:00 UTC. For each doctor with a clinical relationship: creates a `doctor_patients` row (or updates an existing one) with `was_docsera_user=true`, `docsera_account_deleted_at=now`, `prior_user_id=<old user>`. Re-points appointments + documents. Closes any remaining conversations. Drops user-side records (health profile, devices, notifications). Pseudonymizes `public.users` tombstone. **Deletes auth.users** so the patient can no longer log in. |
| Hard purge | year 7 | `fn_cron_account_deletion_hard_purge` runs at 02:30 UTC. Severs `doctor_patients.prior_user_id`. Drops `notification_events` rows for the user. Hard-deletes `public.users` tombstone. The doctor's manual patient record + clinical history remain — they're now fully self-contained. |

What the doctor sees after day 30:
- Patient still in their list with full name + phone + email
- Teal "Former DocSera user · حُذف الحساب YYYY-MM-DD" badge above patient info
- Past appointments, notes, reports — fully intact
- DocSera-side messaging not possible (no account to receive)
- Cannot book on the patient's behalf via DocSera flow — manual booking still works

## Operating it

### Manually fire any cron (testing)

```sql
SELECT public.fn_cron_appointment_reminders();
SELECT public.fn_cron_message_long_unread();
SELECT public.fn_cron_voucher_expiring_7d();
SELECT public.fn_cron_voucher_expiring_1d();
SELECT public.fn_cron_deletion_warning_t7d();
SELECT public.fn_cron_deletion_warning_t1d();
SELECT public.fn_cron_account_deletion_finalize();
SELECT public.fn_cron_account_deletion_hard_purge();
SELECT public.fn_cron_notifications_retention_90d();
```

### Vault secrets must exist

The pg_net call from `fn_emit_notification` reads two secrets. If they're missing, notifications still insert but Pushy never fires — silent failure.

```sql
SELECT name FROM vault.decrypted_secrets
 WHERE name IN ('edge_function_anon_key', 'edge_function_base_url');
-- Must return both rows.
```

To seed (one-time, supabase_admin):

```sql
SELECT vault.create_secret('https://api.docsera.app', 'edge_function_base_url');
SELECT vault.create_secret('<SUPABASE_ANON_KEY>', 'edge_function_anon_key');
```

### Inspect a recent run

```sql
-- What the cron emitted
SELECT created_at, event_code, locale, title, archived_at IS NOT NULL AS hidden
  FROM public.notifications
 ORDER BY created_at DESC LIMIT 20;

-- Did Pushy receive it
SELECT n.event_code, e.event_type, e.detail
  FROM public.notifications n
  LEFT JOIN public.notification_events e ON e.notification_id = n.id
 WHERE n.created_at > now() - interval '1 hour'
 ORDER BY n.created_at DESC, e.at;

-- Is a cron job alive
SELECT jobname, schedule, active FROM cron.job ORDER BY jobname;
SELECT start_time, status, return_message
  FROM cron.job_run_details
 WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname='notif_appointment_reminders')
 ORDER BY start_time DESC LIMIT 5;
```

## What could go wrong

| Symptom | Diagnosis | Fix |
|---|---|---|
| Cron runs but no Pushy push | Vault secrets missing — pg_net call silently no-ops | Seed `edge_function_anon_key` + `edge_function_base_url` (see above) |
| Inbox row created but no realtime banner | NotificationsCubit subscription dropped — usually network blip | Pull-to-refresh in the inbox |
| English copy on AR device or vice versa | `user_devices.locale` not set on this device | Sign out / in once; the device record is upserted with the current app locale |
| Reminder fires twice | Two cron jobs scheduled with same name (re-installing migration) | `SELECT cron.unschedule('<name>') FROM cron.job WHERE jobname='<name>';` then re-run migration |
| User trapped after Tier 1 deactivate | Pre-fix bug: Delete UI called wrong RPC | Fixed in this phase. Tier 1 deactivate is now only callable via the explicit `deactivateMyAccount` service method (no UI uses it). |
| Phone-change OTP "wrong" with `0900000009` + `123456` | Was on the legacy `rpc_request_phone_change` infra not the unified one | Fixed in this phase — patient phone-change now uses `send_sms_otp` |
| `fn_cron_account_deletion_finalize` silent | `deletion_cancellable_until` was not set during a manual deletion | The proper Tier 2 RPC sets it; if you backdate manually for testing, set both `deletion_requested_at` AND `deletion_cancellable_until` |

## Cross-account notification bleed (CRITICAL — fixed this session)

**Symptom seen earlier:** when User A logged out and User B signed in on the same physical device, User A kept receiving their notifications on the device — visible to User B.

**Root cause:** seven of eight `auth.signOut()` call sites in the patient app bypassed `AuthRepository.signOut()` (which already cleaned `user_devices`) and just called `Supabase.instance.client.auth.signOut()` directly. Result: A's `(user_id=A, token=this_token)` row in `user_devices` survived. When B logged in, a new `(B, token)` row was upserted, but A's row stayed. Pushy still delivered A's notifications to A's token, which is on B's hands.

**Fix:** every signOut call site now invokes `NotificationService.instance.deleteToken()` BEFORE `auth.signOut()`. RLS scopes the delete to the current user's own rows, so only the just-leaving user's device row is removed; other devices belonging to that user (laptop, second phone) are untouched. Patched sites:

  * `lib/widgets/custom_bottom_navigation_bar.dart` — main logout button
  * `lib/services/auth/authentication_service.dart` — central `logout()` helper
  * `lib/Business_Logic/Authentication/auth_cubit.dart` — `signOut()` + orphan-session signOut path
  * `lib/Business_Logic/Account_page/user_cubit.dart` — soft-deactivated account auto-signOut
  * `lib/services/supabase/user/account_danger_service.dart` — `deleteMyAccount()` + `deactivateMyAccount()`
  * `lib/screens/home/account/pending_deletion_page.dart` — `_bounceToLogin()` on stale-token state
  * `AuthRepository.signOut()` already had it — unchanged

The two remaining direct callers (`lib/screens/auth/sign_up/cross_app_options.dart` validation-only signin-then-signout, and a debug "Reset Session" button in main_screen.dart) are not auth-context user logouts — the validation-only paths run before any device row is created, and the debug button is gated to development.

## Pre-launch must-do (separate session — flagged but not done here)

| # | Item |
|---|---|
| 1 | **Strip TEST_PHONES whitelists**. Two locations: `supabase/functions/send_sms_otp/index.ts` (the canonical `00963900000001..13` set) and migration `20260509100000_phone_change_test_whitelist.sql` (we added the same bypass to `rpc_verify_phone_otp` 2-arg legacy form for compat). Also remove `TempPass123!` direct-DB password reset commands from any operator runbook. |
| 2 | **Strip the legacy `rpc_request_phone_change` debug shortcut**. The patient app no longer calls it (migrated to `send_sms_otp` in this phase) but the function still exists and still returns OTP plaintext if any caller hits it. Drop the function entirely or rewrite it to call `send_sms_otp` and return void. |
| 3 | **Notification preferences screen — visibility**. The screen exists and writes correctly to `notification_preferences` but it's not heavily exposed in the Account UI. Worth a final review pass to make sure it's discoverable. |
| 4 | **Android device verification**. All Phase 1 testing was done on iPhone. The cron → Pushy → APNs path is platform-agnostic, but the iOS-specific overlay (in-app banner, time-sensitive flag, action-button category) doesn't apply to Android — Android shows heads-up natively. Recommend installing the APK on a real Android device and verifying T-2h reminder + foreground heads-up + action buttons before launch. |

## Score impact

9.7 → **9.85** — full notifications platform shipped, T-2h/T-30m/T-0 reminders verified end-to-end on iOS, account-deletion lifecycle redesigned for clinical retention.
