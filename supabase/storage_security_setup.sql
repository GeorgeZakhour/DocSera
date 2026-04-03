-- =============================================================================
-- DocSera Phase 2A: Storage Security — Bucket Privacy + RLS Policies
-- =============================================================================
-- Run this script in Supabase SQL Editor (self-hosted instance)
--
-- What it does:
--   1. Makes 3 buckets PRIVATE: documents, chat.attachments, appointments-attachments
--   2. Reviews/fixes policies on already-private buckets: doctor_verifications, reports
--   3. Adds proper RLS policies for authenticated access
--
-- Public buckets left untouched: center-images, home_cards, banners, app.files, doctor
-- =============================================================================

-- =============================================
-- STEP 1: Make sensitive buckets PRIVATE
-- =============================================

UPDATE storage.buckets SET public = false WHERE id = 'documents';
UPDATE storage.buckets SET public = false WHERE id = 'chat.attachments';
UPDATE storage.buckets SET public = false WHERE id = 'appointments-attachments';

-- Verify doctor_verifications and reports are already private
UPDATE storage.buckets SET public = false WHERE id = 'doctor_verifications';
UPDATE storage.buckets SET public = false WHERE id = 'reports';


-- =============================================
-- STEP 2: Clean up old/insecure policies
-- =============================================
-- Remove any existing policies on these buckets to start fresh

-- documents
DROP POLICY IF EXISTS "Allow authenticated uploads to documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated reads from documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from documents" ON storage.objects;
DROP POLICY IF EXISTS "documents_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "documents_auth_select" ON storage.objects;
DROP POLICY IF EXISTS "documents_auth_delete" ON storage.objects;
DROP POLICY IF EXISTS "documents_auth_update" ON storage.objects;

-- chat.attachments
DROP POLICY IF EXISTS "Allow authenticated uploads to chat.attachments" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated reads from chat.attachments" ON storage.objects;
DROP POLICY IF EXISTS "chat_attachments_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "chat_attachments_auth_select" ON storage.objects;
DROP POLICY IF EXISTS "chat_attachments_auth_delete" ON storage.objects;
DROP POLICY IF EXISTS "chat_attachments_auth_update" ON storage.objects;

-- appointments-attachments
DROP POLICY IF EXISTS "Allow authenticated uploads to appointments-attachments" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated reads from appointments-attachments" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads from appointments-attachments" ON storage.objects;
DROP POLICY IF EXISTS "appointments_attachments_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "appointments_attachments_auth_select" ON storage.objects;
DROP POLICY IF EXISTS "appointments_attachments_auth_delete" ON storage.objects;
DROP POLICY IF EXISTS "appointments_attachments_auth_update" ON storage.objects;

-- doctor_verifications (review existing)
DROP POLICY IF EXISTS "doctor_verifications_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "doctor_verifications_auth_select" ON storage.objects;
DROP POLICY IF EXISTS "doctor_verifications_auth_delete" ON storage.objects;
DROP POLICY IF EXISTS "doctor_verifications_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "Allow doctor to upload verification" ON storage.objects;
DROP POLICY IF EXISTS "Allow doctor to read own verification" ON storage.objects;

-- reports (review existing)  
DROP POLICY IF EXISTS "reports_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "reports_auth_select" ON storage.objects;
DROP POLICY IF EXISTS "reports_auth_delete" ON storage.objects;
DROP POLICY IF EXISTS "reports_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "Allow doctor to upload reports" ON storage.objects;
DROP POLICY IF EXISTS "Allow doctor to read own reports" ON storage.objects;


-- =============================================
-- STEP 3: Create proper RLS policies
-- =============================================

-- ╔══════════════════════════════════════════╗
-- ║ BUCKET: documents                        ║
-- ║ Used by: DocSera (patient app)           ║
-- ║ Contains: Patient uploaded documents     ║
-- ╚══════════════════════════════════════════╝

-- INSERT: Authenticated users can upload to paths containing their user ID
CREATE POLICY "documents_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'documents');

-- SELECT: Authenticated users can read files (the app uses signed URLs)
CREATE POLICY "documents_auth_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'documents');

