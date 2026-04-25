# Offers Page Redesign + Partner Profiles — Design Spec

**Date:** 2026-04-25
**Scope:** Patient app (DocSera). Doctor-side admin UI for adding partners is explicitly **out of scope** for this round (deferred; partners and offers continue to be added via SQL until the admin panel phase).
**Files affected:**
- New: `lib/screens/home/loyalty/partner_profile_page.dart`
- New: `lib/screens/home/loyalty/widgets/offer_cover_card.dart`
- New: `lib/screens/home/loyalty/widgets/partner_bubble.dart`
- New: `lib/screens/home/loyalty/widgets/category_chip.dart`
- New: `lib/models/partner_model.dart`
- New: `lib/Business_Logic/Loyalty/partner/partner_cubit.dart`
- New: `lib/Business_Logic/Loyalty/partner/partner_state.dart`
- New migration: `supabase/migrations/<ts>_partners_brand_and_about.sql`
- New RPC: `get_partner_profile(p_partner_id uuid)` — returns partner row + its active offers
- Modified: `lib/screens/home/loyalty/offers_page.dart`
- Modified: `lib/screens/home/loyalty/offer_detail_page.dart`
- Modified: `lib/screens/home/loyalty/widgets/offer_card.dart` (replaced by cover card; old kept only if used elsewhere)
- Modified: `lib/models/offer_model.dart` (add brand_color, partner about fields when joined)
- Modified: `lib/services/supabase/loyalty/loyalty_service.dart` (add `getPartnerProfile`)
- Modified: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (new strings)

---

## 1. Goals

- Bring the Offers page up to the visual quality of the Wallet, Vouchers, and Doctor/Center profile pages.
- Make partners first-class entities in the patient experience: each partner has a profile page that lists all their offers.
- Use the unused `offers.image_url` column as the visual hook on every offer card and detail page.
- Improve discovery via category chips, a featured-partners strip, and a richer mega-offers carousel.
- Keep partner onboarding SQL-driven for now; add only the minimal schema fields needed by the new UI.

## 2. Non-goals

- No admin / CMS UI for adding partners or offers in this round (deferred to a later phase).
- No changes to the redeem flow, voucher generation, or the vouchers page.
- No changes to doctor promotions logic.
- No changes to the points-earning system.
- No localization beyond EN + AR (matches existing app).

---

## 3. Schema changes

One small additive migration. All columns are nullable / have defaults — backward compatible.

```sql
-- supabase/migrations/<timestamp>_partners_brand_and_about.sql
ALTER TABLE public.partners
  ADD COLUMN IF NOT EXISTS brand_color text,        -- hex like '#FF8F00'; nullable
  ADD COLUMN IF NOT EXISTS about        text,        -- short bio
  ADD COLUMN IF NOT EXISTS about_ar     text,
  ADD COLUMN IF NOT EXISTS cover_url    text,        -- optional banner image
  ADD COLUMN IF NOT EXISTS partner_type text;        -- 'pharmacy' | 'lab' | 'optical' | 'clinic' | 'other'

CREATE INDEX IF NOT EXISTS idx_partners_partner_type ON public.partners(partner_type);
```

**RPC** (new, `SECURITY DEFINER`, returns `jsonb`):

```sql
CREATE OR REPLACE FUNCTION public.get_partner_profile(p_partner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_partner jsonb;
  v_offers  jsonb;
BEGIN
  -- Explicit projection — never use to_jsonb(partners) here, it leaks verification_secret.
  SELECT jsonb_build_object(
    'id', p.id,
    'name', p.name, 'name_ar', p.name_ar,
    'logo_url', p.logo_url,
    'address', p.address, 'address_ar', p.address_ar,
    'phone', p.phone,
    'is_active', p.is_active,
    'brand_color', p.brand_color,
    'about', p.about, 'about_ar', p.about_ar,
    'cover_url', p.cover_url,
    'partner_type', p.partner_type
  ) INTO v_partner
  FROM public.partners p
  WHERE p.id = p_partner_id AND p.is_active = true;

  IF v_partner IS NULL THEN
    RETURN jsonb_build_object('partner', NULL, 'offers', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(o) ORDER BY o.is_mega_offer DESC, o.created_at DESC), '[]'::jsonb)
    INTO v_offers
  FROM public.offers o
  WHERE o.partner_id = p_partner_id
    AND o.is_active = true
    AND (o.start_date IS NULL OR o.start_date <= now())
    AND (o.end_date   IS NULL OR o.end_date   >  now());

  RETURN jsonb_build_object('partner', v_partner, 'offers', v_offers);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_partner_profile(uuid) TO authenticated;
```

