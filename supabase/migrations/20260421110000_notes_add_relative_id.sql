-- ============================================================
-- Add relative_id to notes so notes can be scoped per-patient
-- (main user or relative), matching the documents pattern.
-- ============================================================

ALTER TABLE public.notes
ADD COLUMN relative_id uuid REFERENCES public.relatives(id) ON DELETE CASCADE;

-- Index for efficient filtering by relative
CREATE INDEX idx_notes_relative_id ON public.notes (relative_id)
WHERE relative_id IS NOT NULL;
