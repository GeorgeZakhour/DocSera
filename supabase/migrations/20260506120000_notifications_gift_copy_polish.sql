-- Tighten the gift.received template copy to read more like a transactional
-- notification ("voucher added to your wallet") and less like a casual
-- announcement ("a personal gift is waiting for you"). The runtime path
-- through handlers/gifts.ts has been updated in lockstep — the templates
-- table is the source of truth for the future template-rendering path.

BEGIN;

UPDATE public.notification_templates
   SET body_template = 'أُضيفت قسيمة جديدة إلى محفظتك. اضغط لعرض التفاصيل.'
 WHERE event_code = 'gift.received'
   AND locale = 'ar';

UPDATE public.notification_templates
   SET body_template = 'A new voucher has been added to your wallet. Tap to view details.'
 WHERE event_code = 'gift.received'
   AND locale = 'en';

COMMIT;
