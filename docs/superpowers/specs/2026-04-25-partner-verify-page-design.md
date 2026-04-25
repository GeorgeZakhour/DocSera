# Partner Verify Page Enhancements (Sub-project A) — Design Spec

**Date:** 2026-04-25
**Scope:** Enhancements to the existing partner voucher verification edge function (`verify-partner-voucher`). The function currently provides a single-step "enter code → consume" flow. This round adds: two-step preview-then-confirm UX, optional QR scanner, paginated activity log, partner identity in the header, and a third tab listing the partner's active offers.

**Sub-projects B (PIN + secret rotation) and C (admin lookup of partner URLs) are explicitly NOT in this spec.**

**Existing assets (already on `main`):**
- Edge function: `supabase/functions/verify-partner-voucher/index.ts` (170 lines, returns HTML page + JSON POST handler)
- RPC: `verify_voucher(p_code text, p_partner_secret text) -> jsonb` in `supabase/migrations/20260421_loyalty_rpcs.sql`
- Schema: `partners.verification_secret` already populated for every partner (random 16-byte hex)
- Live URL pattern: `https://api.docsera.app/functions/v1/verify-partner-voucher?s=<secret>`

**Files affected:**
- Modify: `supabase/functions/verify-partner-voucher/index.ts` (rewrite — drops to ~80 lines, routing only)
- Create: `supabase/functions/verify-partner-voucher/html.ts` (~250 lines — HTML template + CSS + client JS)
- Create: `supabase/functions/verify-partner-voucher/handlers.ts` (~120 lines — JSON action handlers)
- Create: `supabase/migrations/<ts>_partner_verify_v2.sql` (4 new RPCs; existing `verify_voucher` untouched)

---

## 1. Goals

- Two-step confirmation before a voucher is consumed, with full voucher details surfaced before the partner commits.
- Optional QR scanner on devices with a camera (feature-detected); manual entry still always works.
- Paginated activity log scoped to this partner only, filterable by date range and code search.
- Partner identity (logo + name) visible at the top of the page so partner staff trust what they're looking at.
- Third tab listing the partner's currently-active offers, read-only — useful for staff to know what discounts customers might bring.
- DocSera font (Cairo + Montserrat) and color tokens consistent with the patient/doctor apps.

## 2. Non-goals

- No per-session PIN (Sub-project B).
- No partner-side secret rotation (Sub-project B).
- No admin tool to look up partner URLs (Sub-project C / waits for admin panel).
- No partner self-service for editing offers (admin panel scope).
- No offline mode.
- No refund / "undo consume" flow.
- No push notifications to partners.
- No patient-side QR scanner (separate Flutter feature).

---

## 3. Data layer — new RPCs

All `SECURITY DEFINER` with `SET search_path = public, pg_temp`. All authorize only by matching the secret against `partners.verification_secret`. Existing `verify_voucher` RPC stays exactly as-is (kept as the consume step; no signature change).

### 3.1 `preview_voucher(p_code text, p_partner_secret text) -> jsonb`

Read-only. Same logic as `verify_voucher` *except* it does not write. Returns:

```jsonc
// success
{
  "valid": true,
  "code": "DS-A29E1B",
  "offer_title": "10% off vitamins",
  "offer_title_ar": "حسم 10٪ على الفيتامينات",
  "discount_type": "percentage",
  "discount_value": 10,
  "patient_first_name": "Ahmad",
  "redeemed_at": "2026-04-25T18:11:00Z",
  "expires_at":  "2026-05-09T18:11:00Z"
}

// errors (same enum as verify_voucher)
{ "valid": false, "error": "voucher_not_found" }
{ "valid": false, "error": "unauthorized" }
{ "valid": false, "error": "already_used", "used_at": "..." }
{ "valid": false, "error": "expired" }
{ "valid": false, "error": "cancelled" }
```

### 3.2 `partner_info(p_partner_secret text) -> jsonb`

Returns the partner row identified by the secret (without `verification_secret` itself). One round-trip on page load:

