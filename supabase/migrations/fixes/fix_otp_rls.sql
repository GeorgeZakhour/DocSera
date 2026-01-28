-- Enable RLS on the otp table (already enabled, but good practice to include)
ALTER TABLE public.otp ENABLE ROW LEVEL SECURITY;

-- Allow anonymous users to insert new OTPs (for sign up / login)
CREATE POLICY "Allow anonymous insert otp"
ON public.otp
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Allow anonymous users to update OTPs (needed for upsert if phone exists)
CREATE POLICY "Allow anonymous update otp"
ON public.otp
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- Allow anonymous users to select (read) their OTP (optional, strictly speaking not needed for just sending, but might be needed if the client reads back)
-- For security, it's better NOT to allow listing all OTPs.
-- But if the client does an upsert and expects a response, it might need this. 
-- However, standard upsert in Supabase Dart SDK usually just requires write permissions unless .select() is used.
-- We will stick to write/update for now.