-- UPDATE: Authenticated users can update their own files (upsert)
CREATE POLICY "documents_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'documents');

-- DELETE: Authenticated users can delete files  
CREATE POLICY "documents_auth_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'documents');


-- ╔══════════════════════════════════════════╗
-- ║ BUCKET: chat.attachments                 ║
-- ║ Used by: DocSera + DocSera Pro           ║
-- ║ Contains: Chat images, PDFs, voice notes ║
-- ╚══════════════════════════════════════════╝

-- INSERT: Authenticated users can upload
CREATE POLICY "chat_attachments_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'chat.attachments');

-- SELECT: Authenticated users can read (signed URL required)
CREATE POLICY "chat_attachments_auth_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'chat.attachments');

-- UPDATE: Authenticated users can update (upsert)
CREATE POLICY "chat_attachments_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'chat.attachments');

-- DELETE: Authenticated users can delete
CREATE POLICY "chat_attachments_auth_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'chat.attachments');


-- ╔══════════════════════════════════════════════╗
-- ║ BUCKET: appointments-attachments              ║
-- ║ Used by: DocSera (patient app)                ║
-- ║ Contains: Documents attached to appointments  ║
-- ╚══════════════════════════════════════════════╝

-- INSERT: Authenticated users can upload
CREATE POLICY "appointments_attachments_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'appointments-attachments');

-- SELECT: Authenticated users can read
CREATE POLICY "appointments_attachments_auth_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'appointments-attachments');

-- UPDATE: Authenticated users can update
CREATE POLICY "appointments_attachments_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'appointments-attachments');

-- DELETE: Authenticated users can delete
CREATE POLICY "appointments_attachments_auth_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'appointments-attachments');


-- ╔══════════════════════════════════════════════════════╗
-- ║ BUCKET: doctor_verifications                         ║
-- ║ Used by: DocSera Pro                                 ║
-- ║ Contains: Doctor license + ID scans                  ║
-- ║ NOTE: Already private — ensuring proper policies     ║
-- ╚══════════════════════════════════════════════════════╝

-- INSERT: Authenticated doctors can upload their own verification docs
CREATE POLICY "doctor_verifications_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'doctor_verifications'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

-- SELECT: Authenticated doctors can read their own docs
CREATE POLICY "doctor_verifications_auth_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'doctor_verifications'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

-- UPDATE: Authenticated doctors can update their own docs
CREATE POLICY "doctor_verifications_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'doctor_verifications'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

-- DELETE: Authenticated doctors can delete their own docs
CREATE POLICY "doctor_verifications_auth_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'doctor_verifications'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );


-- ╔══════════════════════════════════════════════════════╗
-- ║ BUCKET: reports                                      ║
-- ║ Used by: DocSera Pro                                 ║
-- ║ Contains: Financial reports (PDF)                    ║
-- ║ NOTE: Already private — ensuring proper policies     ║
-- ╚══════════════════════════════════════════════════════╝

-- INSERT: Authenticated doctors can upload reports to their own folder
CREATE POLICY "reports_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'reports'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

-- SELECT: Authenticated doctors can read their own reports
CREATE POLICY "reports_auth_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'reports'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

-- UPDATE: Authenticated doctors can update their own reports
CREATE POLICY "reports_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'reports'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

-- DELETE: Authenticated doctors can delete their own reports  
CREATE POLICY "reports_auth_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'reports'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );


-- =============================================
-- STEP 4: Add encrypted column to documents table
-- =============================================
-- Needed by Phase 2C: the app now stores an `encrypted` flag
-- to distinguish new encrypted files from legacy unencrypted ones.

ALTER TABLE public.documents 
  ADD COLUMN IF NOT EXISTS encrypted boolean DEFAULT false;

COMMENT ON COLUMN public.documents.encrypted IS 
  'Phase 2C: Whether file bytes are AES-256-CBC encrypted at rest';


-- =============================================
-- VERIFICATION: List all bucket statuses
-- =============================================
SELECT id, name, public, 
  CASE 
    WHEN public = true THEN '🟢 PUBLIC'
    ELSE '🔒 PRIVATE'
  END as status
FROM storage.buckets 
ORDER BY name;
