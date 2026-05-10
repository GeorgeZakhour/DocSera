-- Pro appointment-event templates. Seed for Phase 2.1.
--
-- The dispatcher does not require templates — handlers produce
-- `title`/`body` in the intent directly — but seeding templates here
-- means a future admin panel can edit copy without code deploys, and
-- the `notification_templates` row anchors the (event_code, locale)
-- pair for cross-app discoverability.
--
-- Variable placeholders use {{var}} syntax; the engine's render
-- helper substitutes from intent.data. For Phase 2.1 the handler
-- still writes the rendered string into the intent directly; the
-- templates are admin-facing source of truth, not the runtime
-- code path.

INSERT INTO public.notification_templates
  (event_code, locale, title_template, body_template,
   default_importance, default_category, default_deep_link, active, version)
VALUES
  -- booked_pending
  ('pro.appointment.booked_pending', 'ar',
   '‎📨 طلب حجز جديد',
   '‎{{patient_name}} طلب موعداً بتاريخ {{appointment_date}} الساعة {{appointment_time}} — بانتظار تأكيدك.',
   'high', 'appointments', 'appointment:{{appointment_id}}', true, 1),
  ('pro.appointment.booked_pending', 'en',
   '‎📨 New booking request',
   '‎{{patient_name}} requested an appointment on {{appointment_date}} at {{appointment_time}} — awaiting your confirmation.',
   'high', 'appointments', 'appointment:{{appointment_id}}', true, 1),

  -- booked_confirmed
  ('pro.appointment.booked_confirmed', 'ar',
   '‎✅ موعد جديد',
   '‎موعد مؤكد مع {{patient_name}} بتاريخ {{appointment_date}} الساعة {{appointment_time}}.',
   'default', 'appointments', 'appointment:{{appointment_id}}', true, 1),
  ('pro.appointment.booked_confirmed', 'en',
   '‎✅ New appointment',
   '‎Confirmed appointment with {{patient_name}} on {{appointment_date}} at {{appointment_time}}.',
   'default', 'appointments', 'appointment:{{appointment_id}}', true, 1),

  -- cancelled_by_patient
  ('pro.appointment.cancelled_by_patient', 'ar',
   '‎❌ تم إلغاء الموعد',
   '‎{{patient_name}} ألغى موعده بتاريخ {{appointment_date}} الساعة {{appointment_time}}.',
   'high', 'appointments', 'appointment:{{appointment_id}}', true, 1),
  ('pro.appointment.cancelled_by_patient', 'en',
   '‎❌ Appointment cancelled',
   '‎{{patient_name}} cancelled their appointment on {{appointment_date}} at {{appointment_time}}.',
   'high', 'appointments', 'appointment:{{appointment_id}}', true, 1),

  -- rescheduled_by_patient
  ('pro.appointment.rescheduled_by_patient', 'ar',
   '‎🕒 تم تغيير الموعد',
   '‎{{patient_name}} غيّر موعده إلى {{appointment_date}} الساعة {{appointment_time}}.',
   'default', 'appointments', 'appointment:{{appointment_id}}', true, 1),
  ('pro.appointment.rescheduled_by_patient', 'en',
   '‎🕒 Appointment rescheduled',
   '‎{{patient_name}} rescheduled to {{appointment_date}} at {{appointment_time}}.',
   'default', 'appointments', 'appointment:{{appointment_id}}', true, 1),

  -- patient_arrived
  ('pro.appointment.patient_arrived', 'ar',
   '‎🚪 وصل المريض',
   '‎{{patient_name}} في غرفة الانتظار.',
   'time_sensitive', 'appointments', 'appointment:{{appointment_id}}', true, 1),
  ('pro.appointment.patient_arrived', 'en',
   '‎🚪 Patient arrived',
   '‎{{patient_name}} is in the waiting room.',
   'time_sensitive', 'appointments', 'appointment:{{appointment_id}}', true, 1),

  -- no_show_auto
  ('pro.appointment.no_show_auto', 'ar',
   '‎⏰ لم يحضر المريض',
   '‎{{patient_name}} لم يحضر لموعده.',
   'default', 'appointments', 'appointment:{{appointment_id}}', true, 1),
  ('pro.appointment.no_show_auto', 'en',
   '‎⏰ Patient did not arrive',
   '‎{{patient_name}} did not attend their appointment.',
   'default', 'appointments', 'appointment:{{appointment_id}}', true, 1)
ON CONFLICT (event_code, locale) WHERE active DO NOTHING;
