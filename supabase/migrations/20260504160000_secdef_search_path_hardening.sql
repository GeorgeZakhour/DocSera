-- Security hardening: pin SET search_path = public, pg_temp on every existing
-- SECURITY DEFINER function in the public schema.
--
-- Why: a SECURITY DEFINER function runs with the privileges of its owner.
-- If it references unqualified objects (e.g. "users" instead of "public.users"),
-- a malicious caller who created a temp object with the same name in pg_temp
-- could trick the function into operating on their object. Setting search_path
-- explicitly prevents this whole class of attacks (CVE-class: schema injection).
--
-- This migration is generated from the snapshot of SECURITY DEFINER functions
-- present at audit time (2026-05-04). New functions added later should set
-- search_path inline (e.g. SET search_path = public, pg_temp at function head).

BEGIN;
ALTER FUNCTION public.admin_reactivate_doctor(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.book_appointment_by_patient(uuid,timestamp with time zone,uuid,text,text,text,integer,boolean,jsonb,jsonb,text,text,text,text,text,text,uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.book_appointment_by_patient(uuid,timestamp with time zone,uuid,text,text,text,integer,boolean,jsonb,jsonb,text,text,text,text,text,text,text,uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.cancel_appointment_by_patient(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.cancel_appointment_by_patient(uuid,text) SET search_path = public, pg_temp;
ALTER FUNCTION public.check_email_context(text) SET search_path = public, pg_temp;
ALTER FUNCTION public.deactivate_my_doctor_account() SET search_path = public, pg_temp;
ALTER FUNCTION public.email_exists(text) SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_center_has_active_subscription(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_check_subscription_expiry() SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_count_center_doctors(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_count_center_staff(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_get_my_center_id() SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_get_subscription_status(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_has_center_role(uuid,member_role) SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_is_center_member(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_log_subscription_history() SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_populate_appointment_account_id() SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_update_updated_at() SET search_path = public, pg_temp;
ALTER FUNCTION public.remove_appointment_attachment(uuid,text) SET search_path = public, pg_temp;
ALTER FUNCTION public.reschedule_appointment_by_patient(uuid,timestamp with time zone) SET search_path = public, pg_temp;
ALTER FUNCTION public.reschedule_appointment_by_patient(uuid,timestamp with time zone,uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.rpc_cleanup_doctor_otps() SET search_path = public, pg_temp;
ALTER FUNCTION public.rpc_get_my_security_state() SET search_path = public, pg_temp;
ALTER FUNCTION public.rpc_get_my_user() SET search_path = public, pg_temp;
ALTER FUNCTION public.trg_set_message_sender() SET search_path = public, pg_temp;
ALTER FUNCTION public.trust_current_device(text) SET search_path = public, pg_temp;
ALTER FUNCTION public.add_appointment_attachment(uuid,jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.rpc_get_encryption_key() SET search_path = public, pg_temp;
ALTER FUNCTION public.trg_todo_task_completion() SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_deactivate_doctor(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.rpc_get_encryption_key_service() SET search_path = public, pg_temp;
ALTER FUNCTION public.trg_upsert_patient_links_from_appointments() SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_new_message() SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_can_manage_doctor_booking_blocks(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.search_global_patients(text,uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.rpc_cleanup_phone_otps() SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_check_no_show_auto_block() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_doctor_image_to_conversations() SET search_path = public, pg_temp;
ALTER FUNCTION public.fn_is_doctor_account_member(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.register_doctor(text,text,text,text,text,text,text,text,jsonb,jsonb,text) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_doctor_centers(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_active_popups(text,text) SET search_path = public, pg_temp;
ALTER FUNCTION public.generate_referral_code(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.check_referral_abuse(uuid,text,text) SET search_path = public, pg_temp;
ALTER FUNCTION public.redeem_offer(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_user_vouchers(text) SET search_path = public, pg_temp;
ALTER FUNCTION public.verify_voucher(text,text) SET search_path = public, pg_temp;
ALTER FUNCTION public.complete_referral(text,uuid,text,text) SET search_path = public, pg_temp;
ALTER FUNCTION public.process_pending_points() SET search_path = public, pg_temp;
ALTER FUNCTION public.get_my_referral_info() SET search_path = public, pg_temp;
ALTER FUNCTION public.create_doctor_promotion(uuid,text,text,text,text,text,numeric,text,integer,integer,timestamp with time zone,timestamp with time zone) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_promotion_analytics(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.create_doctor_promotion(uuid,text,text,text,text,text,numeric,text,integer,integer,integer,timestamp with time zone,timestamp with time zone) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_promotion_billing_analytics(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_promotion_claim_status() SET search_path = public, pg_temp;
ALTER FUNCTION public.verify_doctor_promotion_voucher(text) SET search_path = public, pg_temp;
ALTER FUNCTION public.complete_referral(uuid,text,text,text) SET search_path = public, pg_temp;
COMMIT;
