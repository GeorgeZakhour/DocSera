-- Seed template for pro.message.received — the doctor-side version
-- of the patient app's message.new event. Body is the literal message
-- text (filled at handle time) so this template is mostly for the
-- title and admin-panel discoverability.

INSERT INTO public.notification_templates
  (event_code, locale, title_template, body_template,
   default_importance, default_category, default_deep_link, active, version)
VALUES
  ('pro.message.received', 'ar',
   '‎💬 {{sender_name}}',
   '‎{{message_preview}}',
   'high', 'messages', 'conversation:{{conversation_id}}', true, 1),
  ('pro.message.received', 'en',
   '‎💬 {{sender_name}}',
   '‎{{message_preview}}',
   'high', 'messages', 'conversation:{{conversation_id}}', true, 1)
ON CONFLICT (event_code, locale) WHERE active DO NOTHING;
