# Admin Panel — Feature Requirements
# ==================================
# This document tracks features that need to be built into the
# DocSera Admin Panel when it is created in the future.
#
# Last updated: 2026-04-23


## 1. Medical Master Item Review Panel
### Priority: HIGH
### Context
The health records system uses a `medical_master` table with predefined items
(allergies, chronic diseases, medications, surgeries, vaccines, family conditions).

A "manual entry" feature was added (2026-04-23) that allows both patients and
doctors to create custom master items when they can't find what they need in the
predefined list. These custom entries are stored with:
- `is_verified = false`
- `source = 'patient'` or `source = 'doctor'`
- `created_by = <user_uuid>`

### Required Admin Features
1. **View all unverified items**
   - Table: `medical_master` WHERE `is_verified = false`
   - Show: name_en, name_ar, category, source, created_by, created_at
   - Sort by: most recent first

2. **Review & Verify**
   - Admin can edit name_en / name_ar / description_en / description_ar
   - Admin can set `is_verified = true` to promote to official list
   - Admin can reject (delete) invalid entries

3. **Merge Duplicates**
   - Detect potential duplicates (fuzzy matching on name_en/name_ar)
   - Allow merging: reassign all `patient_medical_records` pointing to the
     duplicate master_id → to the canonical master_id, then delete the duplicate

4. **Add Missing Translation**
   - Many custom entries will only have one language filled in
   - Admin can add the missing Arabic or English translation

5. **Analytics Dashboard**
   - Show count of unverified items per category
   - Show trending custom entries (most frequently added by users)
   - These trending items should be prioritized for verification

### Database Columns (already added)
```sql
medical_master.is_verified  BOOLEAN DEFAULT true
medical_master.source       TEXT DEFAULT 'system'   -- 'system', 'patient', 'doctor'
medical_master.created_by   UUID REFERENCES auth.users(id)
```

### Notes on Patient vs Doctor Entries
- **Patient entries** (`source = 'patient'`): Lower reliability, may contain
  typos or non-standard terminology. Should be reviewed more carefully.
- **Doctor entries** (`source = 'doctor'`): Higher reliability, likely to use
  correct medical terminology. Can potentially be auto-verified or fast-tracked.
- Future enhancement: Consider a separate reliability score or confidence level.
