-- =====================================================================
-- Offers Redesign — Seed examples for manual UI verification
-- =====================================================================
-- Two partners, six offers (mix of mega + normal + low-stock + credit).
-- Image URLs are direct Unsplash photo references — content-relevant,
-- stable, free to use commercially under the Unsplash license.
-- Add `?w=W&h=H&fit=crop&q=80&auto=format` to control crop + size.

-- ── Partner 1: Al-Razi Pharmacy ──────────────────────────────────────
INSERT INTO public.partners (id, name, name_ar, logo_url, address, address_ar, phone,
                             brand_color, partner_type, about, about_ar, cover_url)
VALUES (
  'b1111111-aaaa-4bbb-8ccc-111111111111',
  'Al-Razi Pharmacy', 'صيدلية الرازي',
  'https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=256&h=256&fit=crop&q=80&auto=format',
  'Mezzeh, Damascus', 'المزة، دمشق', '+963944111222',
  '#0E8F8F', 'pharmacy',
  'A trusted neighborhood pharmacy serving Damascus since 1998.',
  'صيدلية الحي الموثوقة في دمشق منذ 1998.',
  'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=1200&h=600&fit=crop&q=80&auto=format'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.offers (category, title, title_ar, points_cost, partner_id,
                           discount_type, discount_value, voucher_validity_days,
                           image_url, is_mega_offer, max_redemptions, current_redemptions)
VALUES
('partner', '10% off vitamins', 'حسم 10٪ على الفيتامينات', 200,
 'b1111111-aaaa-4bbb-8ccc-111111111111', 'percentage', 10, 14,
 'https://images.unsplash.com/photo-1550572017-edd951b55104?w=800&h=400&fit=crop&q=80&auto=format',
 false, 500, 0),
('partner', '5,000 SYP off skincare', 'حسم 5,000 ل.س على العناية بالبشرة', 450,
 'b1111111-aaaa-4bbb-8ccc-111111111111', 'fixed_amount', 5000, 21,
 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=800&h=400&fit=crop&q=80&auto=format',
 true, NULL, 0),
('partner', 'Free blood-pressure check', 'فحص ضغط الدم مجاني', 80,
 'b1111111-aaaa-4bbb-8ccc-111111111111', 'free_service', NULL, 7,
 'https://images.unsplash.com/photo-1666214280557-f1b5022eb634?w=800&h=400&fit=crop&q=80&auto=format',
 false, 100, 90);  -- 10 left → triggers "X left" badge

-- ── Partner 2: Damascus Optics ───────────────────────────────────────
INSERT INTO public.partners (id, name, name_ar, logo_url, address, address_ar, phone,
                             brand_color, partner_type, about, about_ar, cover_url)
VALUES (
  'b2222222-aaaa-4bbb-8ccc-222222222222',
  'Damascus Optics', 'بصريات دمشق',
  'https://images.unsplash.com/photo-1577803645773-f96470509666?w=256&h=256&fit=crop&q=80&auto=format',
  'Bab Touma, Damascus', 'باب توما، دمشق', '+963944333444',
  '#7E57C2', 'optical',
  'Premium eyewear for the whole family.',
  'نظارات راقية لكل العائلة.',
  'https://images.unsplash.com/photo-1574258495973-f010dfbb5371?w=1200&h=600&fit=crop&q=80&auto=format'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.offers (category, title, title_ar, points_cost, partner_id,
                           discount_type, discount_value, voucher_validity_days,
                           image_url, is_mega_offer)
VALUES
('partner', '15% off prescription glasses', 'حسم 15٪ على النظارات الطبية', 300,
 'b2222222-aaaa-4bbb-8ccc-222222222222', 'percentage', 15, 30,
 'https://images.unsplash.com/photo-1577803645773-f96470509666?w=800&h=400&fit=crop&q=80&auto=format',
 false),
('partner', 'Free eye exam', 'فحص نظر مجاني', 150,
 'b2222222-aaaa-4bbb-8ccc-222222222222', 'free_service', NULL, 14,
 'https://images.unsplash.com/photo-1497019545435-e23eb3a9626a?w=800&h=400&fit=crop&q=80&auto=format',
 false);

-- ── Mobile credit (no partner, no image — gradient fallback) ─────────
INSERT INTO public.offers (category, title, title_ar, points_cost,
                           discount_type, discount_value, voucher_validity_days)
VALUES
('credit', '5,000 SYP MTN credit', 'رصيد MTN بقيمة 5,000 ل.س', 300,
 'fixed_amount', 5000, 3);

-- ── Smoke test ───────────────────────────────────────────────────────
SELECT public.get_available_offers(NULL) LIMIT 1;
SELECT public.get_partner_profile('b1111111-aaaa-4bbb-8ccc-111111111111');