```jsonc
// success
{
  "name": "Al-Razi Pharmacy",
  "name_ar": "صيدلية الرازي",
  "logo_url": "https://...",
  "address_ar": "المزة، دمشق",
  "phone": "+963944111222",
  "brand_color": "#0E8F8F",
  "partner_type": "pharmacy"
}

// failure
{ "error": "unauthorized" }
```

### 3.3 `partner_active_offers(p_partner_secret text) -> jsonb`

Returns the partner's currently-active offers (same `is_active + in window + not sold out` filter as `get_available_offers`):

```jsonc
{
  "offers": [
    {
      "id": "uuid",
      "title": "10% off vitamins",
      "title_ar": "حسم 10٪ على الفيتامينات",
      "description_ar": "...",
      "discount_type": "percentage",
      "discount_value": 10,
      "points_cost": 200,
      "voucher_validity_days": 14,
      "current_redemptions": 12,
      "max_redemptions": 500,
      "end_date": null,
      "is_mega_offer": false
    }
  ]
}
// or { "error": "unauthorized" }
```

### 3.4 `partner_history(p_partner_secret text, p_date_from timestamptz, p_date_to timestamptz, p_search text, p_limit int, p_offset int) -> jsonb`

Paginated activity log. Server-side filtering. Filters: date window on `vouchers.used_at`, optional code substring search (`upper(code) LIKE '%' || upper(p_search) || '%'`).

```jsonc
{
  "total": 137,           // total matching rows for the active filter set
  "rows": [
    {
      "code": "DS-A29E1B",
      "offer_title": "10% off vitamins",
      "offer_title_ar": "حسم 10٪ على الفيتامينات",
      "discount_type": "percentage",
      "discount_value": 10,
      "patient_first_name": "Ahmad",
      "used_at": "2026-04-22T02:54:41Z",
      "redeemed_at": "2026-04-21T01:49:59Z"
    }
  ]
}
// or { "total": 0, "rows": [], "error": "unauthorized" }
```

Filter logic:
```sql
WHERE o.partner_id = (SELECT id FROM partners WHERE verification_secret = p_partner_secret)
  AND v.status   = 'used'
  AND v.used_at >= p_date_from
  AND v.used_at <= p_date_to
  AND (p_search IS NULL OR upper(v.code) LIKE '%' || upper(p_search) || '%')
ORDER BY v.used_at DESC
LIMIT p_limit OFFSET p_offset
```

`p_limit` clamped to `[1, 100]` server-side. `p_offset` clamped to `>= 0`.

---

## 4. Edge function file structure

```
supabase/functions/verify-partner-voucher/
├── index.ts        # ~80 lines — Deno serve(), CORS, route GET → html, route POST → handlers
├── html.ts         # ~250 lines — exports HTML_PAGE constant
└── handlers.ts     # ~120 lines — handlePreview, handleConsume, handleHistory, handleWhoami, handleOffers
```

**Routing in `index.ts`:**

| Method | Body                                           | Handler                | Target RPC                |
|--------|-----------------------------------------------|------------------------|---------------------------|
| GET    | —                                              | return `HTML_PAGE`     | —                         |
| POST   | `{ action: "whoami", partner_secret }`         | `handleWhoami`         | `partner_info`            |
| POST   | `{ action: "preview", code, partner_secret }`  | `handlePreview`        | `preview_voucher`         |
| POST   | `{ action: "consume", code, partner_secret }`  | `handleConsume`        | `verify_voucher`          |
| POST   | `{ action: "offers", partner_secret }`         | `handleOffers`         | `partner_active_offers`   |
| POST   | `{ action: "history", partner_secret, date_from, date_to, search, limit, offset }` | `handleHistory` | `partner_history` |
| OPTIONS| —                                              | CORS preflight (204)   | —                         |
| *      | —                                              | 405 Method Not Allowed | —                         |

CORS headers `Access-Control-Allow-Origin: *` (the page is the only consumer; OK to be permissive).

---

## 5. Page architecture (HTML)

### 5.1 Top header

Replaces the current logo-only header. Visible on every tab:

