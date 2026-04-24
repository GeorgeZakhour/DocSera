-- ===============================================================
-- MIGRATION: Add manual entry support to medical_master table
-- 
-- This migration adds columns to support the hybrid approach
-- where users can create custom master items when they can't
-- find what they need in the predefined list.
-- ===============================================================

-- 1. Add verification status column
-- Existing system-created items stay verified (true by default)
-- User-created items will be inserted with is_verified = false
ALTER TABLE medical_master
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;

-- 2. Add source tracking
-- 'system' = predefined by DocSera team
-- 'patient' = created by patient via manual entry
-- 'doctor' = created by doctor via manual entry (future)
ALTER TABLE medical_master
  ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'system';

-- 3. Add creator tracking (nullable — null for system entries)
ALTER TABLE medical_master
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- ===============================================================
-- RLS POLICY: Allow authenticated users to insert custom items
-- They can only insert with is_verified = false
-- ===============================================================

-- Drop existing policy if any
DROP POLICY IF EXISTS "Users can insert custom master items" ON medical_master;

-- Allow authenticated users to insert into medical_master
-- BUT only with is_verified = false (they can't create verified items)
CREATE POLICY "Users can insert custom master items"
  ON medical_master
  FOR INSERT
  TO authenticated
  WITH CHECK (is_verified = false);

-- ===============================================================
-- RLS POLICY: SELECT — Verified items visible to all,
-- Unverified items visible ONLY to their creator.
-- This prevents random user entries from polluting other
-- users' search results.
-- ===============================================================
DROP POLICY IF EXISTS "Anyone can read medical master items" ON medical_master;

CREATE POLICY "Anyone can read medical master items"
  ON medical_master
  FOR SELECT
  TO authenticated
  USING (
    is_verified = true
    OR created_by = auth.uid()
  );

-- ===============================================================
-- COMMENT: Update existing items to be marked as system entries
-- ===============================================================
UPDATE medical_master
  SET source = 'system', is_verified = true
  WHERE source IS NULL;
