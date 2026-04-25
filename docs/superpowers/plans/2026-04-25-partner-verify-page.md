# Partner Verify Page Enhancements (Sub-project A) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the existing `verify-partner-voucher` Supabase Edge Function with a two-step preview→confirm flow, an optional QR scanner, a partner-identity header, a third "Offers" tab, and a paginated activity log with filters.

**Architecture:** Single edge function (`supabase/functions/verify-partner-voucher`) split into three focused files (`index.ts` routing, `html.ts` HTML/CSS/client JS, `handlers.ts` JSON action handlers). Four new Postgres RPCs alongside the existing `verify_voucher` (kept untouched). All authentication is by URL query-param secret matching `partners.verification_secret`. No schema changes.

**Tech Stack:** Deno (edge function runtime), TypeScript, vanilla HTML/CSS/JS, [`qr-scanner`](https://github.com/nimiq/qr-scanner) v1.4.2 from CDN, Postgres / PL-pgSQL, Supabase JS client.

**Spec:** [docs/superpowers/specs/2026-04-25-partner-verify-page-design.md](../specs/2026-04-25-partner-verify-page-design.md)

**Repo:** Migrations + edge function live in `/Users/georgezakhour/development/DocSera-Pro` (the doctor app owns the `supabase/` folder; the patient app does not need any changes for this feature).

---

## File map

**DocSera-Pro:**

- Create: `supabase/migrations/20260425100000_partner_verify_v2.sql` — 4 new RPCs (`preview_voucher`, `partner_info`, `partner_active_offers`, `partner_history`).
- Modify: `supabase/functions/verify-partner-voucher/index.ts` — rewritten as ~80-line router only.
- Create: `supabase/functions/verify-partner-voucher/html.ts` — HTML template + CSS + client JS, exported as `HTML_PAGE`.
- Create: `supabase/functions/verify-partner-voucher/handlers.ts` — JSON action handlers (`handleWhoami`, `handlePreview`, `handleConsume`, `handleOffers`, `handleHistory`).

**No DocSera (patient app) changes required for this feature.**

---

## Task 1: Add `preview_voucher` RPC (read-only voucher inspection)

**Repo:** DocSera-Pro

**Files:**
- Create: `supabase/migrations/20260425100000_partner_verify_v2.sql`

- [ ] **Step 1: Create the migration file with the `preview_voucher` RPC**

Create the file `/Users/georgezakhour/development/DocSera-Pro/supabase/migrations/20260425100000_partner_verify_v2.sql` with EXACTLY:

```sql
-- ============================================================
-- PARTNER VERIFY PAGE v2 — RPCs
-- Read-only inspection + partner identity + offers list + history.
-- The existing public.verify_voucher RPC is kept exactly as-is
-- (it is the consume step; this migration adds the read-only
-- preview that runs before the partner confirms.)
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- RPC 1: preview_voucher — same shape as verify_voucher's success
-- payload, plus redeemed_at + expires_at for the confirmation modal.
-- Does NOT mutate vouchers.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.preview_voucher(
  p_code text,
  p_partner_secret text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_voucher record;
  v_partner record;
BEGIN
  SELECT v.*, o.partner_id, o.discount_type, o.discount_value, o.title, o.title_ar
  INTO v_voucher
  FROM public.vouchers v
  JOIN public.offers   o ON v.offer_id = o.id
  WHERE v.code = upper(p_code);

  IF v_voucher IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'error', 'voucher_not_found');
  END IF;

  SELECT * INTO v_partner FROM public.partners WHERE id = v_voucher.partner_id;
  IF v_partner IS NULL OR v_partner.verification_secret != p_partner_secret THEN
    RETURN jsonb_build_object('valid', false, 'error', 'unauthorized');
  END IF;

  IF v_voucher.status = 'used' THEN
    RETURN jsonb_build_object(
      'valid', false, 'error', 'already_used', 'used_at', v_voucher.used_at
    );
  END IF;

  IF v_voucher.status = 'expired' OR v_voucher.expires_at < now() THEN
    RETURN jsonb_build_object('valid', false, 'error', 'expired');
  END IF;

  IF v_voucher.status = 'cancelled' THEN
    RETURN jsonb_build_object('valid', false, 'error', 'cancelled');
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'code', v_voucher.code,
    'offer_title', v_voucher.title,
    'offer_title_ar', v_voucher.title_ar,
    'discount_type', v_voucher.discount_type,
    'discount_value', v_voucher.discount_value,
    'patient_first_name',
      (SELECT first_name FROM public.users WHERE id = v_voucher.user_id),
    'redeemed_at', v_voucher.redeemed_at,
    'expires_at', v_voucher.expires_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.preview_voucher(text, text) TO authenticated;
```

- [ ] **Step 2: Apply locally and verify (skip if Docker not running)**

Try `supabase status`. If a local Supabase instance is running:

```bash
cd /Users/georgezakhour/development/DocSera-Pro
supabase db push
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" \
  -c "SELECT public.preview_voucher('DS-XXXXXX', 'wrong-secret');"
```
Expected: jsonb `{"valid": false, "error": "voucher_not_found"}` or `{"valid": false, "error": "unauthorized"}` depending on whether `DS-XXXXXX` exists.

If Supabase is **not** running locally, **do NOT try to start it**. Skip and note in your report — verification will happen against staging later.

- [ ] **Step 3: Commit**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
git add supabase/migrations/20260425100000_partner_verify_v2.sql
git commit -m "feat(loyalty): add preview_voucher RPC (read-only voucher inspection)"
```

The user has authorized committing directly to `main`.

---

## Task 2: Add `partner_info` RPC

**Repo:** DocSera-Pro

**Files:**
- Modify: `supabase/migrations/20260425100000_partner_verify_v2.sql` (append the new RPC at the end of the file)

- [ ] **Step 1: Append `partner_info` to the migration file**

Append the following AT THE END of `/Users/georgezakhour/development/DocSera-Pro/supabase/migrations/20260425100000_partner_verify_v2.sql`:

```sql

-- ──────────────────────────────────────────────────────────────
-- RPC 2: partner_info — returns the partner row identified by the
-- secret, with verification_secret EXPLICITLY excluded from the
-- projection (defence-in-depth).
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.partner_info(p_partner_secret text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_partner record;
BEGIN
  SELECT * INTO v_partner FROM public.partners
  WHERE verification_secret = p_partner_secret AND is_active = true;

  IF v_partner IS NULL THEN
    RETURN jsonb_build_object('error', 'unauthorized');
  END IF;

  RETURN jsonb_build_object(
    'name', v_partner.name,
    'name_ar', v_partner.name_ar,
    'logo_url', v_partner.logo_url,
    'address_ar', v_partner.address_ar,
    'phone', v_partner.phone,
    'brand_color', v_partner.brand_color,
    'partner_type', v_partner.partner_type
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.partner_info(text) TO authenticated;
```

- [ ] **Step 2: Apply and smoke-test (skip if Docker not running)**

If Supabase is running locally:
```bash
cd /Users/georgezakhour/development/DocSera-Pro
supabase db push
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" \
  -c "SELECT public.partner_info((SELECT verification_secret FROM public.partners LIMIT 1));"
```
Expected: jsonb partner object containing `name`, `name_ar`, `brand_color`, `partner_type`, etc., and **no** `verification_secret` key.

Otherwise skip per Task 1's guidance.

- [ ] **Step 3: Commit**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
git add supabase/migrations/20260425100000_partner_verify_v2.sql
git commit -m "feat(loyalty): add partner_info RPC for partner identity in verify page"
```

---

## Task 3: Add `partner_active_offers` RPC

**Repo:** DocSera-Pro

**Files:**
- Modify: `supabase/migrations/20260425100000_partner_verify_v2.sql` (append)

- [ ] **Step 1: Append `partner_active_offers`**

Append the following AT THE END of the migration file:

```sql

-- ──────────────────────────────────────────────────────────────
-- RPC 3: partner_active_offers — list the partner's active offers
-- for the read-only "Offers" tab in the verify page. Same activity
-- filter semantics as get_available_offers but scoped to one partner.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.partner_active_offers(p_partner_secret text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_partner_id uuid;
  v_offers     jsonb;
BEGIN
  SELECT id INTO v_partner_id FROM public.partners
  WHERE verification_secret = p_partner_secret AND is_active = true;

  IF v_partner_id IS NULL THEN
    RETURN jsonb_build_object('error', 'unauthorized');
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'title', o.title,
        'title_ar', o.title_ar,
        'description_ar', o.description_ar,
        'discount_type', o.discount_type,
        'discount_value', o.discount_value,
        'points_cost', o.points_cost,
        'voucher_validity_days', o.voucher_validity_days,
        'current_redemptions', o.current_redemptions,
        'max_redemptions', o.max_redemptions,
        'end_date', o.end_date,
        'is_mega_offer', o.is_mega_offer
      )
      ORDER BY o.is_mega_offer DESC, o.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_offers
  FROM public.offers o
  WHERE o.partner_id = v_partner_id
    AND o.is_active = true
    AND (o.start_date IS NULL OR o.start_date <= now())
    AND (o.end_date   IS NULL OR o.end_date   >  now())
    AND (o.max_redemptions IS NULL OR o.current_redemptions < o.max_redemptions);

  RETURN jsonb_build_object('offers', v_offers);
END;
$$;

GRANT EXECUTE ON FUNCTION public.partner_active_offers(text) TO authenticated;
```

- [ ] **Step 2: Smoke-test (skip if Docker not running)**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
supabase db push
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" \
  -c "SELECT public.partner_active_offers((SELECT verification_secret FROM public.partners LIMIT 1));"
```
Expected: jsonb with `offers` array (may be empty if no active offers seeded for that partner).

- [ ] **Step 3: Commit**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
git add supabase/migrations/20260425100000_partner_verify_v2.sql
git commit -m "feat(loyalty): add partner_active_offers RPC"
```

---

## Task 4: Add `partner_history` RPC (paginated, filterable)

**Repo:** DocSera-Pro

**Files:**
- Modify: `supabase/migrations/20260425100000_partner_verify_v2.sql` (append)

- [ ] **Step 1: Append `partner_history`**

Append AT THE END of the migration file:

```sql

-- ──────────────────────────────────────────────────────────────
-- RPC 4: partner_history — paginated history of vouchers consumed
-- by this partner, filterable by date window and code substring.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.partner_history(
  p_partner_secret text,
  p_date_from      timestamptz,
  p_date_to        timestamptz,
  p_search         text,
  p_limit          int,
  p_offset         int
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_partner_id uuid;
  v_total      int;
  v_rows       jsonb;
  v_limit      int := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
  v_offset     int := GREATEST(COALESCE(p_offset, 0), 0);
  v_search     text := NULLIF(trim(p_search), '');
BEGIN
  SELECT id INTO v_partner_id FROM public.partners
  WHERE verification_secret = p_partner_secret AND is_active = true;

  IF v_partner_id IS NULL THEN
    RETURN jsonb_build_object('total', 0, 'rows', '[]'::jsonb, 'error', 'unauthorized');
  END IF;

  -- Total count (for "Load more" button visibility)
  SELECT count(*)::int INTO v_total
  FROM public.vouchers v
  JOIN public.offers   o ON v.offer_id = o.id
  WHERE o.partner_id = v_partner_id
    AND v.status     = 'used'
    AND v.used_at   >= p_date_from
    AND v.used_at   <= p_date_to
    AND (v_search IS NULL OR upper(v.code) LIKE '%' || upper(v_search) || '%');

  -- Page rows
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'code', page.code,
        'offer_title', page.title,
        'offer_title_ar', page.title_ar,
        'discount_type', page.discount_type,
        'discount_value', page.discount_value,
        'patient_first_name',
          (SELECT first_name FROM public.users WHERE id = page.user_id),
        'used_at', page.used_at,
        'redeemed_at', page.redeemed_at
      )
      ORDER BY page.used_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM (
    SELECT v.code, v.user_id, v.used_at, v.redeemed_at,
           o.title, o.title_ar, o.discount_type, o.discount_value
    FROM public.vouchers v
    JOIN public.offers   o ON v.offer_id = o.id
    WHERE o.partner_id = v_partner_id
      AND v.status     = 'used'
      AND v.used_at   >= p_date_from
      AND v.used_at   <= p_date_to
      AND (v_search IS NULL OR upper(v.code) LIKE '%' || upper(v_search) || '%')
    ORDER BY v.used_at DESC
    LIMIT v_limit OFFSET v_offset
  ) AS page;

  RETURN jsonb_build_object('total', v_total, 'rows', v_rows);
END;
$$;

GRANT EXECUTE ON FUNCTION public.partner_history(text, timestamptz, timestamptz, text, int, int) TO authenticated;
```

- [ ] **Step 2: Smoke-test pagination (skip if Docker not running)**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
supabase db push
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" \
  -c "SELECT public.partner_history(
        (SELECT verification_secret FROM public.partners LIMIT 1),
        now() - interval '30 days', now(), NULL, 20, 0
      );"
```
Expected: jsonb `{"total": <int>, "rows": [...]}` with up to 20 entries; missing-secret path tested implicitly by Task 2.

- [ ] **Step 3: Commit**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
git add supabase/migrations/20260425100000_partner_verify_v2.sql
git commit -m "feat(loyalty): add partner_history RPC (paginated, filterable)"
```

---

## Task 5: Create `handlers.ts` (JSON action handlers)

**Repo:** DocSera-Pro

**Files:**
- Create: `supabase/functions/verify-partner-voucher/handlers.ts`

- [ ] **Step 1: Write the handlers module**

Create `/Users/georgezakhour/development/DocSera-Pro/supabase/functions/verify-partner-voucher/handlers.ts` with EXACTLY:

```typescript
// JSON action handlers for the verify-partner-voucher edge function.
// Each handler corresponds to one POST `action` value and calls one RPC.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function client(): SupabaseClient {
  return createClient(supabaseUrl, serviceKey);
}

const json = (body: unknown, init: ResponseInit = {}): Response =>
  new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      ...(init.headers ?? {}),
    },
  });

interface BaseBody { action: string; partner_secret?: string }

function requireSecret(body: BaseBody): string | null {
  const s = body.partner_secret;
  return typeof s === "string" && s.length > 0 ? s : null;
}

// ── action: whoami ─────────────────────────────────────────────────────
export async function handleWhoami(body: BaseBody): Promise<Response> {
  const secret = requireSecret(body);
  if (!secret) return json({ error: "missing_params" });

  const { data, error } = await client().rpc("partner_info", {
    p_partner_secret: secret,
  });
  if (error) return json({ error: "server_error" });
  return json(data);
}

// ── action: preview ────────────────────────────────────────────────────
interface CodeBody extends BaseBody { code?: string }

export async function handlePreview(body: CodeBody): Promise<Response> {
  const secret = requireSecret(body);
  const code = body.code?.trim();
  if (!secret || !code) return json({ valid: false, error: "missing_params" });

  const { data, error } = await client().rpc("preview_voucher", {
    p_code: code,
    p_partner_secret: secret,
  });
  if (error) return json({ valid: false, error: "server_error" });
  return json(data);
}

// ── action: consume ────────────────────────────────────────────────────
export async function handleConsume(body: CodeBody): Promise<Response> {
  const secret = requireSecret(body);
  const code = body.code?.trim();
  if (!secret || !code) return json({ valid: false, error: "missing_params" });

  const { data, error } = await client().rpc("verify_voucher", {
    p_code: code,
    p_partner_secret: secret,
  });
  if (error) return json({ valid: false, error: "server_error" });
  return json(data);
}

// ── action: offers ─────────────────────────────────────────────────────
export async function handleOffers(body: BaseBody): Promise<Response> {
  const secret = requireSecret(body);
  if (!secret) return json({ error: "missing_params" });

  const { data, error } = await client().rpc("partner_active_offers", {
    p_partner_secret: secret,
  });
  if (error) return json({ error: "server_error" });
  return json(data);
}

// ── action: history ────────────────────────────────────────────────────
interface HistoryBody extends BaseBody {
  date_from?: string;
  date_to?: string;
  search?: string | null;
  limit?: number;
  offset?: number;
}

export async function handleHistory(body: HistoryBody): Promise<Response> {
  const secret = requireSecret(body);
  if (!secret) return json({ total: 0, rows: [], error: "missing_params" });

  const { data, error } = await client().rpc("partner_history", {
    p_partner_secret: secret,
    p_date_from: body.date_from ?? null,
    p_date_to:   body.date_to   ?? null,
    p_search:    body.search    ?? null,
    p_limit:     body.limit     ?? 20,
    p_offset:    body.offset    ?? 0,
  });
  if (error) return json({ total: 0, rows: [], error: "server_error" });
  return json(data);
}
```

- [ ] **Step 2: Lint-check by syntax (Deno is type-checked at deploy)**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
node -e "require('fs').readFileSync('supabase/functions/verify-partner-voucher/handlers.ts','utf8');"
```
Expected: no output (file readable). The real type check happens at `supabase functions deploy` — that runs in Task 9.

- [ ] **Step 3: Commit**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
git add supabase/functions/verify-partner-voucher/handlers.ts
git commit -m "feat(loyalty): add JSON action handlers for verify-partner-voucher"
```

---

## Task 6: Create `html.ts` (HTML template + CSS + client JS)

**Repo:** DocSera-Pro

**Files:**
- Create: `supabase/functions/verify-partner-voucher/html.ts`

This is the largest single file in the feature (~280 lines). Treat it as a single monolithic template literal — no need to split further; it's the entire client-side surface.

- [ ] **Step 1: Write the HTML template**

Create `/Users/georgezakhour/development/DocSera-Pro/supabase/functions/verify-partner-voucher/html.ts` with EXACTLY:

```typescript
// Self-contained HTML page served by GET /. Contains all CSS and client JS
// inline so the partner page is one HTTP request. Loads qr-scanner from CDN
// only if the Scan button is mounted.
export const HTML_PAGE = String.raw`<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<title>DocSera — التحقق من القسيمة</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800&family=Montserrat:wght@400;500;600;700;800&display=swap');
:root {
  --c-main: #009092; --c-main-dark: #007E80;
  --c-bg: #F7F8FA; --c-card: #FFFFFF;
  --c-text: #2C3E50; --c-text-soft: #6B7280;
  --c-success: #009092; --c-error: #E53935; --c-warning: #FF9800;
  --c-mega: #FF8F00;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body, button, input, textarea {
  font-family: 'Cairo', 'Montserrat', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
body { background: var(--c-bg); min-height: 100vh; color: var(--c-text); padding: 20px; }
.shell { max-width: 480px; margin: 0 auto; }
.header { background: var(--c-card); border-radius: 18px; padding: 14px 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
.header .logo { width: 48px; height: 48px; border-radius: 50%; flex-shrink: 0; background: var(--c-main); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 20px; overflow: hidden; }
.header .logo img { width: 100%; height: 100%; object-fit: cover; }
.header .meta { flex: 1; min-width: 0; }
.header .meta .name { font-size: 16px; font-weight: 800; color: var(--c-text); }
.header .meta .sub { font-size: 12px; font-weight: 600; color: var(--c-main); margin-top: 2px; }
.header .brand { font-size: 11px; color: var(--c-text-soft); font-weight: 600; }

.tabs { display: flex; background: var(--c-card); border-radius: 14px; padding: 4px; margin-bottom: 14px; box-shadow: 0 2px 6px rgba(0,0,0,0.04); }
.tabs button { flex: 1; border: 0; background: transparent; padding: 10px; border-radius: 10px; font-size: 14px; font-weight: 700; color: var(--c-text-soft); cursor: pointer; transition: background 0.15s; }
.tabs button.active { background: var(--c-main); color: #fff; }

.card { background: var(--c-card); border-radius: 18px; padding: 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
.card + .card { margin-top: 12px; }

.input { width: 100%; padding: 14px 16px; border: 2px solid var(--c-text-soft); border-radius: 10px; font-size: 18px; text-transform: uppercase; letter-spacing: 3px; text-align: center; direction: ltr; transition: border-color 0.15s; outline: none; }
.input:focus { border-color: var(--c-main); }

.btn { width: 100%; padding: 14px; border-radius: 14px; border: 0; font-size: 16px; font-weight: 700; cursor: pointer; transition: background 0.15s; font-family: inherit; }
.btn-primary { background: var(--c-main); color: #fff; }
.btn-primary:hover { background: var(--c-main-dark); }
.btn-primary:disabled { background: #ccc; cursor: not-allowed; }
.btn-secondary { background: transparent; color: var(--c-main); border: 2px solid var(--c-main); }
.btn-row { margin-top: 12px; }

.helper { font-size: 12px; color: var(--c-text-soft); text-align: center; margin-top: 8px; line-height: 1.5; }
.banner { padding: 12px 14px; border-radius: 10px; margin-top: 14px; font-size: 14px; font-weight: 600; }
.banner-error { background: #fef2f2; color: var(--c-error); border: 1px solid #fecaca; }
.banner-success { background: #ecfdf5; color: var(--c-success); border: 1px solid #a7f3d0; }

.modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: none; align-items: center; justify-content: center; z-index: 1000; padding: 16px; }
.modal-backdrop.open { display: flex; }
.modal { background: var(--c-card); border-radius: 24px; padding: 24px; max-width: 420px; width: 100%; }
.modal h3 { font-size: 18px; font-weight: 800; color: var(--c-success); text-align: center; margin-bottom: 16px; }
.modal .row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f0f0f0; font-size: 14px; }
.modal .row:last-of-type { border-bottom: 0; }
.modal .row .k { color: var(--c-text-soft); }
.modal .row .v { color: var(--c-text); font-weight: 700; }
.modal .warn { background: #fff8e1; color: #92400e; padding: 12px; border-radius: 10px; margin-top: 14px; font-size: 13px; line-height: 1.5; border: 1px solid #ffe082; }
.modal .actions { display: flex; gap: 10px; margin-top: 18px; }
.modal .actions .btn { padding: 12px; }
.btn-cancel { background: #f5f5f5; color: var(--c-text); }

.scanner-overlay { position: fixed; inset: 0; background: #000; display: none; flex-direction: column; align-items: center; justify-content: center; z-index: 2000; }
.scanner-overlay.open { display: flex; }
.scanner-overlay video { width: 100%; max-width: 520px; max-height: 70vh; }
.scanner-close { position: absolute; top: 14px; right: 14px; background: rgba(255,255,255,0.18); border: 0; color: #fff; width: 40px; height: 40px; border-radius: 50%; font-size: 20px; cursor: pointer; }
.scanner-hint { color: #fff; font-size: 14px; margin-top: 16px; }

.filters { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; }
.chip { padding: 8px 14px; border-radius: 20px; background: #fff; border: 1px solid #e5e7eb; font-size: 13px; font-weight: 600; color: var(--c-text-soft); cursor: pointer; transition: all 0.15s; }
.chip.active { background: var(--c-main); color: #fff; border-color: var(--c-main); }
.search-input { width: 100%; padding: 10px 14px; border: 2px solid #e5e7eb; border-radius: 10px; font-size: 14px; outline: none; margin-bottom: 8px; }
.search-input:focus { border-color: var(--c-main); }
.count-line { font-size: 13px; color: var(--c-text-soft); margin-bottom: 12px; padding: 0 4px; }
.day-header { font-size: 13px; font-weight: 700; color: var(--c-main); margin: 18px 0 8px; padding: 6px 8px; background: rgba(0,144,146,0.06); border-radius: 6px; }
.entry { background: var(--c-card); border-radius: 12px; padding: 12px 14px; margin-bottom: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.04); font-size: 13px; }
.entry .top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
.entry .code { font-family: 'Montserrat', monospace; font-weight: 700; color: var(--c-text); letter-spacing: 1px; }
.entry .time { color: var(--c-text-soft); font-size: 12px; }
.entry .title { color: var(--c-text); font-weight: 600; margin: 4px 0; }
.entry .bottom { display: flex; justify-content: space-between; color: var(--c-text-soft); font-size: 12px; }

.skeleton { background: #f0f0f0; border-radius: 12px; height: 76px; margin-bottom: 8px; animation: pulse 1.4s ease-in-out infinite; }
@keyframes pulse { 0% { opacity: 0.6; } 50% { opacity: 1; } 100% { opacity: 0.6; } }

.empty { text-align: center; padding: 40px 20px; color: var(--c-text-soft); font-size: 14px; }
.empty .icon { font-size: 48px; margin-bottom: 12px; opacity: 0.4; }

.full-error { text-align: center; padding: 60px 20px; }
.full-error .icon { font-size: 64px; margin-bottom: 16px; }
.full-error h2 { font-size: 18px; font-weight: 800; color: var(--c-text); margin-bottom: 8px; }
.full-error p { font-size: 14px; color: var(--c-text-soft); line-height: 1.6; }

.toast { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); background: var(--c-text); color: #fff; padding: 12px 20px; border-radius: 10px; font-size: 14px; font-weight: 600; z-index: 3000; opacity: 0; transition: opacity 0.2s; pointer-events: none; }
.toast.show { opacity: 1; }
.hidden { display: none !important; }
</style>
</head>
<body>
  <div class="shell" id="shell">
    <!-- Header / tabs / panels are rendered by JS after whoami() resolves. -->
  </div>

  <div class="modal-backdrop" id="confirm-modal">
    <div class="modal" id="confirm-modal-body"></div>
  </div>

  <div class="scanner-overlay" id="scanner">
    <button class="scanner-close" id="scanner-close" aria-label="إغلاق">✕</button>
    <video id="scanner-video" playsinline></video>
    <div class="scanner-hint">وجّه الكاميرا نحو رمز QR</div>
  </div>

  <div class="toast" id="toast"></div>

<script type="module">
const PARTNER_SECRET = new URLSearchParams(location.search).get('s') || '';
const ENDPOINT = location.pathname;

const fmtDateTime = new Intl.DateTimeFormat('ar-SY', { timeZone: 'Asia/Damascus', year: 'numeric', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit', hour12: true });
const fmtDateOnly = new Intl.DateTimeFormat('ar-SY', { timeZone: 'Asia/Damascus', year: 'numeric', month: 'long', day: 'numeric' });
const fmtTimeOnly = new Intl.DateTimeFormat('ar-SY', { timeZone: 'Asia/Damascus', hour: 'numeric', minute: '2-digit', hour12: true });
const todayDateStr = () => fmtDateOnly.format(new Date());

const ERROR_MSG = {
  voucher_not_found: 'رمز القسيمة غير موجود.',
  unauthorized: 'غير مصرّح. يرجى استخدام رابط التحقق المخصص لكم.',
  already_used: (used_at) => 'تم استخدام هذه القسيمة مسبقاً' + (used_at ? ' (' + fmtDateTime.format(new Date(used_at)) + ')' : '') + '.',
  expired: 'انتهت صلاحية هذه القسيمة.',
  cancelled: 'تم إلغاء هذه القسيمة.',
  network_error: 'خطأ في الاتصال. يرجى التحقق من الشبكة.',
  server_error: 'خطأ في الخادم. حاول مرة أخرى.',
  missing_params: 'بيانات ناقصة.',
};

async function api(action, extra = {}) {
  try {
    const res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action, partner_secret: PARTNER_SECRET, ...extra }),
    });
    return await res.json();
  } catch (e) { return { error: 'network_error' }; }
}

function el(tag, props = {}, ...children) {
  const node = Object.assign(document.createElement(tag), props);
  children.flat().forEach(c => node.append(c?.nodeType ? c : (c == null ? '' : String(c))));
  return node;
}

function showToast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg; t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 2400);
}

async function detectCamera() {
  if (!navigator.mediaDevices?.enumerateDevices) return false;
  try {
    const devices = await navigator.mediaDevices.enumerateDevices();
    return devices.some(d => d.kind === 'videoinput');
  } catch { return false; }
}

let qrScanner = null;
async function openScanner(onCode) {
  const overlay = document.getElementById('scanner');
  const video = document.getElementById('scanner-video');
  overlay.classList.add('open');
  try {
    const QrScanner = (await import('https://cdn.jsdelivr.net/npm/qr-scanner@1.4.2/qr-scanner.min.js')).default;
    qrScanner = new QrScanner(video, (result) => {
      const text = result.data || result;
      if (/^DS-[A-Z0-9]{6}$/.test(text)) {
        navigator.vibrate?.(50);
        closeScanner();
        onCode(text);
      }
    }, { highlightScanRegion: true, highlightCodeOutline: true });
    await qrScanner.start();
  } catch (e) {
    closeScanner();
    showToast('الرجاء السماح بالوصول للكاميرا من إعدادات المتصفح');
  }
}
function closeScanner() {
  document.getElementById('scanner').classList.remove('open');
  if (qrScanner) { qrScanner.stop(); qrScanner.destroy(); qrScanner = null; }
}
document.getElementById('scanner-close').onclick = closeScanner;
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeScanner(); });

function renderHeader(partner) {
  const initial = (partner.name_ar || partner.name || '?')[0];
  const logo = el('div', { className: 'logo' });
  if (partner.logo_url) {
    const img = el('img', { src: partner.logo_url, alt: '' });
    img.onerror = () => { logo.textContent = initial; };
    logo.append(img);
  } else {
    logo.textContent = initial;
  }
  if (partner.brand_color) logo.style.background = partner.brand_color;
  return el('div', { className: 'header' },
    logo,
    el('div', { className: 'meta' },
      el('div', { className: 'name' }, partner.name_ar || partner.name),
      el('div', { className: 'sub' }, 'شريك صحي'),
    ),
    el('div', { className: 'brand' }, 'DocSera'),
  );
}

function renderTabs(activeKey, onSelect) {
  const wrap = el('div', { className: 'tabs' });
  [['verify','تحقق'],['offers','العروض'],['history','النشاط']].forEach(([k,label]) => {
    const b = el('button', { textContent: label });
    if (k === activeKey) b.classList.add('active');
    b.onclick = () => onSelect(k);
    wrap.append(b);
  });
  return wrap;
}

// ── Verify tab ────────────────────────────────────────────────────────────
async function renderVerifyTab(panel, hasCamera) {
  panel.innerHTML = '';
  const card = el('div', { className: 'card' });
  const input = el('input', { className: 'input', placeholder: 'DS-XXXXXX', maxLength: 10, autocomplete: 'off' });
  input.addEventListener('input', () => { input.value = input.value.toUpperCase(); });
  const verifyBtn = el('button', { className: 'btn btn-primary', textContent: 'تحقّق' });
  card.append(input);

  if (hasCamera) {
    const scanBtn = el('button', { className: 'btn btn-secondary btn-row', textContent: '📷 مسح رمز QR' });
    scanBtn.onclick = () => openScanner((code) => { input.value = code; verifyBtn.focus(); });
    card.append(scanBtn);
    card.append(el('div', { className: 'helper' }, 'إذا تعذّر مسح الرمز أو لم يتم العثور عليه، يمكنك إدخاله يدوياً'));
  }

  const verifyRow = el('div', { className: 'btn-row' }, verifyBtn);
  card.append(verifyRow);
  const banner = el('div', { className: 'hidden' });
  card.append(banner);
  panel.append(card);

  function showError(error, used_at) {
    const msg = typeof ERROR_MSG[error] === 'function' ? ERROR_MSG[error](used_at) : (ERROR_MSG[error] || 'خطأ غير معروف.');
    banner.className = 'banner banner-error';
    banner.textContent = msg;
  }
  function clearBanner() { banner.className = 'hidden'; banner.textContent = ''; }

  async function doPreview() {
    const code = input.value.trim();
    if (!code) return;
    clearBanner();
    verifyBtn.disabled = true; verifyBtn.textContent = 'جارِ التحقق...';
    const data = await api('preview', { code });
    verifyBtn.disabled = false; verifyBtn.textContent = 'تحقّق';
    if (!data.valid) { showError(data.error, data.used_at); return; }
    openConfirmModal(data, async () => {
      const res = await api('consume', { code });
      if (res.valid) {
        input.value = ''; clearBanner(); input.focus();
        showToast('✓ تم تسجيل القسيمة كمستخدمة');
      } else {
        showError(res.error, res.used_at);
      }
    });
  }
  verifyBtn.onclick = doPreview;
  input.addEventListener('keypress', (e) => { if (e.key === 'Enter') doPreview(); });
  input.focus();
}

function openConfirmModal(data, onConfirm) {
  const modal = document.getElementById('confirm-modal');
  const body = document.getElementById('confirm-modal-body');
  const discountStr = data.discount_type === 'percentage'
    ? data.discount_value + '٪'
    : data.discount_value + ' ل.س';
  body.innerHTML = '';
  body.append(
    el('h3', {}, '✓ قسيمة صالحة'),
    el('div', { className: 'row' }, el('span', { className: 'k' }, 'الرمز:'), el('span', { className: 'v' }, data.code)),
    el('div', { className: 'row' }, el('span', { className: 'k' }, 'العرض:'), el('span', { className: 'v' }, data.offer_title_ar || data.offer_title)),
    el('div', { className: 'row' }, el('span', { className: 'k' }, 'الخصم:'), el('span', { className: 'v' }, discountStr)),
    el('div', { className: 'row' }, el('span', { className: 'k' }, 'المريض:'), el('span', { className: 'v' }, data.patient_first_name || '—')),
    el('div', { className: 'row' }, el('span', { className: 'k' }, 'تاريخ الاستبدال:'), el('span', { className: 'v' }, fmtDateTime.format(new Date(data.redeemed_at)))),
    el('div', { className: 'row' }, el('span', { className: 'k' }, 'تنتهي في:'), el('span', { className: 'v' }, fmtDateTime.format(new Date(data.expires_at)))),
    el('div', { className: 'warn' }, '⚠ بمجرد التأكيد ستُسجَّل القسيمة كمستخدمة وتظهر للعميل فوراً على أنها مستخدمة.'),
  );
  const cancelBtn = el('button', { className: 'btn btn-cancel', textContent: 'إلغاء' });
  const confirmBtn = el('button', { className: 'btn btn-primary', textContent: 'تأكيد الاستخدام' });
  cancelBtn.onclick = () => modal.classList.remove('open');
  confirmBtn.onclick = async () => {
    confirmBtn.disabled = true; confirmBtn.textContent = 'جارِ التسجيل...';
    await onConfirm();
    modal.classList.remove('open');
  };
  body.append(el('div', { className: 'actions' }, cancelBtn, confirmBtn));
  modal.classList.add('open');
}

// ── Offers tab ────────────────────────────────────────────────────────────
async function renderOffersTab(panel) {
  panel.innerHTML = '';
  const skel = el('div', {}, el('div', { className: 'skeleton' }), el('div', { className: 'skeleton' }));
  panel.append(skel);
  const data = await api('offers');
  panel.innerHTML = '';
  if (data.error || !data.offers || data.offers.length === 0) {
    panel.append(el('div', { className: 'empty' },
      el('div', { className: 'icon' }, '🏷'),
      'لا توجد عروض نشطة حاليًا. تواصل مع DocSera لإضافة عرض جديد.'));
    return;
  }
  data.offers.forEach(o => {
    const discount = o.discount_type === 'percentage' ? o.discount_value + '٪' : o.discount_value + ' ل.س';
    const remaining = o.max_redemptions == null ? 'غير محدود' : (o.max_redemptions - o.current_redemptions);
    const validUntil = o.end_date == null ? 'لا تنتهي' : fmtDateOnly.format(new Date(o.end_date));
    const card = el('div', { className: 'card' },
      el('div', { style: 'font-weight:800;font-size:16px;margin-bottom:10px;' }, (o.is_mega_offer ? '🔥 ' : '') + (o.title_ar || o.title)),
      el('div', { className: 'row' }, el('span', { className: 'k' }, 'الخصم: '), el('span', { className: 'v' }, discount)),
      el('div', { className: 'row' }, el('span', { className: 'k' }, 'السعر بالنقاط: '), el('span', { className: 'v' }, o.points_cost + ' نقطة')),
      el('div', { className: 'row' }, el('span', { className: 'k' }, 'صالحة حتى: '), el('span', { className: 'v' }, validUntil)),
      el('div', { className: 'row' }, el('span', { className: 'k' }, 'متبقّي: '), el('span', { className: 'v' }, remaining)),
      el('div', { className: 'row' }, el('span', { className: 'k' }, 'تم استخدامها: '), el('span', { className: 'v' }, o.current_redemptions + ' مرة')),
    );
    panel.append(card);
  });
}

// ── History tab ───────────────────────────────────────────────────────────
const RANGE_PRESETS = {
  today: () => { const d = new Date(); d.setHours(0,0,0,0); return [d, new Date()]; },
  '7d': () => [new Date(Date.now() - 7*864e5), new Date()],
  '30d': () => [new Date(Date.now() - 30*864e5), new Date()],
  custom: null,
};

async function renderHistoryTab(panel) {
  panel.innerHTML = '';
  const state = { range: 'today', from: null, to: null, search: '', offset: 0, total: 0, rows: [] };

  const filters = el('div', { className: 'filters' });
  const customWrap = el('div', { style: 'display:flex;gap:8px;width:100%;', className: 'hidden' },
    el('input', { type: 'date', className: 'search-input', style: 'flex:1;' }),
    el('input', { type: 'date', className: 'search-input', style: 'flex:1;' })
  );
  ['today','7d','30d','custom'].forEach(k => {
    const labels = { today: 'اليوم', '7d': 'آخر 7 أيام', '30d': 'آخر 30 يوم', custom: 'مخصص' };
    const c = el('button', { className: 'chip' + (k === state.range ? ' active' : ''), textContent: labels[k] });
    c.onclick = () => {
      state.range = k;
      filters.querySelectorAll('.chip').forEach(x => x.classList.remove('active'));
      c.classList.add('active');
      customWrap.classList.toggle('hidden', k !== 'custom');
      reload();
    };
    filters.append(c);
  });

  const search = el('input', { className: 'search-input', placeholder: 'بحث برمز القسيمة', autocomplete: 'off' });
  let debounce;
  search.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => { state.search = search.value.trim().toUpperCase(); reload(); }, 300);
  });
  customWrap.querySelectorAll('input[type=date]').forEach(inp => inp.addEventListener('change', () => {
    if (state.range === 'custom') reload();
  }));

  const countLine = el('div', { className: 'count-line' });
  const list = el('div');
  const loadMoreBtn = el('button', { className: 'btn btn-secondary btn-row', textContent: 'تحميل المزيد', style: 'display:none;' });

  panel.append(filters, customWrap, search, countLine, list, loadMoreBtn);

  function computeRange() {
    if (state.range === 'custom') {
      const [fromInput, toInput] = customWrap.querySelectorAll('input[type=date]');
      const from = fromInput.value ? new Date(fromInput.value + 'T00:00:00') : new Date(0);
      const to = toInput.value ? new Date(toInput.value + 'T23:59:59') : new Date();
      return [from, to];
    }
    return RANGE_PRESETS[state.range]();
  }

  function renderRows() {
    list.innerHTML = '';
    if (state.rows.length === 0) {
      list.append(el('div', { className: 'empty' }, el('div', { className: 'icon' }, '📭'), 'لا توجد عمليات في هذه الفترة'));
      return;
    }
    let lastDay = '';
    state.rows.forEach(r => {
      const day = fmtDateOnly.format(new Date(r.used_at));
      if (day !== lastDay) {
        const isToday = day === todayDateStr();
        list.append(el('div', { className: 'day-header' }, day + (isToday ? ' (اليوم)' : '')));
        lastDay = day;
      }
      const discount = r.discount_type === 'percentage' ? r.discount_value + '٪' : r.discount_value + ' ل.س';
      list.append(el('div', { className: 'entry' },
        el('div', { className: 'top' },
          el('span', { className: 'code' }, r.code),
          el('span', { className: 'time' }, fmtTimeOnly.format(new Date(r.used_at))),
        ),
        el('div', { className: 'title' }, r.offer_title_ar || r.offer_title),
        el('div', { className: 'bottom' },
          el('span', {}, 'المريض: ' + (r.patient_first_name || '—')),
          el('span', {}, 'خصم: ' + discount),
        ),
      ));
    });
  }

  async function fetchPage(append) {
    const [from, to] = computeRange();
    if (!append) { list.innerHTML = ''; [1,2,3].forEach(_ => list.append(el('div', { className: 'skeleton' }))); }
    const data = await api('history', {
      date_from: from.toISOString(),
      date_to: to.toISOString(),
      search: state.search || null,
      limit: 20,
      offset: state.offset,
    });
    if (data.error === 'unauthorized') { state.rows = []; state.total = 0; }
    else { state.total = data.total || 0; state.rows = append ? state.rows.concat(data.rows || []) : (data.rows || []); }
    countLine.textContent = state.total + ' عملية في هذه الفترة';
    renderRows();
    loadMoreBtn.style.display = state.rows.length < state.total ? 'block' : 'none';
    loadMoreBtn.disabled = false; loadMoreBtn.textContent = 'تحميل المزيد';
  }
  function reload() { state.offset = 0; fetchPage(false); }
  loadMoreBtn.onclick = async () => {
    state.offset += 20;
    loadMoreBtn.disabled = true; loadMoreBtn.textContent = 'جارِ التحميل...';
    await fetchPage(true);
  };
  reload();
}

// ── Bootstrap ─────────────────────────────────────────────────────────────
async function bootstrap() {
  const shell = document.getElementById('shell');
  const partner = await api('whoami');
  if (partner.error) {
    shell.innerHTML = '';
    shell.append(el('div', { className: 'card full-error' },
      el('div', { className: 'icon' }, '🔒'),
      el('h2', {}, 'رابط غير صالح'),
      el('p', {}, 'يرجى التواصل مع DocSera للحصول على رابط التحقق المخصص لكم.'),
    ));
    return;
  }
  const hasCamera = await detectCamera();
  shell.innerHTML = '';
  shell.append(renderHeader(partner));
  let currentTab = 'verify';
  const tabsEl = renderTabs(currentTab, switchTab);
  const panel = el('div');
  shell.append(tabsEl, panel);
  const cache = {};
  function switchTab(k) {
    currentTab = k;
    shell.replaceChild(renderTabs(k, switchTab), tabsEl);
    if (k === 'verify') renderVerifyTab(panel, hasCamera);
    else if (k === 'offers') renderOffersTab(panel);
    else if (k === 'history') renderHistoryTab(panel);
  }
  switchTab('verify');
}
bootstrap();
</script>
</body>
</html>`;
```

- [ ] **Step 2: Sanity-check the file size and basic syntax**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
wc -l supabase/functions/verify-partner-voucher/html.ts
```
Expected: ~280–320 lines. The actual TS validation happens at deploy time (Task 9).

- [ ] **Step 3: Commit**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
git add supabase/functions/verify-partner-voucher/html.ts
git commit -m "feat(loyalty): add partner verify HTML page (header, tabs, scanner, modal)"
```

---

## Task 7: Rewrite `index.ts` as a thin router

**Repo:** DocSera-Pro

**Files:**
- Modify: `supabase/functions/verify-partner-voucher/index.ts` (full rewrite)

- [ ] **Step 1: Replace the entire file with the new router**

Replace the entire contents of `/Users/georgezakhour/development/DocSera-Pro/supabase/functions/verify-partner-voucher/index.ts` with EXACTLY:

```typescript
// Edge function entry — routes GET → HTML page, POST → JSON action handlers.
// Auth is by URL query-param secret matching partners.verification_secret;
// no JWT verification (deployed with --no-verify-jwt).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { HTML_PAGE } from "./html.ts";
import {
  handleWhoami,
  handlePreview,
  handleConsume,
  handleOffers,
  handleHistory,
} from "./handlers.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  if (req.method === "GET") {
    return new Response(HTML_PAGE, {
      headers: { ...CORS, "Content-Type": "text/html; charset=utf-8" },
    });
  }

  if (req.method === "POST") {
    let body: any;
    try { body = await req.json(); }
    catch { return new Response(JSON.stringify({ error: "bad_json" }), { headers: { ...CORS, "Content-Type": "application/json" } }); }

    switch (body.action) {
      case "whoami":  return handleWhoami(body);
      case "preview": return handlePreview(body);
      case "consume": return handleConsume(body);
      case "offers":  return handleOffers(body);
      case "history": return handleHistory(body);
      default:
        return new Response(JSON.stringify({ error: "unknown_action" }), {
          status: 400,
          headers: { ...CORS, "Content-Type": "application/json" },
        });
    }
  }

  return new Response("Method not allowed", { status: 405, headers: CORS });
});
```

- [ ] **Step 2: Verify the file is roughly the expected size**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
wc -l supabase/functions/verify-partner-voucher/index.ts
```
Expected: ~50 lines. Down from the current 170-line version. The full type check happens at deploy time.

- [ ] **Step 3: Commit**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
git add supabase/functions/verify-partner-voucher/index.ts
git commit -m "feat(loyalty): split verify-partner-voucher into router/html/handlers"
```

---

## Task 8: Apply the migration to staging

**Repo:** DocSera-Pro

This task is required because Tasks 1–4 only created the migration file locally without applying it (Docker is not running). The function deploy in Task 9 expects the new RPCs to exist.

- [ ] **Step 1: Apply the migration**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
supabase db push
```

If the command requires linking a project first, run `supabase link --project-ref <ref>` and retry. Expected output: confirms `20260425100000_partner_verify_v2.sql` applied.

- [ ] **Step 2: Smoke-test all four new RPCs against staging**

Open the Supabase SQL editor (or psql) and run, replacing `<secret>` with a real partner's `verification_secret`:

```sql
-- 1. preview against an unknown code
SELECT public.preview_voucher('DS-NOPE99', '<secret>');
-- Expected: { "valid": false, "error": "voucher_not_found" }

-- 2. preview with wrong secret
SELECT public.preview_voucher('DS-NOPE99', 'wrong-secret');
-- Expected: { "valid": false, "error": "voucher_not_found" }
-- (returns voucher_not_found because the code itself doesn't exist;
--  if the code exists this would return "unauthorized")

-- 3. partner_info
SELECT public.partner_info('<secret>');
-- Expected: jsonb with name/name_ar/logo_url/brand_color/etc.,
-- and NO verification_secret key.

-- 4. partner_active_offers
SELECT public.partner_active_offers('<secret>');
-- Expected: { "offers": [...] }

-- 5. partner_history (all-time, no filter)
SELECT public.partner_history(
  '<secret>',
  '1970-01-01T00:00:00Z'::timestamptz,
  now() + interval '1 day',
  NULL, 20, 0
);
-- Expected: { "total": <int>, "rows": [...] }
```

If any of these returns an unexpected shape, STOP and report — do not proceed to Task 9.

- [ ] **Step 3: No commit needed**

The migration file is already committed (Tasks 1–4). This task only applies it.

---

## Task 9: Deploy the edge function

**Repo:** DocSera-Pro

- [ ] **Step 1: Deploy to staging**

```bash
cd /Users/georgezakhour/development/DocSera-Pro
supabase functions deploy verify-partner-voucher --no-verify-jwt
```

Expected: Successfully deployed Function `verify-partner-voucher`.

If TypeScript errors surface here (Deno's compile step runs), fix them in `handlers.ts` / `index.ts` / `html.ts` and redeploy.

- [ ] **Step 2: Hit the live URL with curl**

```bash
curl -s "https://api.docsera.app/functions/v1/verify-partner-voucher?s=<secret>" | head -c 200
```
Expected: starts with `<!DOCTYPE html>` and contains `<title>DocSera`. If you see JSON or an HTML 5xx page, the function didn't deploy correctly.

```bash
curl -s -X POST "https://api.docsera.app/functions/v1/verify-partner-voucher?s=<secret>" \
  -H "Content-Type: application/json" \
  -d '{"action":"whoami","partner_secret":"<secret>"}'
```
Expected: jsonb with the partner's name, brand_color, etc.

- [ ] **Step 3: No commit needed (deploy only)**

---

## Task 10: Manual UX walkthrough

This is a verification task — no code changes, runs by a human on a real device. STOP and ask the user to do this; do not skip.

- [ ] **Step 1: Hand the verify URL to the user with this checklist**

Print the URL `https://api.docsera.app/functions/v1/verify-partner-voucher?s=<secret>` and ask the user to open it on:
- A real iPhone Safari
- A desktop Chrome
- (Optional) An Android Chrome

Walk this checklist with the user. Tick each item only after they confirm.

**Header & tabs:**
- [ ] Header shows partner logo (or initial fallback) + Arabic name + "شريك صحي" subtitle + small DocSera mark
- [ ] Three tabs render: تحقق / العروض / النشاط
- [ ] Tab switcher highlights the active tab

**Verify tab:**
- [ ] Code input is centered, LTR, uppercase, autofocused
- [ ] Scan button visible on iPhone, hidden on desktop without webcam
- [ ] Helper text under Scan button is always visible
- [ ] Type a valid code → tap Verify → confirmation modal opens with code + offer + discount + first name + Damascus 12-h timestamps with ص/م
- [ ] Cancel modal → input still has the code
- [ ] Confirm modal → success toast + input clears + voucher status flips to `'used'` in the DB
- [ ] Type an invalid code → red inline banner with the right Arabic message
- [ ] Type an already-used code → banner mentions when it was used
- [ ] Scan a real patient QR → fills input + focuses Verify button

**Offers tab:**
- [ ] Lists active offers; mega ribbon visible on mega offer
- [ ] "متبقّي" / "تم استخدامها" / "صالحة حتى" populate correctly
- [ ] Empty state if no active offers

**Activity tab:**
- [ ] Filter chips render; "اليوم" is selected by default
- [ ] Result count line shows "<N> عملية في هذه الفترة"
- [ ] Cards grouped by Damascus-day with sticky day headers
- [ ] Today's heading appended with "(اليوم)"
- [ ] Tap "آخر 7 أيام" / "آخر 30 يوم" → list refreshes
- [ ] Tap "مخصص" → date pickers appear; pick a range → list refreshes
- [ ] Type in search → debounced filter; matches by partial code
- [ ] "تحميل المزيد" appears when more rows exist; tap it → appends; disappears at the end
- [ ] Empty state for filters with zero matches

**Bad URL:**
- [ ] Open `https://api.docsera.app/functions/v1/verify-partner-voucher?s=garbage` → full-page 🔒 رابط غير صالح state, no tabs, no inputs

- [ ] **Step 2: User signs off**

Once every checkbox is green, the user explicitly confirms before this task is marked done.

---

## Done criteria

- All 10 tasks complete and committed (Tasks 1–7) or executed (Tasks 8–10).
- Migration `20260425100000_partner_verify_v2.sql` applied on staging.
- Edge function deployed to staging and reachable at `https://api.docsera.app/functions/v1/verify-partner-voucher`.
- Manual UX checklist (Task 10) signed off by the user.

## Spec coverage check

| Spec section | Covered by |
|---|---|
| §3.1 `preview_voucher` | Task 1 |
| §3.2 `verify_voucher` (kept as-is) | No task — already exists, untouched |
| §3.3 `partner_info` | Task 2 |
| §3.4 `partner_active_offers` | Task 3 |
| §3.4 `partner_history` | Task 4 |
| §4 File structure (3-file split) | Tasks 5–7 |
| §5.1 Header (partner identity) | Task 6 (`renderHeader` in `html.ts`) + Task 2 RPC |
| §5.2 Tabs | Task 6 (`renderTabs` + `switchTab`) |
| §5.3 Verify tab + 2-step flow | Task 6 (`renderVerifyTab` + `openConfirmModal`) + Tasks 1+5 |
| §5.4 Offers tab | Task 6 (`renderOffersTab`) + Tasks 3+5 |
| §5.5 Activity tab + pagination | Task 6 (`renderHistoryTab`) + Tasks 4+5 |
| §6 QR scanner (conditional + modal) | Task 6 (`detectCamera`, `openScanner`, `closeScanner`) |
| §7 Styling tokens (Cairo + Montserrat + colors) | Task 6 (CSS at top of `HTML_PAGE`) |
| §8 Date formatting (Damascus, 12-h ص/م) | Task 6 (`fmtDateTime` / `fmtDateOnly` / `fmtTimeOnly`) |
| §9 Error handling (Arabic message dispatch) | Task 6 (`ERROR_MSG` table) |
| §10 Security (secret-only auth, no leakage) | Tasks 1–4 (RPC scoping + explicit projection) + Task 9 (`--no-verify-jwt`) |
| §11 Testing (DB smoke + manual checklist) | Tasks 8 + 10 |
| §12 Rollout (apply → deploy → verify) | Tasks 8 + 9 + 10 |
| §13 Out of scope | Honored — no PIN, no rotation, no admin UI |
