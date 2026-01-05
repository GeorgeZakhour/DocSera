-- Migration: Update Banners Table for Localization and Create Storage Bucket

-- 1. Create a storage bucket for banners
INSERT INTO storage.buckets (id, name, public)
VALUES ('banners', 'banners', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Enable public read access to the 'banners' bucket
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'banners' );

-- 3. Update 'banners' table to support localization
-- We will change 'title', 'text', and 'content_sections' to JSONB to hold Key-Value pairs like {"en": "...", "ar": "..."}
-- First, drop the old columns if they exist as text, or convert them.
-- Since the table is fresh/empty (or just seeded with non-localized data), we can alter distinct columns.

-- Rename old columns to serve as temporary holders or delete them if we want to start fresh.
-- Let's ALTER to JSONB using a conversion if possible, or just drop and recreate.
-- Given we are in dev, I'll drop and recreate the columns to be clean.

ALTER TABLE public.banners
    DROP COLUMN title,
    DROP COLUMN text,
    DROP COLUMN content_sections;

ALTER TABLE public.banners
    ADD COLUMN title jsonb,
    ADD COLUMN text jsonb,
    ADD COLUMN content_sections jsonb;

-- 4. Update the schema comment or metadata if needed.
COMMENT ON COLUMN public.banners.title IS 'Localized title: {"en": "Title", "ar": "العنوان"}';
COMMENT ON COLUMN public.banners.text IS 'Localized text: {"en": "Text", "ar": "النصف"}';
COMMENT ON COLUMN public.banners.content_sections IS 'Localized sections: {"en": [...], "ar": [...]}';