The existing `get_available_offers` RPC must also return the partner's `brand_color`, `partner_type`, and `cover_url` so cards can render correctly without a second round-trip. Update the SELECT inside that function accordingly.

---

## 4. New page architecture — `OffersPage`

Replace the current flat AppBar + list with a `NestedScrollView` that mirrors the Wallet page's visual language.

```
┌─────────────────────────────────────────┐
│  Gradient SliverAppBar (180h)           │
│  teal → cyan with decorative circles    │
│  ┌───────────┐                          │
│  │   ★       │   1,250 points           │
│  │           │   Browse offers          │
│  └───────────┘                          │
├─────────────────────────────────────────┤
│ [All] [Pharmacies] [Labs] [Credit] ...  │ ← horizontal chip row
├─────────────────────────────────────────┤
│ 🔥 Mega Offers                          │
│ ┌──────┐ ┌──────┐ ┌──────┐              │ ← cover-image carousel, 200h
│ │ img  │ │ img  │ │ img  │              │
│ └──────┘ └──────┘ └──────┘              │
├─────────────────────────────────────────┤
│ Featured Partners                       │
│ ⊙ ⊙ ⊙ ⊙ ⊙                              │ ← logo bubbles, ~80h, horizontal
├─────────────────────────────────────────┤
│ All Offers                              │
│ ┌───────────────────────────┐           │
│ │  cover image              │           │
│ │  ─────────                │           │ ← OfferCoverCard, 160h
│ │  Title  · partner · 200★  │           │
│ └───────────────────────────┘           │
│ ...                                      │
└─────────────────────────────────────────┘
```

### Section details

- **Hero AppBar:** `expandedHeight: 180.h`. Gradient `[#007E80, #00B4B6]`. Decorative circles (3, white at 3–6% opacity) reused from Wallet for consistency. Center-bottom: stars icon in a translucent circle, the user's points number (32sp, w800), the word "points" (Text2 white@75%), and a one-line subtitle "Browse offers with your points" (Text3 white@65%).
- **Category chips:** horizontal `ListView` directly under the AppBar via `SliverToBoxAdapter`. Pills: 32h, 14sp, selected = `AppColors.main` filled white text, unselected = white with `main@10%` background and `main@70%` text. Tapping a chip filters the lower sections (Mega and All Offers) but keeps Featured Partners always visible.
  - Chips: `All`, `Pharmacies`, `Labs`, `Optical`, `Clinics`, `Mobile Credit`. Chip set is derived from distinct `partner_type` values present in the loaded offers, plus the fixed `Mobile Credit` chip for `category = 'credit'`. `All` is always first.
  - When zero offers match, show the existing empty state inside the All Offers section only — keep the rest visible.
- **Mega Offers carousel:** only rendered when at least one mega offer matches the active chip. 200h, horizontal `ListView`. Each card: 280×200 with full-bleed `image_url` cover, dark gradient overlay (top-transparent → bottom black@45%), corner ribbon "🔥 MEGA", title (bottom-left, white, w800, max 2 lines), points pill (bottom-right). Falls back to the partner's `brand_color` gradient if `image_url` is null.
- **Featured Partners strip:** horizontal `ListView` of `PartnerBubble` widgets. Bubble = 64×64 circular logo with thin `main` ring + name (Text3, max 1 line, ellipsis) below it. Source: distinct active partners with at least one active offer, ordered by total active offer count desc, capped at 12. Tap → `PartnerProfilePage(partnerId)`. Hidden if fewer than 2 partners exist.
- **All Offers list:** `SliverList` of `OfferCoverCard`. Filtered by the active chip. The mega-offer items are NOT excluded here (the carousel duplicates them by design — the same pattern used on e-commerce home screens) but get a small corner ribbon to mark them. Verified harmless because tap behavior and redeem flow are identical.

### Removed elements

- The current `TabController` (3 tabs) is replaced by chips. The `TabBarView` is removed.
- The current "your points" mini-bar above the list is removed (the hero shows it now).

---

## 5. New widget — `OfferCoverCard`

Replaces `OfferCard` for the offers list and partner profile. Old `OfferCard` is deleted unless found in another route (verified during implementation; if used elsewhere, kept and the new one added separately).

**Anatomy** (160h × full width minus 32 horizontal margin, 18r corner radius):

- **Top 60%:** `Image.network(offer.imageUrl)` with `BoxFit.cover`. If null, render a `LinearGradient` from `partner.brand_color → partner.brand_color@70%` (or `AppColors.main → AppColors.mainDark` if also null), with the partner logo or a category icon centered at 30% opacity.
- **Dark gradient overlay** on the image: top transparent → bottom black at 35% opacity. Ensures legibility if title bleeds into image.
- **Corner ribbon (top-start, only if `is_mega_offer`):** small angled orange ribbon "🔥 MEGA" — replaces the current full-width banner.
- **"X left" badge (top-end, only if `max_redemptions != null && remaining < 20`):** pill with `Color(0xFFE53935)@90%`, white text "5 left".
- **Bottom 40% (white panel):**
  - Row 1: Title (Text2, w700, max 2 lines, ellipsis).
  - Row 2: Tiny partner logo (20×20 circle) + partner name (Text3, grey[600]) on the left; points pill (`12pts ★ 200`, gradient `main@8% → main@4%`, w800 main color) on the right.
