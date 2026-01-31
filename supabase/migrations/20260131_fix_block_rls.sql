-- Enable RLS on the table (ensure it is on)
ALTER TABLE "public"."doctor_patient_blocks" ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users (patients) to select/read rows where they are the patient_id
-- This allows them to see if they or their relatives (linked by patient_id) are blocked.
CREATE POLICY "patient_view_own_blocks"
ON "public"."doctor_patient_blocks"
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
  (select auth.uid()) = patient_id
);
