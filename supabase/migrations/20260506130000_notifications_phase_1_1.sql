-- =============================================================================
-- Phase 1.1: comprehensive notification triggers, retention, and crons
-- =============================================================================
-- Adds 15 new event types beyond the 11 already shipped, plus retention
-- infrastructure. Strategy:
--
--   1. notification_events.notification_id is changed from CASCADE to
--      SET NULL so deleting a notifications row preserves its event log.
--      This lets the admin-panel analytics see "150 messages delivered last
--      month" even if the underlying notifications rows have been purged.
--
--   2. fn_emit_notification(...) — generic SQL helper that any RPC, trigger,
--      or cron job can call to insert a notifications row AND fire the edge
--      function asynchronously via pg_net so Pushy delivers the push.
--      Existing edge function handlers (messages, appointments, etc.) keep
--      doing their thing — this helper is for SQL-side sources.
--
--   3. Account-deletion lifecycle: rpc_request_account_deletion and
--      rpc_cancel_account_deletion now emit notifications.
--
--   4. Auth-event triggers on auth.users for password/email/phone changes
--      and on user_devices for new-device login.
--
--   5. pg_cron jobs (require pg_cron extension):
--      - deletion_warning_t7d   (daily 09:00 Damascus)
--      - deletion_warning_t1d   (daily 09:00 Damascus)
--      - voucher_expiring_7d    (daily 10:00 Damascus)
--      - voucher_expiring_1d    (daily 10:00 Damascus)
--      - message_long_unread    (daily 11:00 Damascus, 48h threshold)
--      - notifications_retention_90d (daily 03:00 Damascus, hard delete)
--
--   6. Templates seeded for all new event_codes in AR + EN.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Preserve audit log when notifications rows are deleted
-- ---------------------------------------------------------------------------

ALTER TABLE public.notification_events
  DROP CONSTRAINT IF EXISTS notification_events_notification_id_fkey;

ALTER TABLE public.notification_events
  ALTER COLUMN notification_id DROP NOT NULL;

ALTER TABLE public.notification_events
  ADD CONSTRAINT notification_events_notification_id_fkey
  FOREIGN KEY (notification_id)
  REFERENCES public.notifications(id)
  ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 2. Generic emit helper — used by RPCs, triggers, and cron jobs
-- ---------------------------------------------------------------------------
-- Inserts a row into public.notifications and pings the edge function via
-- pg_net.http_post for Pushy delivery. The edge function recognises payloads
-- with table='_emit' as "row already persisted, just fanout".

