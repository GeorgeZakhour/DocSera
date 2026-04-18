-- Trigger: When a doctor updates their profile image,
-- propagate the change to all their conversations.
CREATE OR REPLACE FUNCTION public.sync_doctor_image_to_conversations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.doctor_image IS DISTINCT FROM OLD.doctor_image THEN
    UPDATE public.conversations
    SET doctor_image = NEW.doctor_image
    WHERE doctor_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_doctor_image_to_conversations
  AFTER UPDATE OF doctor_image ON public.doctors
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_doctor_image_to_conversations();

-- Backfill: Fix all existing conversations that have stale doctor images.
UPDATE public.conversations c
SET doctor_image = d.doctor_image
FROM public.doctors d
WHERE c.doctor_id = d.id
  AND c.doctor_image IS DISTINCT FROM d.doctor_image;
