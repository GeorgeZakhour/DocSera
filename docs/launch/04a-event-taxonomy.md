# 04a — Event Taxonomy (the contract)

This is the canonical reference for every analytics event the DocSera app emits. It is the contract between client code and the data layer. **Adding an event without registering it here AND in `analytics_event_catalog.dart` causes the SDK to drop it.**

## Conventions

- **Event name**: `lower_snake_case`. Past tense for completed actions (`booking_confirmed`), present tense for views (`doctor_profile_viewed`).
- **Category**: groups events for filtering. Used in dashboards and SQL views.
- **Required properties**: SDK drops the event if missing. Marked **bold** below.
- **Allowed properties**: SDK silently drops any property key not on this list.
- **Property values**: must be primitive (string ≤200 chars, num, bool). PII patterns (phone, email) are stripped at three layers.

## Auto-events (emitted by the SDK with no app code required)

| Event | Category | Properties | Fires when |
|---|---|---|---|
| `app_opened` | app | `cold_start` | Every cold start (init) |
| `app_foregrounded` | app | — | App returns to foreground |
| `app_backgrounded` | app | `foreground_duration_seconds_bucket` | App goes to background |
| `session_start` | app | `session_id` | New session begins (cold start or 30min+ background) |
| `session_end` | app | `session_id`, `duration_seconds_bucket`, `reason` | Session ends |
| `screen_viewed` | app | **`screen_name`**, `previous_screen_name` | Every named-route navigation |
| `onboarding_completed` | app | `steps_seen` | First-run onboarding finishes |

## Auth (14 events)

| Event | Properties | Fires when |
|---|---|---|
| `signup_started` | `method` | User taps "Sign up" |
| `signup_completed` | `method` | New account is created |
| `signup_failed` | `method`, `error_code` | Signup RPC errors |
| `login_started` | `method` | User taps "Login" |
| `login_completed` | `method` | Auth state becomes Authenticated |
| `login_failed` | `method`, `error_code` | Auth fails |
| `logout` | — | User signs out |
| `otp_requested` | **`channel`**, `context` | OTP send is initiated. `channel`: `phone`/`email`. `context`: `login`/`signup`/`change_phone`/etc. |
| `otp_verified` | `channel`, `context`, `attempts` | OTP entered correctly |
| `otp_failed` | `channel`, `context`, `error_code`, `attempts` | OTP entry fails or send fails |
| `otp_resent` | `channel`, `attempt_number` | User taps Resend |
| `biometric_prompted` | `biometric_type` | OS biometric sheet shown |
| `biometric_succeeded` | `biometric_type` | OS reports success |
| `biometric_failed` | `biometric_type`, `error_code` | OS reports failure |

## Search & discovery (9 events)

| Event | Properties |
|---|---|
| `search_started` | `source` (`home`/`message`/`deep_link`) |
| `search_filter_applied` | `filter_type`, `filter_value` |
| `search_filter_cleared` | `filter_type` |
| `search_results_viewed` | `results_count_bucket`, `has_results` |
| `search_no_results_shown` | — |
| `search_result_clicked` | `doctor_id`, `position_bucket`, `list_type` |
| `map_view_opened` | — |
| `map_pin_clicked` | `doctor_id` |
| `recent_search_clicked` | — |

## Doctor profile (11 events)

| Event | Properties |
|---|---|
| `doctor_profile_viewed` | **`doctor_id`**, `source`, `specialty_id` |
| `doctor_profile_scrolled_to_bottom` | `doctor_id` |
| `doctor_phone_clicked` | **`doctor_id`** |
| `doctor_email_clicked` | `doctor_id` |
| `doctor_address_clicked` | `doctor_id` |
| `doctor_directions_opened` | `doctor_id` |
| `doctor_share_clicked` | `doctor_id`, `share_method` |
| `doctor_favorited` | **`doctor_id`** |
| `doctor_unfavorited` | **`doctor_id`** |
| `doctor_review_section_viewed` | `doctor_id` |
| `doctor_schedule_viewed` | `doctor_id` |

## Booking funnel (9 events)

