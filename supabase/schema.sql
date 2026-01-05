-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.accounting (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL,
  appointment_id uuid,
  type text NOT NULL CHECK (type = ANY (ARRAY['income'::text, 'expense'::text])),
  label text,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'SYP'::text,
  payment_method text CHECK (payment_method = ANY (ARRAY['cash'::text, 'card'::text, 'other'::text])),
  note text,
  is_billed boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  paid_amount numeric,
  paid_currency text,
  paid_at timestamp with time zone,
  invoice_number bigint,
  doctor_account_id uuid,
  CONSTRAINT accounting_pkey PRIMARY KEY (id),
  CONSTRAINT accounting_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT accounting_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointments(id)
);
CREATE TABLE public.accounting_labels (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL,
  label text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['income'::text, 'expense'::text])),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT accounting_labels_pkey PRIMARY KEY (id),
  CONSTRAINT accounting_labels_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.appointment_reasons (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid,
  label text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT appointment_reasons_pkey PRIMARY KEY (id),
  CONSTRAINT appointment_reasons_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.appointments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  doctor_id uuid,
  appointment_date date,
  appointment_time time without time zone,
  timestamp timestamp with time zone,
  reason text,
  booked boolean DEFAULT false,
  new_patient boolean,
  patient_name text,
  user_gender text,
  user_age integer,
  clinic_address jsonb,
  doctor_title text,
  doctor_image text,
  doctor_specialty text,
  account_name text,
  booking_timestamp timestamp with time zone,
  doctor_name text,
  doctor_gender text DEFAULT 'MALE'::text,
  clinic text,
  is_docsera_user boolean DEFAULT false,
  booked_via text DEFAULT 'DocSera'::text,
  attachments jsonb,
  is_confirmed boolean DEFAULT false,
  relative_id uuid,
  reason_id uuid,
  location jsonb,
  status text DEFAULT 'not_arrived'::text,
  entered_at timestamp with time zone,
  report jsonb,
  duration integer DEFAULT 30,
  appointment_end_time time without time zone,
  manual_id uuid,
  is_billed boolean DEFAULT false,
  doctor_account_id uuid,
  CONSTRAINT appointments_pkey PRIMARY KEY (id),
  CONSTRAINT appointments_reason_id_fkey FOREIGN KEY (reason_id) REFERENCES public.appointment_reasons(id),
  CONSTRAINT appointments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT appointments_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT appointments_manual_id_fkey FOREIGN KEY (manual_id) REFERENCES public.doctor_patients(patient_id),
  CONSTRAINT appointments_relative_id_fkey FOREIGN KEY (relative_id) REFERENCES public.relatives(id)
);
CREATE TABLE public.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid,
  patient_id uuid,
  account_holder_name text,
  doctor_name text,
  doctor_specialty text,
  doctor_image text,
  has_doctor_responded boolean DEFAULT false,
  is_closed boolean DEFAULT false,
  last_message text,
  last_message_read_by_doctor boolean DEFAULT false,
  last_message_read_by_user boolean DEFAULT false,
  last_sender_id text,
  participants ARRAY,
  selected_reason text,
  unread_count_for_doctor integer,
  unread_count_for_user integer,
  updated_at timestamp with time zone DEFAULT now(),
  patient_name text,
  doctor_title text,
  doctor_gender text,
  is_blocked boolean DEFAULT false,
  reason_id uuid,
  relative_id uuid,
  source text,
  doctor_account_id uuid,
  CONSTRAINT conversations_pkey PRIMARY KEY (id),
  CONSTRAINT conversations_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.users(id),
  CONSTRAINT conversations_relative_id_fkey FOREIGN KEY (relative_id) REFERENCES public.relatives(id),
  CONSTRAINT conversations_reason_id_fkey FOREIGN KEY (reason_id) REFERENCES public.message_reasons(id),
  CONSTRAINT conversations_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.default_accounting_labels (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  label text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['income'::text, 'expense'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT default_accounting_labels_pkey PRIMARY KEY (id)
);
CREATE TABLE public.default_report_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  diagnosis text NOT NULL,
  recommendation text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT default_report_templates_pkey PRIMARY KEY (id)
);
CREATE TABLE public.doctor_account_patients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_account_id uuid NOT NULL,
  patient_type text NOT NULL CHECK (patient_type = ANY (ARRAY['user'::text, 'relative'::text, 'manual'::text])),
  patient_ref_id uuid NOT NULL,
  first_seen_at timestamp with time zone NOT NULL DEFAULT now(),
  last_seen_at timestamp with time zone NOT NULL DEFAULT now(),
  source text NOT NULL DEFAULT 'appointment'::text CHECK (source = ANY (ARRAY['appointment'::text, 'manual'::text])),
  CONSTRAINT doctor_account_patients_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_account_patients_doctor_account_id_fkey FOREIGN KEY (doctor_account_id) REFERENCES public.doctor_accounts(id)
);
CREATE TABLE public.doctor_accounts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL DEFAULT 'doctor'::text,
  name text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  primary_doctor_user_id uuid NOT NULL,
  CONSTRAINT doctor_accounts_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_accounts_primary_doctor_user_id_fkey FOREIGN KEY (primary_doctor_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.doctor_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_account_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  doctor_id uuid NOT NULL,
  CONSTRAINT doctor_members_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_members_doctor_account_id_fkey FOREIGN KEY (doctor_account_id) REFERENCES public.doctor_accounts(id),
  CONSTRAINT doctor_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT doctor_members_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.doctor_patient_blocks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL,
  patient_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  manual_key text,
  relative_id uuid,
  CONSTRAINT doctor_patient_blocks_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_patient_blocks_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT doctor_patient_blocks_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.users(id),
  CONSTRAINT doctor_patient_blocks_relative_id_fkey FOREIGN KEY (relative_id) REFERENCES public.relatives(id)
);
CREATE TABLE public.doctor_patient_links (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL,
  patient_type text NOT NULL CHECK (patient_type = ANY (ARRAY['user'::text, 'relative'::text, 'manual'::text])),
  patient_ref_id uuid NOT NULL,
  first_seen_at timestamp with time zone NOT NULL DEFAULT now(),
  last_seen_at timestamp with time zone NOT NULL DEFAULT now(),
  source text NOT NULL DEFAULT 'appointment'::text CHECK (source = ANY (ARRAY['appointment'::text, 'manual'::text])),
  CONSTRAINT doctor_patient_links_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_patient_links_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.doctor_patients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid,
  patient_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  email text,
  phone_number text,
  gender text,
  date_of_birth date,
  user_age integer,
  visits jsonb,
  first_name text,
  last_name text,
  patient_name text,
  CONSTRAINT doctor_patients_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_patients_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.doctor_report_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL,
  title text NOT NULL,
  diagnosis text NOT NULL,
  recommendation text NOT NULL,
  order_index integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT doctor_report_templates_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_report_templates_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.doctor_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid,
  title text NOT NULL,
  type text NOT NULL DEFAULT 'manual'::text CHECK (type = ANY (ARRAY['manual'::text, 'weekly'::text, 'monthly'::text])),
  range_start date,
  range_end date,
  created_at timestamp with time zone DEFAULT now(),
  file_info jsonb,
  CONSTRAINT doctor_reports_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_reports_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.doctor_vacations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT doctor_vacations_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_vacations_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.doctors (
  id uuid NOT NULL,
  first_name text,
  last_name text,
  email text UNIQUE,
  phone_number text,
  gender text CHECK (gender = ANY (ARRAY['ذكر'::text, 'أنثى'::text])),
  title text,
  specialty text,
  specialties ARRAY,
  profile_description jsonb,
  doctor_image text,
  languages ARRAY,
  address jsonb,
  opening_hours jsonb,
  clinic text,
  created_at timestamp with time zone,
  last_updated timestamp with time zone,
  require_confirmation boolean DEFAULT true,
  gallery ARRAY,
  offered_services jsonb,
  faqs jsonb,
  location jsonb,
  avatar_crop jsonb,
  appointment_duration_minutes integer DEFAULT 30,
  appointment_scheduling_mode text DEFAULT 'default'::text,
  cancellation_deadline_hours integer DEFAULT 24,
  max_visibility_days integer NOT NULL DEFAULT 30,
  messages_enabled boolean DEFAULT true,
  messages_access text DEFAULT 'public'::text CHECK (messages_access = ANY (ARRAY['patients'::text, 'public'::text])),
  public_token text UNIQUE,
  doctor_account_id uuid,
  deactivated_by_user_id uuid,
  deactivated_by_role text,
  deactivated_at timestamp with time zone,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT doctors_pkey PRIMARY KEY (id),
  CONSTRAINT doctors_doctor_account_id_fkey FOREIGN KEY (doctor_account_id) REFERENCES public.doctor_accounts(id)
);
CREATE TABLE public.documents (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  patient_id uuid,
  name text,
  type text,
  file_type text,
  preview_url text,
  pages ARRAY,
  uploaded_at timestamp with time zone DEFAULT now(),
  uploaded_by_id uuid,
  came_from_conversation boolean DEFAULT false,
  conversation_doctor_name text,
  CONSTRAINT documents_pkey PRIMARY KEY (id),
  CONSTRAINT documents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.email_otp (
  email text NOT NULL,
  otp text,
  expires_at timestamp with time zone,
  CONSTRAINT email_otp_pkey PRIMARY KEY (email)
);
CREATE TABLE public.email_otps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  email text NOT NULL,
  code_hash text NOT NULL,
  purpose text NOT NULL DEFAULT 'signup_email_verify'::text,
  expires_at timestamp with time zone NOT NULL,
  consumed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT email_otps_pkey PRIMARY KEY (id)
);
CREATE TABLE public.login_otps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  phone_number text NOT NULL,
  code text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT login_otps_pkey PRIMARY KEY (id),
  CONSTRAINT login_otps_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.medical_master (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  category text NOT NULL CHECK (category = ANY (ARRAY['allergy'::text, 'chronic_disease'::text, 'surgery'::text, 'medication'::text, 'family_history'::text, 'vaccination'::text, 'other'::text])),
  type text,
  reference_system text,
  reference_code text,
  name_en text NOT NULL,
  name_ar text NOT NULL,
  description_en text,
  description_ar text,
  severity_allowed boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT medical_master_pkey PRIMARY KEY (id)
);
CREATE TABLE public.message_reasons (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL,
  label text NOT NULL,
  order_index integer,
  CONSTRAINT message_reasons_pkey PRIMARY KEY (id),
  CONSTRAINT message_reasons_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid,
  sender_name text,
  is_user boolean,
  text text,
  read_by_user boolean DEFAULT false,
  read_by_doctor boolean DEFAULT false,
  read_by_user_at timestamp with time zone,
  read_by_doctor_at timestamp with time zone,
  timestamp timestamp with time zone DEFAULT now(),
  attachments jsonb,
  sender_id uuid,
  sender_type text CHECK (sender_type = ANY (ARRAY['patient'::text, 'doctor'::text])),
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
);
CREATE TABLE public.notes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  title text,
  content jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notes_pkey PRIMARY KEY (id),
  CONSTRAINT notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.otp (
  phone text NOT NULL,
  otp text,
  expires_at timestamp with time zone,
  CONSTRAINT otp_pkey PRIMARY KEY (phone)
);
CREATE TABLE public.patient_medical_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  patient_id uuid,
  master_id uuid NOT NULL,
  source text NOT NULL DEFAULT 'patient'::text CHECK (source = ANY (ARRAY['patient'::text, 'doctor'::text, 'system'::text])),
  is_confirmed boolean NOT NULL DEFAULT false,
  severity text CHECK ((severity = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text])) OR severity IS NULL),
  start_date date,
  end_date date,
  notes_en text,
  notes_ar text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  relative_id uuid,
  confirmed_by_doctor_ids ARRAY NOT NULL DEFAULT '{}'::uuid[],
  created_by_doctor_id uuid,
  CONSTRAINT patient_medical_records_pkey PRIMARY KEY (id),
  CONSTRAINT patient_medical_records_relative_id_fkey FOREIGN KEY (relative_id) REFERENCES public.relatives(id),
  CONSTRAINT patient_medical_records_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.users(id),
  CONSTRAINT patient_medical_records_master_id_fkey FOREIGN KEY (master_id) REFERENCES public.medical_master(id),
  CONSTRAINT patient_medical_records_created_by_doctor_fkey FOREIGN KEY (created_by_doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.points_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  appointment_id uuid,
  points integer NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  doctor_name text,
  appointment_date date,
  appointment_time time without time zone,
  patient_name text,
  is_relative boolean,
  CONSTRAINT points_history_pkey PRIMARY KEY (id),
  CONSTRAINT points_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT points_history_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointments(id)
);
CREATE TABLE public.reason_time_slots (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  doctor_id uuid,
  reason_id uuid,
  day_of_week text,
  start_time time without time zone,
  end_time time without time zone,
  CONSTRAINT reason_time_slots_pkey PRIMARY KEY (id),
  CONSTRAINT reason_time_slots_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT reason_time_slots_reason_id_fkey FOREIGN KEY (reason_id) REFERENCES public.appointment_reasons(id)
);
CREATE TABLE public.relatives (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  first_name text,
  last_name text,
  email text,
  phone_number text,
  gender text,
  date_of_birth date,
  address jsonb,
  created_at timestamp with time zone DEFAULT now(),
  doctors ARRAY DEFAULT '{}'::uuid[],
  updated_at timestamp with time zone,
  is_active boolean NOT NULL DEFAULT true,
  deactivated_at timestamp with time zone,
  deactivated_by_user_id uuid,
  deactivated_by_role text,
  CONSTRAINT relatives_pkey PRIMARY KEY (id),
  CONSTRAINT relatives_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.team_profiles (
  doctor_member_id uuid NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  gender text CHECK (gender IS NULL OR (gender = ANY (ARRAY['ذكر'::text, 'أنثى'::text]))),
  email text,
  phone_number text,
  avatar_path text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT team_profiles_pkey PRIMARY KEY (doctor_member_id),
  CONSTRAINT team_profiles_doctor_member_id_fkey FOREIGN KEY (doctor_member_id) REFERENCES public.doctor_members(id)
);
CREATE TABLE public.todo_tasks (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  doctor_id uuid NOT NULL,
  text text NOT NULL,
  done boolean NOT NULL DEFAULT false,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT todo_tasks_pkey PRIMARY KEY (id),
  CONSTRAINT todo_tasks_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.user_devices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  token text NOT NULL,
  platform text NOT NULL CHECK (platform = ANY (ARRAY['ios'::text, 'android'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_devices_pkey PRIMARY KEY (id),
  CONSTRAINT user_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  first_name text,
  last_name text,
  email text UNIQUE,
  email_verified boolean DEFAULT false,
  phone_number text UNIQUE,
  phone_verified boolean DEFAULT false,
  date_of_birth date,
  gender text CHECK (gender = ANY (ARRAY['ذكر'::text, 'أنثى'::text])),
  favorites ARRAY,
  marketing_checked boolean DEFAULT false,
  terms_accepted boolean DEFAULT false,
  trusted_devices ARRAY,
  two_factor_auth_enabled boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  address jsonb,
  is_docsera_user boolean DEFAULT false,
  doctors ARRAY DEFAULT '{}'::uuid[],
  points integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  deactivated_at timestamp with time zone,
  deactivated_by_user_id uuid,
  deactivated_by_role text,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
