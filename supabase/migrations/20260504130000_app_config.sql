-- App-level config that the client checks at startup, primarily for the
-- forced-update gate. Single-row table (id=1 enforced) so the client always
-- gets one config object back.
--
-- Read path: clients call rpc_get_app_config() (SECURITY DEFINER, granted to
-- anon + authenticated) — they never read the table directly. Updates are
-- done by the operator via SQL or Supabase Studio with the service role.

BEGIN;

CREATE TABLE IF NOT EXISTS public.app_config (
  id                            int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  min_supported_version_ios     text NOT NULL,
  min_supported_version_android text NOT NULL,
  latest_version_ios            text NOT NULL,
  latest_version_android        text NOT NULL,
  ios_store_url                 text NOT NULL,
  android_store_url             text NOT NULL,
  force_update_message_en       text NOT NULL DEFAULT 'A required update is available. Please update DocSera to continue.',
  force_update_message_ar       text NOT NULL DEFAULT 'يتوفر تحديث مطلوب. يرجى تحديث دوكسيرا للمتابعة.',
  updated_at                    timestamptz NOT NULL DEFAULT now()
);

-- Lock down direct API access. All reads go through the RPC.
REVOKE ALL ON public.app_config FROM anon, authenticated, PUBLIC;
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config FORCE  ROW LEVEL SECURITY;

-- Seed the single row with placeholder values that won't force any update yet.
-- The operator should update these before launch.
INSERT INTO public.app_config (
  id,
  min_supported_version_ios, min_supported_version_android,
  latest_version_ios,        latest_version_android,
  ios_store_url,             android_store_url
) VALUES (
  1,
  '0.0.0', '0.0.0',
  '0.0.0', '0.0.0',
  'https://apps.apple.com/app/docsera/id000000000',
  'https://play.google.com/store/apps/details?id=app.docsera'
)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.rpc_get_app_config()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT to_jsonb(c) - 'id' - 'updated_at'
  FROM public.app_config c
  WHERE c.id = 1;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_app_config() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_app_config() TO anon, authenticated;

COMMIT;

-- Verify after applying:
--   SELECT public.rpc_get_app_config();