```
┌──────────────────────────────────────────────┐
│   ⊙   صيدلية الرازي                  DocSera │
│       شريك صحي                                │
└──────────────────────────────────────────────┘
```

- Partner logo: 48×48 circle. If `logo_url` null → first character of `name_ar` over a brand-color circle (or `--c-main` if `brand_color` null).
- Partner name in Arabic (16px, font-weight 800).
- Subtitle "شريك صحي" (12px, font-weight 600, brand color).
- DocSera wordmark image at top-end (small, ~20px tall).
- Below the header: tab switcher.

### 5.2 Tabs

Pill-style segmented control:

```
[ تحقق ]  [ العروض ]  [ النشاط ]
```

Selected tab = filled `--c-main` with white text. Switching tabs is purely client-side; data for each tab is fetched on first activation and cached for the session (manual refresh only by re-loading the page).

### 5.3 Verify tab

```
[ Code input — DS-XXXXXX ]
[ 📷 مسح رمز QR ]                  ← only if camera detected
   إذا تعذّر مسح الرمز أو لم يتم العثور عليه، يمكنك إدخاله يدوياً
[ تحقّق ] (primary)

(inline red banner here on preview error)
```

Two-step success flow:

```
Tap "تحقّق"
    ↓
POST { action: "preview", code, partner_secret }
    ↓
┌── error  → red inline banner with localized message
│
└── success → open Confirmation Modal
              ┌──────────────────────────────────────┐
              │   ✓ قسيمة صالحة                       │
              │ ──────────────────────────────────── │
              │ الرمز:           DS-A29E1B            │
              │ العرض:           حسم 10٪ على ...      │
              │ الخصم:           10٪                  │
              │ المريض:          أحمد                 │
              │ تاريخ الاستبدال: 21 نيسان 2026، 4:49 ص│
              │ تنتهي في:        9 أيار 2026، 4:49 ص │
              │ ──────────────────────────────────── │
              │ ⚠ بمجرد التأكيد ستُسجَّل القسيمة     │
              │   كمستخدمة وتظهر للعميل فوراً        │
              │   على أنها مستخدمة.                   │
              │                                      │
              │ [ إلغاء ]   [ تأكيد الاستخدام ]      │
              └──────────────────────────────────────┘
                          ↓ (Confirm)
              POST { action: "consume", code, partner_secret }
                          ↓
                 Success toast: "✓ تم تسجيل القسيمة كمستخدمة"
                 Code input cleared, focus back to input
```

- Verify button shows spinner + disabled during preview.
- Confirm button shows spinner + disabled during consume.
- If consume fails (race: someone else burned the same code in the gap), modal closes and error banner shown.
- Cancel: modal closes, code stays in input.
- Error variants render localized Arabic messages from a fixed dispatch table (existing function already has this).

### 5.4 Offers tab

Read-only list; one card per active offer.

```
┌──────────────────────────────────────────────┐
│ 🔥 حسم 5,000 ل.س على العناية بالبشرة           │  ← 🔥 only if is_mega_offer
│                                              │
│ الخصم:           5,000 ل.س                    │
│ السعر بالنقاط:   450 نقطة                     │
│ صالحة حتى:       لا تنتهي                     │
│ متبقّي:           غير محدود                   │
│ تم استخدامها:    12 مرة                       │
└──────────────────────────────────────────────┘
```

- Loaded via `partner_active_offers` on first activation.
- "صالحة حتى": if `end_date` null → "لا تنتهي"; else format in Damascus locale (date only).
- "متبقّي": if `max_redemptions` null → "غير محدود"; else `max_redemptions - current_redemptions`.
- "تم استخدامها": `current_redemptions` followed by "مرة".
- Empty state: `لا توجد عروض نشطة حاليًا. تواصل مع DocSera لإضافة عرض جديد.` centered with a soft icon.

### 5.5 Activity tab

