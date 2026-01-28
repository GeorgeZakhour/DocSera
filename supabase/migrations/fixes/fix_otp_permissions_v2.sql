-- Ensure the table has RLS enabled
ALTER TABLE public.otp ENABLE ROW LEVEL SECURITY;

-- 1. Grant explicit permissions to the table for anon and authenticated roles
-- RLS policies need these underlying permissions to work.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.otp TO anon, authenticated;

-- 2. Allow anonymous users to SELECT (Read) OTPs
-- Detailed reasoning: 'upsert' operations may effectively perform a read to check for conflicts
-- or return the inserted row. It's safer to allow SELECT for the flow to complete smoothly.
CREATE POLICY "Allow anonymous select otp"
ON public.otp
FOR SELECT
TO anon, authenticated
USING (true);

-- (The previous INSERT and UPDATE policies from fix_otp_rls.sql should still be there. 
-- If not, or if you want to be sure, we can re-declare them safely using IF NOT EXISTS logic 
-- or just drop and recreate to be clean).

-- Drop existing policies to avoid conflicts if re-running
DROP POLICY IF EXISTS "Allow anonymous insert otp" ON public.otp;
DROP POLICY IF EXISTS "Allow anonymous update otp" ON public.otp;

-- Re-create INSERT policy
CREATE POLICY "Allow anonymous insert otp"
ON public.otp
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Re-create UPDATE policy
CREATE POLICY "Allow anonymous update otp"
ON public.otp
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);