CREATE OR REPLACE FUNCTION public.fn_emit_notification(
  p_user_id        uuid,
  p_recipient_app  text,
  p_event_code     text,
  p_category       text,
  p_locale         text,
  p_title          text,
  p_body           text,
  p_deep_link      text,
  p_data           jsonb DEFAULT '{}'::jsonb,
  p_importance     text DEFAULT 'default',
  p_dedup_key      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_id uuid;
  v_url text;
  v_anon text;
BEGIN
  -- Insert (or skip silently on dedup conflict).
  INSERT INTO public.notifications
    (user_id, recipient_app, event_code, category, locale,
     title, body, deep_link, data, importance, dedup_key)
  VALUES
    (p_user_id, p_recipient_app, p_event_code, p_category, p_locale,
     p_title, p_body, p_deep_link, p_data, p_importance, p_dedup_key)
  ON CONFLICT (user_id, event_code, dedup_key) DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    -- Deduped — nothing more to do.
    RETURN NULL;
  END IF;

  -- Fire-and-forget call to edge function for Pushy delivery. Wrapped in
  -- BEGIN/EXCEPTION because pg_net failures must NOT prevent the row from
  -- being inserted (the inbox + realtime path still works without push).
  BEGIN
    SELECT decrypted_secret INTO v_anon
      FROM vault.decrypted_secrets WHERE name = 'edge_function_anon_key' LIMIT 1;
    SELECT decrypted_secret INTO v_url
      FROM vault.decrypted_secrets WHERE name = 'edge_function_base_url' LIMIT 1;

    IF v_anon IS NOT NULL AND v_url IS NOT NULL THEN
      PERFORM net.http_post(
        url := v_url || '/functions/v1/push_notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_anon
        ),
        body := jsonb_build_object(
          'type', 'EMIT',
          'table', '_emit',
          'schema', 'public',
          'record', jsonb_build_object('id', v_id)
        )
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- pg_net unavailable, secrets missing, etc. — row stays, push is just
    -- skipped; user still sees the row in the inbox via realtime.
    RAISE NOTICE 'fn_emit_notification: pg_net call failed (%), row kept', SQLERRM;
  END;

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_emit_notification(
  uuid, text, text, text, text, text, text, text, jsonb, text, text
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. Account-deletion lifecycle: emit notifications from the RPCs
-- ---------------------------------------------------------------------------
-- Wrap rpc_request_account_deletion and rpc_cancel_account_deletion to also
-- emit a notification when called. We use AFTER triggers on the users table
-- so we don't have to redefine the existing RPCs — any path that flips the
-- deletion state (RPC, admin SQL, etc.) gets notified consistently.

CREATE OR REPLACE FUNCTION public.fn_notify_deletion_state_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_locale text;
  v_title  text;
  v_body   text;
BEGIN
  -- Pick recipient locale from any registered device (best-effort).
  SELECT locale INTO v_locale
    FROM public.user_devices
   WHERE user_id = NEW.id AND app = 'docsera'
   ORDER BY last_seen_at DESC NULLS LAST
   LIMIT 1;
  v_locale := COALESCE(v_locale, 'ar');

  -- Transition: NULL → NOT NULL = deletion just requested.
  IF OLD.deletion_requested_at IS NULL AND NEW.deletion_requested_at IS NOT NULL THEN
    IF v_locale = 'en' THEN
      v_title := '⚠️ Account deletion scheduled';
      v_body  := 'Your account will be permanently deleted on '
                 || to_char(NEW.deletion_cancellable_until AT TIME ZONE 'Asia/Damascus', 'DD Mon YYYY')
                 || '. Tap to cancel.';
    ELSE
      v_title := '⚠️ تم جدولة حذف الحساب';
      v_body  := 'سيتم حذف حسابك نهائيًا في '
                 || to_char(NEW.deletion_cancellable_until AT TIME ZONE 'Asia/Damascus', 'DD/MM/YYYY')
                 || '. اضغط للإلغاء.';
    END IF;
    PERFORM public.fn_emit_notification(
      p_user_id       => NEW.id,
      p_recipient_app => 'docsera',
      p_event_code    => 'account.deletion_scheduled',
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account_deletion:pending',
      p_data          => jsonb_build_object(
        'deletion_requested_at', NEW.deletion_requested_at,
        'cancellable_until',     NEW.deletion_cancellable_until
      ),
      p_importance    => 'high',
      p_dedup_key     => 'apt-deletion-scheduled:' || NEW.id::text || ':' || NEW.deletion_requested_at::text
    );
    RETURN NEW;
  END IF;

  -- Transition: NOT NULL → NULL = deletion cancelled.
  IF OLD.deletion_requested_at IS NOT NULL AND NEW.deletion_requested_at IS NULL THEN
    IF v_locale = 'en' THEN
      v_title := '✅ Account deletion cancelled';
      v_body  := 'Your account is back to normal. Welcome back.';
    ELSE
      v_title := '✅ تم إلغاء حذف الحساب';
      v_body  := 'حسابك عاد إلى وضعه الطبيعي. أهلًا بعودتك.';
    END IF;
    PERFORM public.fn_emit_notification(
      p_user_id       => NEW.id,
      p_recipient_app => 'docsera',
      p_event_code    => 'account.deletion_cancelled',
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account:home',
      p_data          => '{}'::jsonb,
      p_importance    => 'high',
      p_dedup_key     => 'apt-deletion-cancelled:' || NEW.id::text || ':' || COALESCE(OLD.deletion_requested_at::text, '')
    );
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_deletion_state ON public.users;
CREATE TRIGGER trg_notify_deletion_state
  AFTER UPDATE OF deletion_requested_at ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notify_deletion_state_changed();

-- ---------------------------------------------------------------------------
-- 4. Security event triggers
-- ---------------------------------------------------------------------------
-- auth.users triggers fire on email / phone / encrypted_password changes.
-- A separate trigger on user_devices fires on new-device login.

CREATE OR REPLACE FUNCTION public.fn_notify_auth_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_locale text;
  v_title  text;
  v_body   text;
  v_event  text;
  v_dedup  text;
BEGIN
  -- Determine which field changed.
  IF NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password THEN
    v_event := 'security.password_changed';
    v_dedup := 'pwd:' || NEW.id::text || ':' || extract(epoch from now())::bigint::text;
  ELSIF NEW.email IS DISTINCT FROM OLD.email THEN
    v_event := 'security.email_changed';
    v_dedup := 'email:' || NEW.id::text || ':' || COALESCE(NEW.email, '');
  ELSIF NEW.phone IS DISTINCT FROM OLD.phone THEN
    v_event := 'security.phone_changed';
    v_dedup := 'phone:' || NEW.id::text || ':' || COALESCE(NEW.phone, '');
  ELSE
    RETURN NEW;
  END IF;

  SELECT locale INTO v_locale
    FROM public.user_devices
   WHERE user_id = NEW.id AND app = 'docsera'
   ORDER BY last_seen_at DESC NULLS LAST
   LIMIT 1;
  v_locale := COALESCE(v_locale, 'ar');

  IF v_event = 'security.password_changed' THEN
    IF v_locale = 'en' THEN
      v_title := '🔐 Password changed';
      v_body  := 'Your password was just changed. If this wasn''t you, secure your account now.';
    ELSE
      v_title := '🔐 تم تغيير كلمة المرور';
      v_body  := 'تم تغيير كلمة المرور للتو. إن لم تكن أنت، أمّن حسابك الآن.';
    END IF;
  ELSIF v_event = 'security.email_changed' THEN
    IF v_locale = 'en' THEN
      v_title := '✉️ Email changed';
      v_body  := 'Your account email was just updated. If this wasn''t you, contact support.';
    ELSE
      v_title := '✉️ تم تغيير البريد الإلكتروني';
      v_body  := 'تم تحديث بريد حسابك. إن لم تكن أنت، تواصل مع الدعم.';
    END IF;
  ELSE  -- phone
    IF v_locale = 'en' THEN
      v_title := '📱 Phone number changed';
      v_body  := 'Your account phone number was just updated. If this wasn''t you, contact support.';
    ELSE
      v_title := '📱 تم تغيير رقم الهاتف';
      v_body  := 'تم تحديث رقم هاتف حسابك. إن لم تكن أنت، تواصل مع الدعم.';
    END IF;
  END IF;

  PERFORM public.fn_emit_notification(
    p_user_id       => NEW.id,
    p_recipient_app => 'docsera',
    p_event_code    => v_event,
    p_category      => 'security',
    p_locale        => v_locale,
    p_title         => v_title,
    p_body          => v_body,
    p_deep_link     => 'account:security',
    p_data          => '{}'::jsonb,
    p_importance    => 'high',
    p_dedup_key     => v_dedup
  );

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_auth_change ON auth.users;
CREATE TRIGGER trg_notify_auth_change
  AFTER UPDATE OF encrypted_password, email, phone ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notify_auth_change();

-- New device login: trigger on user_devices INSERT only when the user
-- already has at least one OTHER device for the same app.
CREATE OR REPLACE FUNCTION public.fn_notify_new_device_login()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_other_count int;
  v_locale text;
  v_title  text;
  v_body   text;
BEGIN
  IF NEW.user_id IS NULL THEN RETURN NEW; END IF;

  SELECT count(*) INTO v_other_count
    FROM public.user_devices
   WHERE user_id = NEW.user_id
     AND app = NEW.app
     AND id <> NEW.id;
  IF v_other_count = 0 THEN RETURN NEW; END IF;

  v_locale := COALESCE(NEW.locale, 'ar');

  IF v_locale = 'en' THEN
    v_title := '🔔 New device signed in';
    v_body  := 'A new ' || COALESCE(NEW.platform, 'device')
               || ' just signed in to your DocSera account. If this wasn''t you, change your password.';
  ELSE
    v_title := '🔔 تسجيل دخول من جهاز جديد';
    v_body  := 'تم تسجيل دخول جديد إلى حساب دوكسيرا من ' || COALESCE(NEW.platform, 'جهاز')
               || '. إن لم يكن أنت، غيّر كلمة المرور.';
  END IF;

  PERFORM public.fn_emit_notification(
    p_user_id       => NEW.user_id,
    p_recipient_app => 'docsera',
    p_event_code    => 'security.new_device_login',
    p_category      => 'security',
    p_locale        => v_locale,
    p_title         => v_title,
    p_body          => v_body,
    p_deep_link     => 'account:security',
    p_data          => jsonb_build_object('device_id', NEW.id, 'platform', NEW.platform),
    p_importance    => 'high',
    p_dedup_key     => 'newdev:' || NEW.id::text
  );

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_new_device_login ON public.user_devices;
CREATE TRIGGER trg_notify_new_device_login
  AFTER INSERT ON public.user_devices
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notify_new_device_login();

-- ---------------------------------------------------------------------------
-- 5. Templates for all new events (AR + EN)
-- ---------------------------------------------------------------------------

INSERT INTO public.notification_templates
  (event_code, locale, title_template, body_template, default_importance, default_category, default_deep_link)
VALUES
  -- conversation lifecycle (handler-driven)
  ('conversation.closed_by_doctor', 'ar',
    'تم إغلاق المحادثة',
    'أغلق د. {{doctor_name}} هذه المحادثة. يمكنك بدء محادثة جديدة عند الحاجة.',
    'default', 'messages', 'conversation:{{conversation_id}}'),
  ('conversation.closed_by_doctor', 'en',
    'Conversation closed',
    'Dr. {{doctor_name}} closed this conversation. You can start a new one when needed.',
    'default', 'messages', 'conversation:{{conversation_id}}'),

  ('conversation.reopened_by_doctor', 'ar',
    'تم إعادة فتح المحادثة',
    'أعاد د. {{doctor_name}} فتح المحادثة. يمكنك إكمال الحديث الآن.',
    'high', 'messages', 'conversation:{{conversation_id}}'),
  ('conversation.reopened_by_doctor', 'en',
    'Conversation reopened',
    'Dr. {{doctor_name}} reopened the conversation. You can continue chatting now.',
    'high', 'messages', 'conversation:{{conversation_id}}'),

  ('document.deleted_by_doctor', 'ar',
    'تم حذف مستند من ملفك',
    'حذف د. {{doctor_name}} مستندًا من ملفك الطبي.',
    'default', 'documents', 'document:home'),
  ('document.deleted_by_doctor', 'en',
    'A document was removed from your file',
    'Dr. {{doctor_name}} removed a document from your medical file.',
    'default', 'documents', 'document:home'),

  ('doctor.vacation_overlap', 'ar',
    'الطبيب في إجازة',
    'سيكون د. {{doctor_name}} في إجازة خلال موعدك المحجوز. يُنصح بإعادة الجدولة.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),
  ('doctor.vacation_overlap', 'en',
    'Your doctor will be away',
    'Dr. {{doctor_name}} will be on vacation during your booked appointment. Consider rescheduling.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),

  -- security (trigger-driven)
  ('security.password_changed', 'ar',
    '🔐 تم تغيير كلمة المرور',
    'تم تغيير كلمة المرور للتو. إن لم تكن أنت، أمّن حسابك الآن.',
    'high', 'security', 'account:security'),
  ('security.password_changed', 'en',
    '🔐 Password changed',
    'Your password was just changed. If this wasn''t you, secure your account now.',
    'high', 'security', 'account:security'),

  ('security.email_changed', 'ar',
    '✉️ تم تغيير البريد الإلكتروني',
    'تم تحديث بريد حسابك. إن لم تكن أنت، تواصل مع الدعم.',
    'high', 'security', 'account:security'),
  ('security.email_changed', 'en',
    '✉️ Email changed',
    'Your account email was just updated. If this wasn''t you, contact support.',
    'high', 'security', 'account:security'),

  ('security.phone_changed', 'ar',
    '📱 تم تغيير رقم الهاتف',
    'تم تحديث رقم هاتف حسابك. إن لم تكن أنت، تواصل مع الدعم.',
    'high', 'security', 'account:security'),
  ('security.phone_changed', 'en',
    '📱 Phone number changed',
    'Your account phone number was just updated. If this wasn''t you, contact support.',
    'high', 'security', 'account:security'),

  ('security.new_device_login', 'ar',
    '🔔 تسجيل دخول من جهاز جديد',
    'تم تسجيل دخول جديد إلى حسابك. إن لم يكن أنت، غيّر كلمة المرور.',
    'high', 'security', 'account:security'),
  ('security.new_device_login', 'en',
    '🔔 New device signed in',
    'A new device just signed in to your account. If this wasn''t you, change your password.',
    'high', 'security', 'account:security'),

  -- account deletion lifecycle (trigger + cron driven)
  ('account.deletion_scheduled', 'ar',
    '⚠️ تم جدولة حذف الحساب',
    'سيتم حذف حسابك نهائيًا في {{deadline_date}}. اضغط للإلغاء.',
    'high', 'security', 'account_deletion:pending'),
  ('account.deletion_scheduled', 'en',
    '⚠️ Account deletion scheduled',
    'Your account will be permanently deleted on {{deadline_date}}. Tap to cancel.',
    'high', 'security', 'account_deletion:pending'),

  ('account.deletion_warning_t7d', 'ar',
    '⏳ ٧ أيام متبقية لحذف الحساب',
    'سيتم حذف حسابك نهائيًا بعد ٧ أيام. اضغط للإلغاء قبل فوات الأوان.',
    'high', 'security', 'account_deletion:pending'),
  ('account.deletion_warning_t7d', 'en',
    '⏳ 7 days left to cancel deletion',
    'Your account will be permanently deleted in 7 days. Tap to cancel before it''s too late.',
    'high', 'security', 'account_deletion:pending'),

  ('account.deletion_warning_t1d', 'ar',
    '⛔ غدًا سيتم حذف حسابك',
    'هذه آخر فرصة لإلغاء حذف حسابك. اضغط الآن.',
    'time_sensitive', 'security', 'account_deletion:pending'),
  ('account.deletion_warning_t1d', 'en',
    '⛔ Account deletes tomorrow',
    'Last chance to cancel your scheduled deletion. Tap now.',
    'time_sensitive', 'security', 'account_deletion:pending'),

  ('account.deletion_cancelled', 'ar',
    '✅ تم إلغاء حذف الحساب',
    'حسابك عاد إلى وضعه الطبيعي. أهلًا بعودتك.',
    'high', 'security', 'account:home'),
  ('account.deletion_cancelled', 'en',
    '✅ Account deletion cancelled',
    'Your account is back to normal. Welcome back.',
    'high', 'security', 'account:home'),

  -- vouchers (cron-driven)
  ('loyalty.voucher_expiring_7d', 'ar',
    '🎁 قسيمتك ستنتهي خلال ٧ أيام',
    'استخدمها قبل انتهاء صلاحيتها في {{expiry_date}}.',
    'default', 'loyalty', 'voucher:{{voucher_id}}'),
  ('loyalty.voucher_expiring_7d', 'en',
    '🎁 Your voucher expires in 7 days',
    'Use it before {{expiry_date}}.',
    'default', 'loyalty', 'voucher:{{voucher_id}}'),

  ('loyalty.voucher_expiring_1d', 'ar',
    '⏰ قسيمتك تنتهي غدًا',
    'هذه آخر فرصة لاستخدامها. اضغط للعرض.',
    'high', 'loyalty', 'voucher:{{voucher_id}}'),
  ('loyalty.voucher_expiring_1d', 'en',
    '⏰ Your voucher expires tomorrow',
    'Last chance to use it. Tap to view.',
    'high', 'loyalty', 'voucher:{{voucher_id}}'),

  -- message long unread (cron-driven)
  ('message.long_unread', 'ar',
    'رسالة غير مقروءة من د. {{doctor_name}}',
    'لديك رسالة لم تقرأها منذ {{days}} {{days_unit}}.',
    'default', 'messages', 'conversation:{{conversation_id}}'),
  ('message.long_unread', 'en',
    'Unread message from Dr. {{doctor_name}}',
    'You have a message you haven''t read in {{days}} {{days_unit}}.',
    'default', 'messages', 'conversation:{{conversation_id}}')
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================================================
-- pg_cron jobs are installed in a separate apply (require the extension to
-- already be enabled and the supabase_admin role). See the companion file:
--   supabase/migrations/20260506130100_notifications_phase_1_1_crons.sql
-- ============================================================================