```
┌─ Filter row (sticky) ───────────────────────┐
│ [ اليوم ] [ آخر 7 أيام ] [ آخر 30 يوم ] [ مخصص ]│
│ 🔍 بحث برمز القسيمة                          │
│ 145 عملية في هذه الفترة                      │
├─────────────────────────────────────────────┤
│  25 نيسان 2026 (اليوم)                       │
│  ┌───────────────────────────────────┐       │
│  │ DS-A29E1B           4:49 ص        │       │
│  │ حسم 10٪ على الفيتامينات             │       │
│  │ المريض: أحمد        خصم: 10٪       │       │
│  └───────────────────────────────────┘       │
│  ...                                         │
│  24 نيسان 2026                               │
│  ┌───────────────────────────────────┐       │
│  │ ...                               │       │
│  └───────────────────────────────────┘       │
│                                              │
│  [ تحميل المزيد ]                            │
└──────────────────────────────────────────────┘
```

- Filter chips single-select. Default: "اليوم". "مخصص" reveals a `<input type="date">` pair (from + to) using the browser's native picker.
- Search input: live with 300ms debounce; uppercase normalisation client-side; server-side substring match.
- Result count line updates with every fetch.
- Cards grouped by Damascus-day (sticky day headings). Today's heading appended with "(اليوم)".
- Pagination: server-side, page size 20. "تحميل المزيد" button at bottom is visible while `loaded.length < total`. Click → fetch next page (offset += 20), append to list. Disabled with spinner during fetch.
- Filter change (date or search) → reset offset to 0, clear list, fetch fresh.
- Initial open + filter changes show skeleton (3 grey card placeholders) until the first response.
- Empty state: `لا توجد عمليات في هذه الفترة` (centered, muted).

---

## 6. QR scanner

