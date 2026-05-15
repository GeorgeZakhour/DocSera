-- =============================================================================
-- Backfill notifications.data->>'doctor_id' for existing Pro rows.
-- =============================================================================
-- The Pro inbox uses notifications.data->>'doctor_id' to render the
-- per-doctor pill and the doctor-scope filter chip for secretaries
-- serving 2+ doctors. Handlers were not putting it in `data` until
-- now, so historical rows have no doctor_id even though the source
-- table (conversations / todo_tasks / appointments) does.
--
-- This backfill walks each event family and merges the doctor_id from
-- the source row into `data`. Rows that already have a doctor_id are
-- skipped (jsonb_set semantics).

BEGIN;

-- Messages — pro.message.received uses data.conversation_id.
UPDATE public.notifications n
   SET data = data || jsonb_build_object('doctor_id', c.doctor_id::text)
  FROM public.conversations c
 WHERE n.recipient_app = 'docsera_pro'
   AND n.event_code = 'pro.message.received'
   AND n.data ? 'conversation_id'
   AND (n.data->>'conversation_id')::uuid = c.id
   AND c.doctor_id IS NOT NULL
   AND NOT (n.data ? 'doctor_id');

-- Todo tasks — every todo_task.* event references data.todo_task_id.
UPDATE public.notifications n
   SET data = data || jsonb_build_object('doctor_id', t.doctor_id::text)
  FROM public.todo_tasks t
 WHERE n.recipient_app = 'docsera_pro'
   AND n.event_code LIKE 'todo_task.%'
   AND n.data ? 'todo_task_id'
   AND (n.data->>'todo_task_id')::uuid = t.id
   AND t.doctor_id IS NOT NULL
   AND NOT (n.data ? 'doctor_id');

-- pro.task.* (the cron-driven family) — same source.
UPDATE public.notifications n
   SET data = data || jsonb_build_object('doctor_id', t.doctor_id::text)
  FROM public.todo_tasks t
 WHERE n.recipient_app = 'docsera_pro'
   AND n.event_code LIKE 'pro.task.%'
   AND n.data ? 'todo_task_id'
   AND (n.data->>'todo_task_id')::uuid = t.id
   AND t.doctor_id IS NOT NULL
   AND NOT (n.data ? 'doctor_id');

-- pro.appointment.* — already populated by the handler; this catches
-- any stragglers (e.g. legacy rows from before the handler fix).
UPDATE public.notifications n
   SET data = data || jsonb_build_object('doctor_id', a.doctor_id::text)
  FROM public.appointments a
 WHERE n.recipient_app = 'docsera_pro'
   AND n.event_code LIKE 'pro.appointment.%'
   AND n.data ? 'appointment_id'
   AND (n.data->>'appointment_id')::uuid = a.id
   AND a.doctor_id IS NOT NULL
   AND NOT (n.data ? 'doctor_id');

COMMIT;