- **Tap:** opens `OfferDetailPage`. Long-press is unused.
- **Animation:** keep the existing `TweenAnimationBuilder` slide-up entrance from the old card.

---

## 6. New page — `PartnerProfilePage`

Route: pushed via `fadePageRoute(PartnerProfilePage(partnerId: ...))`. Same visual language as the doctor and center profile pages so it feels native.

```
┌─────────────────────────────────────────┐
│  Cover image (or brand-color gradient)  │
│  Back button (white, top-start)         │
│  ┌────┐                                 │ ← circular logo overlapping
│  │ ⊙  │                                 │   the cover bottom
│  └────┘                                 │
├─────────────────────────────────────────┤
│  Al-Razi Pharmacy        [Partner badge]│
│  📍 Mezzeh Highway, Damascus            │
│  📞 +963 944 123 456                    │
├─────────────────────────────────────────┤
│  About                                  │
│  Lorem ipsum...                         │ ← only if about / about_ar present
├─────────────────────────────────────────┤
│  Offers (3)                             │
│  [OfferCoverCard]                       │
│  [OfferCoverCard]                       │
│  [OfferCoverCard]                       │
└─────────────────────────────────────────┘
```

**Behavior:**

- Loads via `LoyaltyService.getPartnerProfile(partnerId)` → `get_partner_profile` RPC. Returns `{partner, offers}` in one round-trip.
- Loading state: shimmer placeholder for cover + 3 card skeletons.
- Error / partner not found: full-page empty state with "Partner unavailable" message and back button.
- Phone tap → `tel:` URL launcher (use existing `url_launcher`).
- Address tap → opens platform maps (use `url_launcher` with `https://maps.google.com/?q=<urlEncoded address>`).
- Offers section uses `OfferCoverCard`; tapping an offer pushes `OfferDetailPage` as usual.
- Empty offers (after filtering active/in-window) → small inline "No active offers" message under the Offers heading; the rest of the page still renders.

**Cubit:** `PartnerCubit` with states `Initial`, `Loading`, `Loaded(partner, offers)`, `Error(message)`. One-shot load on `initState`; no realtime subscription needed.

---

## 7. `OfferDetailPage` polish

Keep all existing functionality (description card, discount card, redeem section, warning bottom sheet, success dialog). Visual changes only:

- **Hero image (220h)** at the top of the scroll, full-bleed `image_url` with dark gradient overlay (transparent → black@40% bottom). Title overlaid bottom-start (white, Title1, w800, max 2 lines, ellipsis). Mega ribbon, when applicable, sits as a corner ribbon on the hero (replaces the current in-card pill).
- The current header card becomes a **partner mini-card**: tappable row with logo + partner name + "View all offers (N)" chevron → opens `PartnerProfilePage`. N comes from a new field `partner_offer_count int` returned by the updated `get_available_offers` RPC (computed via a `LATERAL` count of active offers per partner). No secondary RPC call from the detail page.
- AppBar becomes transparent over the hero, then solid `#007E80` once scrolled past the hero (use `SliverAppBar` with `flexibleSpace` and `pinned: true`).
- Description card, discount card, redeem section: unchanged styling — only their order shifts to come after the partner mini-card.
- If `image_url` is null: hero falls back to the partner's `brand_color` gradient + a centered category icon, same logic as `OfferCoverCard`.

---

## 8. Localization

Add to `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`:

| Key | EN | AR |
|---|---|---|
| `browseOffersWithPoints` | Browse offers with your points | تصفّح العروض مقابل نقاطك |
| `pharmacies` | Pharmacies | صيدليات |
| `labs` | Labs | مخابر |
| `opticalShops` | Optical | نظارات |
| `clinics` | Clinics | عيادات |
| `featuredPartners` | Featured Partners | شركاؤنا المميزون |
| `allOffersTitle` | All Offers | جميع العروض |
| `viewAllOffersFromPartner` | View all offers ({count}) | عرض جميع العروض ({count}) |
| `aboutPartner` | About | عن الشريك |
| `partnerBadge` | Health Partner | شريك صحي |
| `noActiveOffersFromPartner` | This partner has no active offers right now. | لا توجد عروض نشطة حاليًا. |
| `partnerUnavailable` | Partner unavailable | الشريك غير متاح |
| `xLeft` | {count} left | متبقّي {count} |