**Library:** [`qr-scanner`](https://github.com/nimiq/qr-scanner) v1.4.2 (~16KB gzipped, MIT). Loaded from CDN inside the HTML, only when the Scan button is rendered:

```html
<script type="module">
  import QrScanner from "https://cdn.jsdelivr.net/npm/qr-scanner@1.4.2/qr-scanner.min.js";
  window.QrScanner = QrScanner;
</script>
```

**Conditional mount:** on page load, run `navigator.mediaDevices?.enumerateDevices()`. If at least one `videoinput` device exists, render the Scan button. Otherwise leave the button out of the DOM entirely. No fallback message, no "your device doesn't support this" — silent absence.

**Scan modal:** fullscreen overlay (z-index 9999) with:
- Close (✕) button top-end
- Live camera feed via `QrScanner.attach(videoEl)`
- Square scan-target overlay (semi-transparent corners)
- Helper text below: `وجّه الكاميرا نحو رمز QR`

**Detection logic:**
- Pattern check: detected text must match `^DS-[A-Z0-9]{6}$`. If not, ignore and keep scanning (no error toast).
- On valid match: vibrate(50ms) on supported devices, stop scanner, close modal, fill code input, focus moves to Verify button.

**Camera lifecycle:**
- Started on modal open (after permission grant).
- Stopped on: close button, ESC key, successful detect.
- Permission denied: modal closes, small toast `الرجاء السماح بالوصول للكاميرا من إعدادات المتصفح`.

**Helper text** (always visible, even when scanner unavailable, but specifically right under the Scan button when it exists): `إذا تعذّر مسح الرمز أو لم يتم العثور عليه، يمكنك إدخاله يدوياً`.

---

## 7. Styling tokens

Loaded once at the top of the HTML stylesheet:

```css
@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800&family=Montserrat:wght@400;500;600;700;800&display=swap');

:root {
  --c-main:        #009092;   /* AppColors.main */
  --c-main-dark:   #007E80;
  --c-bg:          #F7F8FA;
  --c-card:        #FFFFFF;
  --c-text:        #2C3E50;
  --c-text-soft:   #6B7280;
  --c-success:     #009092;
  --c-error:       #E53935;
  --c-warning:     #FF9800;
  --c-mega:        #FF8F00;
}

html, body, button, input, textarea {
  font-family: 'Cairo', 'Montserrat', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
```

**Component conventions:**
- Cards: 18px radius, shadow `0 4px 12px rgba(0,0,0,0.05)`, white background.
- Primary button: filled `--c-main`, white text, 14px radius, 14px vertical padding, 16px font-weight 600.
- Secondary button (Scan): outlined `--c-main`, transparent fill, same dimensions.
- Inputs: 10px radius, 2px border `--c-text-soft`, focus border `--c-main`, 16px font-size.
- Tab switcher: pill segmented control. Selected = filled `--c-main` + white text. Unselected = transparent + `--c-text-soft`.
- Modal: 24px radius, semi-opaque backdrop (black @ 40%).

---

## 8. Date & time formatting

All timestamps stored UTC. All displayed in **Asia/Damascus** with **12-hour Arabic** format (ص / م):

```js
const fmtDateTime = new Intl.DateTimeFormat('ar-SY', {
  timeZone: 'Asia/Damascus',
  year: 'numeric', month: 'long', day: 'numeric',
  hour: 'numeric', minute: '2-digit', hour12: true,
});
// "21 نيسان 2026 في 4:49 ص"

const fmtDateOnly = new Intl.DateTimeFormat('ar-SY', {
  timeZone: 'Asia/Damascus',
  year: 'numeric', month: 'long', day: 'numeric',
});
// "25 نيسان 2026"

const fmtTimeOnly = new Intl.DateTimeFormat('ar-SY', {
  timeZone: 'Asia/Damascus',
  hour: 'numeric', minute: '2-digit', hour12: true,
});
// "4:49 ص"
```

- Confirmation modal: `redeemed_at` and `expires_at` use `fmtDateTime`.
- Activity day groupings: `fmtDateOnly` (today's heading appended with "(اليوم)").
- Activity card timestamps: `fmtTimeOnly`.
- Offers tab `end_date`: `fmtDateOnly`.

This matches `DocSeraTime.tryParseToSyria()` semantics in the Flutter apps.

---

## 9. Error handling

**Inline banner errors (Verify tab, after preview):**

| Error key            | Arabic message                                                  |
|----------------------|-----------------------------------------------------------------|
| `voucher_not_found`  | رمز القسيمة غير موجود.                                          |
| `unauthorized`       | غير مصرّح. يرجى استخدام رابط التحقق المخصص لكم.                  |
| `already_used`       | تم استخدام هذه القسيمة مسبقاً (بتاريخ <fmtDateTime(used_at)>).  |
| `expired`            | انتهت صلاحية هذه القسيمة.                                       |
| `cancelled`          | تم إلغاء هذه القسيمة.                                           |
| `network_error`      | خطأ في الاتصال. يرجى التحقق من الشبكة.                          |
| `server_error`       | خطأ في الخادم. حاول مرة أخرى.                                   |

**Bad URL (`?s=garbage` or missing):** `whoami` returns `unauthorized` → page renders a single full-page state instead of the verifier:

```
🔒 رابط غير صالح
يرجى التواصل مع DocSera للحصول على رابط التحقق المخصص لكم.
```

No tabs, no inputs.

**Network failure on consume:** modal closes with error banner. Voucher status unchanged (preview was read-only; consume call failed before mutating).

**Network failure on history fetch:** retry button replaces "تحميل المزيد"; cards loaded so far stay visible.

**Image load failure (partner logo):** initial-letter placeholder kicks in (same as patient app's `PartnerBubble`).

---

## 10. Security

- `partner.verification_secret` in the URL is the entire authentication. Bounded capability: anyone with the secret can preview/consume vouchers for that partner only, list that partner's offers, and view that partner's history. They cannot read other partners, modify schema, or affect points balances directly.
- All four new RPCs are `SECURITY DEFINER` with `SET search_path = public, pg_temp`.
- All four new RPCs scope every read/write by `(SELECT id FROM partners WHERE verification_secret = p_partner_secret)`. If no row matches → return `unauthorized` (or empty payload).
- No JWT verification on the edge function (deployed with `--no-verify-jwt`, matching the existing version).
- `verification_secret` continues to be excluded from any patient-facing RPC (the recent fix on `get_partner_profile` stays in place; the new RPCs follow the same projection rule).
- Worst-case abuse: someone with leaked URL burns vouchers belonging to one partner. Mitigation: rotate that partner's `verification_secret` (Sub-project B).

---

## 11. Testing

No unit tests for edge functions (no existing pattern in the repo across 13 functions; not introducing one for this round).

**DB-level checks** (psql, after migration applied):

```sql
-- preview returns details, does not consume
SELECT public.preview_voucher('DS-XXXXXX', '<secret>');
SELECT status FROM public.vouchers WHERE code = 'DS-XXXXXX';  -- expected: 'active'

-- consume marks used
SELECT public.verify_voucher('DS-XXXXXX', '<secret>');
SELECT status FROM public.vouchers WHERE code = 'DS-XXXXXX';  -- expected: 'used'

-- second preview on used voucher: 'already_used' with no side effect
SELECT public.preview_voucher('DS-XXXXXX', '<secret>');

-- wrong secret: 'unauthorized'
SELECT public.preview_voucher('DS-XXXXXX', 'wrong-secret');
SELECT public.partner_info('wrong-secret');

-- partner_info shape
SELECT public.partner_info('<secret>');

-- partner_active_offers excludes inactive / past-window / sold-out
SELECT public.partner_active_offers('<secret>');

-- partner_history pagination + search
SELECT public.partner_history('<secret>', now() - interval '30 days', now(), NULL,  20, 0);
SELECT public.partner_history('<secret>', now() - interval '30 days', now(), NULL,  20, 20);
SELECT public.partner_history('<secret>', now() - interval '30 days', now(), 'A29', 20, 0);
```

**Manual UX checklist** (run on a real iPhone Safari and a desktop Chrome):

- Open the verify URL → header shows partner logo + name + DocSera mark.
- Three tabs render: تحقق / العروض / النشاط.
- **Verify tab** — enter valid code → preview modal shows code + offer + discount + first name + Damascus 12-h timestamps with ص/م.
- Cancel modal → input retains code.
- Confirm modal → success toast + input clears + voucher status `'used'` in DB.
- Each error variant renders the right Arabic banner.
- Scan button: visible on iPhone, hidden on desktop without webcam, visible on laptop with webcam.
- Scan a real patient QR → fills input + focuses Verify button.
- Helper text always under Scan button.
- **Offers tab** — lists active offers, mega ribbon visible on mega offer, "متبقّي" / "تم استخدامها" populated.
- **Activity tab** — filters reset to "اليوم"; result count visible; cards grouped by day with sticky headers; "تحميل المزيد" appends; search by partial code works; date-range "مخصص" opens native pickers; empty state renders for filters with zero matches.
- Bad URL (`?s=garbage`) → full-page "🔒 رابط غير صالح".

---

## 12. Rollout

1. Apply migration on staging Supabase: `supabase db push`.
2. Deploy function: `supabase functions deploy verify-partner-voucher --no-verify-jwt` (matches existing).
3. Hit URL on a real phone, walk the manual checklist on staging.
4. Once green, repeat for prod.

No flag needed: URL shape is unchanged, old bookmarks keep working, existing `verify_voucher` RPC unchanged.

---

## 13. Out of scope (carried as TODOs)

- **Sub-project B**: per-session PIN (auth gate before the verifier loads), partner secret rotation (admin-driven), audit log of secret rotations.
- **Sub-project C**: admin tool to look up / copy / regenerate partner verify URLs (will likely fold into the future admin panel).
- Patient-side QR scanner (Flutter `mobile_scanner` package, separate brainstorm).
- Partner refund / "undo consume" flow (would need a `refunded` status + history of state changes).
- Push notifications to partners on patient redemption.
- Multi-language toggle (page is Arabic-only; matches what we send customers).
- Mark all read-only RPCs `STABLE` (bundle into the offers-redesign DB hygiene follow-up).
- Share lookup helper between `preview_voucher` and `verify_voucher` to deduplicate the lookup logic.
