-- =============================================================================
-- Phase 2.4 — Pro subscription warning crons.
-- =============================================================================
--
-- Daily 06:00 UTC (≈09:00 Damascus). Scans subscriptions and emits:
--   pro.subscription.trial_ending_soon   — trial_ends_at  in (3d, 7d, 14d)
--   pro.subscription.expiring_soon       — paid_until     in (3d, 7d, 14d)
--   pro.subscription.expired_grace       — now() > paid_until AND
--                                          now() < grace_ends_at
--   pro.subscription.expired_blocked     — now() > grace_ends_at
--
-- Each row is dedup'd per (subscription_id, event_code, window-day) so:
--   - re-running the cron the same day is a no-op,
--   - the same subscription fires once per window crossed (3d → 7d → 14d).
--
-- The "expired_blocked" event is TS-grade (it locks the clinic out of
-- features). The others are H or D.

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_cron_pro_subscription_warnings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s record;
  r record;
  v_locale text;
  v_event text;
  v_importance text;
  v_window text;
  v_title text;
  v_body text;
  v_window_label text;
BEGIN
  FOR s IN
    SELECT id, center_id, plan::text AS plan, status::text AS status,
           trial_ends_at, paid_until, grace_ends_at
      FROM public.subscriptions
  LOOP
    v_event := NULL;
    v_importance := 'default';
    v_window := NULL;

    -- Already blocked?
    IF s.grace_ends_at IS NOT NULL AND s.grace_ends_at < now() THEN
      v_event := 'pro.subscription.expired_blocked';
      v_importance := 'time_sensitive';
      v_window := to_char(date_trunc('day', now()), 'YYYY-MM-DD');
    -- In grace period?
    ELSIF s.paid_until IS NOT NULL AND s.paid_until < now()
       AND (s.grace_ends_at IS NULL OR s.grace_ends_at > now()) THEN
      v_event := 'pro.subscription.expired_grace';
      v_importance := 'high';
      v_window := to_char(date_trunc('day', now()), 'YYYY-MM-DD');
    -- Trial ending soon
    ELSIF s.trial_ends_at IS NOT NULL THEN
      IF s.trial_ends_at BETWEEN now() + interval '2.5 days'
                              AND now() + interval '3.5 days' THEN
        v_event := 'pro.subscription.trial_ending_soon';
        v_window := '3d';
        v_importance := 'high';
      ELSIF s.trial_ends_at BETWEEN now() + interval '6.5 days'
                                AND now() + interval '7.5 days' THEN
        v_event := 'pro.subscription.trial_ending_soon';
        v_window := '7d';
        v_importance := 'default';
      ELSIF s.trial_ends_at BETWEEN now() + interval '13.5 days'
                                AND now() + interval '14.5 days' THEN
        v_event := 'pro.subscription.trial_ending_soon';
        v_window := '14d';
        v_importance := 'default';
      END IF;
    END IF;

    -- Paid expiring soon (only if not in trial)
    IF v_event IS NULL AND s.paid_until IS NOT NULL THEN
      IF s.paid_until BETWEEN now() + interval '2.5 days'
                          AND now() + interval '3.5 days' THEN
        v_event := 'pro.subscription.expiring_soon';
        v_window := '3d';
        v_importance := 'high';
      ELSIF s.paid_until BETWEEN now() + interval '6.5 days'
                            AND now() + interval '7.5 days' THEN
        v_event := 'pro.subscription.expiring_soon';
        v_window := '7d';
        v_importance := 'default';
      ELSIF s.paid_until BETWEEN now() + interval '13.5 days'
                            AND now() + interval '14.5 days' THEN
        v_event := 'pro.subscription.expiring_soon';
        v_window := '14d';
        v_importance := 'default';
      END IF;
    END IF;

    IF v_event IS NULL THEN
      CONTINUE;
    END IF;

    -- Resolve recipients = owner + admins of the center.
    FOR r IN
      SELECT * FROM public.fn_resolve_recipients(
        v_event,
        jsonb_build_object('center_id', s.center_id)
      ) AS user_id
    LOOP
      SELECT locale INTO v_locale
        FROM public.user_devices
       WHERE user_id = r.user_id AND app = 'docsera_pro'
       ORDER BY last_seen_at DESC NULLS LAST
       LIMIT 1;
      v_locale := COALESCE(v_locale, 'ar');

      v_window_label := COALESCE(v_window, 'now');

      IF v_locale = 'en' THEN
        IF v_event = 'pro.subscription.trial_ending_soon' THEN
          v_title := '⏳ Trial ending soon';
          v_body  := 'Your trial ends in ' || v_window_label ||
                     '. Renew to keep all features active.';
        ELSIF v_event = 'pro.subscription.expiring_soon' THEN
          v_title := '⏳ Subscription expiring soon';
          v_body  := 'Your subscription expires in ' || v_window_label ||
                     '. Renew to avoid interruptions.';
        ELSIF v_event = 'pro.subscription.expired_grace' THEN
          v_title := '⚠️ Subscription expired';
          v_body  := 'You''re in the grace period. Renew soon to keep '
                  || 'your full feature set.';
        ELSE
          v_title := '🚫 Subscription blocked';
          v_body  := 'Your subscription has lapsed. Some features are '
                  || 'unavailable until you renew.';
        END IF;
      ELSE
        IF v_event = 'pro.subscription.trial_ending_soon' THEN
          v_title := '⏳ التجربة المجانية تنتهي قريبًا';
          v_body  := 'تنتهي تجربتك المجانية خلال ' || v_window_label ||
                     ' — جدّد للاستمرار.';
        ELSIF v_event = 'pro.subscription.expiring_soon' THEN
          v_title := '⏳ اشتراكك ينتهي قريبًا';
          v_body  := 'سينتهي اشتراكك خلال ' || v_window_label ||
                     ' — يرجى التجديد.';
        ELSIF v_event = 'pro.subscription.expired_grace' THEN
          v_title := '⚠️ انتهى اشتراكك';
          v_body  := 'أنت في فترة السماح — جدّد قبل انتهائها.';
        ELSE
          v_title := '🚫 تم تعليق الاشتراك';
          v_body  := 'انتهى اشتراكك وبعض الميزات معطّلة حتى التجديد.';
        END IF;
      END IF;

      PERFORM public.fn_emit_notification(
        p_user_id       => r.user_id,
        p_recipient_app => 'docsera_pro',
        p_event_code    => v_event,
        p_category      => 'subscription',
        p_locale        => v_locale,
        p_title         => v_title,
        p_body          => v_body,
        p_deep_link     => 'subscription:',
        p_data          => jsonb_build_object(
                            'subscription_id', s.id,
                            'center_id',       s.center_id,
                            'trial_ends_at',   s.trial_ends_at,
                            'paid_until',      s.paid_until,
                            'grace_ends_at',   s.grace_ends_at,
                            'window',          v_window
                          ),
        p_importance    => v_importance,
        -- Dedup: one emission per (subscription, event, window). For
        -- expired_grace / expired_blocked the window is the day, so
        -- the cron emits at most one row per day per subscription per
        -- recipient.
        p_dedup_key     => 'pro-sub:' || s.id::text ||
                           ':' || v_event ||
                           ':' || COALESCE(v_window, 'now')
      );
    END LOOP;
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_pro_subscription_warnings() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_cron_pro_subscription_warnings() IS
  'Phase 2.4 cron: scans subscriptions for trial-ending / expiring / '
  'grace / blocked windows. Emits one Pro notification per recipient '
  '(owner + admins) per window via fn_resolve_recipients.';

-- Schedule daily 06:00 UTC (≈09:00 Asia/Damascus).
DO $$
BEGIN
  PERFORM cron.unschedule('pro_subscription_warnings')
    WHERE EXISTS (SELECT 1 FROM cron.job
                   WHERE jobname = 'pro_subscription_warnings');
  PERFORM cron.schedule(
    'pro_subscription_warnings',
    '0 6 * * *',
    'SELECT public.fn_cron_pro_subscription_warnings()'
  );
END $$;

COMMIT;
