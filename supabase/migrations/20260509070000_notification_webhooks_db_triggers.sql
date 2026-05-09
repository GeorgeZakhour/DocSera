-- Wire the three notification webhooks via DB triggers + pg_net instead
-- of relying on the Supabase Studio "database webhooks" UI. The edge
-- function handlers already exist for these tables — this migration
-- just makes sure the function gets invoked on the right rows.
--
-- Tables wired:
--   conversations.UPDATE           → handlers/conversations.ts
--   documents.DELETE               → handlers/documents_deletion.ts
--   doctor_vacations.INSERT        → handlers/doctor_vacations.ts
--
-- Why DB triggers, not Studio webhooks:
--   * Studio config is operator-driven, easy to forget, and lives outside
--     migrations so it can't be reproduced on a fresh environment.
--   * pg_net + a trigger function is just code — it ships with the repo.

BEGIN;

-- ---------------------------------------------------------------------------
-- Generic dispatcher: build a webhook-shaped JSON payload and POST it to the
-- push_notifications edge function. Mirrors the Supabase database-webhook
-- envelope so the edge function dispatcher (index.ts) can stay unchanged.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_dispatch_notification_webhook(
  p_type     text,
  p_table    text,
  p_record   jsonb,
  p_old      jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_url  text;
  v_anon text;
BEGIN
  BEGIN
    SELECT decrypted_secret INTO v_anon
      FROM vault.decrypted_secrets WHERE name = 'edge_function_anon_key' LIMIT 1;
    SELECT decrypted_secret INTO v_url
      FROM vault.decrypted_secrets WHERE name = 'edge_function_base_url' LIMIT 1;

    IF v_anon IS NULL OR v_url IS NULL THEN
      RAISE NOTICE 'fn_dispatch_notification_webhook: vault secrets missing — skipping';
      RETURN;
    END IF;

    PERFORM net.http_post(
      url := v_url || '/functions/v1/push_notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_anon
      ),
      body := jsonb_build_object(
        'type', p_type,
        'table', p_table,
        'schema', 'public',
        'record', p_record,
        'old_record', p_old
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'fn_dispatch_notification_webhook(% %): %', p_table, p_type, SQLERRM;
  END;
END $$;

-- ---------------------------------------------------------------------------
-- conversations.UPDATE
-- Fires when a conversation is closed/reopened (is_closed transition).
-- The handler already dedups by including a fresh ISO timestamp in the
-- dedup key, so multi-toggle flows fire one notification per transition.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_conversations_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Only dispatch when is_closed actually transitioned. Other UPDATEs
  -- (last_message, updated_at) shouldn't fan out.
  IF COALESCE(NEW.is_closed, false) <> COALESCE(OLD.is_closed, false) THEN
    PERFORM public.fn_dispatch_notification_webhook(
      'UPDATE', 'conversations', to_jsonb(NEW), to_jsonb(OLD)
    );
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_conversation_state ON public.conversations;
CREATE TRIGGER trg_notify_conversation_state
AFTER UPDATE ON public.conversations
FOR EACH ROW EXECUTE FUNCTION public.fn_trg_conversations_notify();

-- ---------------------------------------------------------------------------
-- documents.DELETE
-- Fires when a doctor-added document is removed from a patient file.
-- The handler filters source='doctor_added' so patient self-uploads
-- being deleted don't emit.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_documents_delete_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.fn_dispatch_notification_webhook(
    'DELETE', 'documents', NULL, to_jsonb(OLD)
  );
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_notify_document_deletion ON public.documents;
CREATE TRIGGER trg_notify_document_deletion
AFTER DELETE ON public.documents
FOR EACH ROW EXECUTE FUNCTION public.fn_trg_documents_delete_notify();

-- ---------------------------------------------------------------------------
-- doctor_vacations.INSERT
-- Fires when a doctor sets a vacation. The handler resolves affected
-- patient appointments and dedups one notification per user.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_doctor_vacations_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.fn_dispatch_notification_webhook(
    'INSERT', 'doctor_vacations', to_jsonb(NEW), NULL
  );
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_doctor_vacation ON public.doctor_vacations;
CREATE TRIGGER trg_notify_doctor_vacation
AFTER INSERT ON public.doctor_vacations
FOR EACH ROW EXECUTE FUNCTION public.fn_trg_doctor_vacations_notify();

COMMIT;
