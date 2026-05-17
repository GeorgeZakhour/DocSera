-- Public discovery view for the centers table.
--
-- Mirrors the pattern set by public_doctors (see DocSera-Pro
-- 20260428130000_doctor_profile_publication_gate.sql and the later
-- subscription_v2 update). The view is the security boundary: it
-- exposes only display-safe columns of active centers and is granted
-- to anon + authenticated so the patient app and the docsera-landing
-- /center/<uuid> page can fetch a center's public profile without a
-- session.
--
-- Why not security_invoker = true (like public_doctors)?
--   public_doctors relies on an existing anon-read RLS policy on the
--   doctors table — that policy was added when the publication gate
--   landed. The centers table doesn't have an analogous anon-read
--   policy, and adding one would broaden RLS on a table that's used
--   for staff/admin flows too. Using security_invoker = false here
--   keeps the public discovery surface narrow: the view owner bypasses
--   centers' RLS, and the view's explicit column list + is_active
--   filter define the public surface in one place.
--
-- Columns excluded on purpose: created_by, legacy_doctor_account_id,
--   license_number, invoice_code — internal/sensitive fields that have
--   no display use case.

CREATE OR REPLACE VIEW public.public_centers
  WITH (security_invoker = false) AS
SELECT
  c.id,
  c.name,
  c.type,
  c.description,
  c.address,
  c.location,
  c.center_image,
  c.center_image_crop,
  c.cover_image,
  c.logo_url,
  c.gallery,
  c.specialties,
  c.manual_specialties,
  c.languages,
  c.facilities,
  c.faqs,
  c.offered_services,
  c.opening_hours,
  c.insurance_accepted,
  c.founded_year,
  c.website,
  c.phone_number,
  c.mobile_number,
  c.phones,
  c.email,
  c.social_media,
  c.is_active,
  c.created_at,
  c.updated_at
FROM public.centers c
WHERE c.is_active = true;

REVOKE ALL ON public.public_centers FROM PUBLIC;
GRANT SELECT ON public.public_centers TO anon, authenticated, service_role;

COMMENT ON VIEW public.public_centers IS
  'Center rows safe for public consumption (active only, non-sensitive columns). Use for DISCOVERY queries: search, public profile, deep link / Universal Link landing page. Mirrors the public_doctors pattern; uses security_invoker=false so the view owner bypasses centers RLS — the view definition itself (explicit column list + is_active filter) is the security boundary.';