| Event | Properties |
|---|---|
| `booking_started` | **`doctor_id`**, `source` |
| `booking_reason_selected` | `doctor_id`, `reason_id` |
| `booking_patient_selected` | `doctor_id`, `patient_kind` (`self`/`relative`) |
| `booking_date_viewed` | `doctor_id`, `days_offset_bucket` |
| `booking_slot_picked` | `doctor_id`, `slot_offset_days_bucket`, `slot_hour_bucket` |
| `booking_review_shown` | `doctor_id` |
| `booking_confirmed` | **`doctor_id`**, `appointment_id`, `reason_id`, `patient_kind` |
| `booking_failed` | `doctor_id`, `error_code` |
| `booking_abandoned` | `doctor_id`, `last_step_reached` |

## Appointment lifecycle (5 events)

| Event | Properties |
|---|---|
| `appointment_viewed` | `appointment_id` |
| `appointment_rescheduled` | `appointment_id` |
| `appointment_cancelled` | `appointment_id`, `cancellation_reason_id` |
| `appointment_reminder_received` | `appointment_id`, `minutes_before` |
| `appointment_review_submitted` | `appointment_id`, `rating` |

## Messaging (6 events)

| Event | Properties |
|---|---|
| `conversation_list_viewed` | — |
| `conversation_opened` | `conversation_id` |
| `message_sent` | `conversation_id`, `length_bucket`, `has_attachment` |
| `message_failed` | `conversation_id`, `error_code` |
| `attachment_sent` | `conversation_id`, `attachment_type`, `size_bucket` |
| `voice_message_sent` | `conversation_id`, `duration_seconds_bucket` |

## Documents (6 events)

| Event | Properties |
|---|---|
| `documents_tab_viewed` | — |
| `document_uploaded` | `document_type`, `source`, `size_bucket` |
| `document_viewed` | `document_id`, `document_type` |
| `document_downloaded` | `document_id`, `document_type` |
| `document_shared` | `document_id`, `share_method` |
| `document_deleted` | `document_id` |

## Loyalty / Offers / Vouchers / Partners (16 events)

| Event | Properties |
|---|---|
| `loyalty_tab_viewed` | — |
| `points_history_viewed` | — |
| `points_earned` | `source`, `amount_bucket` |
| `points_redeemed` | `offer_id`, `points_spent_bucket` |
| `offer_viewed` | **`offer_id`**, `partner_id`, `position_bucket`, `list_context` |
| `offer_clicked` | **`offer_id`**, `partner_id`, `position_bucket` |
| `offer_redeemed` | **`offer_id`**, `partner_id`, `voucher_id` |
| `voucher_received` | `voucher_id`, `offer_id`, `partner_id`, `source` |
| `voucher_viewed` | `voucher_id` |
| `voucher_used` | **`voucher_id`**, `partner_id` |
| `voucher_expired` | `voucher_id` |
| `voucher_shared` | `voucher_id`, `share_method` |
| `partner_profile_viewed` | **`partner_id`**, `source` |
| `partner_phone_clicked` | **`partner_id`** |
| `partner_address_clicked` | `partner_id` |
| `partner_directions_opened` | `partner_id` |

## Referrals (4 events)

| Event | Properties |
|---|---|
| `referral_screen_viewed` | — |
| `referral_link_copied` | — |
| `referral_link_shared` | `channel` |
| `referral_reward_earned` | `amount_bucket` |

## Health profile (5 events)

| Event | Properties |
|---|---|
| `health_profile_viewed` | — |
| `health_profile_edited` | `field_type` |
| `relative_added` | — |
| `relative_removed` | — |
| `patient_switched` | `to_kind` |

## Account & Settings (9 events)

| Event | Properties |
|---|---|
| `account_tab_viewed` | — |
| `profile_edited` | `field_type` |
| `language_changed` | `from`, `to` |
| `notifications_settings_changed` | `channel`, `enabled` |
| `biometric_settings_changed` | `enabled` |
| `account_deletion_started` | — |
| `account_deletion_completed` | — |
| `support_contacted` | `channel` |
| `app_rated` | `rating`, `where_prompted` |

## Banners / Popups / Push (9 events)

| Event | Properties |
|---|---|
| `banner_viewed` | `banner_id`, `position` |
| `banner_clicked` | `banner_id`, `action` |
| `banner_dismissed` | `banner_id` |
| `popup_shown` | `popup_id`, `type` |
| `popup_action_taken` | `popup_id`, `action` |
| `popup_dismissed` | `popup_id` |
| `push_received` | `notification_type` |
| `push_opened` | `notification_type` |
| `deep_link_followed` | `path_kind` |

