-- Seed Banners Table with Localized Static Data

-- 1. Banner: Recurring abdominal pain (Sponsored)
INSERT INTO public.banners (
    title,
    text,
    image_path,
    logo_path,
    is_active,
    is_sponsored,
    logo_container_color,
    order_index,
    content_sections
) VALUES (
    '{"en": "Important Health Alert", "ar": "تنبيه صحي هام"}'::jsonb,
    '{"en": "Recurring, cramp-like abdominal pain? Here''s what could be behind it.", "ar": "ألم بطني متكرر يشبه التقلصات؟ إليك ما قد يكون السبب وراءه."}'::jsonb,
    'assets/images/worker.webp', -- NOTE: User should upload this to 'banners' bucket and update this path later, e.g., 'https://[project].supabase.co/storage/v1/object/public/banners/worker.webp'
    'assets/images/docsera_white.svg',
    true,
    true,
    '#80009688', 
    1,
    '{"en": [
        {
            "type": "text",
            "title": "Understanding Abdominal Pain",
            "body": "Abdominal pain can be caused by many factors, from indigestion to more serious conditions."
        },
        {
            "type": "list",
            "title": "Common Causes",
            "items": ["Gastritis", "IBS", "Food Intolerance", "Muscle Strain"]
        },
        {
            "type": "button",
            "title": "Learn More",
            "url": "https://www.google.com/search?q=abdominal+pain"
        }
    ],
    "ar": [
        {
            "type": "text",
            "title": "فهم ألم البطن",
            "body": "يمكن أن يكون لألم البطن أسباب عديدة، من عسر الهضم إلى حالات أكثر خطورة."
        },
        {
            "type": "list",
            "title": "الأسباب الشائعة",
            "items": ["التهاب المعدة", "القولون العصبي", "عدم تحمل الطعام", "شد عضلي"]
        },
        {
            "type": "button",
            "title": "اعرف المزيد",
            "url": "https://www.google.com/search?q=abdominal+pain"
        }
    ]}'::jsonb
);

-- 2. Banner: Preventive healthcare
INSERT INTO public.banners (
    title,
    text,
    image_path,
    is_active,
    is_sponsored,
    order_index,
    content_sections
) VALUES (
    '{"en": "Important Health Alert", "ar": "تنبيه صحي هام"}'::jsonb,
    '{"en": "Discover the benefits of preventive healthcare.", "ar": "اكتشف فوائد الرعاية الصحية الوقائية."}'::jsonb,
    'assets/images/professional.jpg',
    true,
    false,
    2,
    '{"en": [
        {
            "type": "text",
            "title": "Why Prevention Matters",
            "body": "Preventive healthcare helps you stay healthy and catch problems early when they are easier to treat."
        },
        {
            "type": "image",
            "url": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=800&q=80"
        }
    ],
    "ar": [
         {
            "type": "text",
            "title": "لماذا الوقاية مهمة؟",
            "body": "الرعاية الصحية الوقائية تساعدك على البقاء بصحة جيدة واكتشاف المشاكل مبكراً عندما يكون علاجها أسهل."
        },
        {
            "type": "image",
            "url": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=800&q=80"
        }
    ]}'::jsonb
);

-- 3. Banner: Doctor consultation (Sponsored)
INSERT INTO public.banners (
    title,
    text,
    image_path,
    is_active,
    is_sponsored,
    order_index,
    content_sections
) VALUES (
    '{"en": "Important Health Alert", "ar": "تنبيه صحي هام"}'::jsonb,
    '{"en": "Get a doctor’s consultation from your home!", "ar": "احصل على استشارة طبية من منزلك!"}'::jsonb,
    'assets/images/worker.webp',
    true,
    true,
    3,
    '{"en": [
        {
            "type": "text",
            "title": "Telemedicine is Here",
            "body": "Consult with top doctors via video call. Easy, secure, and convenient."
        },
        {
            "type": "button",
            "title": "Book Now",
            "url": "https://docsera.com/book"
        }
    ],
    "ar": [
        {
            "type": "text",
            "title": "الطب الاتصالي هنا",
            "body": "استشر أفضل الأطباء عبر مكالمة فيديو. سهل، آمن، ومريح."
        },
        {
            "type": "button",
            "title": "احجز الآن",
            "url": "https://docsera.com/book"
        }
    ]}'::jsonb
);