All keys must also be added to `lib/l10n/untranslated_ar.txt` if any AR string is left blank during initial implementation, per the existing convention.

---

## 9. Data flow

```
OffersPage
  └── OffersCubit.loadOffers()
        └── LoyaltyService.getAvailableOffers()
              └── RPC: get_available_offers   (now includes brand_color, partner_type, cover_url, partner_offer_count)
        ↓
    OffersLoaded(allOffers, partnerOffers, creditOffers)
        ↓ derive
    distinct partners → Featured strip
    distinct partner_type → chip row
    is_mega_offer subset → carousel
    filtered subset → All Offers list

PartnerProfilePage
  └── PartnerCubit.load(partnerId)
        └── LoyaltyService.getPartnerProfile(partnerId)
              └── RPC: get_partner_profile
        ↓
    PartnerLoaded(partner, offers)

OfferDetailPage
  (unchanged data flow; uses the OfferModel passed in)
```

No realtime subscriptions are introduced. Pull-to-refresh is added on `OffersPage` (it does not currently have one) re-running `loadOffers()`.

---

## 10. Error handling & edge cases

- **No offers at all:** show the existing centered empty state inside the "All Offers" section. Hero, chips, and Featured Partners still render (Featured will be empty too, hidden by its < 2 partners rule).
- **Image load failure:** every `Image.network` uses `errorBuilder` to fall back to the brand-color gradient + icon. Same pattern already used on the current offer card — just extended.
- **Partner has 0 active offers but is featured:** filter out at query time (Featured Partners only includes partners with >= 1 active offer in the loaded set).
- **Mega offer with null `image_url`:** carousel card uses the partner brand-color gradient + corner ribbon. No "broken image" state ever shown.
- **`brand_color` invalid hex:** parse defensively in a small `colorFromHex` util; on failure, default to `AppColors.main`.
- **RPC returns null partner:** `PartnerProfilePage` shows "Partner unavailable" state and a Back button.
- **Network error on `getPartnerProfile`:** standard error state with retry button.

---

## 11. Testing

Unit + widget tests, following the existing `bloc_test` + `mocktail` conventions in `test/`.

- `test/loyalty/partner_cubit_test.dart`
  - emits `Loading → Loaded` on success
  - emits `Loading → Error` on RPC failure
  - emits `Loaded` with empty offers list when partner has none
- `test/loyalty/offers_cubit_test.dart`
  - existing tests stay green; add a test that the loaded data exposes `brand_color` / `partner_type` when present
- `test/loyalty/widgets/offer_cover_card_test.dart`
  - renders cover image when `image_url` provided
  - renders gradient fallback when `image_url` is null
  - renders mega ribbon iff `is_mega_offer`
  - renders "X left" badge iff remaining < 20
- `test/loyalty/widgets/partner_bubble_test.dart`
  - renders logo + name; falls back to initials when logo URL fails
- `test/loyalty/partner_profile_page_test.dart`
  - shows shimmer in Loading
  - shows partner header + offers list in Loaded
  - shows error state on failure
  - tapping an offer pushes `OfferDetailPage`

Manual UI verification checklist (run in browser/iOS sim, both EN and AR):

- Hero AppBar collapses correctly on scroll.
- Chips filter as expected and "All" returns to full set.
- Mega carousel scrolls; cards tappable.
- Featured Partners bubbles tappable → partner profile opens.
- Partner profile renders with logo overlapping cover; phone and address are tappable.
- AR layout: chips and carousels respect RTL; partner mini-card chevron flips direction.
- Redeem flow on detail page is unchanged.
- Pull-to-refresh on Offers page reloads.

---

## 12. Migration & rollout

1. Apply the schema migration on staging Supabase first; verify existing offers/partners are untouched.
2. Backfill optional fields manually for any seeded partners using `UPDATE` statements (e.g. set `partner_type` for existing rows).
3. Update the `get_available_offers` RPC to return the new fields.
4. Ship the Flutter changes behind no flag (the schema is additive and the UI degrades gracefully when new fields are null).
5. After deploy, seed at least 3 partners with `brand_color`, `cover_url`, and `image_url` on their offers so the new design has visual content to render.

No backwards-compat shim needed: the new model fields are nullable, the old fields are unchanged, and offers without images render the gradient fallback.

---

## 13. Out-of-scope (deferred)

- Admin UI for partner / offer creation (next phase).
- Partner-side dashboard or self-service portal.
- Geocoding partner addresses for the map preview on partner profile (deferred — show address as text only for now).
- Partner reviews or ratings.
- Search bar on the Offers page (chips are enough for v1; revisit if partner count > 30).