## Errors / UX (4 events)

| Event | Properties |
|---|---|
| `error_shown` | `error_code`, `screen` |
| `offline_banner_shown` | — |
| `form_validation_failed` | `form_id`, `field_id`, `error_type` |
| `empty_state_shown` | `screen`, `type` |

---

## Property value standards

### Buckets (privacy-preserving aggregation)

We never log raw counts/durations directly — they're bucketed to coarse strings. This keeps the data resistant to fingerprinting and queries simpler.

| Bucket name | Values |
|---|---|
| `position_bucket` | `1`, `2-3`, `4-10`, `11-20`, `21+` |
| `results_count_bucket` | `0`, `1-5`, `6-20`, `21-50`, `50+` |
| `slot_offset_days_bucket` | `0`, `1`, `2-3`, `4-7`, `8-14`, `15-30`, `30+` |
| `slot_hour_bucket` | `early` (6-9), `morning` (9-12), `afternoon` (12-17), `evening` (17-21), `night` (21-6) |
| `duration_seconds_bucket` | `0-5`, `5-15`, `15-30`, `30-60`, `1-3m`, `3-10m`, `10-30m`, `30-60m`, `60m+` |
| `length_bucket` | `short` (<50 chars), `medium` (50-200), `long` (200+) — message length |
| `size_bucket` | `tiny` (<100KB), `small` (100KB-1MB), `medium` (1-5MB), `large` (5MB+) |
| `amount_bucket` | `<10`, `10-50`, `51-100`, `101-500`, `500+` |
| `age_bucket` | `<18`, `18-25`, `26-35`, `36-50`, `51-65`, `65+` |

### Enums

Stable, low-cardinality strings for filtering. Examples:

| Property | Allowed values |
|---|---|
| `channel` | `phone`, `email`, `whatsapp`, `sms`, `copy`, `other` |
| `source` | `home`, `search`, `deep_link`, `notification`, `recommendation`, `favorites`, `recent` |
| `patient_kind` | `self`, `relative` |
| `share_method` | `copy`, `whatsapp`, `sms`, `system_share`, `other` |
| `attachment_type` | `image`, `document`, `audio`, `video`, `other` |
| `error_code` | `network`, `timeout`, `server`, `validation`, `not_found`, `forbidden`, `slot_already_booked`, `invalid_otp`, `rpc_error`, `unknown` |
| `biometric_type` | `face_id`, `fingerprint`, `iris`, `passcode`, `unknown` |

When in doubt: prefer fewer, broader enum values over many specific ones. We can always split later via property-mining queries.

## Stage 3 instrumentation status

This document lists 133 events. Stage 3 has wired ~10 of the highest-value paths so you see real data immediately:

| Wired in Stage 3 | File |
|---|---|
| `otp_requested`, `otp_verified`, `otp_failed` | `lib/screens/auth/login/login_otp.dart` |
| `booking_confirmed`, `booking_failed` | `lib/screens/doctors/appointment/appointment_confirm.dart` |
| `doctor_profile_viewed`, `doctor_phone_clicked`, `doctor_email_clicked`, `doctor_share_clicked`, `doctor_favorited`, `doctor_unfavorited` | `lib/screens/doctors/doctor_profile_page.dart` |
| `search_started` | `lib/screens/search_page.dart` |
| `partner_profile_viewed` | `lib/screens/home/loyalty/partner_profile_page.dart` |
| `offer_clicked` | `lib/screens/home/loyalty/offer_detail_page.dart` |
| `voucher_viewed` | `lib/screens/home/loyalty/voucher_detail_page.dart` |
| `login_completed` | `lib/main.dart` (AuthCubit listener) |
| Auto-events (`app_opened`, `app_foregrounded`, `app_backgrounded`, `session_start`, `session_end`, `screen_viewed`) | SDK auto-emits |

Remaining ~115 events have schemas registered in the catalog and can be wired by adding one line per call site:

```dart
Analytics.instance.track(Events.<eventName>, {'<prop>': value});
```

The catalog enforces correctness; if you misspell a property key or miss a required one, the SDK drops the event with a debug warning — you'll catch it the first time you run.
