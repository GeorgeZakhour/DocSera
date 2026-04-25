-- =====================================================================
-- Offers Redesign — Seed examples for manual UI verification (Task 17)
-- =====================================================================
-- Two partners, six offers (mix of mega + normal + credit).
-- Run against staging or local Supabase before exercising the new UI.
-- Image URLs use picsum.photos so they always resolve in dev.

-- ── Partner 1: Al-Razi Pharmacy ──────────────────────────────────────
INSERT INTO public.partners (id, name, name_ar, logo_url, address, address_ar, phone,
                             brand_color, partner_type, about, about_ar, cover_url)
VALUES (
  'b1111111-aaaa-4bbb-8ccc-111111111111',
  'Al-Razi Pharmacy', 'صيدلية الرازي',
  'https://picsum.photos/seed/razi-logo/256',
  'Mezzeh, Damascus', 'المزة، دمشق', '+963944111222',
  '#0E8F8F', 'pharmacy',
  'A trusted neighborhood pharmacy serving Damascus since 1998.',
  'صيدلية الحي الموثوقة في دمشق منذ 1998.',
  'https://picsum.photos/seed/razi-cover/1200/600'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.offers (category, title, title_ar, points_cost, partner_id,
                           discount_type, discount_value, voucher_validity_days,
                           image_url, is_mega_offer, max_redemptions, current_redemptions)
VALUES
('partner', '10% off vitamins', 'حسم 10٪ على الفيتامينات', 200,
 'b1111111-aaaa-4bbb-8ccc-111111111111', 'percentage', 10, 14,
 'https://picsum.photos/seed/vitamins/800/400', false, 500, 0),
('partner', '5,000 SYP off skincare', 'حسم 5,000 ل.س على العناية بالبشرة', 450,
 'b1111111-aaaa-4bbb-8ccc-111111111111', 'fixed_amount', 5000, 21,
 'https://picsum.photos/seed/skincare/800/400', true, NULL, 0),
('partner', 'Free blood-pressure check', 'فحص ضغط الدم مجاني', 80,
 'b1111111-aaaa-4bbb-8ccc-111111111111', 'free_service', NULL, 7,
 NULL, false, 100, 90);  -- 10 left → triggers "X left" badge

-- ── Partner 2: Damascus Optics ───────────────────────────────────────
INSERT INTO public.partners (id, name, name_ar, logo_url, address, address_ar, phone,
                             brand_color, partner_type, about, about_ar, cover_url)
VALUES (
  'b2222222-aaaa-4bbb-8ccc-222222222222',
  'Damascus Optics', 'بصريات دمشق',
  'https://picsum.photos/seed/optic-logo/256',
  'Bab Touma, Damascus', 'باب توما، دمشق', '+963944333444',
  '#7E57C2', 'optical',
  'Premium eyewear for the whole family.',
  'نظارات راقية لكل العائلة.',
  'https://picsum.photos/seed/optic-cover/1200/600'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.offers (category, title, title_ar, points_cost, partner_id,
                           discount_type, discount_value, voucher_validity_days,
                           image_url, is_mega_offer)
VALUES
('partner', '15% off prescription glasses', 'حسم 15٪ على النظارات الطبية', 300,
 'b2222222-aaaa-4bbb-8ccc-222222222222', 'percentage', 15, 30,
 'https://picsum.photos/seed/glasses/800/400', false),
('partner', 'Free eye exam', 'فحص نظر مجاني', 150,
 'b2222222-aaaa-4bbb-8ccc-222222222222', 'free_service', NULL, 14,
 'https://picsum.photos/seed/eye-exam/800/400', false);

-- ── Mobile credit (no partner) ───────────────────────────────────────
INSERT INTO public.offers (category, title, title_ar, points_cost,
                           discount_type, discount_value, voucher_validity_days)
VALUES
('credit', '5,000 SYP MTN credit', 'رصيد MTN بقيمة 5,000 ل.س', 300,
 'fixed_amount', 5000, 3);

-- ── Smoke test ───────────────────────────────────────────────────────
SELECT public.get_available_offers(NULL) LIMIT 1;
SELECT public.get_partner_profile('b1111111-aaaa-4bbb-8ccc-111111111111');
