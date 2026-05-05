-- User-legal-consents — audit trail of which user accepted which legal
-- document at which version. Required for the ministry's record-keeping
-- expectations and for proving informed consent in any future dispute.

BEGIN;

CREATE TABLE IF NOT EXISTS public.user_legal_consents (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  document_code text NOT NULL,                    -- 'privacy_policy' / 'terms_of_service' / …
  version       text NOT NULL,                    -- '2.0', '1.0', etc.
  accepted_at   timestamptz NOT NULL DEFAULT now(),
  app_version   text,
  platform      text,
  locale        text,
  UNIQUE (user_id, document_code, version)
);

REVOKE ALL ON public.user_legal_consents FROM anon, authenticated, PUBLIC;
ALTER TABLE public.user_legal_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_legal_consents FORCE  ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_user_legal_consents_user
  ON public.user_legal_consents (user_id, accepted_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_legal_consents_doc
  ON public.user_legal_consents (document_code, version);

-- Record consent. Idempotent on (user_id, document_code, version).
CREATE OR REPLACE FUNCTION public.rpc_record_legal_consent(
  p_document_code text,
  p_version       text,
  p_app_version   text DEFAULT NULL,
  p_platform      text DEFAULT NULL,
  p_locale        text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  IF p_document_code IS NULL OR p_version IS NULL THEN
    RAISE EXCEPTION 'INVALID_INPUT';
  END IF;
  -- Length guards (defense-in-depth against weird inputs)
  IF length(p_document_code) > 64 OR length(p_version) > 16 THEN
    RAISE EXCEPTION 'INVALID_INPUT';
  END IF;

  INSERT INTO public.user_legal_consents
    (user_id, document_code, version, app_version, platform, locale)
  VALUES (v_user_id, p_document_code, p_version, p_app_version, p_platform, p_locale)
  ON CONFLICT (user_id, document_code, version) DO NOTHING;
END $$;

REVOKE ALL ON FUNCTION public.rpc_record_legal_consent(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_record_legal_consent(text, text, text, text, text) TO authenticated;

-- Read which versions the current user has accepted.
CREATE OR REPLACE FUNCTION public.rpc_get_my_legal_consents()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'document_code', document_code,
    'version',       version,
    'accepted_at',   accepted_at
  ) ORDER BY accepted_at DESC), '[]'::jsonb) INTO v_result
  FROM public.user_legal_consents WHERE user_id = v_user_id;
  RETURN v_result;
END $$;

REVOKE ALL ON FUNCTION public.rpc_get_my_legal_consents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_my_legal_consents() TO authenticated;

COMMIT;
